-- TODO
-- Fix error types

local base = _G

module("access")

base.require("luadchpp")

local adchpp = base.luadchpp
local string = base.require('string')

-- Where to read/write user database
local users_file = adchpp.Util_getCfgPath() .. "users.txt"

-- Where to read/write settings
local settings_file = adchpp.Util_getCfgPath() .. "settings.txt"

-- Where to read/write ban database
local bans_file = adchpp.Util_getCfgPath() .. "bans.txt"

-- Users with level lower than the specified will not be allowed to run command at all
local command_min_levels = {
--	[adchpp.AdcCommand_CMD_MSG] = 2
}

-- Users with a level equal to or above the one specified here are operators
local level_op = 2

-- ADC extensions this script adds support for
local extensions = { "PING" }

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
local context_send = "[BDEFH]"
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

local io = base.require('io')
local os = base.require('os')
local json = base.require('json')
local autil = base.require('autil')
local table = base.require('table')
local math = base.require('math')

local start_time = os.time()

local users = {}
users.nicks = {}
users.cids = {}

local bans = {}
bans.cids = {}
bans.ips = {}
bans.nicks = {}
bans.nicksre = {}
bans.msgsre = {}
bans.muted = {}

local stats = {}

local cm = adchpp.getCM()
local pm = adchpp.getPM()

local saltsHandle = pm:registerByteVectorData()

local function description_change()
	local description = autil.settings.topic.value
	if #autil.settings.topic.value == 0 then
		description = autil.settings.description.value
	end
	cm:getEntity(adchpp.AdcCommand_HUB_SID):setField("DE", description)
	cm:sendToAll(adchpp.AdcCommand(adchpp.AdcCommand_CMD_INF, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID):addParam("DE", description):getBuffer())
end

autil.settings.address = {
	alias = { host = true, dns = true },

	help = "host address (DNS or IP)",

	value = adchpp.Util_getLocalIp()
}

autil.settings.description = {
	alias = { hubdescription = true },

	change = description_change,

	help = "hub description",

	value = cm:getEntity(adchpp.AdcCommand_HUB_SID):getField("DE")
}

autil.settings.maxmsglength = {
	alias = { maxmessagelength = true },

	help = "maximum number of characters allowed per chat message, 0 = no limit",

	value = 0
}

autil.settings.maxusers = {
	alias = { max_users = true, user_max = true, users_max = true, usermax = true, usersmax = true },

	help = "maximum number of non-registered users, -1 = no limit, 0 = no unregistered users allowed",

	value = -1
}

autil.settings.name = {
	alias = { hubname = true },

	change = function()
		cm:getEntity(adchpp.AdcCommand_HUB_SID):setField("NI", autil.settings.name.value)
		cm:sendToAll(adchpp.AdcCommand(adchpp.AdcCommand_CMD_INF, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID):addParam("NI", autil.settings.name.value):getBuffer())
	end,

	help = "hub name",

	value = cm:getEntity(adchpp.AdcCommand_HUB_SID):getField("NI")
}

autil.settings.network = {
	value = ""
}

autil.settings.owner = {
	alias = { ownername = true },

	help = "owner name",

	value = ""
}

autil.settings.topic = {
	alias = { hubtopic = true },

	change = description_change,

	help = "hub topic: if set, overrides the description for normal users; the description is then only for use by hub-lists",

	value = ""
}

autil.settings.website = {
	alias = { url = true },

	value = ""
}

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

local function load_settings()
	local file = io.open(settings_file, "r")
	if not file then
		base.print("Unable to open " .. settings_file ..", settings not loaded")
		return
	end

	local str = file:read("*a")
	file:close()

	if #str == 0 then
		return
	end

	local ok, list = base.pcall(json.decode, str)
	if not ok then
		base.print("Unable to decode settings file: " .. list)
		return
	end

	for k, v in base.pairs(list) do
		if autil.settings[k] then
			local change = autil.settings[k].value ~= v
			autil.settings[k].value = v
			if change and autil.settings[k].change then
				autil.settings[k].change()
			end
		end
	end
end

local function save_settings()
	local file = io.open(settings_file, "w")
	if not file then
		base.print("Unable to open " .. settings_file .. ", settings not saved")
		return
	end

	local list = { }
	for k, v in base.pairs(autil.settings) do
		list[k] = v.value
	end
	file:write(json.encode(list))
	file:close()
end

local function load_bans()
	bans = {}
	bans.cids = {}
	bans.ips = {}
	bans.nicks = {}
	bans.nicksre = {}
	bans.msgsre = {}
	bans.muted = {}

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
		bans.cids = {}
	end
	if not bans.ips then
		bans.ips = {}
	end
	if not bans.nicks then
		bans.nicks = {}
	end
	if not bans.nicksre then
		bans.nicksre = {}
	end
	if not bans.msgsre then
		bans.msgsre = {}
	end
	if not bans.muted then
		bans.muted = {}
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
	if autil.settings.maxusers.value == -1 then
		return
	end

	if autil.settings.maxusers.value == 0 then
		return adchpp.AdcCommand_ERROR_REGGED_ONLY, "Only registered users are allowed in here"
	end

	local count = cm:getEntities():size()
	if count >= autil.settings.maxusers.value then
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

local function get_level(c)
	local user = get_user_c(c)
	if not user then
		return 0
	end

	return user.level
end

local function has_level(c, level)
	return get_level(c) >= level
end

local function is_op(c)
	return has_level(c, level_op)
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
		base.pcall(save_users)
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
		base.pcall(save_users)
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

	base.pcall(save_users)
end

local function make_ban(level, reason, minutes)
	local ban = { level = level }
	if string.len(reason) > 0 then
		ban.reason = reason
	end
	if minutes and string.len(minutes) > 0 then
		ban.expires = os.time() + minutes * 60
	end
	return ban
end

local function ban_expiration_diff(ban)
	return os.difftime(ban.expires, os.time())
end

local function clear_expired_bans()
	local save = false

	for _, ban_array in base.pairs(bans) do
		for k, ban in base.pairs(ban_array) do
			if ban.expires and ban_expiration_diff(ban) <= 0 then
				ban_array[k] = nil
				save = true
			end
		end
	end

	if save then
		base.pcall(save_bans)
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

local function ban_return_info(ban)
	local str = " (expires: " .. ban_expiration_string(ban) .. ")"
	if ban.reason then
		str = str .. " (reason: " .. ban.reason .. ")"
	end
	return str
end

local function dump_banned(c, ban)
	local str = "You are banned " .. ban_return_info(ban)

	autil.dump(c, adchpp.AdcCommand_ERROR_BANNED_GENERIC, function(cmd)
		cmd:addParam("MS" .. str)

		local expires
		if ban.expires then
			expires = ban_expiration_diff(ban)
		else
			expires = -1
		end
		cmd:addParam("TL" .. base.tostring(expires))
	end)
end

local function verify_info(c, cid, nick)
	if #nick == 0 or #cid == 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "No valid nick/CID supplied")
		return false
	end

	local level = 0
	local user = get_user(cid, nick) -- can't use get_user_c if checking the first INF
	if user then
		level = user.level
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
	if ban and ban.level > level then
		dump_banned(c, ban)
		return false
	end

	return true
end

local function onSUP(c, cmd)
	-- imitate ClientManager::handle(AdcCommand::SUP, ...)

	if not cm:verifySUP(c, cmd) then
		return false
	end

	if c:getState() ~= adchpp.Entity_STATE_PROTOCOL or not c:hasSupport(adchpp.AdcCommand_toFourCC("PING")) then
		-- let ClientManager further process this SUP
		return true
	end

	-- imitate ClientManager::enterIdentify

	base.print(adchpp.AdcCommand_fromSID(c:getSID()) .. " entering IDENTIFY (supports 'PING')")

	local hub = cm:getEntity(adchpp.AdcCommand_HUB_SID)

	c:send(hub:getSUP())
	c:send(adchpp.AdcCommand(adchpp.AdcCommand_CMD_SID, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
	:addParam(adchpp.AdcCommand_fromSID(c:getSID())));

	local entities = cm:getEntities()
	local uc = entities:size()
	local ss = 0
	local sf = 0
	if uc > 0 then
		for i = 0, uc - 1 do
			local entity = entities[i]
			ss = ss + entity:getField("SS")
			sf = sf + entity:getField("SF")
		end
	end

	local inf = adchpp.AdcCommand(adchpp.AdcCommand_CMD_INF, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
	hub:getAllFields(inf)
	inf:delParam("DE", 0)
	inf:addParam("DE", autil.settings.description.value)
	-- add PING-specific information
	:addParam("HH" .. autil.settings.address.value)
	:addParam("WS" .. autil.settings.website.value)
	:addParam("NE" .. autil.settings.network.value)
	:addParam("OW" .. autil.settings.owner.value)
	:addParam("UC" .. base.tostring(uc))
	:addParam("SS" .. base.tostring(ss))
	:addParam("SF" .. base.tostring(sf))
	:addParam("UP" .. base.tostring(os.difftime(os.time(), adchpp.Stats_startTime)))
	if autil.settings.maxusers.value > 0 then
		inf:addParam("MC" .. base.tostring(autil.settings.maxusers.value))
	end
	c:send(inf)

	c:setState(adchpp.Entity_STATE_IDENTIFY)

	return false
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
		return verify_info(c, c:getCID():toBase32(), c:getField("NI"))
	end

	local nick = cmd:getParam("NI", 0)
	local cid = cmd:getParam("ID", 0)
	if not verify_info(c, cid, nick) then
		return false
	end

	local user = get_user(cid, nick)
	if not user then
		-- non-reg user
		local code, err = check_max_users()
		if code then
			autil.dump(c, code, err)
			return false
		end

		-- let ClientManager further verify this INF
		return true
	end

	if user and user.level >= level_op then
		cmd:addParam("CT4")
		cmd:addParam("OP1") -- old name
	else
		cmd:addParam("CT2")
		cmd:addParam("RG1") -- old name
	end

	if not cm:verifyINF(c, cmd) then
		return false
	end

	c:setByteVectorData(saltsHandle, cm:enterVerify(c, true))
	return false
end

local function onPAS(c, cmd)
	if c:getState() ~= adchpp.Entity_STATE_VERIFY then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Not in VERIFY state")
		return false
	end

	local salt = c:getByteVectorData(saltsHandle)

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
	return false
end

function formatSeconds(t)
	local t_d = math.floor(t / (60*60*24))
	local t_h = math.floor(t / (60*60)) % 24
	local t_m = math.floor(t / 60) % 60
	local t_s = t % 60

	return string.format("%d days, %d hours, %d minutes and %d seconds", t_d, t_h, t_m, t_s)
end

autil.commands.cfg = {
	alias = { changecfg = true, changeconfig = true, config = true, var = true, changevar = true, setvar = true, setcfg = true, setconfig = true },

	command = function(c, parameters)
		if not autil.commands.cfg.protected(c) then
			return
		end

		local name, value = parameters:match("^(%S+) ?(.*)")
		if not name then
			autil.reply(c, "You need to supply a variable name")
			return
		end

		local setting = nil
		for k, v in base.pairs(autil.settings) do
			if k == name or (v.alias and v.alias[name]) then
				setting = v
				break
			end
		end
		if not setting then
			autil.reply(c, "The name " .. name .. " doesn't correspond to any setting variable, use \"+help cfg\" to list all variables")
			return
		end

		local old = setting.value
		local type = base.type(old)

		if not value or #value == 0 then
			-- no value; make up a default one
			if type == "boolean" or type == "number" then
				value = "0"
			elseif type == "string" then
				value = ""
			end
		end

		if type == "boolean" then
			value = value ~= "0"
		elseif type == "number" then
			local num = base.tonumber(value)
			if not num then
				autil.reply(c, "Only numbers are accepted for the variable " .. name)
				return
			end
			value = num
		end

		if value == old then
			autil.reply(c, "The value is the same as before, no change done")
			return
		end

		setting.value = value
		if setting.change then
			setting.change()
		end
		base.pcall(save_settings)
		autil.reply(c, "Variable " .. name .. " changed from " .. base.tostring(old) .. " to " .. base.tostring(setting.value))
	end,

	help = "name value - change hub configuration, use \"+help cfg\" to list all variables",

	helplong = function()
		local list = { }
		for k, v in base.pairs(autil.settings) do
			local str = k .. " - current value: " .. v.value
			if v.help then
				str = str .. " - " .. v.help
			end
			if v.alias then
				local list_alias = { }
				for k_alias, v_alias in base.pairs(v.alias) do
					table.insert(list_alias, k_alias)
				end
				table.sort(list_alias)
				str = str .. " (aliases: " .. table.concat(list_alias, ", ") .. ")"
			end
			table.insert(list, str)
		end
		table.sort(list)
		return "List of all settings variables:\n" .. table.concat(list, "\n")
	end,

	protected = is_op,

	user_command = { params = {
		autil.line_ucmd("Name of the setting to change"),
		autil.line_ucmd("New value for the setting")
	} }
}

autil.commands.help = {
	command = function(c, parameters)
		local command_help = function(k, v)
			local str = "+" .. k
			if v.help then
				str = str .. " " .. v.help
			end
			if v.alias then
				local list_alias = { }
				for k_alias, v_alias in base.pairs(v.alias) do
					table.insert(list_alias, "+" .. k_alias)
				end
				table.sort(list_alias)
				str = str .. " (aliases: " .. table.concat(list_alias, ", ") .. ")"
			end
			return str
		end

		if #parameters > 0 then
			local command = nil
			for k, v in base.pairs(autil.commands) do
				if k == parameters or (v.alias and v.alias[parameters]) then
					command = { k = k, v = v }
					break
				end
			end

			if not command then
				autil.reply(c, "The command +" .. parameters .. " doesn't exist")
				return
			end

			if command.v.protected and not command.v.protected(c) then
				autil.reply(c, "You don't have access to the +" .. parameters .. " command")
				return
			end

			local str = "\n" .. command_help(command.k, command.v)
			if command.v.helplong then
				str = str .. "\n\n"
				if base.type(command.v.helplong) == "function" then
					str = str .. command.v.helplong()
				else
					str = str .. command.v.helplong
				end
			end
			autil.reply(c, str)

		else
			local list = { }
			for k, v in base.pairs(autil.commands) do
				if (not v.protected) or (v.protected and v.protected(c)) then
					table.insert(list, command_help(k, v))
				end
			end
			table.sort(list)
			autil.reply(c, "Available commands:\n" .. table.concat(list, "\n"))
		end
	end,

	help = "[command] - list all available commands, or display detailed information about one specific command",

	user_command = { params = {
		autil.line_ucmd("Command name (facultative)")
	} }
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

			if user then
				local field_function = function(field, text)
					if user:hasField(field) then
						str = str .. text .. ": " .. user:getField(field) .. "\n"
					end
				end

				str = "\n"
				field_function("NI", "Nick")
				field_function("ID", "CID")
				str = str .. "IP: "
				local user_c = user:asClient()
				if user_c then
					str = str .. user_c:getIp()
				else
					str = str .. "unknown"
				end
				str = str .. "\n"
				field_function("DE", "Description")
				field_function("SS", "Share size (bytes)")
				field_function("SF", "Number of shared files")
				field_function("VE", "Client identification")
				field_function("US", "Max upload speed (bytes/s)")
				field_function("DS", "Max download speed (bytes/s)")
				field_function("SL", "Max slots")
				field_function("AS", "Speed limit for auto-slots (bytes/s)")
				field_function("AM", "Minimum auto-slots")
				field_function("EM", "E-mail")
				field_function("HN", "Hubs where user is a normal user")
				field_function("HR", "Hubs where user is registered")
				field_function("HO", "Hubs where user is operator")
				field_function("AW", "Away")
				field_function("SU", "Protocol supports")

			else
				-- by IP
				local users_ip = { }
				local entities = cm:getEntities()
				local size = entities:size()
				if size > 0 then
					for i = 0, size - 1 do
						local user_c = entities[i]:asClient()
						if user_c and user_c:getIp() == parameters then
							table.insert(users_ip, entities[i])
						end
					end
				end
				if table.getn(users_ip) > 0 then
					str = "Users with the IP " .. parameters .. ":\n"
					for i, v in base.ipairs(users_ip) do
						str = str .. v:getField("NI") .. "\n"
					end

				else
					str = "No user found with a nick, CID or IP matching " .. parameters
				end
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

	help = "[nick or CID or IP] - information about a user, or about the hub if no parameter given",

	user_command = { user_params = { "%[userNI]" } }
}

autil.commands.kick = {
	alias = { drop = true, dropuser = true, kickuser = true },

	command = function(c, parameters)
		local level = get_level(c)
		if level < level_op then
			return
		end

		local nick, reason = parameters:match("^(%S+) ?(.*)")
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
			autil.reply(c, "You can't kick users whose level is higher or equal than yours")
			return
		end

		local text = "You have been kicked"
		if string.len(reason) > 0 then
			text = text .. " (reason: " .. reason .. ")"
		end
		autil.dump(victim, adchpp.AdcCommand_ERROR_BANNED_GENERIC, function(cmd)
			cmd:addParam("ID" .. adchpp.AdcCommand_fromSID(c:getSID()))
			:addParam("MS" .. text)
		end)
		autil.reply(c, "\"" .. nick .. "\" (CID: " .. victim_cid .. ") has been kicked")
	end,

	help = "user [reason] - disconnect the user, she can reconnect whenever she wants to",

	protected = is_op,

	user_command = {
		hub_params = {
			autil.line_ucmd("User"),
			autil.line_ucmd("Reason (facultative)")
		},
		user_params = {
			"%[userNI]",
			autil.line_ucmd("Reason (facultative)")
		}
	}
}

autil.commands.listregs = {
	alias = { listreg = true, listregged = true, reggedusers = true, showreg = true, showregs = true, showregged = true },

	command = function(c, parameters)
		local user = get_user_c(c)
		if not user then
			autil.reply(c, "Only registered users can use this command")
			return
		end

		local str = "Registered users with a level <= " .. user.level .. " (your level):\n"
		for k, v in base.pairs(users.nicks) do
			if v.level <= user.level then
				str = str .. "Nick: " .. k .. "\n"
			end
		end
		for k, v in base.pairs(users.cids) do
			if v.level <= user.level then
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
		if not autil.commands.mass.protected(c) then
			return
		end

		local level_pos, _, level = parameters:find(" ?(%d*)$")
		local message = parameters:sub(0, level_pos - 1)
		if #message <= 0 then
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

	help = "message [min-level]",

	protected = is_op,

	user_command = { params = {
		autil.line_ucmd("Message"),
		autil.line_ucmd("Minimum level (facultative)")
	} }
}

autil.commands.mute = {
	alias = { stfu = true },

	command = function(c, parameters)
		local level = get_level(c)
		if level < level_op then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(0, minutes_pos - 1)
			if #parameters <= 0 then
				autil.reply(c, "Bad arguments")
				return
			end
		end
		local nick, reason = parameters:match("^(%S+) ?(.*)")
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
			autil.reply(c, "You can't mute users whose level is higher or equal than yours")
			return
		end

		local ban = make_ban(level, reason, minutes)
		bans.muted[victim_cid] = ban
		base.pcall(save_bans)

		autil.reply(c, "\"" .. nick .. "\" (CID: " .. victim_cid .. ") is now muted")
	end,

	help = "nick [reason] [minutes] - mute an online user (set minutes to 0 to un-mute)",

	protected = is_op,

	user_command = {
		hub_params = {
			autil.line_ucmd("Nick"),
			autil.line_ucmd("Reason (facultative)"),
			autil.line_ucmd("Minutes (facultative)")
		},
		user_params = {
			"%[userNI]",
			autil.line_ucmd("Reason (facultative)"),
			autil.line_ucmd("Minutes (facultative)")
		}
	}
}

autil.commands.myip = {
	alias = { getip = true, getmyip = true, ip = true, showip = true, showmyip = true },

	command = function(c)
		autil.reply(c, "Your IP: " .. c:getIp())
	end
}

autil.commands.mypass = {
	alias = { changepass = true, mypassword = true, changepassword = true, setpass = true, setpassword = true },

	command = function(c, parameters)
		local user = get_user_c(c)
		if not user then
			autil.reply(c, "You are not registered, register with +regme")
			return
		end

		if #parameters <= 0 then
			autil.reply(c, "You must provide a new password")
			return
		end

		user.password = parameters
		base.pcall(save_users)
		autil.reply(c, "Your password has been changed to \"" .. parameters .. "\"")
	end,

	help = "new_pass - change your password, make sure you change it in your client options too",

	protected = function(c) return get_user_c(c) end,

	user_command = { params = {
		autil.line_ucmd("New password")
	} }
}

autil.commands.redirect = {
	alias = { forward = true },

	command = function(c, parameters)
		local level = get_level(c)
		if level < level_op then
			return
		end

		local nick, address = parameters:match("^(%S+) (.+)")
		if not nick or not address then
			autil.reply(c, "You need to supply a nick and an address")
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
			autil.reply(c, "You can't redirect users whose level is higher or equal than yours")
			return
		end

		autil.dump(victim, adchpp.AdcCommand_ERROR_BANNED_GENERIC, function(cmd) cmd:addParam("RD" .. address) end)
		autil.reply(c, "\"" .. nick .. "\" (CID: " .. victim_cid .. ") has been redirected to \"" .. address .. "\"")
	end,

	help = "nick address",

	protected = is_op,

	user_command = {
		hub_params = {
			autil.line_ucmd("Nick"),
			autil.line_ucmd("Address")
		},
		user_params = {
			"%[userNI]",
			autil.line_ucmd("Address")
		}
	}
}

autil.commands.reload = {
	command = function() end, -- empty on purpose, this is handled via PluginManager::handleCommand

	help = "- reload scripts",

	protected = is_op
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

	help = "password",

	user_command = { params = { autil.line_ucmd("Password") } }
}

autil.commands.regnick = {
	alias = { reguser = true },

	command = function(c, parameters)
		local my_user = get_user_c(c)
		if not my_user then
			autil.reply(c, "Only registered users may register others")
			return
		end

		local nick, password, level = parameters:match("^(%S+) ?(%S*) ?(%d*)")
		if not nick then
			autil.reply(c, "You must supply a nick")
			return
		end

		local other = cm:findByNick(nick)

		local cid
		if other then
			cid = other:getCID():toBase32()
		end

		if string.len(level) > 0 then
			level = base.tonumber(level)
			if level >= my_user.level then
				autil.reply(c, "You may only register to a lower level than your own (" .. my_user.level .. ")")
				return
			end
		else
			level = my_user.level - 1
		end
		if level < 1 then
			autil.reply(c, "Level too low")
			return
		end

		if #password == 0 then
			-- un-reg
			if cid then
				users.cids[cid] = nil
			end
			users.nicks[nick] = nil
			base.pcall(save_users)

			autil.reply(c, nick .. " un-registered")

			if other then
				autil.reply(other, "You've been un-registered")
			end
			return
		end

		register_user(cid, nick, password, level)

		autil.reply(c, nick .. " registered")

		if other then
			autil.reply(other, "You've been registered with password " .. password)
		end
	end,

	help = "nick [password] [level] - register a user; use no password to un-reg; level defaults to your own level minus one",

	protected = function(c) return has_level(c, 2) end,

	user_command = {
		hub_params = {
			autil.line_ucmd("Nick"),
			autil.line_ucmd("Password (leave empty to un-reg)"),
			autil.line_ucmd("Level (facultative; defaults to your own level minus one)")
		},
		user_params = {
			"%[userNI]",
			autil.line_ucmd("Password (leave empty to un-reg)"),
			autil.line_ucmd("Level (facultative; defaults to your own level minus one)")
		}
	}
}

autil.commands.test = {
	command = function(c)
		autil.reply(c, "Test ok")
	end,

	help = "- make the hub reply \"Test ok\""
}

-- simply map to +cfg topic
autil.commands.topic = {
	alias = { changetopic = true, settopic = true, changehubtopic = true, sethubtopic = true },

	command = function(c, parameters)
		autil.commands.cfg.command(c, "topic " .. parameters)
	end,

	help = "topic - change the hub topic (shortcut to +cfg topic)",

	protected = autil.commands.cfg.protected,

	user_command = { params = {
		autil.line_ucmd("New topic")
	} }
}

autil.commands.ban = {
	alias = { banuser = true },

	command = function(c, parameters)
		local level = get_level(c)
		if level < level_op then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(0, minutes_pos - 1)
			if #parameters <= 0 then
				autil.reply(c, "Bad arguments")
				return
			end
		end
		local nick, reason = parameters:match("^(%S+) ?(.*)")
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
		base.pcall(save_bans)

		dump_banned(victim, ban)
		autil.reply(c, "\"" .. nick .. "\" (CID: " .. victim_cid .. ") is now banned")
	end,

	help = "nick [reason] [minutes] - ban an online user (set minutes to 0 to un-ban)",

	protected = is_op,

	user_command = {
		hub_params = {
			autil.line_ucmd("Nick"),
			autil.line_ucmd("Reason (facultative)"),
			autil.line_ucmd("Minutes (facultative)")
		},
		user_params = {
			"%[userNI]",
			autil.line_ucmd("Reason (facultative)"),
			autil.line_ucmd("Minutes (facultative)")
		}
	}
}

autil.commands.bancid = {
	command = function(c, parameters)
		local level = get_level(c)
		if level < level_op then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(0, minutes_pos - 1)
			if #parameters <= 0 then
				autil.reply(c, "Bad arguments")
				return
			end
		end
		local cid, reason = parameters:match("^(%S+) ?(.*)")
		if not cid then
			autil.reply(c, "You need to supply a CID")
			return
		end

		bans.cids[cid] = make_ban(level, reason, minutes)
		base.pcall(save_bans)
	
		autil.reply(c, "The CID \"" .. cid .. "\" is now banned")
	end,

	help = "CID [reason] [minutes] (set minutes to 0 to un-ban)",

	protected = is_op,

	user_command = {
		hub_params = {
			autil.line_ucmd("CID"),
			autil.line_ucmd("Reason (facultative)"),
			autil.line_ucmd("Minutes (facultative)")
		},
		user_params = {
			"%[userCID]",
			autil.line_ucmd("Reason (facultative)"),
			autil.line_ucmd("Minutes (facultative)")
		}
	}
}

autil.commands.banip = {
	command = function(c, parameters)
		local level = get_level(c)
		if level < level_op then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(0, minutes_pos - 1)
			if #parameters <= 0 then
				autil.reply(c, "Bad arguments")
				return
			end
		end
		local ip, reason = parameters:match("^(%S+) ?(.*)")
		if not ip then
			autil.reply(c, "You need to supply an IP address")
			return
		end

		bans.ips[ip] = make_ban(level, reason, minutes)
		base.pcall(save_bans)

		autil.reply(c, "The IP address \"" .. ip .. "\" is now banned")
	end,

	help = "IP [reason] [minutes] (set minutes to 0 to un-ban)",

	protected = is_op,

	user_command = {
		hub_params = {
			autil.line_ucmd("IP"),
			autil.line_ucmd("Reason (facultative)"),
			autil.line_ucmd("Minutes (facultative)")
		},
		user_params = {
			"%[userI4]",
			autil.line_ucmd("Reason (facultative)"),
			autil.line_ucmd("Minutes (facultative)")
		}
	}
}

autil.commands.bannick = {
	command = function(c, parameters)
		local level = get_level(c)
		if level < level_op then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(0, minutes_pos - 1)
			if #parameters <= 0 then
				autil.reply(c, "Bad arguments")
				return
			end
		end
		local nick, reason = parameters:match("^(%S+) ?(.*)")
		if not nick then
			autil.reply(c, "You need to supply a nick")
			return
		end

		bans.nicks[nick] = make_ban(level, reason, minutes)
		base.pcall(save_bans)

		autil.reply(c, "The nick \"" .. nick .. "\" is now banned")
	end,

	help = "nick [reason] [minutes] (set minutes to 0 to un-ban)",

	protected = is_op,

	user_command = {
		hub_params = {
			autil.line_ucmd("Nick"),
			autil.line_ucmd("Reason (facultative)"),
			autil.line_ucmd("Minutes (facultative)")
		},
		user_params = {
			"%[userNI]",
			autil.line_ucmd("Reason (facultative)"),
			autil.line_ucmd("Minutes (facultative)")
		}
	}
}

autil.commands.bannickre = {
	command = function(c, parameters)
		local level = get_level(c)
		if level < level_op then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(0, minutes_pos - 1)
			if #parameters <= 0 then
				autil.reply(c, "Bad arguments")
				return
			end
		end
		local re, reason = parameters:match("<([^>]+)> ?(.*)")
		if not re then
			autil.reply(c, "You need to supply a reg exp (within '<' and '>' brackets)")
			return
		end

		bans.nicksre[re] = make_ban(level, reason, minutes)
		base.pcall(save_bans)

		autil.reply(c, "Nicks that match \"" .. re .. "\" are now banned")
	end,

	help = "<nick-reg-exp> [reason] [minutes] - ban nicks that match the given reg exp (must be within '<' and '>' brackets) (set minutes to 0 to un-ban)",

	protected = is_op,

	user_command = { params = {
		"<" .. autil.line_ucmd("Reg Exp of nicks to forbid") .. ">",
		autil.line_ucmd("Reason (facultative)"),
		autil.line_ucmd("Minutes (facultative)")
	} }
}

autil.commands.banmsgre = {
	command = function(c, parameters)
		local level = get_level(c)
		if level < level_op then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(0, minutes_pos - 1)
			if #parameters <= 0 then
				autil.reply(c, "Bad arguments")
				return
			end
		end
		local re, reason = parameters:match("<([^>]+)> ?(.*)")
		if not re then
			autil.reply(c, "You need to supply a reg exp (within '<' and '>' brackets)")
			return
		end

		bans.msgsre[re] = make_ban(level, reason, minutes)
		base.pcall(save_bans)

		autil.reply(c, "Messages that match \"" .. re .. "\" will get the user banned")
	end,

	help = "msg-reg-exp [reason] [minutes] - ban originators of messages that match the given reg exp (must be within '<' and '>' brackets) (set minutes to 0 to un-ban)",

	protected = is_op,

	user_command = { params = {
		"<" .. autil.line_ucmd("Reg Exp of chat messages to forbid") .. ">",
		autil.line_ucmd("Reason (facultative)"),
		autil.line_ucmd("Minutes (facultative)")
	} }
}

autil.commands.listbans = {
	alias = { listban = true, listbanned = true, showban = true, showbans = true, showbanned = true },

	command = function(c)
		local level = get_level(c)
		if level < level_op then
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

		str = str .. "\n\nMuted:"
		for cid, ban in base.pairs(bans.muted) do
			str = str .. "\n\tCID: " .. cid .. ban_info_string(ban)
		end

		autil.reply(c, str)
	end,

	protected = is_op
}

autil.commands.loadbans = {
	alias = { reloadbans = true },

	command = function(c)
		local level = get_level(c)
		if level < level_op then
			return
		end

		base.pcall(load_bans)

		autil.reply(c, "Ban list reloaded")
	end,

	help = "- reload the ban list",

	protected = is_op
}

local function onMSG(c, cmd)
	clear_expired_bans()
	local muted = bans.muted[c:getCID():toBase32()]
	if muted then
		autil.reply(c, "You are muted " .. ban_return_info(muted))
		return false
	end

	local msg = cmd:getParam(0)

	local command, parameters = msg:match("^%+(%a+) ?(.*)")
	if command then
		for k, v in base.pairs(autil.commands) do
			if k == command or (v.alias and v.alias[command]) then
				add_stats('+' .. command)
				v.command(c, parameters)
				return false
			end
		end

	else
		local level = get_level(c)
		clear_expired_bans()
		for re, reban in base.pairs(bans.msgsre) do
			if reban.level >= level and msg:match(re) then
				local ban = { level = reban.level, reason = reban.reason, expires = reban.expires }
				bans.cids[c:getCID():toBase32()] = ban
				base.pcall(save_bans)
				dump_banned(c, ban)
				return false
			end
		end
	end

	if autil.settings.maxmsglength.value > 0 and string.len(msg) > autil.settings.maxmsglength.value then
		autil.reply(c, "Your message contained too many characters, max allowed is " .. autil.settings.maxmsglength.value)
		return false
	end

	return true
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

	if cmd:getCommand() == adchpp.AdcCommand_CMD_SUP then
		return onSUP(c, cmd)
	end
	if cmd:getCommand() == adchpp.AdcCommand_CMD_INF then
		return onINF(c, cmd)
	end
	if cmd:getCommand() == adchpp.AdcCommand_CMD_PAS then
		return onPAS(c, cmd)
	end
	if cmd:getCommand() == adchpp.AdcCommand_CMD_MSG then
		return onMSG(c, cmd)
	end

	return true
end

local function send_user_commands(c)
	local list = { }
	for k, v in base.pairs(autil.commands) do
		if (not v.protected) or (v.protected and v.protected(c)) then
			table.insert(list, k)
		end
	end
	table.sort(list)

	local send_ucmd = function(c, name, command, context)
		local ucmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_CMD, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
		ucmd:addParam("+" .. name)

		local back_cmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_HUB, c:getSID())
		local str = "+" .. name

		local params = nil
		if context == 1 and command.user_command and command.user_command.hub_params then
			params = command.user_command.hub_params
		elseif context == 2 and command.user_command and command.user_command.user_params then
			params = command.user_command.user_params
		elseif command.user_command and command.user_command.params then
			params = command.user_command.params
		end
		if params then
			for _, param in base.ipairs(params) do
				str = str .. " " .. param
			end
		end

		back_cmd:addParam(str)
		ucmd:addParam("TT", back_cmd:toString())

		ucmd:addParam("CT", base.tostring(context))

		c:send(ucmd)
	end

	for i, name in base.ipairs(list) do
		local command = autil.commands[name]

		local hub_sent = false
		if command.user_command and command.user_command.hub_params then
			send_ucmd(c, name, command, 1)
			hub_sent = true
		end

		local user_sent = false
		if command.user_command and command.user_command.user_params then
			send_ucmd(c, name, command, 2)
			user_sent = true
		end

		if (not hub_sent) and (not user_sent) then
			send_ucmd(c, name, command, 3)
		elseif not hub_sent then
			send_ucmd(c, name, command, 1)
		elseif not user_sent then
			send_ucmd(c, name, command, 2)
		end
	end
end

base.pcall(load_users)
base.pcall(load_settings)
base.pcall(load_bans)

table.foreach(extensions, function(_, extension)
	cm:getEntity(adchpp.AdcCommand_HUB_SID):addSupports(adchpp.AdcCommand_toFourCC(extension))
end)

access_1 = cm:signalReceive():connect(function(entity, cmd, ok)
	local res = onReceive(entity, cmd, ok)
	if not res then
		cmd:setPriority(adchpp.AdcCommand_PRIORITY_IGNORE)
	end
	return res
end)

access_2 = cm:signalState():connect(function(entity)
	if entity:getState() == adchpp.Entity_STATE_NORMAL then
		local c = entity:asClient()
		if c and (
			entity:hasSupport(adchpp.AdcCommand_toFourCC("UCMD")) or entity:hasSupport(adchpp.AdcCommand_toFourCC("UCM0"))
			) then
			send_user_commands(c)
		end
	end
end)

access_3 = pm:getCommandSignal("reload"):connect(function(entity, list, ok)
	if not ok then
		return ok
	end
	return is_op(entity)
end)
