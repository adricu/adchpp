-- TODO
-- Fix error types

local base = _G

module("access")

base.require("luadchpp")

local adchpp = base.luadchpp
local string = base.require('string')

-- Configuration

-- Where to read/write user database
local users_file = adchpp.Util_getCfgPath() .. "users.txt"

-- Where to read/write the current topic
local topic_file = adchpp.Util_getCfgPath() .. "topic.txt"

-- Where to read/write ban database
local bans_file = adchpp.Util_getCfgPath() .. "bans.txt"

-- Maximum number of non-registered users, -1 = no limit, 0 = no unregistered users allowed
local max_users = -1

-- Users with level lower than the specified will not be allowed to run command at all
local command_min_levels = {
--	[adchpp.AdcCommand_CMD_MSG] = 2
}

-- Users with a level above the one specified here are operators
local level_op = 2

-- Regexes for the various fields. 
local cid_regex = "^" .. string.rep("[A-Z2-7]", 39) .. "$" -- No way of expressing exactly 39 chars without being explicit it seems
local pid_regex = cid_regex
local sid_regex = "^" .. string.rep("[A-Z2-7]", 4) .. "$"
local integer_regex = "^%d+$"
local bool_regex = "^[1]?$"

local inf_fields = {
	["ID"] = cid_regex,
	["PD"] = pid_regex,
	["I4"] = "^%d+%.%d+%.%d+%.%d+$",
	["I6"] = "^[%x:]+$", -- This could probably be made better...
	["U4"] = integer_regex,
	["U6"] = integer_regex,
	["SS"] = integer_regex,
	["SF"] = integer_regex,
	["US"] = integer_regex,
	["DS"] = integer_regex,
	["SL"] = integer_regex,
	["AS"] = integer_regex,
	["AM"] = integer_regex,
	["NI"] = "^[%S]+$", -- Wonder what this does to 8-bit codes...
	["HN"] = integer_regex,
	["HR"] = integer_regex,
	["HO"] = integer_regex,
	["OP"] = bool_regex,
	["AW"] = "^[12]$",
	["BO"] = bool_regex,
	["HI"] = bool_regex,
	["HU"] = bool_regex,
	["SU"] = "[A-Z,]+"
}

local context_hub = "[H]"
local context_bcast = "[BF]"
local context_direct = "[DE]"
local context_send = "[BFDE]"
local context_hubdirect = "[HDE]"

local command_contexts = {
	[adchpp.AdcCommand_CMD_STA] = context_hubdirect,
	[adchpp.AdcCommand_CMD_SUP] = context_hub,
	[adchpp.AdcCommand_CMD_SID] = context_hub,
	[adchpp.AdcCommand_CMD_INF] = context_bcast,
	[adchpp.AdcCommand_CMD_MSG] = context_send,
	[adchpp.AdcCommand_CMD_SCH] = context_send,
	[adchpp.AdcCommand_CMD_RES] = context_direct,
	[adchpp.AdcCommand_CMD_CTM] = context_direct,
	[adchpp.AdcCommand_CMD_RCM] = context_direct,
	[adchpp.AdcCommand_CMD_GPA] = context_hub,
	[adchpp.AdcCommand_CMD_PAS] = context_hub,
	[adchpp.AdcCommand_CMD_QUI] = context_hub,
	[adchpp.AdcCommand_CMD_GET] = context_hub,
	[adchpp.AdcCommand_CMD_GFI] = context_hub,
	[adchpp.AdcCommand_CMD_SND] = context_hub,
}

local user_commands = {
	Disconnect = "HDSC %[userSID]\n"
}

-- The rest

local io = base.require('io')
local os = base.require('os')
local json = base.require('json')
local autil = base.require('autil')
local table = base.require('table')
local math = base.require('math')

local start_time = os.time()

local salts = { }

local users = { }
users.nicks = { }
users.cids = { }

local topic

local bans = { }
bans.cids = { }
bans.ips = { }
bans.nicks = { }
bans.nicksre = { }
bans.msgsre = { }

local stats = { }

local cm = adchpp.getCM()

function hasbit(x, p) return x % (p + p) >= p end

local function load_users()
	users.cids = { }
	users.nicks = { }

	local file = io.open(users_file, "r")
	if not file then 
		base.print("Unable to open " .. users_file ..", users not loaded")
		return 
	end

	local str = file:read("*a")
	file:close()
	
	if #str == 0 then
		return
	end
	
	local userok, userlist = base.pcall(json.decode, str)
	if not userok then
		base.print("Unable to decode users file: " .. userlist)
		return
	end
	
	for k, user in base.pairs(userlist) do
		if user.cid then
			users.cids[user.cid] = user
		end
		if user.nick then
			users.nicks[user.nick] = user
		end
	end
end

local function save_users()
	local file = io.open(users_file, "w")
	if not file then
		base.print("Unable to open " .. users_file .. ", users not saved")
		return
	end
	
	local userlist = { }
	local nicksdone = { }
	
	local i = 1
	for k, user in base.pairs(users.cids) do
		userlist[i] = user
		if user.nick then
			nicksdone[user] = 1
		end
		i = i + 1
	end
	
	for k, user in base.pairs(users.nicks) do
		if not nicksdone[user] then
			userlist[i] = user
			i = i + 1
		end
	end
	
	file:write(json.encode(userlist))
	file:close()
end

local function set_topic()
	local hub = cm:getEntity(adchpp.AdcCommand_HUB_SID)
	hub:setField("DE", topic)
	cm:sendToAll(adchpp.AdcCommand(adchpp.AdcCommand_CMD_INF, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID):addParam("DE", topic):getBuffer())
end

local function load_topic()
	local file = io.open(topic_file, "r")
	if not file then
		base.print("Unable to open " .. topic_file ..", topic not loaded")
		return
	end

	topic = file:read("*a")
	file:close()

	set_topic()
end

local function save_topic()
	local file = io.open(topic_file, "w")
	if not file then
		base.print("Unable to open " .. topic_file .. ", topic not saved")
		return
	end

	file:write(topic)
	file:close()
end

local function load_bans()
	bans = { }
	bans.cids = { }
	bans.ips = { }
	bans.nicks = { }
	bans.nicksre = { }
	bans.msgsre = { }

	local file = io.open(bans_file, "r")
	if not file then
		base.print("Unable to open " .. bans_file ..", bans not loaded")
		return
	end

	local str = file:read("*a")
	file:close()

	if #str == 0 then
		return
	end

	local ok, list = base.pcall(json.decode, str)
	if not ok then
		base.print("Unable to decode bans file: " .. list)
		return
	end

	bans = list
	if not bans.cids then
		bans.cids = { }
	end
	if not bans.ips then
		bans.ips = { }
	end
	if not bans.nicks then
		bans.nicks = { }
	end
	if not bans.nicksre then
		bans.nicksre = { }
	end
	if not bans.msgsre then
		bans.msgsre = { }
	end

	clear_expired_bans()
end

local function save_bans()
	local file = io.open(bans_file, "w")
	if not file then
		base.print("Unable to open " .. bans_file .. ", bans not saved")
		return
	end

	file:write(json.encode(bans))
	file:close()
end

local function add_stats(stat)
	if stats[stat] then
		stats[stat] = stats[stat] + 1
	else
		stats[stat] = 1
	end
end

local function make_user(cid, nick, password, level)
	local user = { cid = cid, nick = nick, password = password, level = level }
	return user
end

local function check_max_users()
	if max_users == -1 then
		return
	end

	if max_users == 0 then
		return adchpp.AdcCommand_ERROR_REGGED_ONLY, "Only registered users are allowed in here"
	end

	local count = cm:getEntities():size()
	if count >= max_users then
		return adchpp.AdcCommand_ERROR_HUB_FULL, "Hub full, please try again later"
	end
	return
end

local function get_user(cid, nick)
	local user
	if cid then
		user = users.cids[cid]
	end
	
	if not user and nick then
		user = users.nicks[nick]		
	end
	return user
end

local function get_user_c(c)
	return get_user(c:getCID():toBase32(), c:getField("NI"))
end

local function update_user(user, cid, nick)
-- only one of nick and cid may be updated...
	if user.nick ~= nick then
		if users.nicks[nick] then
			-- new nick taken...
			return false, "Nick taken by another registered user"
		end
		
		if user.nick then
			users.nicks[user.nick] = nil
		end
		user.nick = nick
		users.nicks[user.nick] = user
		save_users()
		return true, "Registration data updated (new nick)"
	end
	
	if user.cid ~= cid then
		if users.cids[cid] then
			-- new cid taken...
			return false, "CID taken by another registered user"
		end
		
		if user.cid then
			users.cids[user.cid] = nil
		end
		
		user.cid = cid
		users.cids[user.cid] = user
		save_users()
		return true, "Registration data updated (new CID)"
	end
	
	return true
end

local function register_user(cid, nick, password, level)
	if not nick and not cid then
		base.print("Can't register user with neither nick nor cid")
	end
	
	local user = make_user(cid, nick, password, level)
	if nick then
		users.nicks[nick] = user
	end
	if cid then
		users.cids[cid] = user
	end

	save_users()
end

local function check_banner(c, no_reply)
	local banner = get_user(c:getCID():toBase32(), 0)
	if not banner or banner.level < level_op then
		if not no_reply then
			autil.reply(c, "Only operators can ban")
		end
		return false, 0
	end
	return true, banner.level
end

local function make_ban(level, reason, minutes)
	local ban = { level = level }
	if string.len(reason) > 0 then
		ban.reason = reason
	end
	if string.len(minutes) > 0 then
		ban.expires = os.time() + minutes * 60
	end
	return ban
end

local function ban_expiration_diff(ban)
	return os.difftime(ban.expires, os.time())
end

local function clear_expired_bans()
	local save = false

	for k_, ban_array in base.pairs(bans) do
		for k, ban in base.pairs(ban_array) do
			if ban.expires and ban_expiration_diff(ban) <= 0 then
				ban_array[k] = nil
				save = true
			end
		end
	end

	if save then
		save_bans()
	end
end

local function ban_expiration_string(ban)
	if ban.expires then
		local diff = ban_expiration_diff(ban)
		if diff > 0 then
			return "in " .. formatSeconds(diff)
		else
			return "expired"
		end
	else
		return "never"
	end
end

local function ban_info_string(ban)
	local str = "\tLevel: " .. ban.level
	if ban.reason then
		str = str .. "\tReason: " .. ban.reason
	end
	str = str .. "\tExpires: " .. ban_expiration_string(ban)
	return str
end

local function dump_banned(c, ban)
	local str = "You are banned (expires: " .. ban_expiration_string(ban) .. ")"
	if ban.reason then
		str = str .. " (reason: " .. reason .. ")"
	end
	autil.dump(c, adchpp.AdcCommand_ERROR_BANNED_GENERIC, str)
end

local function onINF(c, cmd)
	for field, regex in base.pairs(inf_fields) do
		val = cmd:getParam(field, 0)
		if #val > 0 and hasVal and not val:match(regex) then
			autil.reply(c, "Field " .. field .. " has an invalid value, removed")
			cmd:delParam(field, 0)
		end
	end

	if #cmd:getParam("HI", 0) > 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Don't hide")
		return false
	end
	
	if #cmd:getParam("CT", 0) > 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "I decide what type you are")
		return false
	end
	
	if #cmd:getParam("OP", 0) > 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "I decide who's an OP")
		return false
	end
	
	if #cmd:getParam("RG", 0) > 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "I decide who's registered")
		return false
	end
	
	if #cmd:getParam("HU", 0) > 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "I'm the hub, not you")
		return false
	end
	
	if #cmd:getParam("BO", 0) > 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "You're not a bot")
		return false
	end
	
	if c:getState() == adchpp.Entity_STATE_NORMAL then
		return true
	end
	
	local nick = cmd:getParam("NI", 0)
	local cid = cmd:getParam("ID", 0)
	
	if #nick == 0 or #cid == 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "No valid nick/CID supplied")
		return false
	end

	clear_expired_bans()
	local ban = nil
	if bans.cids[cid] then
		ban = bans.cids[cid]
	elseif bans.ips[c:getIp()] then
		ban = bans.ips[c:getIp()]
	elseif bans.nicks[nick] then
		ban = bans.nicks[nick]
	else
		for re, reban in base.pairs(bans.nicksre) do
			if nick:match(re) then
				ban = reban
				break
			end
		end
	end

	local user = get_user(cid, nick)
	if not user then
		-- non-reg user
		local code, err = check_max_users()
		if code then
			autil.dump(c, code, err)
			return false
		end

		-- check if banned
		if ban and ban.level > 0 then
			dump_banned(c, ban)
			return false
		end

		-- allow in
		return true
	end

	if ban and ban.level > user.level then
		dump_banned(c, ban)
		return false
	end

	if user.level >= level_op then
		cmd:addParam("CT4")
		cmd:addParam("OP1") -- old name
	else
		cmd:addParam("CT2")
		cmd:addParam("RG1") -- old name
	end

	if not cm:verifyINF(c, cmd) then
		return false
	end
	
	salts[c:getSID()] = cm:enterVerify(c, true)
	return false
end

local function onPAS(c, cmd)
	if c:getState() ~= adchpp.Entity_STATE_VERIFY then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Not in VERIFY state")
		return false
	end
	
	local salt = salts[c:getSID()]
	
	if not salt then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "You didn't get any salt?")
		return false
	end
	
	local cid = c:getCID()
	local nick = c:getField("NI")
	
	local user = get_user_c(c)
	if not user then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Can't find you now")
		return false
	end
	
	local password = ""
	if user.password then
		password = user.password
	end

	if not cm:verifyPassword(c, password, salt, cmd:getParam(0)) then
		autil.dump(c, adchpp.AdcCommand_ERROR_BAD_PASSWORD, "Invalid password")
		return false
	end
	
	local updateOk, message = update_user(user, cid:toBase32(), nick)
	if not updateOk then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, message)
		return false
	end
	
	if message then
		autil.reply(c, message)
	end

	autil.reply(c, "Welcome back")
	cm:enterNormal(c, true, true)

	if user.level >= level_op and (c:hasSupport(adchpp.AdcCommand_toFourCC("UCMD")) or
		c:hasSupport(adchpp.AdcCommand_toFourCC("UCM0"))) then
		for k, v in base.pairs(user_commands) do
			ucmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_CMD, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
			ucmd:addParam(k)
			ucmd:addParam("TT", v)
			ucmd:addParam("CT", "2")
			c:send(ucmd)
		end
	end
	return false
end

function formatSeconds(t)
	local t_d = math.floor(t / (60*60*24))
	local t_h = math.floor(t / (60*60)) % 24
	local t_m = math.floor(t / 60) % 60
	local t_s = t % 60

	return string.format("%d days, %d hours, %d minutes and %d seconds", t_d, t_h, t_m, t_s)
end

autil.commands.help = {
	command = function(c, parameters)
		-- TODO command-specific help if eg "+help mass"
		local list = { }
		for k, v in base.pairs(autil.commands) do
			if (not v.protected) or (v.protected and v.protected(c)) then
				local str = "+" .. k
				if v.help then
					str = str .. " " .. v.help
				end
				if v.alias then
					local list_alias = { }
					for k_alias, v_alias in base.pairs(v.alias) do
						table.insert(list_alias, "+" .. k_alias)
					end
					str = str .. " (aliases: " .. table.concat(list_alias, ", ") .. ")"
				end
				table.insert(list, str)
			end
		end
		table.sort(list)
		autil.reply(c, "Available commands:\n" .. table.concat(list, "\n"))
	end
}

autil.commands.info = {
	alias = { hubinfo = true, stats = true, userinfo = true },

	command = function(c, parameters)
		local str

		if #parameters > 0 then
			local user = cm:getEntity(cm:getSID(parameters)) -- by nick
			if not user then
				user = cm:getEntity(cm:getSID(adchpp.CID(parameters))) -- by CID
			end
			if not user then
				-- by IP
				local entities = cm:getEntities()
				local size = entities:size()
				if size > 0 then
					for i = 0, size - 1 do
						local user_c = entities[i]:asClient()
						if user_c and user_c:getIp() == parameters then
							user = entities[i]
							break
						end
					end
				end
			end

			if user then
				str = "\n"
				str = str .. "Nick: " .. user:getField("NI") .. "\n"
				str = str .. "CID: " .. user:getField("ID") .. "\n"
				str = str .. "IP: "
				local user_c = user:asClient()
				if user_c then
					str = str .. user_c:getIp()
				else
					str = str .. "unknown"
				end
				str = str .. "\n"
				-- TODO add more fields (share size, etc)
				else
				str = "No user found with a nick, CID or IP matching " .. parameters
			end

		else
			local now = os.time()
			local scripttime = os.difftime(now, start_time)
			local hubtime = os.difftime(now, adchpp.Stats_startTime)

			str = "\n"
			str = str .. "Hub uptime: " .. formatSeconds(hubtime) .. "\n"
			str = str .. "Script uptime: " .. formatSeconds(scripttime) .. "\n"

			str = str .. "\nADC and script commands: \n"
			for k, v in base.pairs(stats) do
				str = str .. v .. "\t" .. k .. "\n"
			end

			str = str .. "\nDisconnect reasons: \n"
			for k, v in base.pairs(adchpp) do
				if k:sub(1, 12) == "Util_REASON_" and k ~= "Util_REASON_LAST" then
					str = str .. adchpp.size_t_getitem(adchpp.Util_reasons, adchpp[k]) .. "\t" .. k:sub(6) .. "\n"
				end
			end

			local queued = cm:getQueuedBytes()
			local queueBytes = adchpp.Stats_queueBytes
			local queueCalls = adchpp.Stats_queueCalls
			local sendBytes = adchpp.Stats_sendBytes
			local sendCalls = adchpp.Stats_sendCalls
			local recvBytes = adchpp.Stats_recvBytes
			local recvCalls = adchpp.Stats_recvCalls

			str = str .. "\nBandwidth stats: \n"
			str = str .. adchpp.Util_formatBytes(queued) .. "\tBytes queued (" .. adchpp.Util_formatBytes(queued / cm:getEntities():size()) .. "/user)\n"
			str = str .. adchpp.Util_formatBytes(queueBytes) .. "\tTotal bytes queued (" .. adchpp.Util_formatBytes(queueBytes/hubtime) .. "/s)\n"
			str = str .. queueCalls .. "\tQueue calls (" .. adchpp.Util_formatBytes(queueBytes/queueCalls) .. "/call)\n"
			str = str .. adchpp.Util_formatBytes(sendBytes) .. "\tTotal bytes sent (" .. adchpp.Util_formatBytes(sendBytes/hubtime) .. "/s)\n"
			str = str .. sendCalls .. "\tSend calls (" .. adchpp.Util_formatBytes(sendBytes/sendCalls) .. "/call)\n"
			str = str .. adchpp.Util_formatBytes(recvBytes) .. "\tTotal bytes received (" .. adchpp.Util_formatBytes(recvBytes/hubtime) .. "/s)\n"
			str = str .. recvCalls .. "\tReceive calls (" .. adchpp.Util_formatBytes(recvBytes/recvCalls) .. "/call)\n"
		end

		autil.reply(c, str)
	end,

	help = "[nick or CID or IP] - information about a user, or about the hub if no parameter given"
}

autil.commands.listregs = {
	alias = { listreg = true, listregged = true, reggedusers = true, showreg = true, showregs = true, showregged = true },

	command = function(c, parameters)
		local user = get_user_c(c)
		if not user then
			autil.reply(c, "Only registered users can use this command")
			return
		end

		local str = "Registered users with a level >= " .. user.level .. ":\n"
		for k, v in base.pairs(users.nicks) do
			if v.level >= user.level then
				str = str .. "Nick: " .. k .. "\n"
			end
		end
		for k, v in base.pairs(users.cids) do
			if v.level >= user.level then
				str = str .. "CID: " .. k .. "\n"
			end
		end
		autil.reply(c, str)
	end,

	protected = function(c) return get_user_c(c) end
}

autil.commands.mass = {
	alias = { massmessage = true },

	command = function(c, parameters)
		local message, level = parameters:match("^(%S+) ?(%d*)")
		if not message then
			autil.reply(c, "You need to supply a message")
			return
		end
		if string.len(level) > 0 then
			level = base.tonumber(level)
		end

		local entities = cm:getEntities()
		local size = entities:size()
		if size == 0 then
			return
		end

		-- TODO we send PMs from the originator of the mass message; eventually, we should send these from a bot.
		local mass_cmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_ECHO, adchpp.AdcCommand_HUB_SID)
		mass_cmd:setFrom(c:getSID())
		mass_cmd:addParam(message)
		mass_cmd:addParam("PM", adchpp.AdcCommand_fromSID(mass_cmd:getFrom()))

		local count = 0
		for i = 0, size - 1 do
			local other = entities[i]:asClient()
			if other then
				local ok = string.len(level) == 0 or level <= 0
				if not ok then
					local user = get_user_c(other)
					ok = user and user.level >= level
				end

				if ok then
					mass_cmd:setTo(other:getSID())
					other:send(mass_cmd)
					count = count + 1
				end
			end
		end

		autil.reply(c, "Message sent to " .. count .. " users")
	end,

	help = "message [level]"
}

autil.commands.regme = {
	command = function(c, parameters)
		if not parameters:match("%S+") then
			autil.reply(c, "You need to supply a password without whitespace")
			return
		end

		register_user(c:getCID():toBase32(), c:getField("NI"), parameters, 1)

		autil.reply(c, "You're now registered")
	end,

	help = "password"
}

autil.commands.regnick = {
	command = function(c, parameters)
		local nick, password, level = parameters:match("^(%S+) (%S+) (%d+)")
		if not nick or not password or not level then
			autil.reply(c, "You must supply nick, password and level!")
			return
		end
		level = base.tonumber(level)

		local other = cm:findByNick(nick)

		local cid
		if other then
			cid = other:getCID():toBase32()
		end

		local my_user = get_user_c(c)

		if not my_user then
			autil.reply(c, "Only registered users may register others")
			return
		end

		if level >= my_user.level then
			autil.reply(c, "You may only register to a lower level than your own")
			return
		end

		if level < 1 then
			autil.reply(c, "Level too low")
			return
		end

		register_user(cid, nick, password, level)

		autil.reply(c, nick .. " registered")

		if other then
			autil.reply(other, "You've been registered with password " .. password)
		end
	end,

	help = "nick password level"
}

autil.commands.test = {
	command = function(c)
		autil.reply(c, "Test ok")
	end
}

autil.commands.topic = {
	alias = { changetopic = true, hubtopic = true, settopic = true },

	command = function(c, parameters)
		topic = parameters
		save_topic()
		set_topic()
	end,

	help = "[topic]"
}

autil.commands.ban = {
	alias = { banuser = true },

	command = function(c, parameters)
		local ok, level = check_banner(c)
		if not ok then
			return
		end

		local nick, reason, minutes = parameters:match("^(%S+) ?(%S*) ?(%d*)")
		if not nick then
			autil.reply(c, "You need to supply a nick")
			return
		end

		local victim = cm:getEntity(cm:getSID(nick))
		if victim then
			victim = victim:asClient()
		end
		if not victim then
			autil.reply(c, "No user nick-named \"" .. nick .. "\"")
			return
		end

		local victim_cid = victim:getCID():toBase32()
		local victim_user = get_user(victim_cid, 0)
		if victim_user and level <= victim_user.level then
			autil.reply(c, "You can't ban users whose level is higher or equal than yours")
			return
		end

		local ban = make_ban(level, reason, minutes)
		bans.cids[victim_cid] = ban
		save_bans()

		dump_banned(victim, ban)
		autil.reply(c, "\"" .. nick .. "\" (CID: " .. cid .. ") is now banned")
	end,

	help = "nick [reason] [minutes] - ban an online user",

	protected = function(c) return check_banner(c, true) end
}

autil.commands.bancid = {
	command = function(c, parameters)
		local ok, level = check_banner(c)
		if not ok then
			return
		end

		local cid, reason, minutes = parameters:match("^(%S+) ?(%S*) ?(%d*)")
		if not cid then
			autil.reply(c, "You need to supply a CID")
			return
		end

		bans.cids[cid] = make_ban(level, reason, minutes)
		save_bans()
	
		autil.reply(c, "The CID \"" .. cid .. "\" is now banned")
	end,

	help = "CID [reason] [minutes]",

	protected = function(c) return check_banner(c, true) end
}

autil.commands.banip = {
	command = function(c, parameters)
		local ok, level = check_banner(c)
		if not ok then
			return
		end

		local ip, reason, minutes = parameters:match("^(%S+) ?(%S*) ?(%d*)")
		if not ip then
			autil.reply(c, "You need to supply an IP address")
			return
		end

		bans.ips[ip] = make_ban(level, reason, minutes)
		save_bans()

		autil.reply(c, "The IP address \"" .. ip .. "\" is now banned")
	end,

	help = "IP [reason] [minutes]",

	protected = function(c) return check_banner(c, true) end
}

autil.commands.bannick = {
	command = function(c, parameters)
		local ok, level = check_banner(c)
		if not ok then
			return
		end

		local nick, reason, minutes = parameters:match("^(%S+) ?(%S*) ?(%d*)")
		if not nick then
			autil.reply(c, "You need to supply a nick")
			return
		end

		bans.nicks[nick] = make_ban(level, reason, minutes)
		save_bans()

		autil.reply(c, "The nick \"" .. nick .. "\" is now banned")
	end,

	help = "nick [reason] [minutes]",

	protected = function(c) return check_banner(c, true) end
}

autil.commands.bannickre = {
	command = function(c, parameters)
		local ok, level = check_banner(c)
		if not ok then
			return
		end

		local re, reason, minutes = parameters:match("^(.+) ?(%S*) ?(%d*)")
		if not re then
			autil.reply(c, "You need to supply a reg exp")
			return
		end

		bans.nicksre[re] = make_ban(level, reason, minutes)
		save_bans()

		autil.reply(c, "Nicks that match \"" .. re .. "\" are now banned")
	end,

	help = "nick-reg-exp [reason] [minutes]",

	protected = function(c) return check_banner(c, true) end
}

autil.commands.banmsgre = {
	command = function(c, parameters)
		local ok, level = check_banner(c)
		if not ok then
			return
		end

		local re, reason, minutes = parameters:match("^(.+) ?(%S*) ?(%d*)")
		if not re then
			autil.reply(c, "You need to supply a reg exp")
			return
		end

		bans.msgsre[re] = make_ban(level, reason, minutes)
		save_bans()

		autil.reply(c, "Messages that match \"" .. re .. "\" will get the user banned")
	end,

	help = "msg-reg-exp [reason] [minutes]",

	protected = function(c) return check_banner(c, true) end
}

autil.commands.listbans = {
	alias = { listban = true, listbanned = true, showban = true, showbans = true, showbanned = true },

	command = function(c)
		local ok, level = check_banner(c)
		if not ok then
			return
		end

		clear_expired_bans()

		local str = "\nCID bans:"
		for cid, ban in base.pairs(bans.cids) do
			str = str .. "\n\tCID: " .. cid .. ban_info_string(ban)
		end

		str = str .. "\n\nIP bans:"
		for ip, ban in base.pairs(bans.ips) do
			str = str .. "\n\tIP: " .. ip .. ban_info_string(ban)
		end

		str = str .. "\n\nNick bans:"
		for nick, ban in base.pairs(bans.nicks) do
			str = str .. "\n\tNick: " .. nick .. ban_info_string(ban)
		end

		str = str .. "\n\nNick bans (reg exp):"
		for nickre, ban in base.pairs(bans.nicksre) do
			str = str .. "\n\tReg exp: " .. nickre .. ban_info_string(ban)
		end

		str = str .. "\n\nMessage bans (reg exp):"
		for msgre, ban in base.pairs(bans.msgsre) do
			str = str .. "\n\tReg exp: " .. msgre .. ban_info_string(ban)
		end

		autil.reply(c, str)
	end,

	protected = function(c) return check_banner(c, true) end
}

autil.commands.loadbans = {
	alias = { reloadbans = true },

	command = function(c)
		local ok, level = check_banner(c)
		if not ok then
			return
		end

		base.pcall(load_bans)

		autil.reply(c, "Ban list reloaded")
	end,

	protected = function(c) return check_banner(c, true) end
}

local function onMSG(c, cmd)
	local msg = cmd:getParam(0)
	local command, parameters = msg:match("^%+(%a+) ?(.*)")

	if not command then
		clear_expired_bans()
		for re, reban in base.pairs(bans.msgsre) do
			if msg:match(re) then
				local ban = { level = reban.level, reason = reban.reason, expires = reban.expires }
				bans.cids[c:getCID():toBase32()] = ban
				save_bans()
				dump_banned(c, ban)
				return false
			end
		end

		return true
	end

	add_stats('+' .. command)

	for k, v in base.pairs(autil.commands) do
		if k == command or (v.alias and v.alias[command]) then
			v.command(c, parameters)
			return false
		end
	end

	return true
end

local function onDSC(c, cmd)
	local victim = cm:getClient(adchpp.AdcCommand_toSID(cmd:getParam(0)))
	if not victim then
		autil.reply(c, "Victim not found")
		return false
	end

	victim:disconnect()
	autil.reply(c, "Victim disconnected")
	return false
end

local function onReceive(entity, cmd, ok)
	add_stats(cmd:getCommandString())

	if not ok then
		return ok
	end

	local c = entity:asClient()
	if not c then
		return false
	end

	local allowed_type = command_contexts[cmd:getCommand()]
	if allowed_type then
		if not cmd:getType():match(allowed_type) then
			autil.reply(c, "Invalid context for " .. cmd:getCommandString())
			return false
		end
	end

	if c:getState() == adchpp.Entity_STATE_NORMAL then
		local allowed_level = command_min_levels[cmd:getCommand()]
		if allowed_level then
			local user = get_user_c(c)
			if not user or user.level < allowed_level then
				autil.reply(c, "You don't have access to " .. cmd:getCommandString())
				return false
			end
		end
	end

	if cmd:getCommand() == adchpp.AdcCommand_CMD_INF then
		return onINF(c, cmd)
	elseif cmd:getCommand() == adchpp.AdcCommand_CMD_PAS then
		return onPAS(c, cmd)
	elseif cmd:getCommand() == adchpp.AdcCommand_CMD_MSG then
		return onMSG(c, cmd)
	elseif cmd:getCommandString() == "DSC" then
		return onDSC(c, cmd)
	end
end

local function onDisconnected(c)
	salts[c:getSID()] = nil
end

base.pcall(load_users)
base.pcall(load_topic)
base.pcall(load_bans)

access_1 = cm:signalReceive():connect(function(entity, cmd, ok)
	local res = onReceive(entity, cmd, ok)
	if not res then
		cmd:setPriority(adchpp.AdcCommand_PRIORITY_IGNORE)
	end
	return res
end)
access_2 = cm:signalDisconnected():connect(onDisconnected)
