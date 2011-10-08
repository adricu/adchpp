--[[
The final intention of this script is to base the rate rules on a "severnes" factor meaning taking into account what the context of the command is and the size of the strings it will generate but so far it's only rate based so if somebody feels like ? lol (cologic thx for that idea, it's the only way to do it right)

The intention was to make on 1 side a "hubs users friendly" anti flood and guard system, so if one by "accident" spams he will receive warnings and his action will be stopped, after some time, in most cases less then 15 seconds, he can use the command again like any other user and on the other side prevent the hammering of users that do not comply to the limit rules.

Read the Guard-HowTo.rtf it will give you a nice idea of whats possible and what not ...
]]

local base = _G

module("access.guard")

base.require("luadchpp")
local adchpp = base.luadchpp
local autil = base.require("autil")
local json = base.require("json")
local io = base.require("io")
local os = base.require("os")
local string = base.require("string")
local table = base.require("table")
local math = base.require("math")

base.assert(math.ceil(adchpp.versionFloat * 100) >= 280, 'ADCH++ 2.8.0 or later is required to run access.guard.lua')
base.assert(base['access'], 'access.lua must be loaded and running before ' .. _NAME .. '.lua')
base.assert(base.access['bans'], 'access.bans.lua must be loaded and running before ' .. _NAME .. '.lua')

local start_time = os.time()

local access = base.require("access")
local banslua = base.require("access.bans")
local users = access.users
local commands = access.commands
local cid_regex = access.cid_regex
local pid_regex = access.pid_regex
local sid_regex = access.sid_regex
local integer_regex = access.integer_regex
local inf_fields = access.inf_fields
local context_hub = access.context_hub
local context_bcast = access.context_bcast
local context_direct = access.context_direct
local context_send = access.context_send
local context_hubdirect = access.context_hubdirect
local command_contexts = access.command_contexts
local bans = banslua.bans
local save_bans = banslua.save_bans

local cm = adchpp.getCM()
local lm = adchpp.getLM()
local pm = adchpp.getPM()
local sm = adchpp.getSM()

local function log(message)
	lm:log(_NAME, message)
end

-- Where to read/write database and settings
local fl_settings_file = adchpp.Util_getCfgPath() .. "fl_settings.txt"
local li_settings_file = adchpp.Util_getCfgPath() .. "li_settings.txt"
local en_settings_file = adchpp.Util_getCfgPath() .. "en_settings.txt"
local fldb_folder = "FL_DataBase"
local script_path = base.scriptPath .. '/'
local fldb_path = script_path .. fldb_folder .. '/'
local fldb_path = string.gsub(fldb_path, '\\', '/')
local fldb_path = string.gsub(fldb_path, '//+', '/')
local limitstats_file = fldb_path .. "limitstats.txt"
local commandstats_file = fldb_path .. "commandstats.txt"
local tmpbanstats_file = fldb_path .. "tmpbanstats.txt"
local kickstats_file = fldb_path .. "kickstats.txt"
local entitystats_file = fldb_path .. "entitystats.txt"

-- Setting the level for administrating commands, viewing the stats and script's bans
local level_admin = 9
local level_stats = access.settings.oplevel.value
local level_script = access.settings.oplevel.value

-- Script version
guardrev = "1.0.29"

-- Tmp tables
local data = {}
local update = {}
local info = {}
local histdata = {}

-- Table for the scripts own settings
local fl_settings = {}
local li_settings = {}
local en_settings = {}

-- Cache for TODO Defcon state
local restricted_commands = {}

-- Tables for the temp bans counter
local tmpbanstats = {}
tmpbanstats.ips = {}
tmpbanstats.cids = {}

-- Tables for the kicks counter
local kickstats = {}
kickstats.ips = {}
kickstats.cids = {}

-- Table for each of the adc commandsstats
local commandstats = {}
commandstats.urxcmds = {}
commandstats.crxcmds = {}
commandstats.cmdcmds = {}
commandstats.sidcmds = {}
commandstats.supcmds = {}
commandstats.concmds = {}
commandstats.soccmds = {}
commandstats.infcmds = {}
commandstats.pascmds = {}
commandstats.stacmds = {}
commandstats.msgcmds = {}
commandstats.schmancmds = {}
commandstats.schmansegacmds = {}
commandstats.schtthcmds = {}
commandstats.schmannatcmds = {}
commandstats.schtthnatcmds = {}
commandstats.schtthnatsegacmds = {}
commandstats.rescmds = {}
commandstats.ctmcmds = {}
commandstats.rcmcmds = {}
commandstats.natcmds = {}
commandstats.rntcmds = {}
commandstats.psrcmds = {}
commandstats.getcmds = {}
commandstats.sndcmds = {}

-- Table for each of the limitstats
local limitstats = {}
limitstats.maxschparams = {}
limitstats.maxschlengths = {}
limitstats.minschlengths = {}
limitstats.maxmsglengths = {}
limitstats.minnicklengths = {}
limitstats.maxnicklengths = {}
limitstats.minsharefiles = {}
limitstats.maxsharefiles = {}
limitstats.minsharesizes = {}
limitstats.maxsharesizes = {}
limitstats.minslots = {}
limitstats.maxslots = {}
limitstats.minhubslotratios = {}
limitstats.maxhubslotratios = {}
limitstats.maxhubcounts = {}
limitstats.suadcs = {}
limitstats.sunatts = {}
limitstats.subloms = {}
limitstats.maxsameips = {}

-- Table for the entity's 
local entitystats = {}
entitystats.last_cids = {}
entitystats.hist_cids = {}

local function load_tmpbanstats()
	tmpbanstats = {}
	tmpbanstats.ips = {}
	tmpbanstats.cids = {}
	local file = io.open(tmpbanstats_file, "r")
	if not file then
		os.execute("mkdir ".. fldb_folder)
		log("Unable to open " .. tmpbanstats_file .. ", tmpbanstats not loaded")
		return
	end

	local str = file:read("*a")
	file:close()

	if #str == 0 then
		return
	end

	local ok, list = base.pcall(json.decode, str)
	if not ok then
		log("Unable to decode tmpbanstats file: " .. list)
		return
	end

	tmpbanstats = list
	if not tmpbanstats.ips then
		tmpbanstats.ips = {}
	end
	if not	tmpbanstats.cids then
		tmpbanstats.cids = {}
	end

end

local function load_kickstats()
	kickstats = {}
	kickstats.ips = {}
	kickstats.cids = {}

	local file = io.open(kickstats_file, "r")
	if not file then
		log("Unable to open " .. kickstats_file .. ", kickstats not loaded")
		return
	end

	local str = file:read("*a")
	file:close()

	if #str == 0 then
		return
	end

	local ok, list = base.pcall(json.decode, str)
	if not ok then
		log("Unable to decode kickstats file: " .. list)
		return
	end

	kickstats = list
	if not kickstats.ips then
		kickstats.ips = {}
	end
	if not	kickstats.cids then
		kickstats.cids = {}
	end
end

local function load_commandstats()
	commandstats = {}
	commandstats.urxcmds = {}
	commandstats.crxcmds = {}
	commandstats.sidcmds = {}
	commandstats.cmdcmds = {}
	commandstats.supcmds = {}
	commandstats.concmds = {}
	commandstats.soccmds = {}
	commandstats.infcmds = {}
	commandstats.pascmds = {}
	commandstats.stacmds = {}
	commandstats.msgcmds = {}
	commandstats.schmancmds = {}
	commandstats.schmansegacmds = {}
	commandstats.schtthcmds = {}
	commandstats.schmannatcmds = {}
	commandstats.schmannatsegacmds = {}
	commandstats.schtthnatcmds = {}
	commandstats.rescmds = {}
	commandstats.ctmcmds = {}
	commandstats.rcmcmds = {}
	commandstats.natcmds = {}
	commandstats.rntcmds = {}
	commandstats.psrcmds = {}
	commandstats.getcmds = {}
	commandstats.sndcmds = {}

	local file = io.open(commandstats_file, "r")
	if not file then
		log("Unable to open " .. commandstats_file .. ", commandstats not loaded")
		
		return
	end

	local str = file:read("*a")
	file:close()

	if #str == 0 then
		return
	end

	local ok, list = base.pcall(json.decode, str)
	if not ok then
		log("Unable to decode commandstats file: " .. list)
		return
	end

	commandstats = list
	if not	commandstats.urxcmds then
		commandstats.urxcmds = {}
	end
	if not	commandstats.crxcmds then
		commandstats.crxcmds = {}
	end
	if not	commandstats.cmdcmds then
		commandstats.cmdcmds = {}
	end
	if not	commandstats.sidcmds then
		commandstats.sidcmds = {}
	end
	if not commandstats.supcmds then
		commandstats.supcmds = {}
	end
	if not commandstats.concmds then
		commandstats.concmds = {}
	end
	if not commandstats.soccmds then
		commandstats.soccmds = {}
	end
	if not commandstats.infcmds then
		commandstats.infcmds = {}
	end
	if not commandstats.pascmds then
		commandstats.pascmds = {}
	end
	if not commandstats.stacmds then
		commandstats.stacmds = {}
	end
	if not	commandstats.msgcmds then
		commandstats.msgcmds = {}
	end
	if not commandstats.schmancmds then
		commandstats.schmancmds = {}
	end
	if not commandstats.schmansegacmds then
		commandstats.schmansegacmds = {}
	end
	if not commandstats.schtthcmds then
		commandstats.schtthcmds = {}
	end
	if not commandstats.schmannatcmds then
		commandstats.schmannatcmds = {}
	end
	if not commandstats.schmannatsegacmds then
		commandstats.schmannatsegacmds = {}
	end
	if not commandstats.schtthnatcmds then
		commandstats.schtthnatcmds = {}
	end
	if not commandstats.rescmds then
		commandstats.rescmds = {}
	end
	if not commandstats.ctmcmds then
		commandstats.ctmcmds = {}
	end
	if not commandstats.rcmcmds then
		commandstats.rcmcmds = {}
	end
	if not commandstats.natcmds then
		commandstats.natcmds = {}
	end
	if not commandstats.rntcmds then
		commandstats.rntcmds = {}
	end
	if not commandstats.psrcmds then
		commandstats.psrcmds = {}
	end
	if not commandstats.getcmds then
		commandstats.sndcmds = {}
	end
	if not commandstats.getcmds then
		commandstats.sndcmds = {}
	end
end

local function load_limitstats()
	limitstats = {}
	limitstats.maxschparams = {}
	limitstats.maxschlengths = {}
	limitstats.minschlengths = {}
	limitstats.maxmsglengths = {}
	limitstats.minnicklengths = {}
	limitstats.maxnicklengths = {}
	limitstats.minsharefiles = {}
	limitstats.maxsharefiles = {}
	limitstats.minsharesizes = {}
	limitstats.maxsharesizes = {}
	limitstats.minslots = {}
	limitstats.maxslots = {}
	limitstats.minhubslotratios = {}
	limitstats.maxhubslotratios = {}
	limitstats.maxhubcounts = {}
	limitstats.suadcs = {}
	limitstats.sunatts = {}
	limitstats.subloms = {}
	limitstats.maxsameips = {}
	local file = io.open(limitstats_file, "r")
	if not file then
		log("Unable to open " .. limitstats_file .. ", limitstats not loaded")
		return
	end

	local str = file:read("*a")
	file:close()

	if #str == 0 then
		return
	end

	local ok, list = base.pcall(json.decode, str)
	if not ok then
		log("Unable to decode limitstats file: " .. list)
		return
	end

	limitstats = list
	if not limitstats.maxschparams then
		limitstats.maxschparams = {}
	end
	if not limitstats.maxschlengths then
		limitstats.maxschlengths = {}
	end
	if not limitstats.minschlengths then
		limitstats.minschlengths = {}
	end
	if not limitstats.maxmsglengths then
		limitstats.maxmsglengths = {}
	end
	if not limitstats.minnicklengths then
		limitstats.minnicklengths = {}
	end
	if not limitstats.maxnicklengths then
		limitstats.maxnicklengths = {}
	end
	if not limitstats.minsharefiles then
		limitstats.minsharefiles = {}
	end
	if not limitstats.maxsharefiles then
		limitstats.maxsharefiles = {}
	end
	if not limitstats.minsharesizes then
		limitstats.minsharesizes = {}
	end
	if not limitstats.maxsharesizes then
		limitstats.maxsharesizes = {}
	end
	if not limitstats.minslots then
		limitstats.minslots = {}
	end
	if not limitstats.maxslots then
		limitstats.maxslots = {}
	end
	if not limitstats.minhubslotratios then
		limitstats.minhubslotratios = {}
	end
	if not limitstats.maxhubslotratios then
		limitstats.maxhubslotratios = {}
	end
	if not limitstats.maxhubcounts then
		limitstats.maxhubcounts = {}
	end
	if not limitstats.suadcs then
		limitstats.suadcs = {}
	end
	if not limitstats.sunatts then
		limitstats.sunatts = {}
	end
	if not limitstats.subloms then
		limitstats.subloms = {}
	end
	if not limitstats.maxsameips then
		limitstats.maxsameips = {}
	end
end

local function load_entitystats()
	entitystats = {}
	entitystats.last_cids = {}
	entitystats.hist_cids = {}
	local file = io.open(entitystats_file, "r")
	if not file then
		log("Unable to open " .. entitystats_file .. ", entitystats not loaded")
		return
	end

	local str = file:read("*a")
	file:close()

	if #str == 0 then
		return
	end

	local ok, list = base.pcall(json.decode, str)
	if not ok then
		log("Unable to decode entitystats file: " .. list)
		return
	end

	entitystats = list
	if not entitystats.last_cids then
		entitystats.last_cids = {}
	end
	if not entitystats.hist_cids then
		entitystats.hist_cids = {}
	end
end

local function save_tmpbanstats()
	local file = io.open(tmpbanstats_file, "w")
	if not file then
		log("Unable to open " .. tmpbanstats_file .. ", tmpbanstats not saved")
		return
	end
	file:write(json.encode(tmpbanstats))
	file:close()
end

local function save_kickstats()
	local file = io.open(kickstats_file, "w")
	if not file then
		log("Unable to open " .. kickstats_file .. ", kickstats not saved")
		return
	end
	file:write(json.encode(kickstats))
	file:close()
end

local function save_limitstats()
	local file = io.open(limitstats_file, "w")
	if not file then
		log("Unable to open " .. limitstats_file .. ", limitstats not saved")
		return
	end
	file:write(json.encode(limitstats))
	file:close()
end

local function save_commandstats()
	local file = io.open(commandstats_file, "w")
	if not file then
		log("Unable to open " .. commandstats_file .. ", commandstats not saved")
		return
	end
	file:write(json.encode(commandstats))
	file:close()
end

local function save_entitystats()
	local file = io.open(entitystats_file, "w")
	if not file then
		log("Unable to open " .. entitystats_file .. ", entitystats not saved")
		return
	end
	file:write(json.encode(entitystats))
	file:close()
end

local function handle_plus_command(c, msg)
	local command, parameters = msg:match("^%+(%a+) ?(.*)")
	if command then
		for k, v in base.pairs(commands) do
			if k == command or (v.alias and v.alias[command]) then
				return true
			end
		end
	end
	return false
end

local cut_str = function(str, max)
	if #str > max - 3 then
		return string.sub(str, 1, max - 3) .. "..."
	end
	return str
end

local function data_expiration_diff(data)
	return os.difftime(data.expires, os.time())
end

local function hist_expiration_diff(hist)
	return os.difftime(hist.histexpires, os.time())
end

local function data_started_diff(data)
	return os.difftime(os.time(), data.started)
end

local function data_updated_diff(data)
	return os.difftime(os.time(), data.updated)
end

local function hist_started_diff(hist)
	return os.difftime(os.time(), hist.histstarted)
end

local function data_join_diff(data)
	return os.difftime(os.time(), data.join)
end

local function data_leave_diff(data)
	return os.difftime(os.time(), data.leave)
end

local function data_join_now_diff(data)
	return os.difftime(os.time(), data.join)
end

local function clear_expired_limitstats()
	for _, limitstats_array in base.pairs(limitstats) do
		for k, data in base.pairs(limitstats_array) do
			if data.expires and data_expiration_diff(data) <= 0 then
				limitstats_array[k] = nil
			end
		end
	end
end

local function clear_expired_commandstats()
	for _, command_array in base.pairs(commandstats) do
		for k, data in base.pairs(command_array) do
			if data.expires and data_expiration_diff(data) <= 0 then
				command_array[k] = nil
			end
		end
	end
end

local function clear_expired_tmpbanstats()
	for _, command_array in base.pairs(tmpbanstats) do
		for k, data in base.pairs(command_array) do
			if data.expires and data_expiration_diff(data) <= 0 then
				command_array[k] = nil
			end
		end
	end
end

local function clear_expired_kickstats()
	for _, command_array in base.pairs(kickstats) do
		for k, data in base.pairs(command_array) do
			if data.expires and data_expiration_diff(data) <= 0 then
				command_array[k] = nil
			end
		end
	end
end

local function clear_expired_entitystats()
	for _, command_array in base.pairs(entitystats) do
		for k, data in base.pairs(command_array) do
			if data.expires and data_expiration_diff(data) <= 0 then
				command_array[k] = nil
			end
		end
	end
end

local function data_expiration_string(data)
	if data.expires then
		local diff = data_expiration_diff(data)
		if diff > 0 then
			return "in " .. access.format_seconds(diff)
		else
			return "expired"
		end
	else
		return "never"
	end
end

local function data_started_string(data)
	if data.started then
		local diff = data_started_diff(data)
		if diff > 0 then
			return access.format_seconds(diff).. " ago"
		else
			return "something go's wrong here lol (diff = 0)"
		end
	else
		return "not started after the last kick"
	end
end

local function data_updated_string(data)
	if data.updated then
		local diff = data_updated_diff(data)
		if diff > 0 then
			return access.format_seconds(diff).. " ago"
		else
			return "something go's wrong here lol (diff = 0)"
		end
	else
		return "not updated after first registration"
	end
end

local function data_timeon_string(data)
	if data.ltimeon then
		local time = data.ltimeon + data_join_now_diff(data)
		if time > 0 then
			return access.format_seconds(time)
		else
			return "no online time info yet"
		end
	else
		return "no online time info yet"
	end
end

local function data_join_string(data)
	if data.join then
		local diff = data_join_diff(data)
		if diff > 0 then
			return access.format_seconds(diff).. " ago"
		else
			return "no logon info yet"
		end
	else
		return "no logon info yet"
	end
end

local function data_leave_string(data)
	if data.leave then
		local diff = data_leave_diff(data)
		if diff > 0 then
			return access.format_seconds(diff).. " ago"
		else
			return "no logoff info yet"
		end
	else
		return "no logoff info yet"
	end
end

local function data_rate_string(rate)
	if rate == 0 then
		rate = "0.00"
	end
	return rate
end

local function data_info_string_cid(info)
	local str = "\tCounter: " .. info.count
	if info.warns then
		str = str .. "\tWarns: " .. info.warns
	end

	if info.kicks then
		str = str .. "\tKicks: " .. info.kicks
	end

	if info.rate then
		str = str .. "\n\tAvg.Rate: " .. data_rate_string(info.rate) .. " / m"
	end

	if info.maxrate then
		str = str .. "\t\t\tMax.Rate: " .. data_rate_string(info.maxrate) .. " / m"
	end

	if info.diffrate then
		str = str .. "\t\t\tDiff.Rate: " .. data_rate_string(info.diffrate) .. " / m"
	end

	if info.ip then
		str = str .. "\n\tIP:  " .. info.ip
	end

	if info.ap then
		if info.ve then
			str = str .. " \t\t\tAP: " .. info.ap .. " " .. info.ve 
		end
	else
		if info.ve then
			str = str .. " \t\t\tAP: " .. info.ve
		end
	end

	if info.ni then
		str = str .. "     \t\t\tNI: " .. info.ni
	end

	str = str .. "\n\tStarted: " .. data_started_string(info)

	str = str .. "\t\tExpires: " .. data_expiration_string(info) .. "\n"

	return str
end

local function data_info_string_ip(info)
	local str = "\t\t\t\t\t\tCounter: " .. info.count
	if info.warns then
		str = str .. "\tWarns: " .. info.warns
	end

	if info.kicks then
		str = str .. "\tKicks: " .. info.kicks
	end

	if info.rate then
		str = str .. "\n\tAvg.Rate: " .. data_rate_string(info.rate) .. " / m"
	end

	if info.maxrate then
		str = str .. "\t\t\tMax.Rate: " .. data_rate_string(info.maxrate) .. " / m"
	end

	if info.diffrate then
		str = str .. "\t\t\tDiff.Rate: " .. data_rate_string(info.diffrate) .. " / m"
	end

	str = str .. "\n\tStarted: " .. data_started_string(info)

	str = str .. "\t\tExpires: " .. data_expiration_string(info) .. "\n"
	return str
end

local function data_info_string_log(info)
	local str = "   \t\t\tCounter: " .. info.count
	if info.rate then
		str = str .. "\n\tAvg.Rate: " .. data_rate_string(info.rate) .. " / m"
	end

	if info.maxrate then
		str = str .. "\t\t\tMax.Rate: " .. data_rate_string(info.maxrate) .. " / m"
	end

	if info.diffrate then
		str = str .. "\t\t\tDiff.Rate: " .. data_rate_string(info.diffrate) .. " / m"
	end

	if info.ni then
		str = str .. "\t\t\tNick: " .. info.ni
	end

	if info.reason then
		str = str .. "\n\tReason: " .. info.reason
	end

	if info.ap then
		if info.ve then
			str = str .. "\t\t\tClient: " .. info.ap .. " " .. info.ve
		end
	else
		if info.ve then
			str = str .. "\t\t\tClient: " .. info.ve
		end
	end

	str = str .. "   \t\t\tExpires: " .. data_expiration_string(info) .. "\n"

	return str
end

local function data_info_string_entity(info)

	local str = "\n\tIP:\t\t\t\t\t" .. info.ip

	if info.ni then
		str = str .. "\n\tNick:\t\t\t\t\t" .. info.ni
	end

	if info.ap then
		if info.ve then
			str = str .. "\n\tClient:\t\t\t\t\t" .. info.ap .. " " .. info.ve
		end
	else
		if info.ve then
			str = str .. "\n\tClient:\t\t\t\t\t" .. info.ve
		end
	end

	if info.level then
		str = str .. "\n\tUsers Level:\t\t\t\t" .. info.level
	end

	if info.changes then
		str = str .. "\n\tChanged Nick, IP, CID or Level:\t\t" .. info.changes .. " times"
	end

	if info.logins then
		str = str .. "\n\tLogins:\t\t\t\t\t" .. info.logins .. " times"
	end

	if info.join then
		str = str .. "\n\tLast Logon:\t\t\t\t" .. data_join_string(info)
	end

	if info.leave and info.join and info.leave > info.join then
		str = str .. "\n\tLast Logoff:\t\t\t\t" .. data_leave_string(info)
		if info.ltimeon then
			str = str .. "\n\tTotal Time Online:\t\t\t" .. access.format_seconds(info.ltimeon)
		end
	else
		if info.timeon then
			str = str .. "\n\tTotal Time Online:\t\t\t" .. data_timeon_string(info)
		end
	end

	if info.updated then
	str = str .. "\n\tLast Updated Nick, IP, CID or Level:\t" .. data_updated_string(info)
	end

	if users.cids[info.cid] then
		local user = users.cids[info.cid]
		if user.regby then
			str = str .. "\n\tEntity Regged by:\t\t\t" .. user.regby 
		end
	end

	if info.started then
	str = str .. "\n\tEntity Created:\t\t\t\t" .. data_started_string(info)
	end

	str = str .. "\n\tEntity Expires:\t\t\t\t" .. data_expiration_string(info) .. "\n"

	return str
end

local function data_info_string_entity_hist(info)

	local str = "\tCID: " .. info.cid

	if info.ip then
		str = str .. "\n\tIP: " .. info.ip
	end

	if info.ni then
		str = str .. "\t\tNI: " .. info.ni
	end

	if info.logins then
		str = str .. "\n\tLogins: " .. info.logins
	end

	if info.changes then
		str = str .. "\t\tTimes Changed: " .. info.changes
	end

	if info.ap then
		if info.ve then
			str = str .. " \t\tAP: " .. info.ap .. " " .. info.ve 
		end
	else
		if info.ve then
			str = str .. " \t\tAP: " .. info.ve
		end
	end

	if info.updated then
	str = str .. "\n\tHist Created: " .. data_updated_string(info)
	end

	if info.started then
	str = str .. "\n\tEntity Created: " .. data_started_string(info) .. "\n"
	end

	return str
end

local function get_rate(started, count)
	local round = 2
	local mult = 10^(round or 0)
	local diff = os.difftime(os.time(), started)
	local rawrate = count / diff * 60 
	local rate = base.math.floor(rawrate * mult + 0.5) / mult
	if base.tostring(rate) == "1.#INF" or base.tostring(rate) == "inf" then
		rate = 9999
	end
	return rate
end

local function get_diffrate(fix, agefactor)
	local round = 2
	local mult = 10^(round or 0)
	local rawrate = (fix - (fix * agefactor)) * 60
	local diffrate = base.math.floor(rawrate * mult + 0.5) / mult
	if base.tostring(diffrate) == "1.#INF" or base.tostring(diffrate) == "inf" then
		diffrate = 9999
	end
	return diffrate
end

local function get_sameip(c)
 	local ip = c:getIp()
	local countip = 1 -- user that connects
	local entities = adchpp.getCM():getEntities()
	local size = entities:size()
	if size > 0 then
		for i = 0, size - 1 do
			local c = entities[i]:asClient()
			if c and c:getIp() == ip then
				countip = countip + 1
			end
		end
	end
	return countip
end

local function ban_expiration_diff(minutes)
	local expires = os.time() + minutes * 60
	return os.difftime(expires, os.time())
end

local function verify_maxtmpbans(c, cmd, expire)
	if fl_settings.fl_maxtmpbans.value > 0 then
		local cid
		if c:getState() == adchpp.Entity_STATE_NORMAL then 
			cid = c:getCID():toBase32()
		elseif cmd then
			cid = cmd:getParam("ID", 0)
		end
		local ip = c:getIp()
		if cid and tmpbanstats.cids[cid].count >= fl_settings.fl_maxtmpbans.value then
			tmpbanstats.cids[cid] = nil
			local expire = nil
			return expire
		end
		if tmpbanstats.ips[ip].count >= fl_settings.fl_maxtmpbans.value then
			tmpbanstats.ips[ip] = nil
			local expire = nil
			return expire
		end
	end
	return expire
end

local function dump_banned(c, cmd, update, msg, minutes)
	local cid, count, countcid, countip, tmpban
	local expire = os.time() + minutes * 60
	local logexpire = os.time() + fl_settings.fl_logexptime.value * 86400
	if c:getState() == adchpp.Entity_STATE_NORMAL then
		cid = c:getCID():toBase32()
	elseif cmd then
		cid = cmd:getParam("ID", 0)
	end
	local ip = c:getIp()
	if tmpbanstats.cids[cid] or tmpbanstats.ips[ip] then
		if c:getState() ~= adchpp.Entity_STATE_PROTOCOL and tmpbanstats.cids[cid] then
			countcid = tmpbanstats.cids[cid].count + 1
		else
			countcid = 0
		end
		if tmpbanstats.ips[ip] then
			countip = tmpbanstats.ips[ip].count + 1
		else
			countip = 0
		end
		if countcid >= countip then
			count = countcid
		else
			count = countip
		end
		tmpban = { count = count, reason = msg, rate = update.rate, diffrate = update.diffrate, ni = update.ni, ve = update.ve, expires = logexpire }
	else
		tmpban = { count = 1, reason = msg, rate = update.rate, diffrate = update.diffrate, ni = update.ni, ve = update.ve, expires = logexpire }
	end
	if c:getState() ~= adchpp.Entity_STATE_PROTOCOL then 
		tmpbanstats.cids[cid] = tmpban
	end
	tmpbanstats.ips[ip] = tmpban
	expire = verify_maxtmpbans(c, cmd, expire)
	if not expire then
		msg = "For ( "..count.." times ) beeing temporary banned !!!"
		minutes = expire
	end
	if c:getState() ~= adchpp.Entity_STATE_PROTOCOL then
		if bans.cids[cid] then
			if bans.cids[cid].expires then
				if not expire or bans.cids[cid].expires < expire then
					bans.cids[cid] = { level = level_script, reason = msg, expires = expire }
				end
			end
		else
			bans.cids[cid] = { level = level_script, reason = msg, expires = expire }
		end
	else
		if bans.ips[ip] then
			if bans.ips[ip].expires then
				if not expire or bans.ips[ip].expires < expire then
					bans.ips[ip] = { level = level_script, reason = msg, expires = expire }
				end
			end
		else
			bans.ips[ip] = { level = level_script, reason = msg, expires = expire }
		end
	end
	local str = "You are banned: "
	str = str .. "Reason: " .. msg
	if minutes then
		str = str .. "\n\tExpires in: " .. access.format_seconds(minutes * 60)
	else
		str = str .. "\n\tExpires never !"
	end
	autil.dump(c, adchpp.AdcCommand_ERROR_BANNED_GENERIC, function(cmd)
		cmd:addParam("MS" .. str)
		local expires
		if minutes then
			expires = ban_expiration_diff(minutes)
		else
			expires = -1
		end
		cmd:addParam("TL" .. base.tostring(expires))
	end)
end

local function verify_maxkicks(c, cmd, update, msg, minutes)
	if fl_settings.fl_maxkicks.value > 0 and fl_settings.fl_tmpban.value > 0 then
		local cid
		if c:getState() == adchpp.Entity_STATE_NORMAL then 
			cid = c:getCID():toBase32()
		elseif cmd then
			cid = cmd:getParam("ID", 0)
		end
		local ip = c:getIp()
		if cid and kickstats.cids[cid].count >= fl_settings.fl_maxkicks.value then
			local count = kickstats.cids[cid].count
			local msg = "For ( "..count.." times ) beeing kicked !!! Last kick: " .. msg
			dump_banned(c, cmd, update, msg, minutes)
			kickstats.cids[cid] = nil
			update = nil
			return update
		end
		if kickstats.ips[ip].count >= fl_settings.fl_maxkicks.value then
			local count = kickstats.ips[ip].count
			local msg = "For ( "..count.." times ) beeing kicked !!! Last kick: " .. msg
			dump_banned(c, cmd, update, msg, minutes)
			kickstats.ips[ip] = nil
			update = nil
			return update
		end	
	end
	return update
end

local function dump_kicked(c, cmd, update, msg)
	local str = "You are kicked because:" .. msg
	local expires = -1
	local cid, count
	if c:getState() == adchpp.Entity_STATE_NORMAL then
		cid = c:getCID():toBase32()
	elseif cmd then
		cid = cmd:getParam("ID", 0)
	end
	local ip = c:getIp()

	if fl_settings.fl_logexptime.value > 0 and fl_settings.fl_maxkicks.value > 0 then
		local minutes = fl_settings.fl_tmpban.value
		local logexpires = fl_settings.fl_logexptime.value * 86400
		if cid then
			if not kickstats.cids[cid] and not kickstats.ips[ip] then
				local kick = { count = 1, reason = str, rate = update.rate, diffrate = update.diffrate, ni = update.ni, ve = update.ve, expires = os.time() + logexpires }
				kickstats.cids[cid] = kick
				kickstats.ips[ip] = kick
			else
				local kick = { count = 1, reason = str, rate = update.rate, diffrate = update.diffrate, ni = update.ni, ve = update.ve, expires = os.time() + logexpires }
				if not kickstats.ips[ip] then
					kickstats.ips[ip] = kick
				end
				if not kickstats.cids[cid] then
					kickstats.cids[cid] = kick
				end
				if kickstats.cids[cid] and kickstats.cids[cid].count >= kickstats.ips[ip].count then
					count = kickstats.cids[cid].count + 1
				else
					count = kickstats.ips[ip].count + 1
				end
				local kick = { count = count, reason = str, rate = update.rate, diffrate = update.diffrate, ni = update.ni, ve = update.ve, expires = os.time() + logexpires }
				kickstats.cids[cid] = kick
				kickstats.ips[ip] = kick
				update = verify_maxkicks(c, cmd, update, msg, minutes)
				if not update then
					return update
				end
			end
		else
			if not kickstats.ips[ip] then
				local kick = { count = 1, reason = str, rate = update.rate, diffrate = update.diffrate, ni = update.ni, ve = update.ve, expires = os.time() + logexpires }
				kickstats.ips[ip] = kick
			else
				count = kickstats.ips[ip].count
				local kick = { count = count + 1, reason = str, rate = update.rate, diffrate = update.diffrate, ni = update.ni, ve = update.ve, expires = os.time() + logexpires }
				kickstats.ips[ip] = kick
				update = verify_maxkicks(c, cmd, update, msg, minutes)
				if not update then
					return update
				end
			end
		end
	end
	autil.dump(c, adchpp.AdcCommand_ERROR_BANNED_GENERIC, function(cmd)
		cmd:addParam("MS" .. str)
		cmd:addParam("TL" .. base.tostring(expires))
	end)
	update.count = 0
	update.rate = 0
	update.warns = 0
	update.started = nill
	update.kicks = update.kicks + 1
	update.warning = 0
	return update
end

local function dump_redirected(c, msg)
	local address = li_settings.li_redirect.value
	if string.len(address) > 0 then
		local str = "You are redirected because: " .. msg
		autil.dump(c, adchpp.AdcCommand_ERROR_BANNED_GENERIC, function(cmd)
			cmd:addParam("MS" .. str)
			cmd:addParam("RD" .. address)
		end)
	else
		local str = "You are disconnected because: " .. msg
		autil.dump(c, adchpp.AdcCommand_ERROR_BANNED_GENERIC, function(cmd)
			cmd:addParam("MS" .. str)
			cmd:addParam("TL" .. base.tostring(-1))
		end)
	end
end

local function dump_dropped(c, msg)
	if msg then
		local str = "You are disconnected because: " .. msg
	end
	autil.dump(c, adchpp.AdcCommand_ERROR_BANNED_GENERIC, function(cmd)
		if str then
			cmd:addParam("MS" .. str)
		end
		cmd:addParam("TL" .. base.tostring(-1))
	end)
end

local function update_diffhists(diffhists, diffrate, histdata)
	local minutes = 2 -- expire time for the record, the record will not be used for the differential anymore so user can				spam again if not kicked by the rule this value is also important for the age factor as	that uses 				the total diffhits to lower the diffrate. 
	local trigger = 60 -- age in seconds that adds the record to the calculation off the differential
	local diffcount = 2 -- number of records counted in the trigger time span to trigger the differential rate
	local diffhits = 0
	local diffstimes = 0
--	local defcon = false TODO
	local i = 0
	local agefactor = 0
	local tmp = { count = histdata.count }
	tmp.started = histdata.started
	tmp.rate = histdata.rate
	tmp.maxrate = histdata.maxrate
	tmp.histstarted = os.time()
	tmp.histexpires = os.time() + minutes * 60
	for _, hists in base.pairs(diffhists) do
		table.insert(hists, tmp) -- inserts {tmp} at the end of table hists !!!!!!!!
		for k, hist in base.pairs(hists) do
			if hist.histexpires and hist_expiration_diff(hist) <= 0 then -- clean expired data for this table
				hists[k] = nil -- deletes unique  record in toptable
			end
			if hist.histstarted and hist_started_diff(hist) <= trigger then
				i = i + 1
				diffstimes = diffstimes + hist_started_diff(hist)
				diffhits = k
			end
		end
		if i >= diffcount then
			fix = i / trigger
			agefactor = ((diffstimes / (i -1)) / (trigger / i)) / ((diffhits * 60) / minutes)
			diffrate = get_diffrate(fix, agefactor)
		else
			diffrate = 0
		end
	end
	return diffhists, diffrate
end

local function make_data(c, cmd, msg, type, minutes)
	local cid, ni, ap, ve
	if c:getState() == adchpp.Entity_STATE_NORMAL then
		cid = c:getCID():toBase32()
		ni = c:getField("NI")
		ap = c:getField("AP")
		ve = c:getField("VE")
	elseif cmd then
		cid = cmd:getParam("ID", 0)
		ni = cmd:getParam("NI", 0)
		ap = cmd:getParam("AP", 0)
		ve = cmd:getParam("VE", 0)
	end
	local ip = c:getIp()
	if cid and bans.cids[cid] and not bans.cids[cid].expires then
		return nil
	end
	if bans.ips[ip] and not bans.ips[ip].expires then
		return nil
	end
	local data = { count = 1 }
	data.ip = ip
	if ni and #ni > 0 then
		data.ni = ni
	end
	if ap and #ap > 0 then
		data.ap = ap
	end
	if ve and #ve > 0 then
		data.ve = ve
	end
	data.started = os.time()
	data.rate = 0
	data.maxrate = 0
	data.diffrate = 0
	data.kicks = 0
	data.warns = 0
	data.warning = 0
 	if minutes and minutes > 0 then
		data.expires = os.time() + minutes * 60
	else
		if type == "cmd" then
			data.expires = os.time() + fl_settings.fl_exptime.value * 60
		else
			data.expires = os.time() + li_settings.li_exptime.value * 60
		end
	end
	local diffhists = {}
	diffhists.hists = {}
	local hists = {}
	hists.hist = {}
	local hist = { count = 1 }
	hist.started = data.started
	hist.rate = data.rate
	hist.maxrate = data.maxrate
	hist.expires = data.expires
	hist.histstarted = os.time()
	hist.histexpires = data.expires
	table.insert(hists, hist) -- inserts {hist} at the end of table hists !!!!!!!!!!. 
	data.diffhists = diffhists
	if msg then		
		autil.reply(c, msg)
	end
	return data
end

local function update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
	local ni, ap, ve
	if c:getState() == adchpp.Entity_STATE_NORMAL then
		ni = c:getField("NI")
		ap = c:getField("AP")
		ve = c:getField("VE")
	elseif cmd then
		ni = cmd:getParam("NI", 0)
		ap = cmd:getParam("AP", 0)
		ve = cmd:getParam("VE", 0)
	end
	local ip = c:getIp()
	local update = {count = data.count +1}
	update.ip = ip
	if ni and #ni > 0 then
		update.ni = ni
	end
	if ap and #ap > 0 then
		update.ap = ap
	end
	if ve and #ve > 0 then
		update.ve = ve
	end
	if not data.started then
		update.started = os.time()
		update.rate = 0
	else
		update.started = data.started
		update.rate = get_rate(update.started, update.count)
	end
	if update.rate > data.maxrate then
		update.maxrate = update.rate
	else 
		update.maxrate = data.maxrate
	end
	if minutes and minutes > 0 then
		update.expires = os.time() + minutes * 60
	else
		if type == "cmd" then
			update.expires = os.time() + fl_settings.fl_exptime.value * 60
		else
			update.expires = os.time() + li_settings.li_exptime.value * 60
		end
	end
	update.kicks = data.kicks
	update.warns = data.warns
	update.warning = 0
	update.diffhists, update.diffrate = update_diffhists(data.diffhists, data.diffrate, update)

	if maxcount and maxcount > 0  or maxcount == 0 and li_settings.li_maxcount.value > 0 then
		if maxcount == 0 then
			maxcount = li_settings.li_maxcount.value
		end
		if maxcount <= update.count then
			local msg = " For spamming the hub too often ("..update.count.." times)  with ".. stat .." flooding"
			update = dump_kicked(c, cmd, update, msg)
			return update
		end
	end

	if maxrate and (maxrate > 0  or maxrate == 0 and (fl_settings.fl_maxrate.value > 0 or li_settings.li_maxrate.value > 0)) and update.count > 5 then
		local rate
		if maxrate == 0 then
			if type == "cmd" then
				maxrate = fl_settings.fl_maxrate.value / factor
			else
				maxrate = li_settings.li_maxrate.value / factor
			end
		else
			maxrate = maxrate / factor
		end

		if update.diffrate >= maxrate or update.rate >= maxrate then
			if update.diffrate >= update.rate then
				rate = update.diffrate
			else
				rate = update.rate
			end
			local msg = " You are hammering the hub , cool down or you will be kicked !!!! (" .. rate .. " times / min) with " .. stat .. " "
			if fl_settings.fl_maxwarns.value > 0 and update.warns >= fl_settings.fl_maxwarns.value then
				local msg = " For hammering the hub to often (" .. update.warns .. " times)  for " .. stat .. " !"
				update = dump_kicked(c, cmd, update, msg)
				return update
			end
			update.warns = update.warns + 1
			update.warning = 1
			autil.reply(c, msg)
			return update
		end
		update.warning = 0
	end
	if msg then
		autil.reply(c, msg)
	end
	return update
end

local function make_entity(c, days)
	local ip = c:getIp()
	local ni = c:getField("NI")
	local ap = c:getField("AP")
	local ve = c:getField("VE")
	local level = get_level(c)
	local data = {ip = ip}
	if ni and #ni > 0 then
		data.ni = ni
	end
	if ap and #ap > 0 then
		data.ap = ap
	end
	if ve and #ve > 0 then
		data.ve = ve
	end
	data.level = level
	data.changes = 0
	data.logins = 1
	data.join = os.time()
	data.leave = os.time()
	data.timeon = 0
	data.ltimeon = 0
	data.started = os.time()
	data.updated = os.time()
	data.expires = os.time() + days * 86400
	return data
end

local function logon_entity(c, data, days)
	local cid = c:getCID():toBase32()
	local ip = c:getIp()
	local ni = c:getField("NI")
	local ap = c:getField("AP")
	local ve = c:getField("VE")
	local level = get_level(c)
	local update = { ip = data.ip }
	if ni and #ni > 0 then
		update.ni = ni
	end
	if ap and #ap > 0 then
		update.ap = ap
	end
	if ve and #ve > 0 then
		update.ve = ve
	end
	update.level = level
	update.changes = data.changes
	update.logins = data.logins + 1
	update.join = os.time()
	if data.leave then
		update.leave = data.leave
	else
		update.leave = os.time()
	end
	if data.timeon then
		update.timeon = data.timeon
		update.ltimeon = data.timeon
	else
		update.timeon = 0
		update.ltimeon = 0
	end
	update.started = data.started
	update.updated = data.updated
	update.expires = os.time() + days * 86400

	if ip ~= data.ip or ni ~= data.ni or level ~= data.level then
		update.changes = data.changes + 1
		update.updated = os.time()
		data.cid = cid
		table.insert(entitystats.hist_cids, data) -- inserts {data} at the end of table hist_cids
	end
	return update
end

local function online_entity(c, data, days)
	if data.timeon then
		data.timeon = data.timeon + 900
	else
		data.timeon = 900
	end
	data.expires = os.time() + days * 86400
	return data
end

local function logoff_entity(c, data, days)
	data.leave = os.time()
	if not data.join then
		data.join = os.time() - 1
	end
	if not data.timeon then
		data.timeon = 1
	end
	if not data.ltimeon then
		data.ltimeon = 1
	end
	if os.difftime(data.leave, data.join) >= data.ltimeon then
		data.timeon = os.difftime(data.leave, data.join)
		data.ltimeon = data.timeon
	end
	data.expires = os.time() + days * 86400
	return data
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

function get_user_c(c)
	return get_user(c:getCID():toBase32(), c:getField("NI"))
end

function get_level(c)
	local user = get_user_c(c)
	if not user then
		return 0
	end
	return user.level
end

local function has_level(c, level)
	return get_level(c) >= level
end

local function is_admin(c)
	return has_level(c, level_admin)
end

local function is_stats(c)
	return has_level(c, level_stats)
end

local function load_fl_settings()
	local file = io.open(fl_settings_file, "r")
	if not file then
		log("Unable to open " .. fl_settings_file .. ", fl_settings not loaded")
		return false
	end

	local str = file:read("*a")
	file:close()

	if #str == 0 then
		return false
	end

	local ok, list = base.pcall(json.decode, str)
	if not ok then
		log("Unable to decode fl_settings file: " .. list)
		return false
	end

	for k, v in base.pairs(list) do
		if fl_settings[k] then
			local change = fl_settings[k].value ~= v
			fl_settings[k].value = v
			if change and fl_settings[k].change then
				fl_settings[k].change()
			end
		else
			-- must have been regged by a script that has not been loaded yet
			fl_settings[k] = { value = v }
		end
	end

	return true
end

local function load_li_settings()
	local file = io.open(li_settings_file, "r")
	if not file then
		log("Unable to open " .. li_settings_file .. ", li_settings not loaded")
		return false
	end

	local str = file:read("*a")
	file:close()

	if #str == 0 then
		return false
	end

	local ok, list = base.pcall(json.decode, str)
	if not ok then
		log("Unable to decode li_settings file: " .. list)
		return false
	end

	for k, v in base.pairs(list) do
		if li_settings[k] then
			local change = li_settings[k].value ~= v
			li_settings[k].value = v
			if change and li_settings[k].change then
				li_settings[k].change()
			end
		else
			-- must have been regged by a script that has not been loaded yet
			li_settings[k] = { value = v }
		end
	end

	return true
end

local function load_en_settings()
	local file = io.open(en_settings_file, "r")
	if not file then
		log("Unable to open " .. en_settings_file .. ", en_settings not loaded")
		return false
	end

	local str = file:read("*a")
	file:close()

	if #str == 0 then
		return false
	end

	local ok, list = base.pcall(json.decode, str)
	if not ok then
		log("Unable to decode en_settings file: " .. list)
		return false
	end

	for k, v in base.pairs(list) do
		if en_settings[k] then
			local change = en_settings[k].value ~= v
			en_settings[k].value = v
			if change and en_settings[k].change then
				en_settings[k].change()
			end
		else
			-- must have been regged by a script that has not been loaded yet
			en_settings[k] = { value = v }
		end
	end

	return true
end

local function save_fl_settings()
	local file = io.open(fl_settings_file, "w")
	if not file then
		log("Unable to open " .. fl_settings_file .. ", fl_settings not saved")
		return
	end

	local list = {}
	for k, v in base.pairs(fl_settings) do
		list[k] = v.value
	end
	file:write(json.encode(list))
	file:close()
end

local function save_li_settings()
	local file = io.open(li_settings_file, "w")
	if not file then
		log("Unable to open " .. li_settings_file .. ", li_settings not saved")
		return
	end

	local list = {}
	for k, v in base.pairs(li_settings) do
		list[k] = v.value
	end
	file:write(json.encode(list))
	file:close()
end

local function save_en_settings()
	local file = io.open(en_settings_file, "w")
	if not file then
		log("Unable to open " .. en_settings_file .. ", en_settings not saved")
		return
	end

	local list = {}
	for k, v in base.pairs(en_settings) do
		list[k] = v.value
	end
	file:write(json.encode(list))
	file:close()
end

local function onSOC(c) -- Stats verification for creating open sockets

	local ip = c:getIp()

	if fl_settings.cmdsoc_rate.value > 0 or fl_settings.fl_maxrate.value > 0 then
		local stat = "cmdsoc_rate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdsoc_rate.value
		local minutes = fl_settings.cmdsoc_exp.value
		if commandstats.soccmds[ip] then
			for victim_ip, data in base.pairs(commandstats.soccmds) do
				if victim_ip == ip then
					commandstats.soccmds[ip] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.soccmds[ip] and commandstats.soccmds[ip].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.soccmds[ip] = make_data(c, cmd, msg, type, minutes)
		return true
	end
	return true
end

local function onCON(c) -- Stats verification for connects and building entitys tables

	local cid = c:getCID():toBase32()

	if en_settings.entitylog.value > 0 then
		local days, match
		if get_level(c) > 0 then
			days = en_settings.entitylogregexptime.value
		else
			days = en_settings.entitylogexptime.value
		end
		for ent, data in base.pairs(entitystats.last_cids) do
			if ent == cid then
				match = true
				entitystats.last_cids[cid] = logon_entity(c, data, days)
			end
		end
		if not match then
			entitystats.last_cids[cid] = make_entity(c, days)
		end
	end

	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.cmdcon_rate.value > 0 or fl_settings.fl_maxrate.value > 0 then
		local stat = "cmdcon_rate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdcon_rate.value
		local minutes = fl_settings.cmdcon_exp.value
		if commandstats.concmds[cid] then
			for victim_cid, data in base.pairs(commandstats.concmds) do
				if cid == victim_cid then
					commandstats.concmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.concmds[cid] and commandstats.concmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.concmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end
	return true
end

local function onONL() -- Stats verification for online users and updating entity,s tables
	if en_settings.entitylog.value > 0 and en_settings_done then
		local entities = adchpp.getCM():getEntities()
		local size = entities:size()
		if size > 0 then
			for i = 0, size - 1 do
				local c = entities[i]:asClient()
				if c and c:getState() == adchpp.Entity_STATE_NORMAL then
					local days, match
					local cid = c:getCID():toBase32()
					if get_level(c) > 0 then
						days = en_settings.entitylogregexptime.value
					else
						days = en_settings.entitylogexptime.value
					end
					for ent, data in base.pairs(entitystats.last_cids) do
						if ent == cid then
							match = true
							entitystats.last_cids[cid] = online_entity(c, data, days)
						end
					end
					if not match then
						entitystats.last_cids[cid] = make_entity(c, days)
					end
				end
			end
		end
	end
	return true
end

local function onDIS(c) -- Stats verification for disconnects and updating entitys tables

	local cid = c:getCID():toBase32()

	if en_settings.entitylog.value > 0 then
		local days
		if get_level(c) > 0 then
			days = en_settings.entitylogregexptime.value
		else
			days = en_settings.entitylogexptime.value
		end
		for ent, data in base.pairs(entitystats.last_cids) do
			if ent == cid then
				entitystats.last_cids[cid] = logoff_entity(c, data, days)
				return true
			end
		end
		entitystats.last_cids[cid] = make_entity(c, days)
	end
	return true
end

local function onURX(c, cmd) -- Stats and flood verification for unknown command strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cid = c:getCID():toBase32()

	if (fl_settings.fl_maxrate.value > 0 or fl_settings.cmdurx_rate.value > 0) then
		local stat = "cmdurxrate"
		local type = "cmd"
		local factor = 1
		local maxcount = 0
		local maxrate = fl_settings.cmdurx_rate.value
		local minutes = fl_settings.cmdurx_exp.value
		if commandstats.urxcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.urxcmds) do
				if cid == victim_cid then
					commandstats.urxcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.urxcmds[cid] and commandstats.urxcmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.urxcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end
	return true
end

local function onCRX(c, cmd) -- Stats and rules verification for bad context command strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cid = c:getCID():toBase32()

	if (fl_settings.fl_maxrate.value > 0 or fl_settings.cmdcrx_rate.value > 0) then
		local stat = "cmdcrxrate"
		local msg = "Invalid context for a ( ".. cmd:getCommandString() .." ) command, the command is blocked !!!"
		local type = "cmd"
		local factor = 1
		local maxcount = 0
		local maxrate = fl_settings.cmdcrx_rate.value
		local minutes = fl_settings.cmdcrx_exp.value
		if commandstats.crxcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.crxcmds) do
				if cid == victim_cid then
					commandstats.crxcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.crxcmds[cid] and commandstats.crxcmds[cid].warning > 0 then
						return false
					end
					return false
				end
			end
		end
		commandstats.crxcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return false
	end
	return false
end

local function onCMD(c, cmd) -- Stats and rules verification for command strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cid = c:getCID():toBase32()

	if (fl_settings.fl_maxrate.value > 0 or fl_settings.cmdcmd_rate.value > 0) then
		local stat = "cmdcmdrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdcmd_rate.value
		local minutes = fl_settings.cmdcmd_exp.value
		if commandstats.cmdcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.cmdcmds) do
				if cid == victim_cid then
					commandstats.cmdcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.cmdcmds[cid] and commandstats.cmdcmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.cmdcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end
	return true
end

local function onSUP(c, cmd) -- Stats and rules verification for support strings

	local blom = c:hasSupport(adchpp.AdcCommand_toFourCC("BLO0")) or c:hasSupport(adchpp.AdcCommand_toFourCC("BLOM")) or 
c:hasSupport(adchpp.AdcCommand_toFourCC("PING")) -- excluding hublistpingers from this limitrule

	if li_settings.sublom.value > 0 and li_settings.li_minlevel.value <= get_level(c) and not blom then
		local ip = c:getIp()
		local stat = "sublom"
		local str = "This hub requires that your client supports the BLOM (TTH search filtering) extention !"
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.sublom_rate.value
		local minutes = li_settings.sublom_exp.value
		if limitstats.subloms[ip] then
			for victim_ip, data in base.pairs(limitstats.subloms) do
				if ip == victim_ip then
					limitstats.subloms[ip] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.subloms[ip] and limitstats.subloms[ip].warning > 0 then
						dump_redirected(c, str)
						return false
					end
				end
			end
		else
			limitstats.subloms[ip] = make_data(c, cmd, msg, type, minutes)
		end
		dump_redirected(c, str)
		return false
	end

	if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdsup_rate.value > 0 then
		local ip = c:getIp()
		local stat = "cmdsuprate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdsup_rate.value
		local minutes = fl_settings.cmdsup_exp.value
		if commandstats.supcmds[ip] then
			for victim_ip, data in base.pairs(commandstats.supcmds) do
				if ip == victim_ip then
					commandstats.supcmds[ip] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.supcmds[ip] and commandstats.supcmds[ip].warning > 0 then
						dump_dropped(c, "You are dropped for hammering the hub, stop or be kicked !!!")
						return false
					end
					return true
				end
			end
		end
		commandstats.supcmds[ip] = make_data(c, cmd, msg, type, minutes)
		return true
	end

	return true
end

local function onSID(c, cmd) -- Stats and rules verification for sid strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cid = c:getCID():toBase32()

	if (fl_settings.fl_maxrate.value > 0 or fl_settings.cmdsid_rate.value > 0) then
		local stat = "cmdsidrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdsid_rate.value
		local minutes = fl_settings.cmdsid_exp.value
		if commandstats.sidcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.sidcmds) do
				if cid == victim_cid then
					commandstats.sidcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.sidcmds[cid] and commandstats.sidcmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.sidcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end
	return true
end

local function onPAS(c, cmd) -- Stats and rules verification for password strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cid = c:getCID():toBase32()

	if (fl_settings.fl_maxrate.value > 0 or fl_settings.cmdpas_rate.value > 0) then
		local stat = "cmdpasrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdpas_rate.value
		local minutes = fl_settings.cmdpas_exp.value
		if commandstats.pascmds[cid] then
			for victim_cid, data in base.pairs(commandstats.pascmds) do
				if cid == victim_cid then
					commandstats.pascmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.pascmds[cid] and commandstats.pascmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.pascmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end
	return true
end

local function onSTA(c, cmd) -- Stats and rules verification for status strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cid = c:getCID():toBase32()

	if (fl_settings.fl_maxrate.value > 0 or fl_settings.cmdsta_rate.value > 0) then
		local stat = "cmdstarate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdsta_rate.value
		local minutes = fl_settings.cmdsta_exp.value
		if commandstats.stacmds[cid] then
			for victim_cid, data in base.pairs(commandstats.stacmds) do
				if cid == victim_cid then
					commandstats.stacmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.stacmds[cid] and commandstats.stacmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.stacmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end
	return true
end

local function onSCH(c, cmd) -- Stats and rules verification for search strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end
	
	local sch = cmd:getParameters()
	local params = sch:size()

	if li_settings.maxschparam.value > 0 and params >= li_settings.maxschparam.value then
		local cid = c:getCID():toBase32()
		local stat = "maxschparam"
		local msg = "Your search contained too many parameters, max allowed is ".. li_settings.maxschparam.value.." "
		local type = "lim"
		local factor = 60
		local maxcount = 0
		local maxrate = li_settings.maxschparam_rate.value
		local minutes = li_settings.maxschparam_exp.value
		if limitstats.maxmsglengths[cid] then
			for victim_cid, data in base.pairs(limitstats.maxschparams) do
				if cid == victim_cid then
					limitstats.maxschparams[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					return false
				end
			end
		end
		limitstats.maxschparams[cid] = make_data(c, cmd, msg, type, minutes)
		return false
	end

	local TTH, AN1, AN2, AN3 = cmd:getParam("TR", 0), cmd:getParam("AN", 0), cmd:getParam("AN", 1), cmd:getParam("AN", 2)
	local chars = #TTH + #AN1 + #AN2 + #AN3

	if li_settings.maxschlength.value > 0 and chars > li_settings.maxschlength.value then
		local cid = c:getCID():toBase32()
		local stat = "maxschlength"
		local msg = "Your search string contained too many characters, max allowed is " .. li_settings.maxschlength.value
		local type = "lim"
		local factor = 60
		local maxcount = 0
		local maxrate = li_settings.maxschlength_rate.value
		local minutes = li_settings.maxschlength_exp.value
		if limitstats.maxschlengths[cid] then
			for victim_cid, data in base.pairs(limitstats.maxschlengths) do
				if cid == victim_cid then
					limitstats.maxschlengths[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.maxschlengths[cid] and limitstats.maxschlengths[cid].warning > 0 then
						return false
					end
					return false
				end
			end
		else
			limitstats.maxschlengths[cid] = make_data(c, cmd, msg, type, minutes)
			return false
		end
	end

	if li_settings.minschlength.value > 0 and chars < li_settings.minschlength.value then
		local cid = c:getCID():toBase32()
		local stat = "minschlength"
		local msg = "Your search string has not enough characters min alowed is ".. li_settings.minschlength.value.." "
		local type = "lim"
		local factor = 60
		local maxcount = 0
		local maxrate = li_settings.minschlength_rate.value
		local minutes = li_settings.minschlength_exp.value
		if limitstats.minschlengths[cid] then
			for victim_cid, data in base.pairs(limitstats.minschlengths) do
				if cid == victim_cid then
					limitstats.minschlengths[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.minschlengths[cid] and limitstats.minschlengths[cid].warning > 0 then
						return false
					end
					return false
				end
			end
		else
			limitstats.minschlengths[cid] = make_data(c, cmd, msg, type, minutes)
			return false
		end
	end

	local feature = base.tostring(cmd:getFeatures())

	if string.len(TTH) > 0 and not string.match(feature, "+NAT0") and (fl_settings.fl_maxrate.value > 0 or fl_settings.cmdschtth_rate.value > 0) then
		local cid = c:getCID():toBase32()
		local stat = "cmdschtthrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdschtth_rate.value
		local minutes = fl_settings.cmdschtth_exp.value
		if commandstats.schtthcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.schtthcmds) do
				if cid == victim_cid then
					commandstats.schtthcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.schtthcmds[cid] and commandstats.schtthcmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.schtthcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end

	if string.len(TTH) > 0 and (fl_settings.fl_maxrate.value > 0 or fl_settings.cmdschtth_rate.value > 0) then
		local cid = c:getCID():toBase32()
		local stat = "cmdschtthnatrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdschtth_rate.value
		local minutes = fl_settings.cmdschtth_exp.value
		if commandstats.schtthnatcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.schtthnatcmds) do
				if cid == victim_cid then
					commandstats.schtthnatcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.schtthnatcmds[cid] and commandstats.schtthnatcmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.schtthnatcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end

	if not string.match(feature, "+NAT0") and (fl_settings.fl_maxrate.value > 0 or fl_settings.cmdschman_rate.value > 0) then
		local cid = c:getCID():toBase32()
		local stat = "cmdschmanrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdschman_rate.value
		local minutes = fl_settings.cmdschman_exp.value
		if not string.match(feature, "+SEGA") then
			if commandstats.schmancmds[cid] then
				for victim_cid, data in base.pairs(commandstats.schmancmds) do
					if cid == victim_cid then
						commandstats.schmancmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
						if commandstats.schmancmds[cid] and commandstats.schmancmds[cid].warning > 0 then
							return false
						end
						return true
					end
				end
			end
			commandstats.schmancmds[cid] = make_data(c, cmd, msg, type, minutes)
			return true
		else
			if commandstats.schmansegacmds[cid] then
				for victim_cid, data in base.pairs(commandstats.schmansegacmds) do
					if cid == victim_cid then
						commandstats.schmansegacmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
						if commandstats.schmansegacmds[cid] and commandstats.schmansegacmds[cid].warning > 0 then
							return false
						end
						return true
					end
				end
			end
			commandstats.schmansegacmds[cid] = make_data(c, cmd, msg, type, minutes)
			return true
		end
	end

	if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdschman_rate.value > 0 then
		local cid = c:getCID():toBase32()
		local stat = "cmdschmannatrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdschman_rate.value
		local minutes = fl_settings.cmdschman_exp.value
		if not string.match(feature, "+SEGA") then
			if commandstats.schmannatcmds[cid] then
				for victim_cid, data in base.pairs(commandstats.schmannatcmds) do
					if cid == victim_cid then
						commandstats.schmannatcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
						if commandstats.schmannatcmds[cid] and commandstats.schmannatcmds[cid].warning > 0 then
							return false
						end
						return true
					end
				end
			end
			commandstats.schmannatcmds[cid] = make_data(c, cmd, msg, type, minutes)
			return true
		else
			if commandstats.schmannatsegacmds[cid] then
				for victim_cid, data in base.pairs(commandstats.schmannatsegacmds) do
					if cid == victim_cid then
						commandstats.schmannatsegacmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
						if commandstats.schmannatsegacmds[cid] and commandstats.schmannatsegacmds[cid].warning > 0 then
							return false
						end
						return true
					end
				end
			end
			commandstats.schmannatsegacmds[cid] = make_data(c, cmd, msg, type, minutes)
			return true
		end
	end

	return true
end

local function onMSG(c, cmd) -- Stats and rules verification for messages strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cmdmsg = cmd:getParam(0)

	if li_settings.maxmsglength.value > 0 and string.len(cmdmsg) >= li_settings.maxmsglength.value then
		local cid = c:getCID():toBase32()
		local stat = "maxmsglength"
		local msg = "Your message contained too many characters, max allowed is ".. li_settings.maxmsglength.value.." "
		local type = "lim"
		local factor = 60
		local maxcount = 0
		local maxrate = li_settings.maxmsglength_rate.value
		local minutes = li_settings.maxmsglength_exp.value
		if limitstats.maxmsglengths[cid] then
			for victim_cid, data in base.pairs(limitstats.maxmsglengths) do
				if cid == victim_cid then
					limitstats.maxmsglengths[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.maxmsglengths[cid] and limitstats.maxmsglengths[cid].warning > 0 then
						return false
					end
					return false
				end
			end
		end
		limitstats.maxmsglengths[cid] = make_data(c, cmd, msg, type, minutes)
		return false
	end

	if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdmsg_rate.value > 0 then
		local cid = c:getCID():toBase32()
		local stat = "cmdmsgrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdmsg_rate.value
		local minutes = fl_settings.cmdmsg_exp.value
		if commandstats.msgcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.msgcmds) do
				if cid == victim_cid then
					commandstats.msgcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.msgcmds[cid] and commandstats.msgcmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.msgcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end

	return true
end

local function onINF(c, cmd) -- Stats and rules verification for info strings

	local cid, ni
	if c:getState() == adchpp.Entity_STATE_NORMAL then 
		cid = c:getCID():toBase32()
		ni = c:getField("NI")
	else
		cid = cmd:getParam("ID", 0)
		ni = cmd:getParam("NI", 0)
	end

-- TODO exclude pingers from certain verifications excluded DCHublistspinger for now

	if get_level(c) > fl_settings.fl_level.value or cid == "UTKSLGRRI3RYPRCWUEYTROGTRFQJQRQDVHTMOOY" then
		return true
	end

	local countip
	if c:getState() ~= adchpp.Entity_STATE_NORMAL then
		countip = get_sameip(c)
	end

	if countip and li_settings.maxsameip.value > 0 and countip > li_settings.maxsameip.value then
		local stat = "maxsameip"
		local str = "This hub allows a maximum of ( " .. li_settings.maxsameip.value .. " ) connections from the same ip address and that value is reached sorry for now !"
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.maxsameip_rate.value
		local minutes = li_settings.maxsameip_exp.value
		if limitstats.maxsameips[cid] then
			for victim_cid, data in base.pairs(limitstats.maxsameips) do
				if cid == victim_cid then
					limitstats.maxsameips[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.maxsameips[cid] and limitstats.maxsameips[cid].warning > 0 then
						dump_dropped(c, str)
						return false
					end
				end
			end
		else
			limitstats.maxsameips[cid] = make_data(c, cmd, msg, type, minutes)
		end
		dump_dropped(c, str)
		return false
	end

	local su = base.tostring(cmd:getParam("SU", 0))
	if su == '' then
		su = base.tostring(c:getField("SU"))
	end
	local adcs = string.find(su, 'ADC0') or string.find(su, 'ADCS')

	if li_settings.suadcs.value > 0 and li_settings.li_minlevel.value <= get_level(c) and not adcs then
		local stat = "suadcs"
		local str = "This hub requires that you have the secure transfer option enabled, go to Settings/Security Cerificates and enable 'Use TLS when remote client supports it' !"
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.suadcs_rate.value
		local minutes = li_settings.suadcs_exp.value
		if limitstats.suadcs[cid] then
			for victim_cid, data in base.pairs(limitstats.suadcs) do
				if cid == victim_cid then
					limitstats.suadcs[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.suadcs[cid] and limitstats.suadcs[cid].warning > 0 then
						dump_redirected(c, str)
						return false
					end
				end
			end
		else
			limitstats.suadcs[cid] = make_data(c, cmd, msg, type, minutes)
		end
		dump_redirected(c, str)
		return false
	end

	local natt = string.find(su, 'NAT0') or string.find(su, 'NATT') or string.find(su, 'TCP4') or string.find(su, 'TCP6')
	-- user must either be active or support NAT-T

	if li_settings.sunatt.value > 0 and li_settings.li_minlevel.value <= get_level(c) and not natt then
		local stat = "sunatt"
		local str = "This hub requires that you have the NAT-T option enabled if you use passive mode, go to Settings and enable it or use a client that supports it !"
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.sunatt_rate.value
		local minutes = li_settings.sunatt_exp.value
		if limitstats.sunatts[cid] then
			for victim_cid, data in base.pairs(limitstats.sunatts) do
				if cid == victim_cid then
					limitstats.sunatts[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.sunatts[cid] and limitstats.sunatts[cid].warning > 0 then
						dump_redirected(c, str)
						return false
					end
				end
			end
		else
			limitstats.sunatts[cid] = make_data(c, cmd, msg, type, minutes)
		end
		dump_redirected(c, str)
		return false
	end

	local ss = base.tonumber(cmd:getParam("SS", 0)) or base.tonumber(c:getField("SS")) or 0

	if li_settings.minsharesize.value > 0 and li_settings.li_minlevel.value <= get_level(c) and ss < li_settings.minsharesize.value then
		local stat = "minsharesize"
		local str = "Your share size ( " .. adchpp.Util_formatBytes(ss) .. " ) is too low, the minimum required size is " .. adchpp.Util_formatBytes(li_settings.minsharesize.value)
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.minsharesize_rate.value
		local minutes = li_settings.minsharesize_exp.value
		if limitstats.minsharesizes[cid] then
			for victim_cid, data in base.pairs(limitstats.minsharesizes) do
				if cid == victim_cid then
					limitstats.minsharesizes[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.minsharesizes[cid] and limitstats.minsharesizes[cid].warning > 0 then
						dump_redirected(c, str)
						return false
					end
				end
			end
		else
			limitstats.minsharesizes[cid] = make_data(c, cmd, msg, type, minutes)
		end
		dump_redirected(c, str)
		return false
	end

	if li_settings.maxsharesize.value > 0 and li_settings.li_minlevel.value <= get_level(c) and ss > li_settings.maxsharesize.value then
		local stat = "maxsharesize"
		local str = "Your share size ( " .. adchpp.Util_formatBytes(ss) .. " ) is too high, the maximum allowed size is " .. adchpp.Util_formatBytes(li_settings.maxsharesize.value)
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.maxsharesize_rate.value
		local minutes = li_settings.maxsharesize_exp.value
		if limitstats.maxsharesizes[cid] then
			for victim_cid, data in base.pairs(limitstats.maxsharesizes) do
				if cid == victim_cid then
					limitstats.maxsharesizes[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.maxsharesizes[cid] and limitstats.maxsharesizes[cid].warning > 0 then
						dump_redirected(c, str)
						return false
					end
				end
			end
		else
			limitstats.maxsharesizes[cid] = make_data(c, cmd, msg, type, minutes)
		end
		dump_redirected(c, str)
		return false
	end

	local sf = base.tonumber(cmd:getParam("SF", 0)) or base.tonumber(c:getField("SF")) or 0

	if li_settings.minsharefiles.value > 0 and li_settings.li_minlevel.value <= get_level(c) and sf < li_settings.minsharefiles.value then
		local stat = "minsharefiles"
		local str = "Your nr of shared files ( " .. sf .. " ) is too low, the minimum required nr of files is " .. li_settings.minsharefiles.value
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.minsharefiles_rate.value
		local minutes = li_settings.minsharefiles_exp.value
		if limitstats.minsharefiles[cid] then
			for victim_cid, data in base.pairs(limitstats.minsharefiles) do
				if cid == victim_cid then
					limitstats.minsharefiles[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.minsharefiles[cid] and limitstats.minsharefiles[cid].warning > 0 then
						dump_redirected(c, str)
						return false
					end
				end
			end
		else
			limitstats.minsharefiles[cid] = make_data(c, cmd, msg, type, minutes)
		end
		dump_redirected(c, str)
		return false
	end

	if li_settings.maxsharefiles.value > 0 and li_settings.li_minlevel.value <= get_level(c) and sf > li_settings.maxsharefiles.value then
		local stat = "maxsharefiles"
		local str = "Your nr of shared files ( " .. sf .. " ) is too high, the maximum allowed nr of files is " .. li_settings.maxsharefiles.value
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.maxsharefiles_rate.value
		local minutes = li_settings.maxsharefiles_exp.value
		if limitstats.maxsharefiles[cid] then
			for victim_cid, data in base.pairs(limitstats.maxsharefiles) do
				if cid == victim_cid then
					limitstats.maxsharefiles[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.maxsharefiles[cid] and limitstats.maxsharefiles[cid].warning > 0 then
						dump_redirected(c, str)
						return false
					end
				end
			end
		else
			limitstats.maxsharefiles[cid] = make_data(c, cmd, msg, type, minutes)
		end
		dump_redirected(c, str)
		return false
	end

	local sl = base.tonumber(cmd:getParam("SL", 0)) or base.tonumber(c:getField("SL")) or 0

	if li_settings.minslots.value > 0 and li_settings.li_minlevel.value <= get_level(c) and sl < li_settings.minslots.value then
		local stat = "minslots"
		local str = "You have too few upload slots open ( " .. base.tostring(sl) .. " ), the minimum required is " .. base.tostring(li_settings.minslots.value)
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.minslots_rate.value
		local minutes = li_settings.minslots_exp.value
		if limitstats.minslots[cid] then
			for victim_cid, data in base.pairs(limitstats.minslots) do
				if cid == victim_cid then
					limitstats.minslots[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.minslots[cid] and limitstats.minslots[cid].warning > 0 then
						dump_redirected(c, str)
						return false
					end
				end
			end
		else
			limitstats.minslots[cid] = make_data(c, cmd, msg, type, minutes)
		end
		dump_redirected(c, str)
		return false
	end

	if li_settings.maxslots.value > 0 and li_settings.li_minlevel.value <= get_level(c) and sl > li_settings.maxslots.value then
		local stat = "maxslots"
		local str = "You have too many upload slots open ( " .. base.tostring(sl) .. " ), the maximum allowed is " .. base.tostring(li_settings.maxslots.value)
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.maxslots_rate.value
		local minutes = li_settings.maxslots_exp.value
		if limitstats.maxslots[cid] then
			for victim_cid, data in base.pairs(limitstats.maxslots) do
				if cid == victim_cid then
					limitstats.maxslots[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.maxslots[cid] and limitstats.maxslots[cid].warning > 0 then
						dump_redirected(c, str)
						return false
					end
				end
			end
		else
			limitstats.maxslots[cid] = make_data(c, cmd, msg, type, minutes)
		end
		dump_redirected(c, str)
		return false
	end

	local h1 = base.tonumber(cmd:getParam("HN", 0)) or base.tonumber(c:getField("HN")) or 0
	local h2 = base.tonumber(cmd:getParam("HR", 0)) or base.tonumber(c:getField("HR")) or 0
	local h3 = base.tonumber(cmd:getParam("HO", 0)) or base.tonumber(c:getField("HO")) or 0
	local h = h1 + h2 + h3
	if h < 1 then
		h = 1
	end
	local r = sl / h

	if li_settings.minhubslotratio.value > 0 and li_settings.li_minlevel.value <= get_level(c) and r < li_settings.minhubslotratio.value then
		local stat = "minhubslotratio"
		local str = "Your hubs/slots ratio ( " .. base.tostring(r) .. " ) is too low, you must open up more upload slots or disconnect from some hubs to achieve a ratio of " .. base.tostring(li_settings.minhubslotratio.value)
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.minhubslotratio_rate.value
		local minutes = li_settings.minhubslotratio_exp.value
		if limitstats.minhubslotratios[cid] then
			for victim_cid, data in base.pairs(limitstats.minhubslotratios) do
				if cid == victim_cid then
					limitstats.minhubslotratios[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.minhubslotratios[cid] and limitstats.minhubslotratios[cid].warning > 0 then
						dump_redirected(c, str)
						return false
					end
				end
			end
		else
			limitstats.minhubslotratios[cid] = make_data(c, cmd, msg, type, minutes)
		end
		dump_redirected(c, str)
		return false
	end

	if li_settings.maxhubslotratio.value > 0 and li_settings.li_minlevel.value <= get_level(c) and r > li_settings.maxhubslotratio.value then
		local stat = "maxhubslotratio"
		local str = "Your hubs/slots ratio ( " .. base.tostring(r) .. " ) is too high, you must reduce your open upload slots or connect to more hubs to achieve a ratio of " .. base.tostring(li_settings.maxhubslotratio.value)
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.maxhubslotratio_rate.value
		local minutes = li_settings.maxhubslotratio_exp.value
		if limitstats.maxhubslotratios[cid] then
			for victim_cid, data in base.pairs(limitstats.maxhubslotratios) do
				if cid == victim_cid then
					limitstats.maxhubslotratios[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.maxhubslotratios[cid] and limitstats.maxhubslotratios[cid].warning > 0 then
						dump_redirected(c, str)
						return false
					end
				end
			end
		else
			limitstats.maxhubslotratios[cid] = make_data(c, cmd, msg, type, minutes)
		end
		dump_redirected(c, str)
		return false
	end

	if li_settings.maxhubcount.value > 0 and li_settings.li_minlevel.value <= get_level(c) and h > li_settings.maxhubcount.value then
		local stat = "maxhubcount"
		local str = "The number of hubs you're connected to ( " .. base.tostring(h) .. " ) is too high, the maximum allowed is " .. base.tostring(li_settings.maxhubcount.value)
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.maxhubcount_rate.value
		local minutes = li_settings.maxhubcount_exp.value
		if limitstats.maxhubcounts[cid] then
			for victim_cid, data in base.pairs(limitstats.maxhubcounts) do
				if cid == victim_cid then
					limitstats.maxhubcounts[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.maxhubcounts[cid] and limitstats.maxhubcounts[cid].warning > 0 then
						dump_redirected(c, str)
						return false
					end
				end
			end
		else
			limitstats.maxhubcounts[cid] = make_data(c, cmd, msg, type, minutes)
		end
		dump_redirected(c, str)
		return false
	end

	if li_settings.minnicklength.value > 0 and #ni < li_settings.minnicklength.value then
		local stat = "minnicklength"
		local str = "Your nick ( " .. ni .. " ) is too short, it must contain " .. base.tostring(li_settings.minnicklength.value) .. " characters minimum"
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.minnicklength_rate.value
		local minutes = li_settings.minnicklength_exp.value
		if limitstats.minnicklengths[cid] then
			for victim_cid, data in base.pairs(limitstats.minnicklengths) do
				if cid == victim_cid then
					limitstats.minnicklengths[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.minnicklengths[cid] and limitstats.minnicklengths[cid].warning > 0 then
						dump_dropped(c, str)
						return false
					end
				end
			end
		else
			limitstats.minnicklengths[cid] = make_data(c, cmd, msg, type, minutes)
		end
		dump_dropped(c, str)
		return false
	end

	if li_settings.maxnicklength.value > 0 and #ni > li_settings.maxnicklength.value then
		local stat = "maxnicklength"
		local str = "Your nick ( " .. ni .. " ) is too long, it can contain " .. base.tostring(li_settings.maxnicklength.value) .. " characters maximum"
		local type = "lim"
		local factor = 60
		local maxcount = 0
		maxrate = li_settings.maxnicklength_rate.value
		local minutes = li_settings.maxnicklength_exp.value
		if limitstats.maxnicklengths[cid] then
			for victim_cid, data in base.pairs(limitstats.maxnicklengths) do
				if cid == victim_cid then
					limitstats.maxnicklengths[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if limitstats.maxnicklengths[cid] and limitstats.maxnicklengths[cid].warning > 0 then
						dump_dropped(c, str)
						return false
					end
				end
			end
		else
			limitstats.maxnicklengths[cid] = make_data(c, cmd, msg, type, minutes)
		end
		dump_dropped(c, str)
		return false
	end

	if (fl_settings.fl_maxrate.value > 0 or fl_settings.cmdinf_rate.value > 0) and c:getState() == adchpp.Entity_STATE_NORMAL then
		local stat = "cmdinfrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdinf_rate.value
		local minutes = fl_settings.cmdinf_exp.value
		if commandstats.infcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.infcmds) do
				if cid == victim_cid then
					commandstats.infcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.infcmds[cid] and commandstats.infcmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.infcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end

	return true
end

local function onRES(c, cmd) -- Stats and rules verification for search results strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cid = c:getCID():toBase32()

	if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdres_rate.value > 0 then
		local stat = "cmdresrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdres_rate.value
		local minutes = fl_settings.cmdres_exp.value
		if commandstats.rescmds[cid] then
			for victim_cid, data in base.pairs(commandstats.rescmds) do
				if cid == victim_cid then
					commandstats.rescmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.rescmds[cid] and commandstats.rescmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.rescmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end

	return true
end

local function onCTM(c, cmd) -- Stats and rules verification for connect to me strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cid = c:getCID():toBase32()

	if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdctm_rate.value > 0 then
		local stat = "cmdctmrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdctm_rate.value
		local minutes = fl_settings.cmdctm_exp.value
		if commandstats.ctmcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.ctmcmds) do
				if cid == victim_cid then
					commandstats.ctmcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.ctmcmds[cid] and commandstats.ctmcmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.ctmcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end

	return true
end

local function onRCM(c, cmd) -- Stats and rules verification for reverse connect to me strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cid = c:getCID():toBase32()

	if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdrcm_rate.value > 0 then
		local stat = "cmdrcmrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdrcm_rate.value
		local minutes = fl_settings.cmdrcm_exp.value
		if commandstats.rcmcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.rcmcmds) do
				if cid == victim_cid then
					commandstats.rcmcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.rcmcmds[cid] and commandstats.rcmcmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.rcmcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end

	return true
end

local function onNAT(c, cmd) -- Stats and rules verification for nat traversal connect to me strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cid = c:getCID():toBase32()

	if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdnat_rate.value > 0 then
		local stat = "cmdnatrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdnat_rate.value
		local minutes = fl_settings.cmdnat_exp.value
		if commandstats.natcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.natcmds) do
				if cid == victim_cid then
					commandstats.natcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.natcmds[cid] and commandstats.natcmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.natcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end

	return true
end

local function onRNT(c, cmd) -- Stats and rules verification for nat traversal rev connect to me strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cid = c:getCID():toBase32()

	if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdrnt_rate.value > 0 then
		local stat = "cmdrntrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdrnt_rate.value
		local minutes = fl_settings.cmdrnt_exp.value
		if commandstats.rntcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.rntcmds) do
				if cid == victim_cid then
					commandstats.rntcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.rntcmds[cid] and commandstats.rntcmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.rntcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end

	return true
end

local function onPSR(c, cmd) -- Stats and rules verification for partitial filesharing strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cid = c:getCID():toBase32()

	if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdpsr_rate.value > 0 then
		local stat = "cmdpsrrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdpsr_rate.value
		local minutes = fl_settings.cmdpsr_exp.value
		if commandstats.psrcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.psrcmds) do
				if cid == victim_cid then
					commandstats.psrcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.psrcmds[cid] and commandstats.psrcmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.psrcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end

	return true
end

local function onGET(c, cmd) -- Stats and rules verification for get strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cid = c:getCID():toBase32()

	if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdget_rate.value > 0 then
		local stat = "cmdgetrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdget_rate.value
		local minutes = fl_settings.cmdget_exp.value
		if commandstats.getcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.getcmds) do
				if cid == victim_cid then
					commandstats.getcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.getcmds[cid] and commandstats.getcmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.getcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end

	return true
end

local function onSND(c, cmd) -- Stats and rules verification for send strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	local cid = c:getCID():toBase32()

	if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdsnd_rate.value > 0 then
		local stat = "cmdsndrate"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdsnd_rate.value
		local minutes = fl_settings.cmdsnd_exp.value
		if commandstats.sndcmds[cid] then
			for victim_cid, data in base.pairs(commandstats.sndcmds) do
				if cid == victim_cid then
					commandstats.sndcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
					if commandstats.sndcmds[cid] and commandstats.sndcmds[cid].warning > 0 then
						return false
					end
					return true
				end
			end
		end
		commandstats.sndcmds[cid] = make_data(c, cmd, msg, type, minutes)
		return true
	end

	return true
end

local function recheck_info()
	if li_settings_done then
		local entities = adchpp.getCM():getEntities()
		local size = entities:size()
		if size > 0 then
			for i = 0, size - 1 do
				local c = entities[i]:asClient()
				if c then
					onINF(c, adchpp.AdcCommand(c:getINF()))
				end
			end
		end
	end
end

-- Default flood settings for all limits and adc commands

fl_settings.fl_maxkicks = {
	alias = { maximumkicks = true, maxkicks = true },

	help = "maximum count of kicks before user is tmp bannend, 0 = disabled !!!!",

	value = 0
}

fl_settings.fl_maxwarns = {
	alias = { maximumwarns = true, maxwarns = true },

	help = "maximum count of hammering warnings before user is kicked, 0 = disabled !!!!",

	value = 0
}

fl_settings.fl_maxtmpbans = {
	alias = { maximumtmpbans = true, maxtmpbans = true },

	help = "maximum count of tmpbans before user is banned for ever, 0 = disabled !!!!",

	value = 0
}

fl_settings.fl_tmpban =  {
	alias = { floodtmpban = true },

	help = "minutes a user will be temp banned after reaching the maxkicks value,  0 = disabled !!!!",

	value = 0
}

fl_settings.fl_maxrate = {
	alias = { cmdmaxrate = true, maxratecmd = true},

	help = "default maximum rate in counts/min for all enabled command stats,  0 = disabled",

	value = 15
}

fl_settings.fl_level = {
	alias = { verifylevel = true },

	help = "all users whose level <= this setting wil be affected by the flood and limit rules, -1 = disabled",

	value = access.settings.oplevel.value - 1
}

fl_settings.fl_exptime = {
	alias = { cmdexpiretime = true, expiretime = true},

	help = "default expiretime for all enabled command stats in minutes,  must be > 0",

	value = 2
}

fl_settings.fl_logexptime = {
	alias = { floodlogexpiretime = true, logexpiretime = true},

	help = "expiretime in days for the tmpban and kick logs, 0 = disabled",

	value = 7
}


-- ADC Command flood settings

fl_settings.cmdinf_rate = {
	alias = { inf_rate = true },

	help = "max rate in counts/min that a client can send his inf updates, 0 = default, -1 = disabled",

	value = 10
}

fl_settings.cmdschman_rate = {
	alias = { sch_rate = true },

	help = "max rate in counts/min that a client can send searches, 0 = default, -1 = disabled",

	value = 6
}

fl_settings.cmdschtth_rate = {
	alias = { sch_rate = true },

	help = "max rate in counts/min that a client can send TTH searches, 0 = default, -1 = disabled",

	value = 3
}

fl_settings.cmdmsg_rate = {
	alias = { msg_rate = true },

	help = "max rate in counts/min that a client can send msg's, 0 = default, -1 = disabled",

	value = 0
}

fl_settings.cmdsup_rate = {
	alias = { sup_rate = true },

	help = "max rate in counts/min that a client can send sup strings, 0 = default, -1 = disabled",

	value = 0
}

fl_settings.cmdsid_rate = {
	alias = { sid_rate = true },

	help = "max rate in counts/min that a client can send sid strings, 0 = default, -1 = disabled",

	value = 0
}

fl_settings.cmdcon_rate = {
	alias = { con_rate = true },

	help = "maximum rate in counts/min that a user can reconnect, 0 = default, -1 = disabled",

	value = 0
}

fl_settings.cmdsoc_rate = {
	alias = { soc_rate = true },

	help = "maximum rate in counts/min that the same ip can open a new socket, 0 = default, -1 = disabled",

	value = 15
}

fl_settings.cmdurx_rate = {
	alias = { brx_rate = true },

	help = "max rate in counts/min that a client can send unknown adc commands, 0 = default, -1 = disabled",

	value = 0
}

fl_settings.cmdcrx_rate = {
	alias = { trx_rate = true },

	help = "max rate in counts/min that a client can send adc commands with a bad context, 0 = default, -1 = disabled",

	value = 0
}

fl_settings.cmdpas_rate = {
	alias = { pas_rate = true },

	help = "max rate in counts/min that a client can send pas strings, 0 = default, -1 = disabled",

	value = 0
}

fl_settings.cmdsta_rate = {
	alias = { sta_rate = true },

	help = "max rate in counts/min that a client can send sta strings, 0 = default, -1 = disabled",

	value = 0
}

fl_settings.cmdcmd_rate = {
	alias = { cmd_rate = true },

	help = "max rate in counts/min that a client can send cmd strings, 0 = default, -1 = disabled",

	value = 5
}

fl_settings.cmdres_rate = {
	alias = { res_rate = true },

	help = "max rate in counts/min that a client can send search results, 0 = default, -1 = disabled",

	value = -1
}

fl_settings.cmdctm_rate = {
	alias = { ctm_rate = true },

	help = "max rate in counts/min that a client can send connect request's, 0 = default, -1 = disabled",

	value = 120
}

fl_settings.cmdrcm_rate = {
	alias = { rcm_rate = true },

	help = "max rate in counts/min that a client can send reverse connect's, 0 = default, -1 = disabled",

	value = 8
}

fl_settings.cmdnat_rate = {
	alias = { nat_rate = true },

	help = "max rate in counts/min that a client can send nat connect request's, 0 = default, -1 = disabled",

	value = 120
}

fl_settings.cmdrnt_rate = {
	alias = { rnt_rate = true },

	help = "max rate in counts/min that a client can send reverse nat connect's, 0 = default, -1 = disabled",

	value = 8
}

fl_settings.cmdpsr_rate = {
	alias = { psr_rate = true },

	help = "max rate in counts/min that a client can send partitial file sharing string's, 0 = default, -1 = disabled",

	value = 10
}

fl_settings.cmdget_rate = {
	alias = { get_rate = true },

	help = "max rate in counts/min that a client can the get transfer command, 0 = default, -1 = disabled",

	value = 0
}

fl_settings.cmdsnd_rate = {
	alias = { snd_rate = true },

	help = "max rate in counts/min that a client can send the send transfer command, 0 = default, -1 = disabled",

	value = 10
}

fl_settings.cmdinf_exp = {
	alias = { inf_exp = true },

	help = "minutes before the inf commandstats are removed, 0 = default",

	value = 0
}

fl_settings.cmdmsg_exp = {
	alias = { msg_exp = true },

	help = "minutes before the msg commandstats are removed, 0 = default",

	value = 0
}

fl_settings.cmdschman_exp = {
	alias = { sch_exp = true },

	help = "minutes before the MAN sch commandstats are removed, 0 = default",

	value = 0
}

fl_settings.cmdschtth_exp = {
	alias = { sch_exp = true },

	help = "minutes before the TTH sch commandstats are removed, 0 = default",

	value = 0
}

fl_settings.cmdsup_exp = {
	alias = { sch_exp = true },

	help = "minutes before the sup commandstats are removed, 0 = default",

	value = 10
}

fl_settings.cmdsid_exp = {
	alias = { sid_exp = true },

	help = "minutes before the sid commandstats are removed, 0 = default",

	value = 10
}

fl_settings.cmdcon_exp = {
	alias = { con_exp = true },

	help = "minutes before the connect attempts are removed, 0 = default",

	value = 10
}

fl_settings.cmdsoc_exp = {
	alias = { soc_exp = true },

	help = "minutes before the open sockets stats that are pending to connect are removed, 0 = default",

	value = 10
}

fl_settings.cmdurx_exp = {
	alias = { brx_exp = true },

	help = "minutes before the unknown adc commandstats are removed, 0 = default",

	value = 360
}

fl_settings.cmdcrx_exp = {
	alias = { trx_exp = true },

	help = "minutes before the bad context adc commandstats are removed, 0 = default",

	value = 360
}

fl_settings.cmdsta_exp = {
	alias = { sta_exp = true },

	help = "minutes before the sta commandstats are removed, 0 = default",

	value = 0
}

fl_settings.cmdpas_exp = {
	alias = { pas_exp = true },

	help = "minutes before the pas commandstats are removed, 0 = default",

	value = 10
}

fl_settings.cmdcmd_exp = {
	alias = { cmd_exp = true },

	help = "minutes before the cmd commandstats are removed, 0 = default",

	value = 0
}

fl_settings.cmdres_exp = {
	alias = { res_exp = true },

	help = "minutes before the res commandstats are removed, 0 = default",

	value = 0
}

fl_settings.cmdctm_exp = {
	alias = { ctm_exp = true },

	help = "minutes before the ctm commandstats are removed, 0 = default",

	value = 0
}

fl_settings.cmdrcm_exp = {
	alias = { rcm_exp = true },

	help = "minutes before the rcm commandstats are removed, 0 = default",

	value = 0
}

fl_settings.cmdnat_exp = {
	alias = { nat_exp = true },

	help = "minutes before the nat commandstats are removed, 0 = default",

	value = 0
}

fl_settings.cmdrnt_exp = {
	alias = { rnt_exp = true },

	help = "minutes before the rnt commandstats are removed, 0 = default",

	value = 0
}

fl_settings.cmdpsr_exp = {
	alias = { psr_exp = true },

	help = "minutes before the psr commandstats are removed, 0 = default",

	value = 0
}

fl_settings.cmdget_exp = {
	alias = { get_exp = true },

	help = "minutes before the get commandstats are removed, 0 = default",

	value = 0
}

fl_settings.cmdsnd_exp = {
	alias = { snd_exp = true },

	help = "minutes before the snd commandstats are removed, 0 = default",

	value = 0
}

-- Special Search limits flood settings

li_settings.maxschparam_rate = {
	alias = { maxsearchparam_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.maxschparam_exp = {
	alias = { maxsearchparam_exp = true },

	help = "minutes before the maxschparam attempts are removed, 0 = default",

	value = 0
}

li_settings.maxschlength_rate = {
	alias = { maxsearchlength_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.maxschlength_exp = {
	alias = { maxsearchlength_exp = true },

	help = "minutes before the maxschlength attempts are removed, 0 = default",

	value = 0
}

li_settings.minschlength_rate = {
	alias = { minsearchlength_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.minschlength_exp = {
	alias = { minsearchlength_exp = true },

	help = "minutes before the minschlength attempts are removed, 0 = default",

	value = 0
}


-- Special Message limits flood settings

li_settings.maxmsglength_rate = {
	alias = { maxmessagelength_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.maxmsglength_exp = {
	alias = { maxmessagelength_exp = true },

	help = "minutes before the maxmsglength attempts are removed, 0 = default",

	value = 0
}


-- Special Info limits flood settings

li_settings.minsharefiles_rate = {
	alias = { minimumsharefiles_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.minsharefiles_exp = {
	alias = { minimumsharefiles_exp = true },

	help = "minutes before the minsharefiles attempts are removed, 0 = default",

	value = 0
}

li_settings.maxsharefiles_rate = {
	alias = { maximumsharefiles_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.maxsharefiles_exp = {
	alias = { maximumsharefiles_exp = true },

	help = "minutes before the maxsharefiles attempts are removed, 0 = default",

	value = 0
}

li_settings.minsharesize_rate = {
	alias = { minimumsharesize_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.minsharesize_exp = {
	alias = { minimumsharesize_exp = true },

	help = "minutes before the minsharesize attempts are removed, 0 = default",

	value = 0
}

li_settings.maxsharesize_rate = {
	alias = { maximumsharesize_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.maxsharesize_exp = {
	alias = { maximumsharesize_exp = true },

	help = "minutes before the maxsharesize attempts are removed, 0 = default",

	value = 0
}

li_settings.maxnicklength_rate = {
	alias = { maxnilength_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.maxnicklength_exp = {
	alias = { maxniclength_exp = true },

	help = "minutes before the maxnicklength attempts are removed, 0 = default",

	value = 0
}

li_settings.minnicklength_rate = {
	alias = { minnilength_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.minnicklength_exp = {
	alias = { minniclength_exp = true },

	help = "minutes before the minnicklength attempts are removed, 0 = default",

	value = 0
}

li_settings.minslots_rate = {
	alias = { minimumslots_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.minslots_exp = {
	alias = { minimumslots_exp = true },

	help = "minutes before the minslots attempts are removed, 0 = default",

	value = 0
}

li_settings.maxslots_rate = {
	alias = { maximumslots_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.maxslots_exp = {
	alias = { mmaximumslots_exp = true },

	help = "minutes before the maxslots attempts are removed, 0 = default",

	value = 0
}

li_settings.minhubslotratio_rate = {
	alias = { minimumhubslotratio_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.minhubslotratio_exp = {
	alias = { minimumhubslotratio_exp = true },

	help = "minutes before the minhubslotratios attempts are removed, 0 = default",

	value = 0
}

li_settings.maxhubslotratio_rate = {
	alias = { maximumhubslotratio_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.maxhubslotratio_exp = {
	alias = { maximumhubslotratio_exp = true },

	help = "minutes before the maxhubslotratios attempts are removed, 0 = default",

	value = 0
}

li_settings.maxhubcount_rate = {
	alias = { maximumhubcount_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.maxhubcount_exp = {
	alias = { maximumhubcount_exp = true },

	help = "minutes before the maxhubcount attempts are removed, 0 = default",

	value = 0
}

li_settings.suadcs_rate = {
	alias = { supportadcs_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.suadcs_exp = {
	alias = { supportadcs_exp = true },

	help = "minutes before the support adcs attempts are removed, 0 = default",

	value = 0
}

li_settings.sunatt_rate = {
	alias = { supportnatt_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.sunatt_exp = {
	alias = { supportnatt_exp = true },

	help = "minutes before the support natt attempts are removed, 0 = default",

	value = 0
}

li_settings.sublom_rate = {
	alias = { supportblom_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.sublom_exp = {
	alias = { supportblom_exp = true },

	help = "minutes before the support blom attempts are removed, 0 = default",

	value = 0
}

li_settings.maxsameip_rate = {
	alias = { maxsameips_rate = true },

	help = "maximum rate in counts / hour that a user can try this, 0 = default, -1 = disabled",

	value = 0
}

li_settings.maxsameip_exp = {
	alias = { maxsameips_exp = true },

	help = "minutes before the maximum same ip connect attempts are removed, 0 = default",

	value = 0
}

-- All the specific limits settings values

li_settings.li_maxrate = {
	alias = { limratelim = true, maxratelim = true},

	help = "default maximum rate in counts/hour for all enabled limit stats,  0 = disabled",

	value = 0
}

li_settings.li_exptime = {
	alias = { liexpiretime = true, expiretime = true},

	help = "default expiretime for all enabled limit stats in minutes,  must be > 0",

	value = 720
}

li_settings.li_maxcount = {
	alias = { maxspamcount = true, maxspam = true },

	help = "default maximum count of attempts allowed for all limit rules, 0 = disabled",

	value = 0
}

li_settings.li_minlevel = {
	alias = { limitminlevel = true },

	change = recheck_info,

	help = "minimum level to verify a user regarding the sharing limit rules like slots/hubs/sharesize, 0 = all user will be verifyed",

	value = 0
}

li_settings.li_redirect = {
	alias = { limitredirect = true },

	help = "redirect address for the sharing limit rules like slots/hubs/sharesize, ' ' = users are just disconnected",

	value = ""
}

li_settings.minsharefiles = {
	alias = { minimumsharefiles = true },

	change = recheck_info,

	help = "minimum number of shared files, 0 = disabled",

	value = 0
}

li_settings.maxsharefiles = {
	alias = { maximumsharefiles = true },

	change = recheck_info,

	help = "maximum number of shared files, 0 = disabled",

	value = 0
}

li_settings.minsharesize = {
	alias = { minimumsharesize = true },

	change = recheck_info,

	help = "minimum share size allowed in bytes, 0 = disabled",

	value = 0
}

li_settings.maxsharesize = {
	alias = { maximumsharesize = true },

	change = recheck_info,

	help = "maximum share size allowed in bytes, 0 = disabled",

	value = 0
}

li_settings.minslots = {
	alias = { minimumslots = true },

	change = recheck_info,

	help = "minimum number of opened upload slots allowed, 0 = disabled",

	value = 0
}

li_settings.maxslots = {
	alias = { maximumslots = true },

	change = recheck_info,

	help = "maximum number of opened upload slots allowed, 0 = disabled",

	value = 0
}

li_settings.minhubslotratio = {
	alias = { minimumhubslotratio = true },

	change = recheck_info,

	help = "minimum hub/slot ratio allowed, 0 = disabled",

	value = 0
}

li_settings.maxhubslotratio = {
	alias = { maximumhubslotratio = true },

	change = recheck_info,

	help = "maximum hub/slot ratio allowed, 0 = disabled",

	value = 0
}

li_settings.maxhubcount = {
	alias = { maximumhubcount = true },

	change = recheck_info,

	help = "maximum number of connected hubs allowed, 0 = disabled",

	value = 0
}

li_settings.maxmsglength = {
	alias = { maxmessagelength = true },

	help = "maximum number of characters allowed per chat message, 0 = no limit",

	value = 0
}

li_settings.maxschparam = {
	alias = { maxsearchparam = true },

	help = "maximum number of search parameters allowed, 0 = disabled",

	value = 100
}

li_settings.minschlength = {
	alias = { minsearchlength = true },

	help = "minimum length of search string allowed, 0 = disabled",

	value = 0
}

li_settings.maxschlength = {
	alias = { maxsearchlength = true },

	help = "maximum length of search string allowed, 0 = disabled",

	value = 0
}

li_settings.minnicklength = {
	alias = { minnilenght = true },

	change = recheck_info,

	help = "minimum number of characters allowed for the nick, 0 = no limit",

	value = 0
}

li_settings.maxnicklength = {
	alias = { maxnilenght = true },

	change = recheck_info,

	help = "maximum number of characters allowed for the nick, 0 = no limit",

	value = 0
}

li_settings.suadcs = {
	alias = { supportacds = true },

	change = recheck_info,

	help = "disallow users that have disabled ADCS (TLS) support for file transfers, 0 = disabled",

	value = 0
}

li_settings.sunatt = {
	alias = { supportnatt = true },

	change = recheck_info,

	help = "disallow passive users that have disabled NAT-T (passive-passive) support for file transfers, 0 = disabled",

	value = 0
}

li_settings.sublom = {
	alias = { supportblom = true },

	change = recheck_info,

	help = "disallow clients that don't have BLOM (TTH search filtering) support, 0 = disabled",

	value = 0
}

li_settings.maxsameip = {
	alias = { maxsameips = true },

	change = recheck_info,

	help = "maximum number of connected users with the same ip address, 0 = disabled",

	value = 0
}

-- All the Entity settings

en_settings.entitylog = {
	alias = { entityloging = true },

	change = onONL,

	help = "logs users cid , ip , nicks etc into a database and keeps history , 0 = disabled",

	value = 0
}

en_settings.entitylogexptime = {
	alias = { entitylogexpiretime = true, entityexpiretime = true},

	help = "expiretime in days for a non registered user entity logs, 0 = disabled",

	value = 7
}

en_settings.entitylogregexptime = {
	alias = { entitylogregexpiretime = true, entityregexpiretime = true},

	help = "expiretime in days for a registered user entity logs, 0 = disabled",

	value = 60
}

local function verify_port(c, port)
	local socket = base.require "socket"
	local cid = c:getCID():toBase32()
	local ip = c:getIp()
	local tcp = port
	local test_timeout = 0.9
	local res = {}

	local test = { cid, socket = socket.connect( ip, tcp ) }
	if test.socket then
		test.socket:settimeout( test_timeout )
		test.socket:send( " \n" )
		local str, err = test.socket:receive()
		if err == "closed" then
			res.tcp = true
		else
			res.err = err
		end
		res.socket = true
	end
	return res
end

local cfgfl_list_done = false
local function gen_cfgfl_list()
	if cfgfl_list_done then
		return
	end
	local list = {}
	for k, v in base.pairs(fl_settings) do
		local str = cut_str(v.help or "no information", 30)
		str = string.gsub(str, '/', '//')
		str = string.gsub(str, '%[', '{')
		str = string.gsub(str, '%]', '}')
		table.insert(list, k .. ": <" .. str .. ">")
	end
	table.sort(list)
	commands.cfgfl.user_command.params[1] = autil.ucmd_list("Name of the fl_setting to change", list)
	cfgfl_list_done = true
end

commands.cfgfl = {
	alias = { changecfgfl = true, changeflconfig = true, configfl = true, varfl = true, changevarfl = true, setvarfl = true, setcfgfl = true, setflconfig = true },

	command = function(c, parameters)
		if not commands.cfgfl.protected(c) then
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
		for k, v in base.pairs(fl_settings) do
			if k == name or (v.alias and v.alias[name]) then
				setting = v
				break
			end
		end
		if not setting then
			autil.reply(c, "The name " .. name .. " doesn't correspond to any flood setting variable, use \"+help cfgfl\" to list all variables")
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
		base.pcall(save_fl_settings)
		autil.reply(c, "Variable " .. name .. " changed from " .. base.tostring(old) .. " to " .. base.tostring(setting.value))
	end,

	help = "name value - change flood configuration, use \"+help cfgfl\" to list all variables",

	helplong = function()
		local list = {}
		for k, v in base.pairs(fl_settings) do
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
		return "List of all flood settings variables:\n" .. table.concat(list, "\n")
	end,

	protected = is_admin,

	user_command = {
		name = "Guard management" .. autil.ucmd_sep .. "Hub Flood protection" .. autil.ucmd_sep .. "Change a Flood setting",
		params = {
			'', -- will be set by gen_cfgfl_list
			autil.ucmd_line("New value for the setting")
		}
	}
}

local cfgli_list_done = false
local function gen_cfgli_list()
	if cfgli_list_done then
		return
	end
	local list = {}
	for k, v in base.pairs(li_settings) do
		local str = cut_str(v.help or "no information", 30)
		str = string.gsub(str, '/', '//')
		str = string.gsub(str, '%[', '{')
		str = string.gsub(str, '%]', '}')
		table.insert(list, k .. ": <" .. str .. ">")
	end
	table.sort(list)
	commands.cfgli.user_command.params[1] = autil.ucmd_list("Name of the li_setting to change", list)
	cfgli_list_done = true
end

commands.cfgli = {
	alias = { changecfgli = true, changeliconfig = true, configli = true, varli = true, changevarli = true, setvarli = true, setcfgli = true, setliconfig = true },

	command = function(c, parameters)
		if not commands.cfgli.protected(c) then
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
		for k, v in base.pairs(li_settings) do
			if k == name or (v.alias and v.alias[name]) then
				setting = v
				break
			end
		end
		if not setting then
			autil.reply(c, "The name " .. name .. " doesn't correspond to any limit setting variable, use \"+help cfgli\" to list all variables")
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
		base.pcall(save_li_settings)
		autil.reply(c, "Variable " .. name .. " changed from " .. base.tostring(old) .. " to " .. base.tostring(setting.value))
	end,

	help = "name value - change limits configuration, use \"+help cfgli\" to list all variables",

	helplong = function()
		local list = {}
		for k, v in base.pairs(li_settings) do
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
		return "List of all limit settings variables:\n" .. table.concat(list, "\n")
	end,

	protected = is_admin,

	user_command = {
		name = "Guard management" .. autil.ucmd_sep .. "Hub Limits and Rules" .. autil.ucmd_sep .. "Change a Limit setting",
		params = {
			'', -- will be set by gen_cfgli_list
			autil.ucmd_line("New value for the setting")
		}
	}
}

local cfgen_list_done = false
local function gen_cfgen_list()
	if cfgen_list_done then
		return
	end
	local list = {}
	for k, v in base.pairs(en_settings) do
		local str = cut_str(v.help or "no information", 30)
		str = string.gsub(str, '/', '//')
		str = string.gsub(str, '%[', '{')
		str = string.gsub(str, '%]', '}')
		table.insert(list, k .. ": <" .. str .. ">")
	end
	table.sort(list)
	commands.cfgen.user_command.params[1] = autil.ucmd_list("Name of the en_setting to change", list)
	cfgen_list_done = true
end

commands.cfgen = {
	alias = { changecfgen = true, changeenconfig = true, configen = true, varen = true, changevaren = true, setvaren = true, setcfgen = true, setenconfig = true },

	command = function(c, parameters)
		if not commands.cfgen.protected(c) then
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
		for k, v in base.pairs(en_settings) do
			if k == name or (v.alias and v.alias[name]) then
				setting = v
				break
			end
		end
		if not setting then
			autil.reply(c, "The name " .. name .. " doesn't correspond to any entity setting variable, use \"+help cfgen\" to list all variables")
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
		base.pcall(save_en_settings)
		autil.reply(c, "Variable " .. name .. " changed from " .. base.tostring(old) .. " to " .. base.tostring(setting.value))
	end,

	help = "name value - change entity configuration, use \"+help cfgen\" to list all variables",

	helplong = function()
		local list = {}
		for k, v in base.pairs(en_settings) do
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
		return "List of all entity settings variables:\n" .. table.concat(list, "\n")
	end,

	protected = is_admin,

	user_command = {
		name = "Guard management" .. autil.ucmd_sep .. "Entity Info Logs" .. autil.ucmd_sep .. "Change a Entity log setting",
		params = {
			'', -- will be set by gen_cfgli_list
			autil.ucmd_line("New value for the setting")
		}
	}
}

commands.listcmdstats = {
	alias = { listcmdstat = true, listcommandstats = true },

--	data_info_sort(statstable) TODO

	command = function(c)
		if not commands.listcmdstats.protected(c) then
			return
		end

		str = "\n\nDefault settings for all cmd's:\t\t\tMaximum Rate: " .. fl_settings.fl_maxrate.value .. " / m"
		str = str .. "\t\t\tExpire time: " .. fl_settings.fl_exptime.value
		str = str .. "\n\n\nSCH command rules:\nSCH TTH string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdschtth_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdschtth_exp.value .. "\n"
		for schtthcmds, info in base.pairs(commandstats.schtthcmds) do
			str = str .. "\n\tCID: " .. schtthcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nSCH TTHn string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdschtth_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdschtth_exp.value .. "\n"
		for schtthnatcmds, info in base.pairs(commandstats.schtthnatcmds) do
			str = str .. "\n\tCID: " .. schtthnatcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nSCH MAN string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdschman_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdschman_exp.value .. "\n"
		for schmancmds, info in base.pairs(commandstats.schmancmds) do
			str = str .. "\n\tCID: " .. schmancmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nSCH MANs string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdschman_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdschman_exp.value .. "\n"
		for schmansegacmds, info in base.pairs(commandstats.schmansegacmds) do
			str = str .. "\n\tCID: " .. schmansegacmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nSCH MANn string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdschman_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdschman_exp.value .. "\n"
		for schmannatcmds, info in base.pairs(commandstats.schmannatcmds) do
			str = str .. "\n\tCID: " .. schmannatcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nSCH MANns string stats:"
		str = str .. "\t\t\tMaximum Rate: " .. fl_settings.cmdschman_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdschman_exp.value .. "\n"
		for schmannatsegacmds, info in base.pairs(commandstats.schmannatsegacmds) do
			str = str .. "\n\tCID: " .. schmannatsegacmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nRES command rules:\nRES string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdres_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdres_exp.value .. "\n"
		for rescmds, info in base.pairs(commandstats.rescmds) do
			str = str .. "\n\tCID: " .. rescmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nMSG command rules:\nMSG string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdmsg_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdmsg_exp.value .. "\n"
		for msgcmds, info in base.pairs(commandstats.msgcmds) do
			str = str .. "\n\tCID: " .. msgcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nINF command rules:\nINF updating stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdinf_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdinf_exp.value .. "\n"
		for infcmds, info in base.pairs(commandstats.infcmds) do
			str = str .. "\n\tCID: " .. infcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nCTM command rules:\nCTM string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdctm_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdctm_exp.value .. "\n"
		for ctmcmds, info in base.pairs(commandstats.ctmcmds) do
			str = str .. "\n\tCID: " .. ctmcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nRCM command rules:\nRCM string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdrcm_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdrcm_exp.value .. "\n"
		for rcmcmds, info in base.pairs(commandstats.rcmcmds) do
			str = str .. "\n\tCID: " .. rcmcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nNAT command rules:\nNAT string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdnat_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdnat_exp.value .. "\n"
		for natcmds, info in base.pairs(commandstats.natcmds) do
			str = str .. "\n\tCID: " .. natcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nRNT command rules:\nRNT string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdrnt_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdrnt_exp.value .. "\n"
		for rntcmds, info in base.pairs(commandstats.rntcmds) do
			str = str .. "\n\tCID: " .. rntcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nPSR command rules:\nPSR string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdpsr_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdpsr_exp.value .. "\n"
		for psrcmds, info in base.pairs(commandstats.psrcmds) do
			str = str .. "\n\tCID: " .. psrcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nGET command rules:\nGET string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdget_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdget_exp.value .. "\n"
		for getcmds, info in base.pairs(commandstats.getcmds) do
			str = str .. "\n\tCID: " .. getcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nSND command rules:\nSND string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdsnd_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdsnd_exp.value .. "\n"
		for sndcmds, info in base.pairs(commandstats.sndcmds) do
			str = str .. "\n\tCID: " .. sndcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nSTA command rules:\nSTA string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdsta_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdsta_exp.value .. "\n"
		for stacmds, info in base.pairs(commandstats.stacmds) do
			str = str .. "\n\tCID: " .. stacmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nSID command rules:\nSID string  stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdsid_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdsid_exp.value .. "\n"
		for sidcmds, info in base.pairs(commandstats.sidcmds) do
			str = str .. "\n\tCID: " .. sidcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nPAS command rules:\nPAS string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdpas_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdpas_exp.value .. "\n"
		for pascmds, info in base.pairs(commandstats.pascmds) do
			str = str .. "\n\tCID: " .. pascmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nCON attempt rules:\nCON attempt stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdcon_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdcon_exp.value .. "\n"
		for concmds, info in base.pairs(commandstats.concmds) do
			str = str .. "\n\tCID:  " .. concmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nSUP command rules:\nSUP string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdsup_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdsup_exp.value .. "\n"
		for supcmds, info in base.pairs(commandstats.supcmds) do
			str = str .. "\n\tIP:  " .. supcmds .. data_info_string_ip(info)
		end

		str = str .. "\n\nSOC command rules:\nSOC string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdsoc_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdsoc_exp.value .. "\n"
		for soccmds, info in base.pairs(commandstats.soccmds) do
			str = str .. "\n\tIP:  " .. soccmds .. data_info_string_ip(info)
		end

		str = str .. "\n\nCMD command rules:\nCMD string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdcmd_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdcmd_exp.value .. "\n"
		for cmdcmds, info in base.pairs(commandstats.cmdcmds) do
			str = str .. "\n\tCID:  " .. cmdcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nUnknown ADC cmd rules:\nURX string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdurx_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdurx_exp.value .. "\n"
		for urxcmds, info in base.pairs(commandstats.urxcmds) do
			str = str .. "\n\tCID: " .. urxcmds .. data_info_string_cid(info)
		end

		str = str .. "\n\nBad context ADC cmd rules:\nCRX string stats:"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.cmdcrx_rate.value .. " / m"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.cmdcrx_exp.value .. "\n"
		for crxcmds, info in base.pairs(commandstats.crxcmds) do
			str = str .. "\n\tCID: " .. crxcmds .. data_info_string_cid(info)
		end

		autil.reply(c, str)
	end,

	help = "lists a statistic overview of all adc commands used in the hub",

	protected = is_stats,

	user_command = { name = "Guard management" .. autil.ucmd_sep .. "Hub Flood Protection" .. autil.ucmd_sep ..  "List Command Stats" }
}

commands.listlimstats = {
	alias = { listlimstat = true, listlimitstats = true },

--	data_info_sort(statstable) TODO

	command = function(c)
		if not commands.listlimstats.protected(c) then
			return
		end

		str = "\n\nDefault settings for all limits:\tMaximum Rate: " .. li_settings.li_maxrate.value .. " / h"
		str = str .. "\t\t\tExpire time: " .. li_settings.li_exptime.value
		str = str .. "\t\t\tMax level: " .. fl_settings.fl_level.value
		str = str .. "\n\nSharing (*) limits settings:\tMin Level: " .. li_settings.li_minlevel.value
		str = str .. "\t\t\t\tRedirect address: " .. li_settings.li_redirect.value
		str = str .. "\n\n\nSearch limits:\n\nSearch parameters:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.maxschparam_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.maxschparam_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.maxschparam.value .. "\n"
		for maxschparams, info in base.pairs(limitstats.maxschparams) do
			str = str .. "\n\tCID: " .. maxschparams .. data_info_string_cid(info)
		end

		str = str .. "\n\nMin Search length:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.minschlength_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.minschlength_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.minschlength.value .. "\n"
		for minschlengths, info in base.pairs(limitstats.minschlengths) do
			str = str .. "\n\tCID: " .. minschlengths .. data_info_string_cid(info)
		end

		str = str .. "\n\nMax Search length:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.maxschlength_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.maxschlength_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.maxschlength.value .. "\n"
		for maxschlengths, info in base.pairs(limitstats.maxschlengths) do
			str = str .. "\n\tCID: " .. maxschlengths .. data_info_string_cid(info)
		end

		str = str .. "\n\nShare limits (*):\n\nMinimum Sharesize:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.minsharesize_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.minsharesize_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.minsharesize.value .. "\n"
		for minsharesizes, info in base.pairs(limitstats.minsharesizes) do
			str = str .. "\n\tCID: " .. minsharesizes .. data_info_string_cid(info)
		end

		str = str .. "\n\nMaximum Sharesize:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.maxsharesize_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.maxsharesize_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.maxsharesize.value .. "\n"
		for maxsharesizes, info in base.pairs(limitstats.maxsharesizes) do
			str = str .. "\n\tCID: " .. maxsharesizes .. data_info_string_cid(info)
		end

		str = str .. "\n\nMinimum Sharefiles:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.minsharefiles_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.minsharefiles_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.minsharefiles.value .. "\n"
		for minsharefiles, info in base.pairs(limitstats.minsharefiles) do
			str = str .. "\n\tCID: " .. minsharefiles .. data_info_string_cid(info)
		end

		str = str .. "\n\nMaximum Sharefiles:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.maxsharefiles_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.maxsharefiles_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.maxsharefiles.value .. "\n"
		for maxsharefiles, info in base.pairs(limitstats.maxsharefiles) do
			str = str .. "\n\tCID: " .. maxsharefiles .. data_info_string_cid(info)
		end

		str = str .. "\n\nOpen Slot limits (*):\n\nMinimum Open Slots:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.minslots_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.minslots_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.minslots.value .. "\n"
		for minslots, info in base.pairs(limitstats.minslots) do
			str = str .. "\n\tCID: " .. minslots .. data_info_string_cid(info)
		end

		str = str .. "\n\nMaximum Open Slots:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.maxslots_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.maxslots_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.maxslots.value .. "\n"
		for maxslots, info in base.pairs(limitstats.maxslots) do
			str = str .. "\n\tCID: " .. maxslots .. data_info_string_cid(info)
		end

		str = str .. "\n\nHub Count and Ratio limits (*):\n\nMin Hub Slotratio:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.minhubslotratio_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.minhubslotratio_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.minhubslotratio.value .. "\n"
		for minhubslotratios, info in base.pairs(limitstats.minhubslotratios) do
			str = str .. "\n\tCID: " .. minhubslotratios .. data_info_string_cid(info)
		end

		str = str .. "\n\nMax Hub Slotratio:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.maxhubslotratio_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.maxhubslotratio_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.maxhubslotratio.value .. "\n"
		for maxhubslotratios, info in base.pairs(limitstats.maxhubslotratios) do
			str = str .. "\n\tCID: " .. maxhubslotratios .. data_info_string_cid(info)
		end

		str = str .. "\n\nMax Open Hubcount:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.maxhubcount_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.maxhubcount_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.maxhubcount.value .. "\n"
		for maxhubcounts, info in base.pairs(limitstats.maxhubcounts) do
			str = str .. "\n\tCID: " .. maxhubcounts .. data_info_string_cid(info)
		end

		str = str .. "\n\nSupport limits (*):\n\nSupport ADCS forced:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.suadcs_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.suadcs_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.suadcs.value .. "\n"
		for suadcs, info in base.pairs(limitstats.suadcs) do
			str = str .. "\n\tCID: " .. suadcs .. data_info_string_cid(info)
		end

		str = str .. "\n\nSupport NATT forced:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.sunatt_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.sunatt_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.sunatt.value .. "\n"
		for sunatts, info in base.pairs(limitstats.sunatts) do
			str = str .. "\n\tCID: " .. sunatts .. data_info_string_cid(info)
		end

		str = str .. "\n\nSupport BLOM forced:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.sublom_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.sublom_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.sublom.value .. "\n"
		for subloms, info in base.pairs(limitstats.subloms) do
			str = str .. "\n\tCID: " .. subloms .. data_info_string_ip(info)
		end

		str = str .. "\n\nMessage limits:\n\nMax Message length:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.maxmsglength_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.maxmsglength_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.maxmsglength.value .. "\n"
		for maxmsglengths, info in base.pairs(limitstats.maxmsglengths) do
			str = str .. "\n\tCID: " .. maxmsglengths .. data_info_string_cid(info)
		end

		str = str .. "\n\nNick limits:\n\nMin Nick length stats:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.minnicklength_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.minnicklength_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.minnicklength.value .. "\n"
		for minnicklengths, info in base.pairs(limitstats.minnicklengths) do
			str = str .. "\n\tCID: " .. minnicklengths .. data_info_string_cid(info)
		end

		str = str .. "\n\nMax Nick length stats:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.maxnicklength_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.maxnicklength_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.maxnicklength.value .. "\n"
		for maxnicklengths, info in base.pairs(limitstats.maxnicklengths) do
			str = str .. "\n\tCID: " .. maxnicklengths .. data_info_string_cid(info)
		end

		str = str .. "\n\nUser IP limits:\n\nMax Same IP stats:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.maxsameip_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.maxsameip_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.maxsameip.value .. "\n"
		for maxsameips, info in base.pairs(limitstats.maxsameips) do
			str = str .. "\n\tCID: " .. maxsameips .. data_info_string_cid(info)
		end

		autil.reply(c, str)
	end,

	help = "lists a statistic overview of all limit rules in the hub and their settings",

	protected = is_stats,

	user_command = { name = "Guard management" .. autil.ucmd_sep .. "Hub Limits and Rules" .. autil.ucmd_sep .. "List Limit Stats" }
}

commands.showkicklog = {
	alias = { listkicklog = true },

	command = function(c)
		if not commands.showkicklog.protected(c) then
			return
		end

		str = "\n\nKick settings:\t\t\tMaximum kicks: " .. fl_settings.fl_maxkicks.value
		str = str .. "\t\t\tExpire time: " .. fl_settings.fl_logexptime.value .. " day(s)"
		str = str .. "\n\nKick IP records:"
		for ipkick, info in base.pairs(kickstats.ips) do
			str = str .. "\n\tIP: " .. ipkick .. "\t\t\t\t\t" .. data_info_string_log(info)
		end

		str = str .. "\n\nKick CID records:"
		for cidkick, info in base.pairs(kickstats.cids) do
			str = str .. "\n\tCID: " .. cidkick .. data_info_string_log(info)
		end
		autil.reply(c, str)
	end,

	help = "shows the kick log and the kicks settings",

	protected = is_stats,

	user_command = { name = "Guard management" .. autil.ucmd_sep .. "Action logs" .. autil.ucmd_sep .. "Show Kick log" }
}

commands.showtmpbanlog = {
	alias = { listtmpbanlog = true },

	command = function(c)
		if not commands.showtmpbanlog.protected(c) then
			return
		end

		str = "\n\nTmp Ban settings:\t\t\tMaximum tmpbans: " .. fl_settings.fl_maxtmpbans.value
		str = str .. "\t\t\tExpire time: " .. fl_settings.fl_logexptime.value .. " day(s)"
		str = str .. "\n\nTmp Ban IP records:"
		for iptmpban, info in base.pairs(tmpbanstats.ips) do
			str = str .. "\n\tIP: " .. iptmpban .. "\t\t\t\t\t" .. data_info_string_log(info)
		end

		str = str .. "\n\nTmp Ban CID records:"
		for cidtmpban, info in base.pairs(tmpbanstats.cids) do
			str = str .. "\n\tCID: " .. cidtmpban .. data_info_string_log(info)
		end
		autil.reply(c, str)
	end,

	help = "shows the tmpban log and the tmpban settings",

	protected = is_stats,

	user_command = { name = "Guard management" .. autil.ucmd_sep .. "Action Logs" .. autil.ucmd_sep .. "Show Tmpban log" }
}

commands.showentity = {
	alias = { listentity = true },

	command = function(c, param)
		if not commands.showentity.protected(c) then
			return
		end

		local value = param

		local entity = base.tostring(value) -- TODO IP validation
		if not entity then
			autil.reply(c, "This is not a valid Nick , CID or IP ")
			return
		end

		str = "\n\nEntity Log settings:\t\t\tEntity Log enabled: " .. en_settings.entitylog.value
		str = str .. "\t\t\tExpire time User / Reg: " .. en_settings.entitylogexptime.value .. " / " .. en_settings.entitylogregexptime.value .." day(s)"
		str = str .. "\n\nAll current Entity records that match your search criteria: [ " .. entity .. " ]\n" 
		for last_cid, info in base.pairs(entitystats.last_cids) do
			if entity == last_cid or entity == info.ip or (info.ni and string.lower(info.ni) == string.lower(entity)) then
				str = str .. "\n\tEntity CID: \t\t\t\t" .. last_cid .. data_info_string_entity(info)
			end
		end

		autil.reply(c, str)

	end,

	help = "shows full last info for all entity(s) that match either Nick, IP or CID",

	protected = is_stats,

	user_command = { name = "Guard management" .. autil.ucmd_sep .. "Entity Info Logs" .. autil.ucmd_sep .. "Show Entity Info", 			hub_params = { autil.ucmd_line("Entity Nick, IP or CID") },
			user_params = { "%[userCID]" }
	}
}

commands.traceip = {
	alias = { tracebyip = true },

	command = function(c, param)
		if not commands.traceip.protected(c) then
			return
		end

		local entni, entcid = { }, { }
		local value = param
		local ip = base.tostring(value)
		if not ip then -- TODO make it poss to use a range and have a ip validation
			autil.reply(c, "This is not a valid IP address")
			return
		end

		str = "\n\nEntity Log settings:\t\t\tEntity Log enabled: " .. en_settings.entitylog.value
		str = str .. "\t\t\tExpire time User / Reg: " .. en_settings.entitylogexptime.value .. " / " .. en_settings.entitylogregexptime.value .." day(s)"
		str = str .. "\n\nEntity Last records:"
		for last_cid, info in base.pairs(entitystats.last_cids) do
			if info.ip and info.ip == ip then
				table.insert(entni, info.ni)
				table.insert(entcid, last_cid)
				str = str .. "\n\tEntity CID: \t\t\t\t" .. last_cid .. data_info_string_entity(info)
			end
		end

		str = str .. "\n\nAll Hist records that used this NI:"
		for hist_cid, info in base.pairs(entitystats.hist_cids) do
			for i,v in base.ipairs(entni) do
				if info.ni and v == info.ni then	
					str = str .. "\n" .. data_info_string_entity_hist(info)
				end
			end
		end

		str = str .. "\n\nAll Hist records that used this IP:"
		for hist_cid, info in base.pairs(entitystats.hist_cids) do
			if info.ip and info.ip == ip then
				str = str .. "\n" .. data_info_string_entity_hist(info)
			end
		end

		str = str .. "\n\nAll Hist records that used this CID:"
		for hist_cid, info in base.pairs(entitystats.hist_cids) do
			for i,v in base.ipairs(entcid) do
				if info.cid and v == info.cid then	
					str = str .. "\n" .. data_info_string_entity_hist(info)
				end
			end
		end
		autil.reply(c, str)

	end,

	help = "trace a entity last info and history using his IP address",

	protected = is_stats,

	user_command = { name = "Guard management" .. autil.ucmd_sep .. "Entity Info Logs" .. autil.ucmd_sep .. "Trace Entity by IP",
			hub_params = { autil.ucmd_line("Entity IP address to find") },
			user_params = { "%[userI4]" }
	}
}

commands.tracecid = {
	alias = { tracebycid = true },

	command = function(c, param)
		if not commands.tracecid.protected(c) then
			return
		end

		local entni, entip = { }, { }
		local value = param

		local cid = base.tostring(value)
		if not cid then
			autil.reply(c, "This is not a valid CID")
			return
		end

		str = "\n\nEntity Log settings:\t\t\tEntity Log enabled: " .. en_settings.entitylog.value
		str = str .. "\t\t\tExpire time User / Reg: " .. en_settings.entitylogexptime.value .. " / " .. en_settings.entitylogregexptime.value .." day(s)"
		str = str .. "\n\nEntity Last records:"
		for last_cid, info in base.pairs(entitystats.last_cids) do
			if last_cid == cid then
				table.insert(entni, info.ni)
				table.insert(entip, info.ip)
				str = str .. "\n\tEntity CID: \t\t\t\t" .. last_cid .. data_info_string_entity(info)
			end
		end

		str = str .. "\n\nAll Hist records that used this NI:"
		for hist_cid, info in base.pairs(entitystats.hist_cids) do
			for i,v in base.ipairs(entni) do
				if info.ni and v == info.ni then	
					str = str .. "\n" .. data_info_string_entity_hist(info)
				end
			end
		end

		str = str .. "\n\nAll Hist records that used this IP:"
		for hist_cid, info in base.pairs(entitystats.hist_cids) do
			for i,v in base.ipairs(entip) do
				if info.ip and v == info.ip then	
					str = str .. "\n" .. data_info_string_entity_hist(info)
				end
			end
		end

		str = str .. "\n\nAll Hist records that used this CID:"
		for hist_cid, info in base.pairs(entitystats.hist_cids) do
			if info.cid and info.cid == cid then	
				str = str .. "\n" .. data_info_string_entity_hist(info)
			end
		end
		autil.reply(c, str)

	end,

	help = "trace a entity last info and history using his CID",

	protected = is_stats,

	user_command = { name = "Guard management" .. autil.ucmd_sep .. "Entity Info Logs" .. autil.ucmd_sep .. "Trace Entity by CID",
			hub_params = { autil.ucmd_line("Entity CID string to find") },
			user_params = { "%[userCID]" }
	}
}

commands.traceni = {
	alias = { tracebyni = true },

	command = function(c, param)
		if not commands.traceni.protected(c) then
			return
		end

		local entip, entcid = { }, { }
		local value = param

		local ni = base.tostring(value) -- TODO make it poss to use a regexp
		if not ni then
			autil.reply(c, "This is not a valid Nick")
			return
		end

		str = "\n\nEntity Log settings:\t\t\tEntity Log enabled: " .. en_settings.entitylog.value
		str = str .. "\t\t\tExpire time User / Reg: " .. en_settings.entitylogexptime.value .. " / " .. en_settings.entitylogregexptime.value .." day(s)"
		str = str .. "\n\nEntity Last records:"
		for last_cid, info in base.pairs(entitystats.last_cids) do
			if info.ni and string.lower(info.ni) == string.lower(ni) then
				table.insert(entip, info.ip)
				table.insert(entcid, last_cid)
				str = str .. "\n\tEntity\t\t\t\t\tCID: " .. last_cid .. data_info_string_entity(info)
			end
		end

		str = str .. "\n\nAll Hist records that used this NI:"
		for hist_cid, info in base.pairs(entitystats.hist_cids) do
			if info.ni and string.lower(info.ni) == string.lower(ni) then
				str = str .. "\n" .. data_info_string_entity_hist(info)
			end
		end

		str = str .. "\n\nAll Hist records that used this IP:"
		for hist_cid, info in base.pairs(entitystats.hist_cids) do
			for i,v in base.ipairs(entip) do
				if info.ip and v == info.ip then	
					str = str .. "\n" .. data_info_string_entity_hist(info)
				end
			end
		end

		str = str .. "\n\nAll Hist records that used this CID:"
		for hist_cid, info in base.pairs(entitystats.hist_cids) do
			for i,v in base.ipairs(entcid) do
				if info.cid and v == info.cid then	
					str = str .. "\n" .. data_info_string_entity_hist(info)
				end
			end
		end
		autil.reply(c, str)

	end,

	help = "trace a entity last info and history using his Nick",

	protected = is_stats,

	user_command = { name = "Guard management" .. autil.ucmd_sep .. "Entity Info Logs" .. autil.ucmd_sep .. "Trace Entity by Nick",
			hub_params = { autil.ucmd_line("Entity Nick string to find") },
			user_params = { "%[userNI]" }
	}
}

base.pcall(load_limitstats)
base.pcall(load_commandstats)
base.pcall(load_tmpbanstats)
base.pcall(load_kickstats)
base.pcall(load_entitystats)

fl_settings_loaded = load_fl_settings()
li_settings_loaded = load_li_settings()
en_settings_loaded = load_en_settings()

if not fl_settings_loaded then
	base.pcall(save_fl_settings) -- save initial fl_settings
	fl_settings_loaded = true
end

if not li_settings_loaded then
	base.pcall(save_li_settings) -- save initial li_settings
	li_settings_loaded = true
end

if not en_settings_loaded then
	base.pcall(save_en_settings)  -- save initial en_settings
	en_settings_loaded = true
end

fl_settings_done = true
li_settings_done = true
en_settings_done = true

local handlers = { 
	[adchpp.AdcCommand_CMD_SID] = { onSID },
	[adchpp.AdcCommand_CMD_SUP] = { onSUP },
	[adchpp.AdcCommand_CMD_INF] = { onINF }, 
	[adchpp.AdcCommand_CMD_PAS] = { onPAS },
	[adchpp.AdcCommand_CMD_STA] = { onSTA },
	[adchpp.AdcCommand_CMD_SCH] = { onSCH },
	[adchpp.AdcCommand_CMD_RES] = { onRES },
	[adchpp.AdcCommand_CMD_MSG] = { onMSG },
	[adchpp.AdcCommand_CMD_CTM] = { onCTM },
	[adchpp.AdcCommand_CMD_RCM] = { onRCM },
	[adchpp.AdcCommand_CMD_NAT] = { onNAT },
	[adchpp.AdcCommand_CMD_RNT] = { onRNT },
--	[adchpp.AdcCommand_CMD_PSR] = { onPSR },
	[adchpp.AdcCommand_CMD_GET] = { onGET },
	[adchpp.AdcCommand_CMD_SND] = { onSND },
	[adchpp.AdcCommand_CMD_CMD] = { onCMD }
}

local function onReceive(entity, cmd, ok)

	local c = entity:asClient()
	if not c then
		return false
	end

	local allowed_type = command_contexts[cmd:getCommand()]
	if allowed_type then
		if not cmd:getType():match(allowed_type) then
			local crx = onCRX(c, cmd)
			if not crx then
				return false
			end
		end
	else
		if cmd:getCommandString() == base.tostring("PSR") then
			local psr = onPSR(c, cmd)
			if not psr then
				return false
			end
		else
			local urx = onURX(c, cmd)
			if not urx then
				return false
			end
		end
	end

	if c:getState() == adchpp.Entity_STATE_NORMAL and cmd:getCommandString() == base.tostring("MSG") then
		local msg = cmd:getParam(0)
		if handle_plus_command(c, msg) then
			local cmd = onCMD(c, cmd)
			if not cmd then
				return false
			end
			return true
		end
	end

	local ret = true
	local handler = handlers[cmd:getCommand()]
	if handler then
		for _, v in base.pairs(handler) do
			ret = v(c, cmd) and ret
		end
	end

	if not ok then
		return ok
	end

	return ret
end

guard_1 = cm:signalReceive():connect(function(entity, cmd, ok)
	local res = onReceive(entity, cmd, ok)
	if not res then
		cmd:setPriority(adchpp.AdcCommand_PRIORITY_IGNORE)
	end

	return res
end)

guard_2 = cm:signalState():connect(function(entity)
	if entity:getState() == adchpp.Entity_STATE_NORMAL then
		local c = entity:asClient()
		if c then
			local con = onCON(c)
			if not con then
				dump_dropped(c, "You are disconnected for hammering the hub with connect attempts, stop or be kicked !!!")
				return false
			end
		end
	end
end)

guard_3 = cm:signalDisconnected():connect(function(entity)
	if entity:getState() == adchpp.Entity_STATE_NORMAL then
		local c = entity:asClient()
		if c then
			local dis = onDIS(c)
		end
	end
end)

guard_4 = cm:signalConnected():connect(function(entity)
	-- Calling function for building table of ip's in login state and drop above max rate.
		local c = entity:asClient()
		if c then
			local soc = onSOC(c)
			if not soc then
				dump_dropped(c)
				return false
			end
		end
end)

guard_5 = gen_cfgfl_list(), gen_cfgli_list(), gen_cfgen_list()

onONL_timer = sm:addTimedJob(900000, onONL)
autil.on_unloading(_NAME, onONL_timer)

save_tmpbanstats_timer = sm:addTimedJob(1800000, save_tmpbanstats)
autil.on_unloading(_NAME, save_tmpbanstats_timer)

save_kickstats_timer = sm:addTimedJob(1800000, save_kickstats)
autil.on_unloading(_NAME, save_kickstats_timer)

save_limitstats_timer = sm:addTimedJob(1800000, save_limitstats)
autil.on_unloading(_NAME, save_limitstats_timer)

save_commandstats_timer = sm:addTimedJob(1800000, save_commandstats)
autil.on_unloading(_NAME, save_commandstats_timer)

save_entitystats_timer = sm:addTimedJob(1800000, save_entitystats)
autil.on_unloading(_NAME, save_entitystats_timer)

save_bans_timer = sm:addTimedJob(1800000, banslua.save_bans)
autil.on_unloading(_NAME, save_bans_timer)

limitstats_clean_timer = sm:addTimedJob(30000, clear_expired_limitstats)
autil.on_unloading(_NAME, limitstats_clean_timer)

commandstats_clean_timer = sm:addTimedJob(30000, clear_expired_commandstats)
autil.on_unloading(_NAME, commandstats_clean_timer)

tmpbanstats_clean_timer = sm:addTimedJob(900000, clear_expired_tmpbanstats)
autil.on_unloading(_NAME, tmpbanstats_clean_timer)

kickstats_clean_timer = sm:addTimedJob(900000, clear_expired_kickstats)
autil.on_unloading(_NAME, kickstats_clean_timer)

entitystats_clean_timer = sm:addTimedJob(900000, clear_expired_entitystats)
autil.on_unloading(_NAME, entitystats_clean_timer)

autil.on_unloading(_NAME, function()
	base.pcall(onONL)
end)

autil.on_unloading(_NAME, function()
 	base.pcall(save_tmpbanstats)
end)

autil.on_unloading(_NAME, function()
	base.pcall(save_kickstats)
end)

autil.on_unloading(_NAME, function()
	base.pcall(save_limitstats)
end)

autil.on_unloading(_NAME, function()
	base.pcall(save_commandstats)
end)

autil.on_unloading(_NAME, function()
	base.pcall(save_entitystats)
end)

autil.on_unloading(_NAME, function()
	base.pcall(banslua.save_bans)
end)
