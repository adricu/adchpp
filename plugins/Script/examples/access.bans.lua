-- This script contains commands and settings related to banning and muting users

local base=_G
module("access.bans")

base.require("luadchpp")
local adchpp = base.luadchpp
local access = base.require("access")
local autil = base.require("autil")
local json = base.require("json")
local io = base.require("io")
local os = base.require("os")
local string = base.require("string")

-- Where to read/write ban database
local bans_file = adchpp.Util_getCfgPath() .. "bans.txt"

local bans = {}
bans.cids = {}
bans.ips = {}
bans.nicks = {}
bans.nicksre = {}
bans.msgsre = {}
bans.muted = {}

local settings = access.settings
local commands = access.commands
local level_op = access.level_op

local cm = adchpp.getCM()
local sm = adchpp.getSM()

local function log(message)
	lm:log(_NAME, message)
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
		log("Unable to open " .. bans_file .. ", bans not loaded")
		return
	end

	local str = file:read("*a")
	file:close()

	if #str == 0 then
		return
	end

	local ok, list = base.pcall(json.decode, str)
	if not ok then
		log("Unable to decode bans file: " .. list)
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
end

local function save_bans()
	local file = io.open(bans_file, "w")
	if not file then
		log("Unable to open " .. bans_file .. ", bans not saved")
		return
	end

	file:write(json.encode(bans))
	file:close()
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
			return "in " .. access.format_seconds(diff)
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
	local str = "You are banned" .. ban_return_info(ban)

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

commands.ban = {
	alias = { banuser = true },

	command = function(c, parameters)
		local level = access.get_level(c)
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

		local victim = cm:findByNick(nick)
		if victim then
			victim = victim:asClient()
		end
		if not victim then
			autil.reply(c, "No user nick-named \"" .. nick .. "\"")
			return
		end

		local victim_cid = victim:getCID():toBase32()
		local victim_user = access.get_user(victim_cid, 0)
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

	protected = access.is_op,

	user_command = {
		hub_params = {
			autil.ucmd_line("Nick"),
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Minutes (facultative)")
		},
		name = "Hub management" .. autil.ucmd_sep .. "Punish" .. autil.ucmd_sep .. "Ban",
		user_params = {
			"%[userNI]",
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Minutes (facultative)")
		}
	}
}

commands.bancid = {
	command = function(c, parameters)
		local level = access.get_level(c)
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

	protected = access.is_op,

	user_command = {
		hub_params = {
			autil.ucmd_line("CID"),
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Minutes (facultative)")
		},
		name = "Hub management" .. autil.ucmd_sep .. "Punish" .. autil.ucmd_sep .. "Ban CID",
		user_params = {
			"%[userCID]",
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Minutes (facultative)")
		}
	}
}

commands.banip = {
	command = function(c, parameters)
		local level = access.get_level(c)
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

	protected = access.is_op,

	user_command = {
		hub_params = {
			autil.ucmd_line("IP"),
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Minutes (facultative)")
		},
		name = "Hub management" .. autil.ucmd_sep .. "Punish" .. autil.ucmd_sep .. "Ban IP",
		user_params = {
			"%[userI4]",
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Minutes (facultative)")
		}
	}
}

commands.bannick = {
	command = function(c, parameters)
		local level = access.get_level(c)
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

	protected = access.is_op,

	user_command = {
		hub_params = {
			autil.ucmd_line("Nick"),
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Minutes (facultative)")
		},
		name = "Hub management" .. autil.ucmd_sep .. "Punish" .. autil.ucmd_sep .. "Ban nick",
		user_params = {
			"%[userNI]",
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Minutes (facultative)")
		}
	}
}

commands.bannickre = {
	command = function(c, parameters)
		local level = access.get_level(c)
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

	protected = access.is_op,

	user_command = {
		name = "Hub management" .. autil.ucmd_sep .. "Punish" .. autil.ucmd_sep .. "Ban nick (reg exp)",
		params = {
			"<" .. autil.ucmd_line("Reg exp of nicks to forbid") .. ">",
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Minutes (facultative)")
		}
	}
}

commands.banmsgre = {
	command = function(c, parameters)
		local level = access.get_level(c)
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

	user_command = {
		name = "Hub management" .. autil.ucmd_sep .. "Punish" .. autil.ucmd_sep .. "Ban chat (reg exp)",
		params = {
			"<" .. autil.ucmd_line("Reg exp of chat messages to forbid") .. ">",
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Minutes (facultative)")
		}
	}
}

commands.listbans = {
	alias = { listban = true, listbanned = true, showban = true, showbans = true, showbanned = true },

	command = function(c)
		local level = access.get_level(c)
		if level < level_op then
			return
		end

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

	protected = is_op,

	user_command = { name = "Hub management" .. autil.ucmd_sep .. "List bans" }
}

commands.loadbans = {
	alias = { reloadbans = true },

	command = function(c)
		local level = access.get_level(c)
		if level < level_op then
			return
		end

		base.pcall(load_bans)

		autil.reply(c, "Ban list reloaded")
	end,

	help = "- reload the ban list",

	protected = is_op,

	user_command = { name = "Hub management" .. autil.ucmd_sep .. "Reload bans" }
}

commands.mute = {
	alias = { stfu = true },

	command = function(c, parameters)
		local level = access.get_level(c)
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

		local victim = cm:findByNick(nick)
		if victim then
			victim = victim:asClient()
		end
		if not victim then
			autil.reply(c, "No user nick-named \"" .. nick .. "\"")
			return
		end

		local victim_cid = victim:getCID():toBase32()
		local victim_user = access.get_user(victim_cid, 0)
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

	protected = access.is_op,

	user_command = {
		hub_params = {
			autil.ucmd_line("Nick"),
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Minutes (facultative)")
		},
		name = "Hub management" .. autil.ucmd_sep .. "Punish" .. autil.ucmd_sep .. "Mute",
		user_params = {
			"%[userNI]",
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Minutes (facultative)")
		}
	}
}


local function onMSG(c, cmd)
	local muted = bans.muted[c:getCID():toBase32()]
	if muted then
		autil.reply(c, "You are muted" .. ban_return_info(muted))
		return false
	end

	local level = access.get_level(c)
	local msg = cmd:getParam(0)

	for re, reban in base.pairs(bans.msgsre) do
		if reban.level >= level and msg:match(re) then
			local ban = { level = reban.level, reason = reban.reason, expires = reban.expires }
			bans.cids[c:getCID():toBase32()] = ban
			base.pcall(save_bans)
			dump_banned(c, ban)
			return false
		end
	end
	
	return true
end

local function onINF(c, cmd)
	local cid = c:getCID():toBase32()
	local nick = c:getField("NI")

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
	if ban and ban.level > access.get_level(c) then
		dump_banned(c, ban)
		return false
	end

	return true
end

base.pcall(load_bans)

access.register_handler(adchpp.AdcCommand_CMD_MSG, onMSG, true)
access.register_handler(adchpp.AdcCommand_CMD_INF, onINF)

cancel_timer = sm:addTimedJob(1000, clear_expired_bans)
autil.on_unloading(_NAME, cancel_timer)
