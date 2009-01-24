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

-- Maximum number of non-registered users, -1 = no limit, 0 = no unregistered users allowed
local max_users = -1

-- Users with level lower than the specified will not be allowed to run command at all
local command_min_levels = {
--	[adchpp.AdcCommand_CMD_MSG] = 2
}

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

local stats = { }

local cm = adchpp.getCM()

function hasbit(x, p) return x % (p + p) >= p end

local function load_users()
	users.cids = { }
	users.nicks = { }

	local file = io.open(users_file, "r")
	if not file then 
		print("Unable to open " .. users_file ..", users not loaded")
		return 
	end

	str = file:read("*a")
	file:close()
	
	if #str == 0 then
		return
	end
	
	local userok, userlist = base.pcall(json.decode, str)
	if not userok then
		print("Unable to decode users file: " .. userlist)
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
		print("Unable to open " .. users_file .. ", users not saved")
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

	local count = cm:getClients():size()
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
		print("Can't register user with neither nick nor cid")
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
		return autil.handled
	end
	
	if #cmd:getParam("CT", 0) > 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "I decide what type you are")
		return autil.handled
	end
	
	if #cmd:getParam("OP", 0) > 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "I decide who's an OP")
		return autil.handled
	end
	
	if #cmd:getParam("RG", 0) > 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "I decide who's registered")
		return autil.handled
	end
	
	if #cmd:getParam("HU", 0) > 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "I'm the hub, not you")
		return autil.handled
	end
	
	if #cmd:getParam("BO", 0) > 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "You're not a bot")
		return autil.handled
	end
	
	if c:getState() == adchpp.Client_STATE_NORMAL then
		return 0
	end
	
	local nick = cmd:getParam("NI", 0)
	local cid = cmd:getParam("ID", 0)
	
	if #nick == 0 or #cid == 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "No valid nick/CID supplied")
		return autil.handled
	end
	
	local user = get_user(cid, nick)
	if not user then
		local code, err = check_max_users()
		if code then
			autil.dump(c, code, err)
			return autil.handled
		end
		return 0
	end

	if user.level > 1 then
		cmd:addParam("CT4")
		cmd:addParam("OP1") -- old name
	else
		cmd:addParam("CT2")
		cmd:addParam("RG1") -- old name
	end

	if not cm:verifyINF(c, cmd) then
		return autil.handled
	end
	
	salts[c:getSID()] = cm:enterVerify(c, true)
	return autil.handled
end

local function onPAS(c, cmd)
	if c:getState() ~= adchpp.Client_STATE_VERIFY then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Not in VERIFY state")
		return autil.handled
	end
	
	local salt = salts[c:getSID()]
	
	if not salt then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "You didn't get any salt?")
		return autil.handled
	end
	
	local cid = c:getCID()
	local nick = c:getField("NI")
	
	local user = get_user(c:getCID():toBase32(), c:getField("NI"))
	if not user then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Can't find you now")
		return autil.handled
	end
	
	local password = ""
	if user.password then
		password = user.password
	end

	if not cm:verifyPassword(c, password, salt, cmd:getParam(0)) then
		autil.dump(c, adchpp.AdcCommand_ERROR_BAD_PASSWORD, "Invalid password")
		return autil.handled
	end
	
	local updateOk, message = update_user(user, cid:toBase32(), nick)
	if not updateOk then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, message)
		return autil.handled
	end
	
	if message then
		autil.reply(c, message)
	end
		
	autil.reply(c, "Welcome back")
	cm:enterNormal(c, true, true)
	
	if user.level > 1 and (c:supports("UCMD") or c:supports("UCM0")) then
		for k, v in base.pairs(user_commands) do
			ucmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_CMD, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
			ucmd:addParam(k)
			ucmd:addParam("TT", v)
			ucmd:addParam("CT", "2")
			c:send(ucmd)
		end
	end
	return autil.handled
end

local function formatSeconds(t)
	local t_d = math.floor(t / (60*60*24))
	local t_h = math.floor(t / (60*60)) % 24
	local t_m = math.floor(t / 60) % 60
	local t_s = t % 60

	return string.format("%d days, %d hours, %d minutes and %d seconds", t_d, t_h, t_m, t_s)
end

local function pairsByKeys (t, f)
	local a = {}
	for n in base.pairs(t) do table.insert(a, n) end
		table.sort(a, f)
		local i = 0      -- iterator variable
		local iter = function ()   -- iterator function
		i = i + 1
		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end
	end
	return iter
end

local function onMSG(c, cmd)
	msg = cmd:getParam(0)
	local command, parameters = msg:match("^%+(%a+) ?(.*)")

	if not command then
		return 0
	end

	add_stats('+' .. command)
	
	if command == "test" then
		autil.reply(c, "Test ok")
		return adchpp.ClientManager_DONT_SEND
	elseif command == "error" then
		xxxxyyyy()
		return adchpp.ClientManager_DONT_SEND
	elseif command == "help" then
		autil.reply(c, "+test, +help, +regme password, +regnick nick password level")
		return adchpp.ClientManager_DONT_SEND
	elseif command == "regme" then
		if not parameters:match("%S+") then
			autil.reply(c, "You need to supply a password without whitespace")
			return adchpp.ClientManager_DONT_SEND
		end
		
		register_user(c:getCID():toBase32(), c:getField("NI"), parameters, 1)
				
		autil.reply(c, "You're now registered")
		return adchpp.ClientManager_DONT_SEND
	elseif command == "regnick" then
		local nick, password, level = parameters:match("^(%S+) (%S+) (%d+)")
		if not nick or not password or not level then
			autil.reply(c, "You must supply nick, password and level!")
			return adchpp.ClientManager_DONT_SEND
		end
		
		level = tonumber(level)
		
		other = cm:findByNick(nick)
		
		local cid
		if other then
			cid = other:getCID():toBase32()
		end
		
		my_user = get_user(c:getCID():toBase32(), c:getField("NI"))
		
		if not my_user then
			autil.reply(c, "Only registered users may register others")
			return adchpp.ClientManager_DONT_SEND
		end
		
		if level >= my_user.level then
			autil.reply(c, "You may only register to a lower level than your own")
			return adchpp.ClientManager_DONT_SEND
		end
		
		if level < 1 then
			autil.reply(c, "Level too low")
			return adchpp.ClientManager_DONT_SEND
		end
		
		register_user(cid, nick, password, level)

		autil.reply(c, nick .. " registered")
		
		if other then
			autil.reply(other, "You've been registered with password " .. password)
		end

		return adchpp.ClientManager_DONT_SEND
	elseif command == "stats" then
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
		str = str .. adchpp.Util_formatBytes(queued) .. "\tBytes queued (" .. adchpp.Util_formatBytes(queued / cm:getClients():size()) .. "/user)\n"
		str = str .. adchpp.Util_formatBytes(queueBytes) .. "\tTotal bytes queued (" .. adchpp.Util_formatBytes(queueBytes/hubtime) .. "/s)\n"
		str = str .. queueCalls .. "\tQueue calls (" .. adchpp.Util_formatBytes(queueBytes/queueCalls) .. "/call)\n"
		str = str .. adchpp.Util_formatBytes(sendBytes) .. "\tTotal bytes sent (" .. adchpp.Util_formatBytes(sendBytes/hubtime) .. "/s)\n"
		str = str .. sendCalls .. "\tSend calls (" .. adchpp.Util_formatBytes(sendBytes/sendCalls) .. "/call)\n"
		str = str .. adchpp.Util_formatBytes(recvBytes) .. "\tTotal bytes received (" .. adchpp.Util_formatBytes(recvBytes/hubtime) .. "/s)\n"
		str = str .. recvCalls .. "\tReceive calls (" .. adchpp.Util_formatBytes(recvBytes/recvCalls) .. "/call)\n"
		
		autil.reply(c, str)
		return adchpp.ClientManager_DONT_SEND
	end
	
	return 0
end

local function onDSC(c, cmd)
	sid = cmd:getParam(0)
	
	victim = cm:getClient(adchpp.AdcCommand_toSID(sid))
	if not victim then
		autil.reply(c, "Victim not found")
		return autil.handled
	end
	
	victim:disconnect()
	autil.reply(c, "Victim disconnected")
	return autil.handled
end

local function onReceive(c, cmd, override)
	add_stats(cmd:getCommandString())

	if hasbit(override, adchpp.ClientManager_DONT_DISPATCH) then
		return 0
	end
	
	local allowed_type = command_contexts[cmd:getCommand()]
	if allowed_type then
		if not cmd:getType():match(allowed_type) then
			autil.reply(c, "Invalid context for " .. cmd:getCommandString())
			return autil.handled
		end
	end
	
	if c:getState() == adchpp.Client_STATE_NORMAL then
		local allowed_level = command_min_levels[cmd:getCommand()]
		if allowed_level then
			user = get_user(c:getCID(), c:getField("NI"))
			if not user or user.level < allowed_level then
				autil.reply(c, "You don't have access to " .. cmd:getCommandString())
				return autil.handled
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
	return 0
end

local function onDisconnected(c)
	salts[c] = nil
end

base.pcall(load_users)

conn = cm:signalReceive():connect(onReceive)
dis = cm:signalDisconnected():connect(onDisconnected)
