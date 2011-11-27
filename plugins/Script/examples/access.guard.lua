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
local aio = base.require('aio')
local io = base.require("io")
local os = base.require("os")
local string = base.require("string")
local table = base.require("table")
local math = base.require("math")

base.assert(math.ceil(adchpp.versionFloat * 100) >= 280, 'ADCH++ 2.8.0 or later is required to run access.guard.lua')
base.assert(base['access'], 'access.lua must be loaded and running before ' .. _NAME .. '.lua')
base.assert(base.access['bans'], 'access.bans.lua must be loaded and running before ' .. _NAME .. '.lua')

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
guardrev = "1.0.43"

-- Local declaration for the timers and on_unload functions
local clear_expired_commandstats_timer, save_commandstats_timer, save_commandstats
local clear_expired_limitstats_timer, save_limitstats_timer, save_limitstats
local clear_expired_entitystats_timer, save_entitystats_timer, save_entitystats
local clear_expired_tmpbanstats_timer, save_tmpbanstats_timer, save_tmpbanstats
local clear_expired_kickstats_timer, save_kickstats_timer, save_kickstats

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
commandstats.schmannatcmds = {}
commandstats.schmannatsegacmds = {}
commandstats.schtthcmds = {}
commandstats.schtthnatcmds = {}
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

local function verify_fldb_folder()
	local fldb_folder_exist = 1
	local file = io.open(tmpbanstats_file, "r")
	if not file then
		log('The folder '.. fldb_path .. ' was not found, creating it ...')
		fldb_folder_exist = os.execute("mkdir ".. fldb_folder)
	else
		file:close()
	end
	return fldb_folder_exist
end

local function load_tmpbanstats()
	tmpbanstats = {}
	tmpbanstats.ips = {}
	tmpbanstats.cids = {}

	local ok, list, err = aio.load_file(tmpbanstats_file, aio.json_loader)
	if err then
		log('Tmpbanstats loading: ' .. err)
	end
	if not ok then
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

	local ok, list, err = aio.load_file(kickstats_file, aio.json_loader)
	if err then
		log('Kickstats loading: ' .. err)
	end
	if not ok then
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
	if adchpp.versionString:match('Debug$') then
		base.print("Start loading Commandstats ...")
	end
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
	commandstats.schmannatcmds = {}
	commandstats.schmannatsegacmds = {}
	commandstats.schtthcmds = {}
	commandstats.schtthnatcmds = {}
	commandstats.rescmds = {}
	commandstats.ctmcmds = {}
	commandstats.rcmcmds = {}
	commandstats.natcmds = {}
	commandstats.rntcmds = {}
	commandstats.psrcmds = {}
	commandstats.getcmds = {}
	commandstats.sndcmds = {}

	local ok, list, err = aio.load_file(commandstats_file, aio.json_loader)
	if err then
		log('Commandstats loading: ' .. err)
	end
	if not ok then
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
	if adchpp.versionString:match('Debug$') then
		base.print("... Commandstats loaded.")
	end
end

local function load_limitstats()
	if adchpp.versionString:match('Debug$') then
		base.print("Start loading Limitstats ...")
	end
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

	local ok, list, err = aio.load_file(limitstats_file, aio.json_loader)
	if err then
		log('Limitstats loading: ' .. err)
	end
	if not ok then
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
	if adchpp.versionString:match('Debug$') then
		base.print("... Limitstats loaded.")
	end
end

local function load_entitystats()
	if adchpp.versionString:match('Debug$') then
		base.print("Start loading entitystats ...")
	end
	entitystats = {}
	entitystats.last_cids = {}
	entitystats.hist_cids = {}

	local ok, list, err = aio.load_file(entitystats_file, aio.json_loader)
	if err then
		log('Entitystats loading: ' .. err)
	end
	if not ok then
		return
	end

	entitystats = list
	if not entitystats.last_cids then
		entitystats.last_cids = {}
	end
	if not entitystats.hist_cids then
		entitystats.hist_cids = {}
	end
	if adchpp.versionString:match('Debug$') then
		base.print("... Entitystats loaded.")
	end
end

local function save_tmpbanstats()
	local err = aio.save_file(tmpbanstats_file, json.encode(tmpbanstats))
	if err then
		log('Tmpbanstats not saved: ' .. err)
	end
end

local function save_kickstats()
	local err = aio.save_file(kickstats_file, json.encode(kickstats))
	if err then
		log('kickstats not saved: ' .. err)
	end
end

local function save_limitstats()
	local err = aio.save_file(limitstats_file, json.encode(limitstats))
	if err then
		log('Limitstats not saved: ' .. err)
	end
end

local function save_commandstats()
	local err = aio.save_file(commandstats_file, json.encode(commandstats))
	if err then
		log('Commandstats not saved: ' .. err)
	end
end

local function save_entitystats()
	local err = aio.save_file(entitystats_file, json.encode(entitystats))
	if err then
		log('Entitystats not saved: ' .. err)
	end
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
			if not data.expires or data_expiration_diff(data) <= 0 then
				limitstats_array[k] = nil
			end
		end
	end
end

local function clear_expired_commandstats()
	for _, command_array in base.pairs(commandstats) do
		for k, data in base.pairs(command_array) do
			if not data.expires or data_expiration_diff(data) <= 0 then
				command_array[k] = nil
			end
		end
	end
end

local function clear_expired_tmpbanstats()
	for _, command_array in base.pairs(tmpbanstats) do
		for k, data in base.pairs(command_array) do
			if not data.expires or data_expiration_diff(data) <= 0 then
				command_array[k] = nil
			end
		end
	end
end

local function clear_expired_kickstats()
	for _, command_array in base.pairs(kickstats) do
		for k, data in base.pairs(command_array) do
			if not data.expires or data_expiration_diff(data) <= 0 then
				command_array[k] = nil
			end
		end
	end
end

local function clear_expired_entitystats()
	for _, command_array in base.pairs(entitystats) do
		for k, data in base.pairs(command_array) do
			if not data.expires or data_expiration_diff(data) <= 0 then
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

local function data_connection_string(con)
	local speed = adchpp.Util_formatBytes(con)
	if speed == "0 B" then
		speed = "0.00 B"
	end
	return speed
end

local function data_sharesize_string(size)
	local share = adchpp.Util_formatBytes(size)
	if share == "0 B" then
		share = "0.00 B"
	end
	return share
end

local function data_info_string_cid(info)
	local str = "\t"
	if info.count then
		str = str .. "Counter: " .. info.count
	end

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

	if info.started then
		str = str .. "\n\tStarted: " .. data_started_string(info)
	end

	if info.expires then
		str = str .. "\t\tExpires: " .. data_expiration_string(info) .. "\n"
	end

	return str
end

local function data_info_string_ip(info)
	local str = "\t"
	if info.count then
		str = str .. "\t\t\t\t\tCounter: " .. info.count
	end

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

	if info.started then
		str = str .. "\n\tStarted: " .. data_started_string(info)
	end

	if info.expires then
		str = str .. "\t\tExpires: " .. data_expiration_string(info) .. "\n"
	end

	return str
end

local function data_info_string_log(info)
	local str = "\t"
	if info.count then
		str = str .. "\t\tCounter: " .. info.count
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

	if info.ni then
		str = str .. "\t\t\tNick: " .. info.ni
	end

	if info.reason then
		str = str .. "\n\tReason: " .. info.reason .. "\n"
	end

	if info.ap then
		if info.ve then
			str = str .. "\tApplication: " .. info.ap .. " " .. info.ve .. "       \t"
		end
	else
		if info.ve then
			str = str .. "\tApplication: " .. info.ve .. "       \t"
		end
	end
	if info.expires then
		str = str .. "\tExpires: " .. data_expiration_string(info) .. "\n"
	end

	return str
end

local function data_info_string_entity(info)
	local str = "\n"
	if info.sid then
		str = str .. "\tEntity SID, Nick:\t\t\tSID: " .. info.sid
	end

	if info.ni then
		str = str .. "\t\t\tNick: " .. info.ni
	end

	if info.ip then
		str = str ..  "\n\tEntity IP's: \t\t\t\tCon. IP: " .. info.ip .. "   "
	end

	if info.i4 and info.i4 ~= info.ip then
		str = str .. "\t\tIPv4: " .. info.i4
	end

	if info.i6 and info.i6 ~= info.ip then
		str = str .. "\t\tIPv6: " .. info.i6
	end

	if info.us then
		str = str .. "\n\tConnection:\t\t\t\tUp: " .. data_connection_string(info.us) .. "/s   "
	end

	if info.ds then
		str = str .. "\t\tDown: " .. data_connection_string(info.ds) .. "/s"
	end

	if info.ss then
		str = str .. "\n\tEntity Share:\t\t\t\tSize: " .. data_sharesize_string(info.ss) .. "   "
	end

	if info.sf then
		str = str .. "\t\tFiles: " .. info.sf
	end

	if info.sl then
		str = str .. "\n\tEntity Slots:\t\t\t\tMax: " .. info.sl .. "  "
	end

	if info.fs then
		str = str .. "\t\t\tFree: " .. info.fs
	end

	if info.hn or info.hr or info.ho then
		str = str .. "\n\tEntity Hubs:\t\t"
		if info.hn then
			str = str .. "\t\tHN: " .. info.hn
		end
		if info.hr then
			str = str .. "\t\tHN: " .. info.hr
		end
		if info.ho then
			str = str .. "\t\tHN: " .. info.ho
		end
	end

	if info.ap then
		if info.ve then
			str = str .. "\n\tApplication:\t\t\t\t" .. info.ap .. " " .. info.ve .. "   "
		end
	else
		if info.ve then
			str = str .. "\n\tApplication:\t\t\t\t" .. info.ve .. "   "
		end
	end

	if info.su then
		str = str .. "\n\tSupports:\t\t\t\t" .. info.su
	end

	if users.cids[info.cid] then
		local user = users.cids[info.cid]
		if user.level then
			str = str .. "\n\tEntity Regged:\t\t\t\tLevel: " .. user.level .. "  "
		end
		if user.regby then
			str = str .. "\t\t\tBy: " .. user.regby .. "  "
		end
	end

	if info.changes then
		str = str .. "\n\tChanged Nick, IP, AP or Level:\t\t" .. info.changes .. " times"
	end

	if info.logins then
		str = str .. "\n\tEntity Logins:\t\t\t\t" .. info.logins .. " times"
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
		str = str .. "\n\tLast Updated Nick, IP, AP or Level:\t" .. data_updated_string(info)
	end

	if info.started then
		str = str .. "\n\tEntity Created:\t\t\t\t" .. data_started_string(info)
	end

	if info.expires then
		str = str .. "\n\tEntity Expires:\t\t\t\t" .. data_expiration_string(info) .. "\n"
	end

	return str
end

local function data_info_string_entity_hist(info)
	local str = "\t"
	if info.cid then
		str = str .. "CID: " .. info.cid
	end

	if info.ip then
		str = str .. "\n\tCon. IP: " .. info.ip .. "  "
	end

	if info.i4 and info.i4 ~= info.ip then
		str = str .. "\tIPv4: " .. info.i4 .. "\t      "
	end

	if info.i6 and info.i6 ~= info.ip then
		str = str .. "\tIPv6: " .. info.i6 .. "     "
	end

	if not (info.i4 and info.i4 ~= info.ip) and not (info.i6 and info.i6 ~= info.ip) then
		str = str .. "\t\t\t\t"
	end

	if info.ni then
		str = str .. "\tNI: " .. info.ni
	end

	if info.level then
		str = str .. "\n\tLevel: " .. info.level .. "  "
	end

	if info.regby then
			str = str .. "\t\t\t\t\t\tBy: " .. info.regby
	end

	if info.logins then
		str = str .. "\n\tLogins: " .. info.logins .. "  "
	end

	if info.changes then
		str = str .. "\t\tTimes Changed: " .. info.changes .. "  "
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
	local countip = 0
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
	save_bans()
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
			local str = "For ( "..count.." times ) beeing kicked !!! Last kick: " .. msg
			dump_banned(c, cmd, update, str, minutes)
			kickstats.cids[cid] = nil
			update = nil
			return update
		end
		if kickstats.ips[ip].count >= fl_settings.fl_maxkicks.value then
			local count = kickstats.ips[ip].count
			local str = "For ( "..count.." times ) beeing kicked !!! Last kick: " .. msg
			dump_banned(c, cmd, update, str, minutes)
			kickstats.ips[ip] = nil
			update = nil
			return update
		end	
	end
	return update
end

local function dump_kicked(c, cmd, update, msg)
	local str = "You are kicked: " .. msg
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
	local str
	if msg then
		str = "You are disconnected because: " .. msg
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
			local msg = "For spamming the hub too often (" ..update.count.. " times)  with " .. stat .. " !!!!"
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
			if fl_settings.fl_maxwarnmsg.value > update.warns or fl_settings.fl_maxwarnmsg.value == -1 then
				msg = "You are hammering the hub  (" .. rate .. " times / min) with the " .. stat .. " , cool down ..."
				if fl_settings.fl_maxwarns.value > 0 then
					msg = msg .. " , or you will be kicked !!!!"
				end
			end
			if fl_settings.fl_maxwarns.value > 0 and update.warns >= fl_settings.fl_maxwarns.value then
				msg = "For hammering the hub to often (" .. update.warns .. " times)  with the " .. stat .. " !"
				update = dump_kicked(c, cmd, update, msg)
				return update
			end
			update.warns = update.warns + 1
			update.warning = 1
			if msg then
				autil.reply(c, msg)
			end
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
	local strparam = { "ni", "ap", "ve", "i4", "i6", "su" } -- string parameters we want created
	local intparam = { "ss", "sf", "sl", "fs", "us", "ds", "hn", "hr", "ho" } -- integer parameters we want created

	local data = { ip = c:getIp() }
	data.sid = adchpp.AdcCommand_fromSID(c:getSID())

	for _, param in base.ipairs(strparam) do
		if c:getField(string.upper(param)) then
			if #base.tostring(c:getField(string.upper(param))) > 0 then
				data[param] = base.tostring(c:getField(string.upper(param)))
			end
		end
	end

	for _, param in base.ipairs(intparam) do
		if c:getField(string.upper(param)) then
			if base.tonumber(c:getField(string.upper(param))) then
				data[param] = base.tonumber(c:getField(string.upper(param)))
			end
		end
	end

	if users.cids[c:getCID():toBase32()] then
		local user = users.cids[c:getCID():toBase32()]
		if user.level then
			data.level = user.level
		end
		if user.regby then
			data.regby = user.regby
		end
	end
	data.logins = 1
	data.join = os.time()
	data.leave = os.time()
	data.timeon = 0
	data.ltimeon = 0
	data.started = os.time()
	data.expires = os.time() + days * 86400

	return data
end

local function make_entity_hist(c, data, days)
	local strparam = { "ip", "ni", "ap", "ve", "i4", "i6", "level", "regby", "logins", "join", "leave", "timeon", "ltimeon", "started" } -- string parameters we want in hist

	local hist = { cid = c:getCID():toBase32() }

	for _, param in base.ipairs(strparam) do
		if data[param] then
			if #base.tostring(data[param]) > 0 or base.tonumber(data[param]) then
				hist[param] = data[param]
			end
		end
	end

	if data.changes then
		hist.changes = data.changes
	else
		hist.changes = 0
	end
	hist.updated = os.time()
	hist.expires = os.time() + days * 86400

	return hist
end

local function connect_entity(c, data, days)
	local strparam = { "ni", "ap", "ve", "i4", "i6", "su" } -- string parameters we want updated
	local intparam = { "ss", "sf", "sl", "fs", "us", "ds", "hn", "hr", "ho" } -- integer parameters we want updated
	local tabparam = { "started", "changes", "updated" } --  table parameters we want updated

	local update = { ip = c:getIp() }
	update.sid = adchpp.AdcCommand_fromSID(c:getSID())

	for _, param in base.ipairs(strparam) do
		if c:getField(string.upper(param)) then
			if #base.tostring(c:getField(string.upper(param))) > 0 then
				update[param] = base.tostring(c:getField(string.upper(param)))
			end
		end
	end

	for _, param in base.ipairs(intparam) do
		if c:getField(string.upper(param)) then
			if base.tonumber(c:getField(string.upper(param))) then
				update[param] = base.tonumber(c:getField(string.upper(param)))
			end
		end
	end

	for _, param in base.ipairs(tabparam) do
		if data[param] then
			if #base.tostring(data[param]) > 0 or base.tonumber(data[param]) then
				update[param] = data[param]
			end
		end
	end

	if users.cids[c:getCID():toBase32()] then
		local user = users.cids[c:getCID():toBase32()]
		if user.level then
			update.level = user.level
		end
		if user.regby then
			update.regby = user.regby
		end
	end
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
	update.expires = os.time() + days * 86400

	if update.ip ~= data.ip or update.i4 ~= data.i4 or update.i6 ~= data.i6 or update.ni ~= data.ni or update.level ~= data.level or update.regby ~= data.regby or (ap and data.ap and update.ap ~= data.ap) or (ve and data.ve and update.ve ~= data.ve) then
		if data.changes then
			update.changes = data.changes + 1
		else
			update.changes = 1
		end
		update.updated = os.time()	
		local hist = make_entity_hist(c, data, days)
		table.insert(entitystats.hist_cids, hist) -- inserts { hist } at the end of table hist_cids
	end

	return update
end

local function update_entity(c, data, days ,cmd)
	local strparam = { "ni", "ap", "ve", "i4", "i6", "su" } -- string parameters we want updated
	local intparam = { "ss", "sf", "sl", "fs", "us", "ds", "hn", "hr", "ho" } -- integer parameters we want updated

	if cmd:hasParam("NI", 0) or cmd:hasParam("AP", 0) or cmd:hasParam("VE", 0) or cmd:hasParam("I4", 0) or cmd:hasParam("I6", 0) then
		local hist = make_entity_hist(c, data, days)
		table.insert(entitystats.hist_cids, hist) -- inserts { hist } at the end of table hist_cids
		if data.changes then
			data.changes = data.changes + 1
		else
			data.changes = 1
		end
		data.updated = os.time()
	end

	for _, param in base.ipairs(strparam) do
		if cmd:hasParam(string.upper(param), 0) then
			if #base.tostring(cmd:getParam(string.upper(param), 0)) > 0 then
				data[param] = base.tostring(cmd:getParam(string.upper(param), 0))
			else
				data[param] = nil
			end
		end
	end

	for _, param in base.ipairs(intparam) do
		if cmd:hasParam(string.upper(param), 0) then
			if base.tonumber(cmd:getParam(string.upper(param), 0)) then
				data[param] = base.tonumber(cmd:getParam(string.upper(param), 0))
			else
				data[param] = nil
			end
		end
	end

	data.expires = os.time() + days * 86400

	return data
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
	local ok, list, err = aio.load_file(fl_settings_file, aio.json_loader)

	if err then
		log('Flood settings loading: ' .. err)
	end
	if not ok then
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
	local ok, list, err = aio.load_file(li_settings_file, aio.json_loader)

	if err then
		log('Limit settings loading: ' .. err)
	end
	if not ok then
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
	local ok, list, err = aio.load_file(en_settings_file, aio.json_loader)

	if err then
		log('Entity settings loading: ' .. err)
	end
	if not ok then
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
	local list = {}
	for k, v in base.pairs(fl_settings) do
		list[k] = v.value
	end
	local err = aio.save_file(fl_settings_file, json.encode(list))
	if err then
		log('Flood settings not saved: ' .. err)
	end
end

local function save_li_settings()
	local list = {}
	for k, v in base.pairs(li_settings) do
		list[k] = v.value
	end
	local err = aio.save_file(li_settings_file, json.encode(list))
	if err then
		log('Limit settings not saved: ' .. err)
	end
end

local function save_en_settings()
	local list = {}
	for k, v in base.pairs(en_settings) do
		list[k] = v.value
	end
	local err = aio.save_file(en_settings_file, json.encode(list))
	if err then
		log('Entity settings not saved: ' .. err)
	end
end

local function onSOC(c) -- Stats verification for creating open sockets

	if fl_settings.fl_commandstats.value >= 0 then
		local ip = c:getIp()
		if (fl_settings.cmdsoc_rate.value > 0 or fl_settings.fl_maxrate.value > 0) then
			local stat = "Open socket command"
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
					end
				end
			else
				commandstats.soccmds[ip] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onCON(c) -- Stats and limit verification for connects and building entitys tables

	if li_settings.li_limitstats.value >= 0 and get_level(c) <= fl_settings.fl_level.value then
		local countip = get_sameip(c)
		if countip and li_settings.maxsameip.value > 0 and countip > li_settings.maxsameip.value then
			local stat = "max same IP"
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
	end

	if en_settings.en_entitystats.value >= 0 then
		local cid = c:getCID():toBase32()
		local days, match
		if get_level(c) > 0 then
			days = en_settings.en_entitystatsregexptime.value
		else
			days = en_settings.en_entitystatsexptime.value
		end
		if days > 0 then
			for ent, data in base.pairs(entitystats.last_cids) do
				if ent == cid then
					match = true
					entitystats.last_cids[cid] = connect_entity(c, data, days)
				end
			end
			if not match then
				entitystats.last_cids[cid] = make_entity(c, days)
			end
		end
	end

	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid = c:getCID():toBase32()
		if fl_settings.cmdcon_rate.value > 0 or fl_settings.fl_maxrate.value > 0 then
			local stat = "Connect command"
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
					end
				end
			else
				commandstats.concmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onONL() -- Stats verification for online users and updating entity,s tables

	if en_settings.en_entitystats.value >= 0  then
		local entities = adchpp.getCM():getEntities()
		local size = entities:size()
		if size > 0 then
			for i = 0, size - 1 do
				local c = entities[i]:asClient()
				if c and c:getState() == adchpp.Entity_STATE_NORMAL then
					local days, match
					local cid = c:getCID():toBase32()
					if get_level(c) > 0 then
						days = en_settings.en_entitystatsregexptime.value
					else
						days = en_settings.en_entitystatsexptime.value
					end
					if days > 0 then
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
	end
	return true
end

local function onDIS(c) -- Stats verification for disconnects and updating entitys tables

	if en_settings.en_entitystats.value >= 0 then
		local days
		local cid = c:getCID():toBase32()
		if get_level(c) > 0 then
			days = en_settings.en_entitystatsregexptime.value
		else
			days = en_settings.en_entitystatsexptime.value
		end
		if days > 0 then
			for ent, data in base.pairs(entitystats.last_cids) do
				if ent == cid then
					entitystats.last_cids[cid] = logoff_entity(c, data, days)
					return true
				end
			end
			entitystats.last_cids[cid] = make_entity(c, days)
		end
	end
	return true
end

local function onURX(c, cmd) -- Stats and flood verification for unknown command strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid = c:getCID():toBase32()
		if (fl_settings.fl_maxrate.value > 0 or fl_settings.cmdurx_rate.value > 0) then
			local stat = "Unknown command"
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
	end
	return true
end

local function onCRX(c, cmd) -- Stats and rules verification for bad context command strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid = c:getCID():toBase32()
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdcrx_rate.value > 0 then
			local stat = "Command with invalid context"
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
					end
				end
			else
				commandstats.crxcmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
		return false
	end
	return false
end

local function onCMD(c, cmd) -- Stats and rules verification for command strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid = c:getCID():toBase32()
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdcmd_rate.value > 0 then
			local stat = "a user Command"
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
					end
				end
			else
				commandstats.cmdcmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onSUP(c, cmd) -- Stats and rules verification for support strings

	if li_settings.li_limitstats.value >= 0 then
		local blom = c:hasSupport(adchpp.AdcCommand_toFourCC("BLO0")) or c:hasSupport(adchpp.AdcCommand_toFourCC("BLOM")) or c:hasSupport(adchpp.AdcCommand_toFourCC("PING")) -- excluding hublistpingers from this rule
		if li_settings.sublom.value > 0 and li_settings.li_minlevel.value <= get_level(c) and not blom then
			local ip = c:getIp()
			local stat = "Support BLOM filter forced"
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
	end

	if fl_settings.fl_commandstats.value >= 0 then
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdsup_rate.value > 0 then
			local ip = c:getIp()
			local stat = "SUP command"
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
					end
				end
			else
				commandstats.supcmds[ip] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onSID(c, cmd) -- Stats and rules verification for sid strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid = c:getCID():toBase32()
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdsid_rate.value > 0 then
			local stat = "SID command"
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
					end
				end
			else
				commandstats.sidcmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onPAS(c, cmd) -- Stats and rules verification for password strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then 
		local cid = c:getCID():toBase32()
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdpas_rate.value > 0 then
			local stat = "PAS command"
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
					end
				end
			else
				commandstats.pascmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onSTA(c, cmd) -- Stats and rules verification for status strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid = c:getCID():toBase32()
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdsta_rate.value > 0 then
			local stat = "STA command"
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
					end
				end
			else
				commandstats.stacmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onSCH(c, cmd) -- Stats and rules verification for search strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end
	
	local NATT, SEGA, TTH, chars
	if li_settings.li_limitstats.value >= 0 then
		local cid = c:getCID():toBase32()
		local params = cmd:getParameters()
		local params_size = params:size()
		if #cmd:getParam("TR", 0) > 0 then
			TTH = true
		end
		if not TTH then -- only getting search size for manual searches
			local vars = {}
			if params_size > 0 then
				for i = 0, params_size - 1 do
					local param = params[i]
					if #param > 2 then
						local field = string.sub(param, 1, 2)
						if field == 'AN' then
							local var = string.sub(param, 3)
							table.insert(vars, string.lower(var))
						end
					end
				end
			end
			chars = #table.concat(vars, ' ')
		end
		if li_settings.maxschparam.value > 0 and params_size >= li_settings.maxschparam.value then
			local stat = "Max Search parameters limit"
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
		if chars and li_settings.maxschlength.value > 0 and chars > li_settings.maxschlength.value then
			local stat = "Max Search length limit"
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
					end
				end
			else
				limitstats.maxschlengths[cid] = make_data(c, cmd, msg, type, minutes)
			end
			return false
		end
		if chars and li_settings.minschlength.value > 0 and chars < li_settings.minschlength.value then
			local stat = "Min Search length limit"
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
					end
				end
			else
				limitstats.minschlengths[cid] = make_data(c, cmd, msg, type, minutes)
			end
			return false
		end
	end

	if fl_settings.fl_commandstats.value < 0 then
		return true
	end

	local cid = c:getCID():toBase32()
	local feature = base.tostring(cmd:getFeatures())
	if #feature > 0 then
		NATT = feature:match("+NAT0") or feature:match("+NATT")
		SEGA = feature:match("+SEG0") or feature:match("+SEGA")
	end
	if TTH and not NATT and (fl_settings.fl_maxrate.value > 0 or fl_settings.cmdschtth_rate.value > 0) then
		local stat = "TTH Search command"
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
				end
			end
		else
			commandstats.schtthcmds[cid] = make_data(c, cmd, msg, type, minutes)
		end
		return true
	end
	if TTH and (fl_settings.fl_maxrate.value > 0 or fl_settings.cmdschtth_rate.value > 0) then
		local stat = "NAT TTH Search command"
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
				end
			end
		else
			commandstats.schtthnatcmds[cid] = make_data(c, cmd, msg, type, minutes)
		end
		return true
	end
	if not NATT and (fl_settings.fl_maxrate.value > 0 or fl_settings.cmdschman_rate.value > 0) then
		local stat = "manual Search command"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdschman_rate.value
		local minutes = fl_settings.cmdschman_exp.value
		if not SEGA then
			if commandstats.schmancmds[cid] then
				for victim_cid, data in base.pairs(commandstats.schmancmds) do
					if cid == victim_cid then
						commandstats.schmancmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
						if commandstats.schmancmds[cid] and commandstats.schmancmds[cid].warning > 0 then
							return false
						end
					end
				end
			else
				commandstats.schmancmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		else
			if commandstats.schmansegacmds[cid] then
				for victim_cid, data in base.pairs(commandstats.schmansegacmds) do
					if cid == victim_cid then
						commandstats.schmansegacmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
						if commandstats.schmansegacmds[cid] and commandstats.schmansegacmds[cid].warning > 0 then
							return false
						end
					end
				end
			else
				commandstats.schmansegacmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
		return true
	end
	if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdschman_rate.value > 0 then
		local stat = "NAT manual Search command"
		local type = "cmd"
		local factor = 1
		local maxcount = -1
		local maxrate = fl_settings.cmdschman_rate.value
		local minutes = fl_settings.cmdschman_exp.value
		if not SEGA then
			if commandstats.schmannatcmds[cid] then
				for victim_cid, data in base.pairs(commandstats.schmannatcmds) do
					if cid == victim_cid then
						commandstats.schmannatcmds[cid] = update_data(c, cmd, data, maxcount, maxrate, factor, msg, type, stat, minutes)
						if commandstats.schmannatcmds[cid] and commandstats.schmannatcmds[cid].warning > 0 then
							return false
						end
					end
				end
			else
				commandstats.schmannatcmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
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
			else
				commandstats.schmannatsegacmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onMSG(c, cmd) -- Stats and rules verification for messages strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if li_settings.li_limitstats.value >= 0 then
		if li_settings.maxmsglength.value > 0 and #cmd:getParam(0) >= li_settings.maxmsglength.value then
			local cid = c:getCID():toBase32()
			local stat = "Max Message length limit"
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
					end
				end
			else
				limitstats.maxmsglengths[cid] = make_data(c, cmd, msg, type, minutes)
			end
			return false
		end
	end

	if fl_settings.fl_commandstats.value >= 0 then
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdmsg_rate.value > 0 then
			local cid = c:getCID():toBase32()
			local stat = "MSG command"
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
					end
				end
			else
				commandstats.msgcmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onINF(c, cmd) -- Stats and rules verification for info strings

	if en_settings.en_entitystats.value >= 0 then
		if c:getState() == adchpp.Entity_STATE_NORMAL then
			local days, match, hist
			cid = c:getCID():toBase32()
			if get_level(c) > 0 then
				days = en_settings.en_entitystatsregexptime.value
			else
				days = en_settings.en_entitystatsexptime.value
			end
			if days > 0 then
				for ent, data in base.pairs(entitystats.last_cids) do
					if ent == cid then
						match = true
						entitystats.last_cids[cid] = update_entity(c, data, days, cmd, hist)
					end
				end
				if not match then
					entitystats.last_cids[cid] = make_entity(c, days)
				end
			end
		end
	end

	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid, ni
		if c:getState() == adchpp.Entity_STATE_NORMAL then 
			cid = c:getCID():toBase32()
			ni = c:getField("NI")
		else
			cid = cmd:getParam("ID", 0)
			ni = cmd:getParam("NI", 0)
		end
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdinf_rate.value > 0 and c:getState() == adchpp.Entity_STATE_NORMAL then
			local stat = "INF command"
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
					end
				end
			else
				commandstats.infcmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end

	-- TODO exclude pingers from certain verifications excluded DCHublistspinger for now
	if c:hasSupport(adchpp.AdcCommand_toFourCC("PING")) and c:getIp() == "208.115.230.197" then
		return true
	end

	if li_settings.li_limitstats.value < 0 then
		return true
	end

	local cid, ni
	if c:getState() == adchpp.Entity_STATE_NORMAL then 
		cid = c:getCID():toBase32()
		ni = c:getField("NI")
	else
		cid = cmd:getParam("ID", 0)
		ni = cmd:getParam("NI", 0)
	end

	local su
	if cmd:hasParam("SU", 0) then
		su = base.tostring(cmd:getParam("SU", 0))
	else
		su = base.tostring(c:getField("SU"))
	end
	local adcs = string.find(su, 'ADC0') or string.find(su, 'ADCS')
	if li_settings.suadcs.value > 0 and li_settings.li_minlevel.value <= get_level(c) and not adcs then
		local stat = "Support ADCS forced"
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
		local stat = "Support NAT-T forced"
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
		local stat = "Min Share size limit"
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
		local stat = "Max Share size limit"
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
		local stat = "Min Shared files limit"
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
		local stat = "Max Shared files limit"
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
		local stat = "Min Slots limit"
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
		local stat = "Max Slots limit"
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
		local stat = "Min Hub/Slot ratio limit"
		local str = "Your Hubs/Slots ratio ( " .. base.tostring(r) .. " ) is too low, you must open up more upload slots or disconnect from some hubs to achieve a ratio of " .. base.tostring(li_settings.minhubslotratio.value)
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
		local stat = "Max Hub/Slot ratio limit"
		local str = "Your Hubs/Slots ratio ( " .. base.tostring(r) .. " ) is too high, you must reduce your open upload slots or connect to more hubs to achieve a ratio of " .. base.tostring(li_settings.maxhubslotratio.value)
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
		local stat = "Max Hubcount limit"
		local str = "The number of Hubs you're connected to ( " .. base.tostring(h) .. " ) is too high, the maximum allowed is " .. base.tostring(li_settings.maxhubcount.value)
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
		local stat = "Min Nick length limit"
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
		local stat = "Max Nick length limit"
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
	return true
end

local function onRES(c, cmd) -- Stats and rules verification for search results strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid = c:getCID():toBase32()
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdres_rate.value > 0 then
			local stat = "Search Results command"
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
					end
				end
			else
				commandstats.rescmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onCTM(c, cmd) -- Stats and rules verification for connect to me strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid = c:getCID():toBase32()
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdctm_rate.value > 0 then
			local stat = "CTM command"
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
					end
				end
			else
				commandstats.ctmcmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onRCM(c, cmd) -- Stats and rules verification for reverse connect to me strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid = c:getCID():toBase32()
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdrcm_rate.value > 0 then
			local stat = "RCM command"
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
					end
				end
			else
				commandstats.rcmcmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onNAT(c, cmd) -- Stats and rules verification for nat traversal connect to me strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid = c:getCID():toBase32()
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdnat_rate.value > 0 then
			local stat = "NAT command"
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
					end
				end
			else
				commandstats.natcmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onRNT(c, cmd) -- Stats and rules verification for nat traversal rev connect to me strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid = c:getCID():toBase32()
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdrnt_rate.value > 0 then
			local stat = "RNT command"
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
					end
				end
			else
				commandstats.rntcmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onPSR(c, cmd) -- Stats and rules verification for partitial filesharing strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid = c:getCID():toBase32()
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdpsr_rate.value > 0 then
			local stat = "PSR command"
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
					end
				end
			else
				commandstats.psrcmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onGET(c, cmd) -- Stats and rules verification for get strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid = c:getCID():toBase32()
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdget_rate.value > 0 then
			local stat = "GET command"
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
					end
				end
			else
				commandstats.getcmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
	end
	return true
end

local function onSND(c, cmd) -- Stats and rules verification for send strings
	if get_level(c) > fl_settings.fl_level.value then
		return true
	end

	if fl_settings.fl_commandstats.value >= 0 then
		local cid = c:getCID():toBase32()
		if fl_settings.fl_maxrate.value > 0 or fl_settings.cmdsnd_rate.value > 0 then
			local stat = "SND command"
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
			else
				commandstats.sndcmds[cid] = make_data(c, cmd, msg, type, minutes)
			end
		end
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

local function logging_change(value, clear_t, clear_s, save_t, save_s, load_f, clear_f, save_f)
	if value >= 0 then
		if not clear_t then
			clear_t = sm:addTimedJob(clear_s, clear_f)
		end
		if value == 0 then
			if save_t then
				save_t = save_t() -- unloads timer and gives the function a nil value
			end
		end
		if value > 0 then
			base.pcall(load_f)
			if not save_t then
				save_t = sm:addTimedJob(save_s, save_f)
			end
		end
	else
		if clear_t then
			clear_t = clear_t()
		end
		if save_t then
			save_t = save_t()
		end
	end
	return clear_t, save_t
end

-- Default flood settings for all limits and adc commands

fl_settings.fl_commandstats = {
	alias = { commandstats = true, commandlog = true },

	change = function()
		clear_expired_commandstats_timer, save_commandstats_timer = logging_change(fl_settings.fl_commandstats.value, clear_expired_commandstats_timer, 30000, save_commandstats_timer, 1800000, load_commandstats, clear_expired_commandstats, save_commandstats)
	end,

	announce = true,

	help = "enforces the enabled flood rules and if selected saves a log, -1 = disabled, 0 = enabled, 1 = write to file",

	value = -1
}

fl_settings.fl_maxkicks = {
	alias = { maximumkicks = true, maxkicks = true },

	help = "maximum count of kicks before user is tmp bannend, 0 = disabled !!!!",

	value = 3
}

fl_settings.fl_maxwarns = {
	alias = { maximumwarns = true, maxwarns = true },

	help = "maximum count of flood attempts before user is kicked, 0 = disabled !!!!",

	value = 20
}

fl_settings.fl_maxwarnmsg = {
	alias = { maxwarnsmsg = true, maximumwarnsmsg = true },

	help = "maximum warning messages send to the user, after that the flood attempt just get blocked , -1 = all msg's are send, 0 = no msg's are send !!!!",

	value = 5
}

fl_settings.fl_maxtmpbans = {
	alias = { maximumtmpbans = true, maxtmpbans = true },

	help = "maximum count of tmpbans before user is banned for ever, 0 = disabled !!!!",

	value = 0
}

fl_settings.fl_tmpban =  {
	alias = { floodtmpban = true },

	help = "minutes a user will be temp banned after reaching the maxkicks value,  0 = disabled !!!!",

	value = 30
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

	value = 1
}

fl_settings.cmdsid_rate = {
	alias = { sid_rate = true },

	help = "max rate in counts/min that a client can send sid strings, 0 = default, -1 = disabled",

	value = 0
}

fl_settings.cmdcon_rate = {
	alias = { con_rate = true },

	help = "maximum rate in counts/min that a user can reconnect, 0 = default, -1 = disabled",

	value = 1
}

fl_settings.cmdsoc_rate = {
	alias = { soc_rate = true },

	help = "maximum rate in counts/min that the same ip can open a new socket, 0 = default, -1 = disabled",

	value = 2
}

fl_settings.cmdurx_rate = {
	alias = { urx_rate = true },

	help = "max rate in counts/min that a client can send unknown adc commands, 0 = default, -1 = disabled",

	value = 5
}

fl_settings.cmdcrx_rate = {
	alias = { crx_rate = true },

	help = "max rate in counts/min that a client can send adc commands with a bad context, 0 = default, -1 = disabled",

	value = 5
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

	value = 6
}

fl_settings.cmdres_rate = {
	alias = { res_rate = true },

	help = "max rate in counts/min that a client can send search results, 0 = default, -1 = disabled",

	value = -1
}

fl_settings.cmdctm_rate = {
	alias = { ctm_rate = true },

	help = "max rate in counts/min that a client can send connect request's, 0 = default, -1 = disabled",

	value = 60
}

fl_settings.cmdrcm_rate = {
	alias = { rcm_rate = true },

	help = "max rate in counts/min that a client can send reverse connect's, 0 = default, -1 = disabled",

	value = 6
}

fl_settings.cmdnat_rate = {
	alias = { nat_rate = true },

	help = "max rate in counts/min that a client can send nat connect request's, 0 = default, -1 = disabled",

	value = 60
}

fl_settings.cmdrnt_rate = {
	alias = { rnt_rate = true },

	help = "max rate in counts/min that a client can send reverse nat connect's, 0 = default, -1 = disabled",

	value = 6
}

fl_settings.cmdpsr_rate = {
	alias = { psr_rate = true },

	help = "max rate in counts/min that a client can send partitial file sharing string's, 0 = default, -1 = disabled",

	value = 0
}

fl_settings.cmdget_rate = {
	alias = { get_rate = true },

	help = "max rate in counts/min that a client can send the get transfer command, 0 = default, -1 = disabled",

	value = 0
}

fl_settings.cmdsnd_rate = {
	alias = { snd_rate = true },

	help = "max rate in counts/min that a client can send the send transfer command, 0 = default, -1 = disabled",

	value = 5
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
	alias = { sup_exp = true },

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
	alias = { urx_exp = true },

	help = "minutes before the unknown adc commandstats are removed, 0 = default",

	value = 360
}

fl_settings.cmdcrx_exp = {
	alias = { crx_exp = true },

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

li_settings.li_limitstats = {
	alias = { limitstats = true, limitlog = true },

	change = function()
		clear_expired_limitstats_timer, save_limitstats_timer = logging_change(li_settings.li_limitstats.value, clear_expired_limitstats_timer, 30000, save_limitstats_timer, 1800000, load_limitstats, clear_expired_limitstats, save_limitstats)
		recheck_info()
	end,

	announce = true,

	help = "enforces the enabled limit rules and if selected saves a log, -1 = disabled, 0 = enabled, 1 = write to file",

	value = -1
}

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

	announce = true,

	value = 0
}

li_settings.maxsharefiles = {
	alias = { maximumsharefiles = true },

	change = recheck_info,

	help = "maximum number of shared files, 0 = disabled",

	announce = true,

	value = 0
}

li_settings.minsharesize = {
	alias = { minimumsharesize = true },

	change = recheck_info,

	help = "minimum share size allowed in bytes, 0 = disabled",

	announce = true,

	value = 0
}

li_settings.maxsharesize = {
	alias = { maximumsharesize = true },

	change = recheck_info,

	help = "maximum share size allowed in bytes, 0 = disabled",

	announce = true,

	value = 0
}

li_settings.minslots = {
	alias = { minimumslots = true },

	change = recheck_info,

	help = "minimum number of opened upload slots allowed, 0 = disabled",

	announce = true,

	value = 0
}

li_settings.maxslots = {
	alias = { maximumslots = true },

	change = recheck_info,

	help = "maximum number of opened upload slots allowed, 0 = disabled",

	announce = true,

	value = 0
}

li_settings.minhubslotratio = {
	alias = { minimumhubslotratio = true },

	change = recheck_info,

	help = "minimum hub/slot ratio allowed, 0 = disabled",

	announce = true,

	value = 0
}

li_settings.maxhubslotratio = {
	alias = { maximumhubslotratio = true },

	change = recheck_info,

	help = "maximum hub/slot ratio allowed, 0 = disabled",

	announce = true,

	value = 0
}

li_settings.maxhubcount = {
	alias = { maximumhubcount = true },

	change = recheck_info,

	help = "maximum number of connected hubs allowed, 0 = disabled",

	announce = true,

	value = 0
}

li_settings.maxmsglength = {
	alias = { maxmessagelength = true },

	help = "maximum number of characters allowed per chat message, 0 = no limit",

	announce = true,

	value = 0
}

li_settings.maxschparam = {
	alias = { maxsearchparam = true },

	help = "maximum number of search parameters allowed, 0 = disabled",

	announce = true,

	value = 100
}

li_settings.minschlength = {
	alias = { minsearchlength = true },

	help = "minimum length of search string allowed, 0 = disabled",

	announce = true,

	value = 0
}

li_settings.maxschlength = {
	alias = { maxsearchlength = true },

	help = "maximum length of search string allowed, 0 = disabled",

	announce = true,

	value = 0
}

li_settings.minnicklength = {
	alias = { minnilenght = true },

	change = recheck_info,

	help = "minimum number of characters allowed for the nick, 0 = no limit",

	announce = true,

	value = 0
}

li_settings.maxnicklength = {
	alias = { maxnilenght = true },

	change = recheck_info,

	help = "maximum number of characters allowed for the nick, 0 = no limit",

	announce = true,

	value = 0
}

li_settings.suadcs = {
	alias = { supportacds = true },

	change = recheck_info,

	help = "disallow users that have disabled ADCS (TLS) support for file transfers, 0 = disabled",

	announce = true,

	value = 0
}

li_settings.sunatt = {
	alias = { supportnatt = true },

	change = recheck_info,

	help = "disallow passive users that have disabled NAT-T (passive-passive) support for file transfers, 0 = disabled",

	announce = true,

	value = 0
}

li_settings.sublom = {
	alias = { supportblom = true },

	change = recheck_info,

	help = "disallow clients that don't have BLOM (TTH search filtering) support, 0 = disabled",

	announce = true,

	value = 0
}

li_settings.maxsameip = {
	alias = { maxsameips = true },

	help = "maximum number of connected users with the same ip address, 0 = disabled",

	announce = true,

	value = 0
}

-- All the Entity settings

en_settings.en_entitystats = {
	alias = { entitystats = true, entitylog = true },

	change = function()
		clear_expired_entitystats_timer, save_entitystats_timer = logging_change(en_settings.en_entitystats.value, clear_expired_entitystats_timer, 900000, save_entitystats_timer, 1800000, load_entitystats, clear_expired_entitystats, save_entitystats)
		if en_settings.en_entitystats.value and en_settings.en_entitystats.value >= 0 then
			onONL()
		end
	end,

	announce = true,

	help = "logs users cid , ip's , nicks etc into a database and keeps history of changes , -1 = disabled, 0 = enabled, 1 = write to file",

	value = -1
}

en_settings.en_entitystatsexptime = {
	alias = { entitystatexpiretime = true, entityexpiretime = true},

	help = "expiretime in days for a non registered user entity logs, 0 = disabled",

	value = 7
}

en_settings.en_entitystatsregexptime = {
	alias = { entitystatregexpiretime = true, entityregexpiretime = true},

	help = "expiretime in days for a registered user entity logs, 0 = disabled",

	value = 60
}

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
		save_fl_settings()

		local message = c:getField('NI') .. ' has changed "' .. name .. '" from "' .. base.tostring(old) .. '" to "' .. base.tostring(setting.value) .. '"'
		log(message)
		if setting.announce and access.settings.announcecfg.value ~= 0 then
			cm:sendToAll(autil.info(message):getBuffer())
		else
			autil.reply(c, "Variable " .. name .. " changed from " .. base.tostring(old) .. " to " .. base.tostring(setting.value))
		end
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
		save_li_settings()

		local message = c:getField('NI') .. ' has changed "' .. name .. '" from "' .. base.tostring(old) .. '" to "' .. base.tostring(setting.value) .. '"'
		log(message)
		if setting.announce and access.settings.announcecfg.value ~= 0 then
			cm:sendToAll(autil.info(message):getBuffer())
		else
			autil.reply(c, "Variable " .. name .. " changed from " .. base.tostring(old) .. " to " .. base.tostring(setting.value))
		end
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
		save_en_settings()

		local message = c:getField('NI') .. ' has changed "' .. name .. '" from "' .. base.tostring(old) .. '" to "' .. base.tostring(setting.value) .. '"'
		log(message)
		if setting.announce and access.settings.announcecfg.value ~= 0 then
			cm:sendToAll(autil.info(message):getBuffer())
		else
			autil.reply(c, "Variable " .. name .. " changed from " .. base.tostring(old) .. " to " .. base.tostring(setting.value))
		end
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

		str = "\n\nDefault settings for all floods:\tMaximum Level: " .. fl_settings.fl_level.value
		str = str .. "\t\t\tMaximum Warns: " .. fl_settings.fl_maxwarns.value
		str = str .. "\t\tFlood Log Enabled: " .. fl_settings.fl_commandstats.value .. "\n\n"
		str = str .. "\t\t\t\tMaximum Rate: " .. fl_settings.fl_maxrate.value .. " /h"
		str = str .. "\t\t\tExpire Time: " .. fl_settings.fl_exptime.value
		str = str .. "\t\t\tFor help use: +help cfgfl"
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

		str = "\n\nDefault settings for all limits:\tMaximum Rate: " .. li_settings.li_maxrate.value .. " /h"
		str = str .. "\t\t\tMaximum Count: " .. li_settings.li_maxcount.value
		str = str .. "\t\tLimit Log Enabled: " .. li_settings.li_limitstats.value .. "\n\n"
		str = str .. "\t\t\t\tMaximum Level: " .. fl_settings.fl_level.value
		str = str .. "\t\t\tExpire Time: " .. li_settings.li_exptime.value
		str = str .. "\t\tFor help use: +help cfgli"
		str = str .. "\n\nSharing (*) Limits Settings:\tMinimum Level: " .. li_settings.li_minlevel.value
		str = str .. "\t\t\tRedirect Address: " .. li_settings.li_redirect.value

		str = str .. "\n\n\nSearch Limits:\n\nSearch Parameters:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.maxschparam_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.maxschparam_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.maxschparam.value .. "\n"
		for maxschparams, info in base.pairs(limitstats.maxschparams) do
			str = str .. "\n\tCID: " .. maxschparams .. data_info_string_cid(info)
		end

		str = str .. "\n\nMin Search Length:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.minschlength_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.minschlength_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.minschlength.value .. "\n"
		for minschlengths, info in base.pairs(limitstats.minschlengths) do
			str = str .. "\n\tCID: " .. minschlengths .. data_info_string_cid(info)
		end

		str = str .. "\n\nMax Search Length:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.maxschlength_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.maxschlength_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.maxschlength.value .. "\n"
		for maxschlengths, info in base.pairs(limitstats.maxschlengths) do
			str = str .. "\n\tCID: " .. maxschlengths .. data_info_string_cid(info)
		end

		str = str .. "\n\nShare Limits (*):\n\nMinimum Sharesize:"
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

		str = str .. "\n\nHub Count and Ratio Limits (*):\n\nMin Hub Slotratio:"
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

		str = str .. "\n\nSupport Limits (*):\n\nSupport ADCS Forced:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.suadcs_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.suadcs_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.suadcs.value .. "\n"
		for suadcs, info in base.pairs(limitstats.suadcs) do
			str = str .. "\n\tCID: " .. suadcs .. data_info_string_cid(info)
		end

		str = str .. "\n\nSupport NATT Forced:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.sunatt_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.sunatt_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.sunatt.value .. "\n"
		for sunatts, info in base.pairs(limitstats.sunatts) do
			str = str .. "\n\tCID: " .. sunatts .. data_info_string_cid(info)
		end

		str = str .. "\n\nSupport BLOM Forced:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.sublom_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.sublom_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.sublom.value .. "\n"
		for subloms, info in base.pairs(limitstats.subloms) do
			str = str .. "\n\tCID: " .. subloms .. data_info_string_ip(info)
		end

		str = str .. "\n\nMessage limits:\n\nMax Message Length:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.maxmsglength_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.maxmsglength_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.maxmsglength.value .. "\n"
		for maxmsglengths, info in base.pairs(limitstats.maxmsglengths) do
			str = str .. "\n\tCID: " .. maxmsglengths .. data_info_string_cid(info)
		end

		str = str .. "\n\nNick limits:\n\nMin Nick Length Stats:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.minnicklength_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.minnicklength_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.minnicklength.value .. "\n"
		for minnicklengths, info in base.pairs(limitstats.minnicklengths) do
			str = str .. "\n\tCID: " .. minnicklengths .. data_info_string_cid(info)
		end

		str = str .. "\n\nMax Nick Length Stats:"
		str = str .. "\t\tMaximum Rate: " .. li_settings.maxnicklength_rate.value .. " / h"
		str = str .. "\t\t\tExpire Time: " .. li_settings.maxnicklength_exp.value
		str = str .. "\t\t\tValue: " .. li_settings.maxnicklength.value .. "\n"
		for maxnicklengths, info in base.pairs(limitstats.maxnicklengths) do
			str = str .. "\n\tCID: " .. maxnicklengths .. data_info_string_cid(info)
		end

		str = str .. "\n\nUser IP limits:\n\nMax Same IP Stats:"
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
			str = str .. "\n\tIP: " .. ipkick .. "  \t\t\t\t\t" .. data_info_string_log(info)
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

		str = "\n\nEntity Log settings: Entity Log enabled: " .. en_settings.en_entitystats.value
		str = str .. "\tFor help use: +help cfgen"
		str = str .. "\tExpire time User / Reg: " .. en_settings.en_entitystatsexptime.value .. " / " .. en_settings.en_entitystatsregexptime.value .." day(s)"
		str = str .. "\n\n\tAll current Entity records that match your search criteria: [ " .. entity .. " ]\n" 
		for last_cid, info in base.pairs(entitystats.last_cids) do
			if entity == last_cid or entity == info.ip or (info.ni and string.lower(info.ni) == string.lower(entity)) then
				info.cid = last_cid
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

		str = "\n\nEntity Log settings: Entity Log enabled: " .. en_settings.en_entitystats.value
		str = str .. "\tFor help use: +help cfgen"
		str = str .. "\tExpire time User / Reg: " .. en_settings.en_entitystatsexptime.value .. " / " .. en_settings.en_entitystatsregexptime.value .." day(s)"
		str = str .. "\n\nEntity Last records:"
		for last_cid, info in base.pairs(entitystats.last_cids) do
			if info.ip and info.ip == ip then
				table.insert(entni, info.ni)
				table.insert(entcid, last_cid)
				info.cid = last_cid
				str = str .. "\n\tEntity CID: \t\t\t\t" .. last_cid .. data_info_string_entity(info)
			end
		end

		str = str .. "\n\nAll Hist records that used this NI:"
		for hist_cid, info in base.ipairs(entitystats.hist_cids) do
			for i,v in base.ipairs(entni) do
				if info.ni and v == info.ni then	
					str = str .. "\n" .. data_info_string_entity_hist(info)
				end
			end
		end

		str = str .. "\n\nAll Hist records that used this IP:"
		for hist_cid, info in base.ipairs(entitystats.hist_cids) do
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

		str = "\n\nEntity Log settings: Entity Log enabled: " .. en_settings.en_entitystats.value
		str = str .. "\tFor help use: +help cfgen"
		str = str .. "\tExpire time User / Reg: " .. en_settings.en_entitystatsexptime.value .. " / " .. en_settings.en_entitystatsregexptime.value .." day(s)"
		str = str .. "\n\nEntity Last records:"
		for last_cid, info in base.pairs(entitystats.last_cids) do
			if last_cid == cid then
				table.insert(entni, info.ni)
				table.insert(entip, info.ip)
				info.cid = last_cid
				str = str .. "\n\tEntity CID: \t\t\t\t" .. last_cid .. data_info_string_entity(info)
			end
		end

		str = str .. "\n\nAll Hist records that used this NI:"
		for hist_cid, info in base.ipairs(entitystats.hist_cids) do
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
		for hist_cid, info in base.ipairs(entitystats.hist_cids) do
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

		str = "\n\nEntity Log settings: Entity Log enabled: " .. en_settings.en_entitystats.value
		str = str .. "\tFor help use: +help cfgen"
		str = str .. "\tExpire time User / Reg: " .. en_settings.en_entitystatsexptime.value .. " / " .. en_settings.en_entitystatsregexptime.value .." day(s)"
		str = str .. "\n\nEntity Last records:"
		for last_cid, info in base.pairs(entitystats.last_cids) do
			if info.ni and string.lower(info.ni) == string.lower(ni) then
				table.insert(entip, info.ip)
				table.insert(entcid, last_cid)
				info.cid = last_cid
				str = str .. "\n\tEntity CID: \t\t\t\t" .. last_cid .. data_info_string_entity(info)
			end
		end

		str = str .. "\n\nAll Hist records that used this NI:"
		for hist_cid, info in base.ipairs(entitystats.hist_cids) do
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

if verify_fldb_folder() ~= 0 then
	base.pcall(load_tmpbanstats)
	base.pcall(load_kickstats)
else
	base.pcall(save_tmpbanstats)
	base.pcall(save_kickstats)
	base.pcall(save_limitstats)
	base.pcall(save_commandstats)
	base.pcall(save_entitystats)
end

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

local onONL_timer = sm:addTimedJob(900000, onONL)
autil.on_unloading(_NAME, onONL_timer)
autil.on_unloading(_NAME, onONL)

-- The 2 timers are created on settings change
autil.on_unloading(_NAME, function() if clear_expired_commandstats_timer then clear_expired_commandstats_timer() end end)
autil.on_unloading(_NAME, function() if save_commandstats_timer then save_commandstats_timer() end end)
autil.on_unloading(_NAME, function() if fl_settings.fl_commandstats.value > 0 then save_commandstats() end end)

-- The 2 timers are created on settings change
autil.on_unloading(_NAME, function() if clear_expired_limitstats_timer then clear_expired_limitstats_timer() end end)
autil.on_unloading(_NAME, function() if save_limitstats_timer then save_limitstats_timer() end end)
autil.on_unloading(_NAME, function() if li_settings.li_limitstats.value > 0 then save_limitstats() end end)

-- The 2 timers are created on settings change
autil.on_unloading(_NAME, function() if clear_expired_entitystats_timer then clear_expired_entitystats_timer() end end)
autil.on_unloading(_NAME, function() if save_entitystats_timer then save_entitystats_timer() end end)
autil.on_unloading(_NAME, function() if en_settings.en_entitystats.value > 0 then save_entitystats() end end)

save_kickstats_timer = sm:addTimedJob(1800000, save_kickstats)
clear_expired_kickstats_timer = sm:addTimedJob(900000, clear_expired_kickstats)
autil.on_unloading(_NAME, clear_expired_kickstats_timer)
autil.on_unloading(_NAME, save_kickstats_timer)
autil.on_unloading(_NAME, save_kickstats)

save_tmpbanstats_timer = sm:addTimedJob(1800000, save_tmpbanstats)
clear_expired_tmpbanstats_timer = sm:addTimedJob(900000, clear_expired_tmpbanstats)
autil.on_unloading(_NAME, clear_expired_tmpbanstats_timer)
autil.on_unloading(_NAME, save_tmpbanstats_timer)
autil.on_unloading(_NAME, save_tmpbanstats)
