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

-- Users with a level equal to or above the one specified here are operators
level_op = 2

-- ADC extensions this script adds support for
local extensions = { "PING" }

-- Regexes for the various fields. 
local cid_regex = "^" .. string.rep("[A-Z2-7]", 39) .. "$" -- No way of expressing exactly 39 chars without being explicit it seems
local pid_regex = cid_regex
local sid_regex = "^" .. string.rep("[A-Z2-7]", 4) .. "$"
local integer_regex = "^%d+$"

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
	["CT"] = integer_regex,
	["AW"] = "^[12]$",
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

users = {}
users.nicks = {}
users.cids = {}

local stats = {}
local dispatch_stats = false

-- cache for +cfg min*level
local restricted_commands = {}

local cm = adchpp.getCM()
local lm = adchpp.getLM()
local pm = adchpp.getPM()
local sm = adchpp.getSM()

local saltsHandle = pm:registerByteVectorData()

-- forward declarations.
local format_seconds, cut_str,
send_user_commands, remove_user_commands,
verify_info

-- Settings loaded and saved by the main script. Possible fields each setting can contain:
-- * alias: other names that can also be used to reach this setting.
-- * change: function called when the value has changed.
-- * help: information about this setting, displayed in +help cfg.
-- * value: the value of this setting, either a number or a string. [compulsory]
-- * validate: function(string) called before changing the value; may return an error string.
settings = {}

-- List of +commands handled by the main script. Possible fields each command can contain:
-- * alias: other names that can also trigger this command.
-- * command: function(Client c, string parameters). [compulsory]
-- * help: information about this command, displayed in +help.
-- * helplong: detailed information about this command, displayed in +help command-name.
-- * protected: function(Client c) returning whether the command is to be shown in +help.
-- * user_command: table containing information about the user command which will refer to this
--                 command. Possible fields each user_command table can contain:
--                 ** hub_params: list of arguments to be passed to this command for hub menus.
--                 ** name: name of the user command (defaults to capitalized command name).
--                 ** params: list of arguments to be passed to this command for all menus.
--                 ** user_params: list of arguments to be passed to this command for user menus.
commands = {}

local function log(message)
	lm:log(_NAME, message)
end

local function description_change()
	local description = settings.topic.value
	if #settings.topic.value == 0 then
		description = settings.description.value
	end
	cm:getEntity(adchpp.AdcCommand_HUB_SID):setField("DE", description)
	cm:sendToAll(adchpp.AdcCommand(adchpp.AdcCommand_CMD_INF, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID):addParam("DE", description):getBuffer())
end

local function validate_ni(new)
	for _, char in base.ipairs({ string.byte(new, 1, #new) }) do
		if char <= 32 then
			return "the name can't contain any space nor new line"
		end
	end
end

local function validate_de(new)
	for _, char in base.ipairs({ string.byte(new, 1, #new) }) do
		if char < 32 then
			return "the description can't contain any new line nor tabulation"
		end
	end
end

local function recheck_info()
	local entities = cm:getEntities()
	local size = entities:size()
	if size > 0 then
		for i = 0, size - 1 do
			local c = entities[i]:asClient()
			if c then
				verify_info(c)
			end
		end
	end
end

settings.address = {
	alias = { host = true, dns = true },

	help = "host address (DNS or IP)",

	value = adchpp.Util_getLocalIp()
}

settings.allownickchange = {
	help = "authorize regged users to connect with a different nick, 1 = allow, 0 = disallow",

	value = 1
}

settings.allowreg = {
	alias = { allowregistration = true },

	help = "authorize un-regged users to register themselves with +mypass (otherwise, they'll have to ask an operator), 1 = alllow, 0 = disallow",

	value = 1
}

settings.description = {
	alias = { hubdescription = true },

	change = description_change,

	help = "hub description",

	value = cm:getEntity(adchpp.AdcCommand_HUB_SID):getField("DE"),

	validate = validate_de
}

settings.maxmsglength = {
	alias = { maxmessagelength = true },

	help = "maximum number of characters allowed per chat message, 0 = no limit",

	value = 0
}

settings.maxnicklength = {
	change = recheck_info,

	help = "maximum number of characters allowed per nick, 0 = no limit",

	value = 50
}

settings.maxusers = {
	alias = { max_users = true, user_max = true, users_max = true, usermax = true, usersmax = true },

	help = "maximum number of non-registered users, -1 = no limit, 0 = no unregistered users allowed",

	value = -1
}

settings.menuname = {
	alias = { ucmdname = true },

	help = "title of the main user command menu sent to clients",

	value = "ADCH++"
}

settings.minchatlevel = {
	change = function()
		restricted_commands[adchpp.AdcCommand_CMD_MSG] = { level = settings.minchatlevel.value, str = "chat" }
	end,

	help = "minimum level to chat - hub restart recommended",

	value = 0
}

settings.mindownloadlevel = {
	alias = { mindllevel = true, mintransferlevel = true },

	change = function()
		restricted_commands[adchpp.AdcCommand_CMD_CTM] = { level = settings.mindownloadlevel.value, str = "download" }
		restricted_commands[adchpp.AdcCommand_CMD_RCM] = { level = settings.mindownloadlevel.value, str = "download" }
	end,

	help = "minimum level to download - hub restart recommended",

	value = 0
}

settings.minsearchlevel = {
	change = function()
		restricted_commands[adchpp.AdcCommand_CMD_SCH] = { level = settings.minsearchlevel.value, str = "search" }
		restricted_commands[adchpp.AdcCommand_CMD_RES] = { level = settings.minsearchlevel.value, str = "send search results" }
	end,

	help = "minimum level to search - hub restart recommended",

	value = 0
}

settings.name = {
	alias = { hubname = true },

	change = function()
		cm:getEntity(adchpp.AdcCommand_HUB_SID):setField("NI", settings.name.value)
		cm:sendToAll(adchpp.AdcCommand(adchpp.AdcCommand_CMD_INF, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID):addParam("NI", settings.name.value):getBuffer())
	end,

	help = "hub name",

	value = cm:getEntity(adchpp.AdcCommand_HUB_SID):getField("NI"),

	validate = validate_ni
}

settings.network = {
	value = ""
}

settings.owner = {
	alias = { ownername = true },

	help = "owner name",

	value = ""
}

settings.passinlist = {
	help = "show passwords of users with a lower level in +listregs, 1 = show, 0 = don't show",

	value = 1
}

settings.sendversion = {
	alias = { displayversion = true },

	help = "send hub version information at login, 1 = alllow, 0 = disallow",

	value = 1
}

settings.topic = {
	alias = { hubtopic = true },

	change = description_change,

	help = "hub topic: if set, overrides the description for normal users; the description is then only for use by hub-lists",

	value = "",

	validate = validate_de
}

settings.website = {
	alias = { url = true },

	value = ""
}

function registered_users()
	local ret = {}
	local nicksdone = {}

	for _, user in base.pairs(users.cids) do
		table.insert(ret, user)
		if user.nick then
			nicksdone[user] = 1
		end
	end

	for _, user in base.pairs(users.nicks) do
		if not nicksdone[user] then
			table.insert(ret, user)
		end
	end

	return ret
end

local function load_users()
	users.cids = {}
	users.nicks = {}

	local file = io.open(users_file, "r")
	if not file then
		log("Unable to open " .. users_file .. ", users not loaded")
		return
	end

	local str = file:read("*a")
	file:close()

	if #str == 0 then
		return
	end

	local userok, userlist = base.pcall(json.decode, str)
	if not userok then
		log("Unable to decode users file: " .. userlist)
		return
	end

	for _, user in base.pairs(userlist) do
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
		log("Unable to open " .. users_file .. ", users not saved")
		return
	end

	file:write(json.encode(registered_users()))
	file:close()
end

function add_setting(name, options)
	local change = false
	if settings[name] then
		change = settings[name].value ~= options.value
		options.value = settings[name].value
	end

	settings[name] = options

	if change and options.change then
		settings[name].change()
	end
end

local function load_settings()
	local file = io.open(settings_file, "r")
	if not file then
		log("Unable to open " .. settings_file .. ", settings not loaded")
		return false
	end

	local str = file:read("*a")
	file:close()

	if #str == 0 then
		return false
	end

	local ok, list = base.pcall(json.decode, str)
	if not ok then
		log("Unable to decode settings file: " .. list)
		return false
	end

	for k, v in base.pairs(list) do
		if settings[k] then
			local change = settings[k].value ~= v
			settings[k].value = v
			if change and settings[k].change then
				settings[k].change()
			end
		else
			-- must have been regged by a script that has not been loaded yet
			settings[k] = { value = v }
		end
	end

	return true
end

local function save_settings()
	local file = io.open(settings_file, "w")
	if not file then
		log("Unable to open " .. settings_file .. ", settings not saved")
		return
	end

	local list = {}
	for k, v in base.pairs(settings) do
		list[k] = v.value
	end
	file:write(json.encode(list))
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
	if settings.maxusers.value == -1 then
		return
	end

	if settings.maxusers.value == 0 then
		return adchpp.AdcCommand_ERROR_REGGED_ONLY, "Only registered users are allowed in here"
	end

	local count = cm:getEntities():size()
	if count >= settings.maxusers.value then
		return adchpp.AdcCommand_ERROR_HUB_FULL, "Hub full, please try again later"
	end
	return
end

local default_user = { level = 0, is_default = true }

local function get_user(cid, nick)
	local user

	if cid then
		user = users.cids[cid]
	end

	if not user and nick then
		user = users.nicks[nick]
	end
	
	if not user then
		user = default_user
	end

	return user
end

local function get_user_c(c)
	return get_user(c:getCID():toBase32(), c:getField("NI"))
end

function get_level(c)
	local user = get_user_c(c)
	if not user then
		return 0
	end

	return user.level
end

function has_level(c, level)
	return get_level(c) >= level
end

function is_op(c)
	return has_level(c, level_op)
end

local function update_user(user, cid, nick)
	-- only one of nick and cid may be updated...

	if user.nick ~= nick then
		if settings.allownickchange.value == 0 then
			return false, "This hub doesn't allow registered users to change their nick; ask an operator to delete your current registration data if you really want a new nick. Please connect again with your current registered nick: " .. user.nick
		end

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

function register_user(cid, nick, password, level)
	local user = make_user(cid, nick, password, level)
	if nick then
		users.nicks[nick] = user
	end
	if cid then
		users.cids[cid] = user
	end

	base.pcall(save_users)
	
	return user
end

local function get_ucmd_name(k, v)
	if v.user_command and v.user_command.name then
		return v.user_command.name
	else
		return string.upper(string.sub(k, 1, 1)) .. string.sub(k, 2)
	end
end

send_user_commands = function(c)
	local names = {}
	local list = {}
	for k, v in base.pairs(commands) do
		if (not v.protected) or (v.protected and v.protected(c)) then
			local name = get_ucmd_name(k, v)
			table.insert(list, name)
			names[name] = k
		end
	end
	table.sort(list)

	local function send_ucmd(name, internal_name, command, context)
		local ucmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_CMD, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
		ucmd:addParam(settings.menuname.value .. autil.ucmd_sep .. name)

		local back_cmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_HUB, c:getSID())
		local str = "+" .. internal_name

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

	for _, name in base.ipairs(list) do
		local internal_name = names[name]
		local command = commands[internal_name]

		local hub_sent = false
		if command.user_command and command.user_command.hub_params then
			send_ucmd(name, internal_name, command, 1)
			hub_sent = true
		end

		local user_sent = false
		if command.user_command and command.user_command.user_params then
			send_ucmd(name, internal_name, command, 2)
			user_sent = true
		end

		if (not hub_sent) and (not user_sent) then
			send_ucmd(name, internal_name, command, 3)
		elseif not hub_sent then
			send_ucmd(name, internal_name, command, 1)
		elseif not user_sent then
			send_ucmd(name, internal_name, command, 2)
		end
	end
end

remove_user_commands = function(c)
	local function send_ucmd(name, context)
		c:send(adchpp.AdcCommand(adchpp.AdcCommand_CMD_CMD, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
		:addParam(settings.menuname.value .. autil.ucmd_sep .. name)
		:addParam("RM", "1")
		:addParam("CT", base.tostring(context)))
	end

	for k, v in base.pairs(commands) do
		local name = get_ucmd_name(k, v)
		send_ucmd(name, 1)
		send_ucmd(name, 2)
		send_ucmd(name, 3)
	end
end

verify_info = function(c, cid, nick)
	if not cid or #cid == 0 then
		cid = c:getCID():toBase32()
	end
	if not nick or #nick == 0 then
		nick = c:getField("NI")
	end
	if #nick == 0 or #cid == 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "No valid nick/CID supplied")
		return false
	end

	local user = get_user(cid, nick) -- can't use get_user_c if checking the first INF
	local level = user.level

	if settings.maxnicklength.value > 0 and #nick > settings.maxnicklength.value then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Your nick (" .. nick .. ") is too long, it must contain " .. base.tostring(settings.maxnicklength.value) .. " characters max")
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

	if string.match(adchpp.versionString, 'Debug$') then
		base.print(adchpp.AdcCommand_fromSID(c:getSID()) .. " entering IDENTIFY (supports 'PING')")
	end

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
			local ss_ = entity:getField("SS")
			if #ss_ > 0 then
				ss = ss + base.tonumber(ss_)
			end
			local sf_ = entity:getField("SF")
			if #sf_ > 0 then
				sf = sf + base.tonumber(sf_)
			end
		end
	end

	local inf = adchpp.AdcCommand(adchpp.AdcCommand_CMD_INF, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
	hub:getAllFields(inf)
	inf:delParam("DE", 0)
	inf:addParam("DE", settings.description.value)
	-- add PING-specific information
	:addParam("HH" .. settings.address.value)
	:addParam("WS" .. settings.website.value)
	:addParam("NE" .. settings.network.value)
	:addParam("OW" .. settings.owner.value)
	:addParam("UC" .. base.tostring(uc))
	:addParam("SS" .. base.tostring(ss))
	:addParam("SF" .. base.tostring(sf))
	:addParam("UP" .. base.tostring(os.difftime(os.time(), adchpp.Stats_startTime)))
	if settings.maxusers.value > 0 then
		inf:addParam("MC" .. base.tostring(settings.maxusers.value))
	end
	c:send(inf)

	c:setState(adchpp.Entity_STATE_IDENTIFY)

	return false
end

local function onINF(c, cmd)
	for field, regex in base.pairs(inf_fields) do
		val = cmd:getParam(field, 0)
		if #val > 0 and not val:match(regex) then
			autil.reply(c, "INF parsing: field " .. field .. " has an invalid value, removed")
			cmd:delParam(field, 0)
		end
	end

	if #cmd:getParam("CT", 0) > 0 then
		autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "I decide what type you are")
		return false
	end

	local cid = cmd:getParam("ID", 0)
	local nick = cmd:getParam("NI", 0)
	if c:getState() == adchpp.Entity_STATE_NORMAL then
		return verify_info(c, cid, nick)
	end
	if not verify_info(c, cid, nick) then
		return false
	end

	if settings.sendversion.value == 1 then
		autil.reply(c, "This hub is running " .. adchpp.versionString)
	end

	local user = get_user(cid, nick)
	if user.level == 0 then
		-- non-reg user
		local code, err = check_max_users()
		if code then
			autil.dump(c, code, err)
			return false
		end

		-- let ClientManager further verify this INF
		return true
	end

	c:setFlag(adchpp.Entity_FLAG_REGISTERED)
	if user.level >= level_op then
		c:setFlag(adchpp.Entity_FLAG_OP)
	end
	cmd:addParam("CT", c:getField("CT"))

	if not cm:verifyINF(c, cmd) then
		return false
	end

	autil.reply(c, "You are registered, please provide a password")

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
	if user.is_default then
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
	
	if not cm:verifyOverflow(c) then
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

format_seconds = function(t)
	local t_d = math.floor(t / (60*60*24))
	local t_h = math.floor(t / (60*60)) % 24
	local t_m = math.floor(t / 60) % 60
	local t_s = t % 60

	return string.format("%d days, %d hours, %d minutes and %d seconds", t_d, t_h, t_m, t_s)
end

cut_str = function(str, max)
	if #str > max - 3 then
		return string.sub(str, 1, max - 3) .. "..."
	end
	return str
end

local cfg_list_done = false
local function gen_cfg_list()
	if cfg_list_done then
		return
	end
	local list = {}
	for k, v in base.pairs(settings) do
		local str = cut_str(v.help or "no information", 30)
		str = string.gsub(str, '/', '//')
		str = string.gsub(str, '%[', '{')
		str = string.gsub(str, '%]', '}')
		table.insert(list, k .. ": <" .. str .. ">")
	end
	table.sort(list)
	commands.cfg.user_command.params[1] = autil.ucmd_list("Name of the setting to change", list)
	cfg_list_done = true
end

commands.cfg = {
	alias = { changecfg = true, changeconfig = true, config = true, var = true, changevar = true, setvar = true, setcfg = true, setconfig = true },

	command = function(c, parameters)
		if not commands.cfg.protected(c) then
			return
		end

		local name, value = parameters:match("^(%S+) ?(.*)")
		if not name then
			autil.reply(c, "You need to supply a variable name")
			return
		end

		if string.sub(name, #name) == ":" then
			-- get rid of additional info for the UCMD list
			local found, _, params = string.find(parameters, "^[^>]+> (.+)")
			if not found then
				autil.reply(c, "Invalid parameters")
				return
			end
			name = string.sub(name, 1, #name - 1)
			value = params
		end

		local setting = nil
		for k, v in base.pairs(settings) do
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
			if type == "number" then
				value = "0"
			else
				value = ""
			end
		end

		if type == "number" then
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

		if setting.validate then
			local err = setting.validate(value)
			if err then
				autil.reply(c, "The new value \"" .. value .. "\" is invalid, no change done (" .. err .. ")")
				return
			end
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
		local list = {}
		for k, v in base.pairs(settings) do
			local str = k .. " - current value: " .. base.tostring(v.value)
			if v.help then
				str = str .. " - " .. v.help
			end
			if v.alias then
				local list_alias = {}
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

	user_command = {
		name = "Hub management" .. autil.ucmd_sep .. "Change a setting",
		params = {
			'', -- will be set by gen_cfg_list
			autil.ucmd_line("New value for the setting")
		}
	}
}

commands.help = {
	command = function(c, parameters)
		local command_help = function(k, v)
			local str = "+" .. k
			if v.help then
				str = str .. " " .. v.help
			end
			if v.alias then
				local list_alias = {}
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
			for k, v in base.pairs(commands) do
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
			local list = {}
			for k, v in base.pairs(commands) do
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
		autil.ucmd_line("Command name (facultative)")
	} }
}

commands.info = {
	alias = { hubinfo = true, stats = true, userinfo = true },

	command = function(c, parameters)
		if dispatch_stats then
			return
		end

		local str

		if #parameters > 0 then
			local user = cm:findByNick(parameters) -- by nick
			if not user then
				user = cm:findByCID(adchpp.CID(parameters)) -- by CID
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
				str = str .. "Level: " .. get_level(user) .. "\n"
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
				local users_ip = {}
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
			dispatch_stats = true
			c:inject(adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_HUB, c:getSID())
			:addParam('+stats'))
			dispatch_stats = false

			local now = os.time()
			local scripttime = os.difftime(now, start_time)
			local hubtime = os.difftime(now, adchpp.Stats_startTime)

			str = "\n"
			str = str .. "Hub uptime: " .. format_seconds(hubtime) .. "\n"
			str = str .. "Script uptime: " .. format_seconds(scripttime) .. "\n"

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
			
			str = str .. "\nSocket errors: \n"
			
			local keys = sm.errors:keys()
			local size = keys:size()
			
			for i = 0, size - 1 do
				local k = keys[i]
				str = str .. k .. "\t" .. sm.errors:get(k) .. "\n"
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

commands.listregs = {
	alias = { listreg = true, listregged = true, reggedusers = true, showreg = true, showregs = true, showregged = true },

	command = function(c, parameters)
		local user = get_user_c(c)
		if user.level == 0 then
			autil.reply(c, "Only registered users can use this command")
			return
		end

		local list = {}
		for _, v in base.ipairs(registered_users()) do
			if v.level <= user.level then
				local fields = {}
				if v.nick then
					table.insert(fields, "Nick: " .. v.nick)
				end
				if v.cid then
					table.insert(fields, "CID: " .. v.cid)
				end
				if settings.passinlist.value ~=0 and v.level < user.level and v.password then
					table.insert(fields, "Pass: " .. v.password)
				end
				table.insert(list, table.concat(fields, "\t"))
			end
		end
		table.sort(list)

		autil.reply(c, "Registered users with a level <= " .. user.level .. " (your level):\n" .. table.concat(list, "\n"))
	end,

	protected = function(c) return not get_user_c(c).is_default end,

	user_command = { name = "List regs" }
}

commands.myip = {
	alias = { getip = true, getmyip = true, ip = true, showip = true, showmyip = true },

	command = function(c)
		autil.reply(c, "Your IP: " .. c:getIp())
	end,

	user_command = { name = "My IP" }
}

commands.mypass = {
	alias = { regme = true, changepass = true, mypassword = true, changepassword = true, setpass = true, setpassword = true },

	command = function(c, parameters)
		if #parameters <= 0 then
			autil.reply(c, "You must provide a password")
			return
		end

		local user = get_user_c(c)
		if not user.is_default then
			-- already regged
			user.password = parameters
			base.pcall(save_users)
			autil.reply(c, "Your password has been changed to \"" .. parameters .. "\"")
		elseif settings.allowreg.value ~= 0 then
			register_user(c:getCID():toBase32(), c:getField("NI"), parameters, 1)
			autil.reply(c, "You're now registered with the password \"" .. parameters .. "\"")
		else
			autil.reply(c, "You are not allowed to register by yourself; ask an operator to do it for you")
			return
		end
	end,

	help = "new_pass - change your password, make sure you change it in your client options too",

	protected = function(c) return settings.allowreg.value ~=0 or has_level(c, 2) end,

	user_command = {
		name = "My pass",
		params = { autil.ucmd_line("New password") }
	}
}

commands.reload = {
	command = function() end, -- empty on purpose, this is handled via PluginManager::handleCommand

	help = "- reload scripts",

	protected = is_op,

	user_command = { name = "Hub management" .. autil.ucmd_sep .. "Reload scripts" }
}

commands.regnick = {
	alias = { reguser = true },

	command = function(c, parameters)
		local my_user = get_user_c(c)
		if my_user.is_default then
			autil.reply(c, "Only registered users may register others")
			return
		end

		local level_pos, _, level = parameters:find(" (%d*)$")
		if level_pos then
			parameters = parameters:sub(0, level_pos - 1)
			if #parameters <= 0 then
				autil.reply(c, "Bad arguments")
				return
			end
		end
		local nick, password = parameters:match("^(%S+) ?(.*)")
		if not nick then
			autil.reply(c, "You need to supply a nick")
			return
		end

		local other = cm:findByNick(nick)

		local cid
		if other then
			cid = other:getCID():toBase32()
		end

		local other_user = get_user(cid, nick)
		if other_user.level >= my_user.level then
			autil.reply(c, "There is already a registered user with a level higher or equal than yours with this nick")
			return
		end

		if level and string.len(level) > 0 then
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
			if not other_user then
				autil.reply(c, "\"" .. nick .. "\" is not registered")
				return
			end
			if other_user.nick then
				users.nicks[other_user.nick] = nil
			end
			if other_user.cid then
				users.cids[other_user.cid] = nil
			end
			base.pcall(save_users)

			autil.reply(c, "\"" .. nick .. "\" has been un-registered")

			if other then
				autil.reply(other, "You've been un-registered")
			end
			return
		end

		register_user(cid, nick, password, level)

		autil.reply(c, "\"" .. nick .. "\" has been registered")

		if other then
			autil.reply(other, "You've been registered with password \"" .. password .. "\"")
		end
	end,

	help = "nick [password] [level] - register a user; use no password to un-reg; level defaults to your own level minus one",

	protected = function(c) return has_level(c, 2) end,

	user_command = {
		hub_params = {
			autil.ucmd_line("Nick"),
			autil.ucmd_line("Password (leave empty to un-reg)"),
			autil.ucmd_line("Level (facultative; defaults to your own level minus one)")
		},
		name = "Hub management" .. autil.ucmd_sep .. "Register nick",
		user_params = {
			"%[userNI]",
			autil.ucmd_line("Password (leave empty to un-reg)"),
			autil.ucmd_line("Level (facultative; defaults to your own level minus one)")
		}
	}
}

commands.test = {
	command = function(c)
		autil.reply(c, "Test ok")
	end,

	help = "- make the hub reply \"Test ok\""
}

-- simply map to +cfg topic
commands.topic = {
	alias = { changetopic = true, settopic = true, changehubtopic = true, sethubtopic = true },

	command = function(c, parameters)
		commands.cfg.command(c, "topic " .. parameters)
	end,

	help = "topic - change the hub topic (shortcut to +cfg topic)",

	protected = commands.cfg.protected,

	user_command = {
		name = "Hub management" .. autil.ucmd_sep .. "Change the topic",
		params = { autil.ucmd_line("New topic") }
	}
}

function handle_plus_command(c, msg)
	local command, parameters = msg:match("^%+(%a+) ?(.*)")
	if command then
		for k, v in base.pairs(commands) do
			if k == command or (v.alias and v.alias[command]) then
				add_stats('+' .. command)
				v.command(c, parameters)
				return true
			end
		end
	end
	
	return false
end

local function onMSG(c, cmd)
	local msg = cmd:getParam(0)

	if not autil.reply_from then
		if handle_plus_command(c, msg) then
			return false
		end
	end

	if settings.maxmsglength.value > 0 and string.len(msg) > settings.maxmsglength.value then
		autil.reply(c, "Your message contained too many characters, max allowed is " .. settings.maxmsglength.value)
		return false
	end

	return true
end

local handlers = { 
	[adchpp.AdcCommand_CMD_SUP] = { onSUP }, 
	[adchpp.AdcCommand_CMD_INF] = { onINF }, 
	[adchpp.AdcCommand_CMD_PAS] = { onPAS }, 
	[adchpp.AdcCommand_CMD_MSG] = { onMSG },
}

function register_handler(command, handler, prio)
	if not handlers[command] then
		handlers[command] = { handler }
	else
		if prio then
			table.insert(handlers[command], 1, handler)
		else
			table.insert(handlers[command], handler)
		end			
	end
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
		local restricted = restricted_commands[cmd:getCommand()]
		if restricted and get_level(c) < restricted.level then
			c:send(adchpp.AdcCommand(adchpp.AdcCommand_CMD_STA, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
			:addParam(adchpp.AdcCommand_SEV_RECOVERABLE .. adchpp.AdcCommand_ERROR_COMMAND_ACCESS)
			:addParam("You are not allowed to " .. restricted.str .. " in this hub")
			:addParam("FC" .. cmd:getFourCC()))
			return false
		end
	end

	if cmd:getTo() ~= adchpp.AdcCommand_HUB_SID then
		autil.reply_from = cm:getEntity(cmd:getTo())
	end

	-- TODO There has to be a better way of doing this...
	local meta = base.getmetatable(c)
	local fn = meta[".fn"]
	if not fn.getUser then
		fn.getUser = get_user_c
		fn.getLevel = function(c) return get_user_c(c).level end
	end
	
	local ret = true
	local handler = handlers[cmd:getCommand()]
	if handler then
		for k,v in base.pairs(handler) do
			ret = v(c, cmd)
			if not ret then
				break
			end
		end
	end

	autil.reply_from = nil

	return ret
end

base.pcall(load_users)

if not base.pcall(load_settings) then
	base.pcall(save_settings) -- save initial settings
end

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
			gen_cfg_list()
			send_user_commands(c)
		end
	end
end)

access_3 = pm:getCommandSignal("reload"):connect(function(entity, list, ok)
	return commands.reload.protected(entity)
end)

access_4 = pm:getCommandSignal("stats"):connect(function()
	return dispatch_stats
end)
