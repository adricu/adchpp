-- TODO
-- Fix error types

require("luadchpp")

adchpp = luadchpp

-- Configuration
local users_file = adchpp.Util_getCfgPath() .. "users.txt"

local command_min_levels = {
--	[adchpp.CMD_DSC] = 2
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
local context_send = "[BFD]"

local command_contexts = {
	[adchpp.AdcCommand_CMD_STA] = context_hub,
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

io = require('io')
os = require('os')
json = require('json')
string = require('string')

local start_time = os.time()
local salts = { }
local users = { }
users.nicks = { }
users.cids = { }

local stats = { }

local cm = adchpp.getCM()

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
	
	local userok, userlist = pcall(json.decode, str)
	if not userok then
		print("Unable to decode users file: " .. userlist)
		return
	end
	
	for k, user in pairs(userlist) do
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
	for k, user in pairs(users.cids) do
		userlist[i] = user
		if user.nick then
			nicksdone[user] = 1
		end
		i = i + 1
	end
	
	for k, user in pairs(users.nicks) do
		if not nicksdone[user] then
			userlist[i] = user
			i = i + 1
		end
	end
	
	file:write(json.encode(userlist))
	file:close()
end

local function make_user(cid, nick, password, level)
	local user = { cid = cid, nick = nick, password = password, level = level }
	return user
end

local function dump(c, code, msg)
	answer = adchpp.AdcCommand(adchpp.CMD_STA, adchpp.TYPE_INFO, adchpp.HUB_SID)
	answer:addParam("" .. adchpp.SEV_FATAL .. code):addParam(msg)
	c:send(answer)
	c:disconnect()
end

local function reply(c, msg)
	answer = adchpp.AdcCommand(adchpp.CMD_MSG, adchpp.TYPE_INFO, adchpp.HUB_SID)
	answer:addParam(msg)
	c:send(answer)
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
	
	user = make_user(cid, nick, password, level)
	if nick then
		users.nicks[nick] = user
	end
	if cid then
		users.cids[cid] = user
	end

	save_users()
end

local command_processed = adchpp.ClientManager_DONT_DISPATCH + adchpp.ClientManager_DONT_SEND

local function onINF(c, cmd)
	
	for field, regex in pairs(inf_fields) do
		val = cmd:getParam(field, 0)
		if #val > 0 and hasVal and not val:match(regex) then
			print("Bad INF " .. field)
			reply(c, "Field " .. field .. " has an invalid value, removed")
			cmd:delParam(field, 0)
		end
	end

	if #cmd:getParam("HI", 0) > 0 then
		dump(c, adchpp.ERROR_PROTOCOL_GENERIC, "Don't hide")
		return command_processed
	end
	
	if #cmd:getParam("OP", 0) > 0 then
		dump(c, adchpp.ERROR_PROTOCOL_GENERIC, "I decide who's an OP")
		return command_processed
	end
	
	if #cmd:getParam("RG", 0) > 0 then
		dump(c, adchpp.ERROR_PROTOCOL_GENERIC, "I decide who's registered")
		return command_processed
	end
	
	if #cmd:getParam("HU", 0) > 0 then
		dump(c, adchpp.ERROR_PROTOCOL_GENERIC, "I'm the hub, not you")
		return command_processed
	end
	
	if #cmd:getParam("BO", 0) > 0 then
		dump(c, adchpp.ERROR_PROTOCOL_GENERIC, "You're not a bot")
		return command_processed
	end
	
	if c:getState() == adchpp.STATE_NORMAL then
		return 0
	end
	
	local nick = cmd:getParam("NI", 0)
	local cid = cmd:getParam("ID", 0)
	
	if #nick == 0 or #cid == 0 then
		dump(c, adchpp.ERROR_PROTOCOL_GENERIC, "No valid nick/CID supplied")
		return command_processed
	end
	
	local user = get_user(cid, nick)
	if not user then
		return 0
	end

	if user.level > 1 then
		cmd:addParam("OP1")
	else
		cmd:addParam("RG1")
	end

	if not cm:verifyINF(c, cmd) then
		return command_processed
	end
	
	salts[c:getSID()] = cm:enterVerify(c, true)
	return command_processed
end

local function onPAS(c, cmd)
	if c:getState() ~= adchpp.STATE_VERIFY then
		dump(c, adchpp.ERROR_PROTOCOL_GENERIC, "Not in VERIFY state")
		return command_processed
	end
	
	local salt = salts[c:getSID()]
	
	if not salt then
		dump(c, adchpp.ERROR_PROTOCOL_GENERIC, "You didn't get any salt?")
		return command_processed
	end
	
	local cid = c:getCID()
	local nick = c:getField("NI")
	
	local user = get_user(c:getCID():toBase32(), c:getField("NI"))
	if not user then
		print("User sending PAS not found (?)")
		dump(c, adchpp.ERROR_PROTOCOL_GENERIC, "Can't find you now")
		return command_processed
	end
	
	local password = ""
	if user.password then
		password = user.password
	end

	if not cm:verifyPassword(c, password, salt, cmd:getParam(0)) then
		dump(c, adchpp.ERROR_BAD_PASSWORD, "Invalid password")
		return command_processed
	end
	
	local updateOk, message = update_user(user, cid:toBase32(), nick)
	if not updateOk then
		dump(c, adchpp.ERROR_PROTOCOL_GENERIC, message)
		return command_processed
	end
	
	if message then
		reply(c, message)
	end
		
	reply(c, "Welcome back")
	cm:enterNormal(c, true, true)
	
	if user.level > 1 and c:supports("UCMD") then
		for k, v in pairs(user_commands) do
			ucmd = adchpp.AdcCommand(adchpp.CMD_CMD, adchpp.TYPE_INFO, adchpp.HUB_SID)
			ucmd:addParam(k)
			ucmd:addParam("TT", v)
			ucmd:addParam("CT", "2")
			c:send(ucmd)
		end
	end
	return command_processed
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
	for n in pairs(t) do table.insert(a, n) end
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

	local stat = '+' .. command
	if stats[stat] then
		stats[stat] = stats[stat] + 1
	else
		stats[stat] = 1
	end
	
	if command == "test" then
		reply(c, "Test ok")
		return adchpp.DONT_SEND
	elseif command == "error" then
		xxxxyyyy()
		return adchpp.DONT_SEND
	elseif command == "help" then
		reply(c, "+test, +help, +regme password, +regnick nick password level")
		return adchpp.DONT_SEND
	elseif command == "regme" then
		if not parameters:match("%S+") then
			reply(c, "You need to supply a password without whitespace")
			return adchpp.DONT_SEND
		end
		
		register_user(c:getCID():toBase32(), c:getField("NI"), parameters, 1)
				
		reply(c, "You're now registered")
		return adchpp.DONT_SEND
	elseif command == "regnick" then
		local nick, password, level = parameters:match("^(%S+) (%S+) (%d+)")
		if not nick or not password or not level then
			reply(c, "You must supply nick, password and level!")
			return adchpp.DONT_SEND
		end
		
		level = tonumber(level)
		
		other = cm:findByNick(nick)
		
		local cid
		if other then
			cid = other:getCID():toBase32()
		end
		
		my_user = get_user(c:getCID():toBase32(), c:getField("NI"))
		
		if not my_user then
			reply(c, "Only registered users may register others")
			return adchpp.DONT_SEND
		end
		
		if level >= my_user.level then
			reply(c, "You may only register to a lower level than your own")
			return adchpp.DONT_SEND
		end
		
		if level < 1 then
			reply(c, "Level too low")
			return adchpp.DONT_SEND
		end
		
		register_user(cid, nick, password, level)

		reply(c, nick .. " registered")
		
		if other then
			reply(other, "You've been registered with password " .. password)
		end

		return adchpp.DONT_SEND
	elseif command == "stats" then
		local now = os.time()
		local scripttime = os.difftime(now, start_time)
		local hubtime = os.difftime(now, adchpp.Stats_startTime)
		
		str = "\n"
		str = str .. "Hub uptime: " .. formatSeconds(hubtime) .. "\n"
		str = str .. "Script uptime: " .. formatSeconds(scripttime) .. "\n"
		
		str = str .. "\nADC and script commands: \n"
		
		for k, v in pairs(stats) do
			str = str .. v .. "\t" .. k .. "\n"
		end
		
		str = str .. "\nDisconnect reasons: \n"
		for k, v in pairs(adchpp) do
			if k:sub(1, 7) == "REASON_" and k ~= "REASON_LAST" then
				str = str .. adchpp.size_t_getitem(adchpp.Util_reasons, adchpp[k]) .. "\t" .. k .. "\n"
			end
		end
		
		sm = adchpp.getSocketManager()
		a = sm:getAcceptErrors()
		r = sm:getReadErrors()
		w = sm:getWriteErrors()
		str = str .. "\nSocket errors: \n"
		str = str .. " - Accept errors: \n"
		for i = 0, a:size()-1 do
			e = a[i]
			str = str .. e.first .. "\t" .. e.second .. "\t" .. adchpp.Util_translateError(e.first) .. "\n"
		end
		str = str .. " - Read errors: \n"
		for i = 0, r:size()-1 do
			e = r[i]
			str = str .. e.first .. "\t" .. e.second .. "\t" .. adchpp.Util_translateError(e.first) .. "\n"
		end
		str = str .. " - Write errors: \n"
		for i = 0, w:size()-1 do
			e = w[i]
			str = str .. e.first .. "\t" .. e.second .. "\t" .. adchpp.Util_translateError(e.first) .. "\n"
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
		
		reply(c, str)
		return adchpp.DONT_SEND
	end
	
	return 0
end

local function onDSC(c, cmd)
	sid = cmd:getParam(0)
	
	victim = cm:getClient(adchpp.AdcCommand_toSID(sid))
	if not victim then
		print "Victim not found"
		return command_processed
	end
	
	victim:disconnect()
	reply(c, "Victim disconnected")
	return command_processed
end

local function onReceive(c, cmd, override)
	
	cmdstr = cmd:getCommandString()
	if stats[cmdstr] then
		stats[cmdstr] = stats[cmdstr] + 1
	else
		stats[cmdstr] = 1
	end

	if override > 0 then
		return 0
	end
	
	local allowed_type = command_contexts[cmd:getCommand()]
	if allowed_type then
		if not cmd:getType():match(allowed_type) then
			print("Invalid context for " .. cmd:getCommandString())
			reply(c, "Invalid context for " .. cmd:getCommandString())
			return command_processed
		end
	end
	
	if c:getState() == adchpp.STATE_NORMAL then
		local allowed_level = command_min_levels[cmd:getCommand()]
		if allowed_level then
			user = get_user(c:getCID(), c:getField("NI"))
			if not user or user.level < allowed_level then
				print("unallowed")
				reply(c, "You don't have access to " .. cmd:getCommandString())
				return command_processed
			end
		end
	end		
		
	if cmd:getCommand() == adchpp.CMD_INF then
		return onINF(c, cmd)
	elseif cmd:getCommand() == adchpp.CMD_PAS then
		return onPAS(c, cmd)
	elseif cmd:getCommand() == adchpp.CMD_MSG then
		return onMSG(c, cmd)
	elseif cmd:getCommandString() == "DSC" then
		return onDSC(c, cmd)
	end
	return 0
end

local function onDisconnected(c)
	salts[c] = nil
end

load_users()

local cm = adchpp.getCM()
conn = cm:signalReceive():connect(onReceive)
dis = cm:signalDisconnected():connect(onDisconnected)

