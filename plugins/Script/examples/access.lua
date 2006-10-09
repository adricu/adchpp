-- TODO
-- Fix error types

require("luadchpp")

adchpp = luadchpp

-- Temporary fixes for SWIG 1.3.29
adchpp.TYPE_BROADCAST = string.char(adchpp.TYPE_BROADCAST)
adchpp.TYPE_DIRECT = string.char(adchpp.TYPE_DIRECT)
adchpp.TYPE_ECHO = string.char(adchpp.TYPE_ECHO)
adchpp.TYPE_FEATURE = string.char(adchpp.TYPE_FEATURE)
adchpp.TYPE_INFO = string.char(adchpp.TYPE_INFO)
adchpp.TYPE_HUB = string.char(adchpp.TYPE_HUB)

-- Configuration
local users_file = adchpp.Util_getCfgPath() .. "users.txt"

local command_min_levels = {
	[adchpp.CMD_DSC] = 2
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
	[adchpp.CMD_STA] = context_hub,
	[adchpp.CMD_SUP] = context_hub,
	[adchpp.CMD_SID] = context_hub,
	[adchpp.CMD_INF] = context_bcast,
	[adchpp.CMD_MSG] = context_send,
	[adchpp.CMD_SCH] = context_send,
	[adchpp.CMD_RES] = context_direct,
	[adchpp.CMD_CTM] = context_direct,
	[adchpp.CMD_RCM] = context_direct,
	[adchpp.CMD_GPA] = context_hub,
	[adchpp.CMD_PAS] = context_hub,
	[adchpp.CMD_QUI] = context_hub,
	[adchpp.CMD_DSC] = context_hub,
	[adchpp.CMD_GET] = context_hub,
	[adchpp.CMD_GFI] = context_hub,
	[adchpp.CMD_SND] = context_hub,
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

local command_processed = adchpp.DONT_DISPATCH + adchpp.DONT_SEND

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
		if #cmd:getParam("NI", 0) > 0 or #cmd:getParam("ID", 0) > 0 or #cmd:getParam("PD", 0) > 0 then
			dump(c, adchpp.ERROR_PROTOCOL_GENERIC, "Nick/CID changes not supported, please reconnect")
			return command_processed
		end
		
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
	return command_processed
end

local function onMSG(c, cmd)
	msg = cmd:getParam(0)

	command, parameters = msg:match("^%+(%a+) ?(.*)")
	
	if not command then
		return 0
	end
		
	if command == "test" then
		reply(c, "Test ok")
		return adchpp.DONT_SEND
	end
	
	if command == "error" then
		xxxxyyyy()
		return adchpp.DONT_SEND
	end
	
	if command == "help" then
		reply(c, "+test, +help, +regme password, +regnick nick password level")
		return adchpp.DONT_SEND
	end
	
	if command == "regme" then
		if not parameters then
			reply(c, "You need to supply a password")
			return adchpp.DONT_SEND
		end
		
		if not parameters:match("%S+") then
			reply(c, "No whitespace allowed in password")
			return adchpp.DONT_SEND
		end
		
		register_user(c:getCID():toBase32(), c:getField("NI"), parameters, 1)
				
		reply(c, "You're now registered")
		return adchpp.DONT_SEND
	end
	
	if command == "regnick" then
		local nick, password, level = parameters:match("^(%S+) (%S+) (%d+)")
		if not nick or not password or not level then
			reply(c, "You must supply nick, password and level!")
			return adchpp.DONT_SEND
		end
		
		level = tonumber(level)
		
		other = cm:getClientByNick(nick)
		
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
	end
	
	if command == "stats" then
		local uptime = os.difftime(os.time(), start_time)
		local uptime_d = math.floor(uptime / (60*60*24))
		local uptime_h = math.floor(uptime / (60*60)) % 24
		local uptime_m = math.floor(uptime / 60) % 60
		local uptime_s = uptime % 60
		
		str = "\nScript uptime: " .. string.format("%d days, %d hours, %d minutes and %d seconds\n", uptime_d, uptime_h, uptime_m,uptime_s)
		for k, v in pairs(stats) do
			str = str .. k .. ": " .. v .. "\n"
		end
		reply(c, str)
		return command_processed
	end
	
	return 0
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

