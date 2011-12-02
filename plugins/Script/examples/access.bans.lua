-- This script contains commands and settings related to banning and muting users

local base=_G
module("access.bans")

base.require("luadchpp")
local adchpp = base.luadchpp
local access = base.require("access")
local aio = base.require('aio')
local autil = base.require("autil")
local json = base.require("json")
local os = base.require("os")
local string = base.require("string")
local table = base.require("table")

-- Where to read/write ban database
local bans_file = adchpp.Util_getCfgPath() .. "bans.txt"
bans = {}
bans.cids = {}
bans.ips = {}
bans.nicks = {}
bans.nicksre = {}
bans.msgsre = {}
bans.schsre = {}
bans.muted = {}

local settings = access.settings
local commands = access.commands
local is_op = access.is_op

local cm = adchpp.getCM()
local sm = adchpp.getSM()
local lm = adchpp.getLM()

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
	bans.schsre = {}
	bans.muted = {}

	local ok, list, err = aio.load_file(bans_file, aio.json_loader)

	if err then
		log('Ban loading: ' .. err)
	end
	if not ok then
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
	if not bans.schsre then
		bans.schsre = {}
	end
	if not bans.muted then
		bans.muted = {}
	end
end

function save_bans()
	local err = aio.save_file(bans_file, json.encode(bans))
	if err then
		log('Bans not saved: ' .. err)
	end
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
		save_bans()
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

local function ban_info_string(ban, sep)
	if not sep then
		sep = "\t | "
	end

	local str = "Level: " .. ban.level

	if ban.reason then
		str = str .. sep .. "Reason: " .. ban.reason
	end

	str = str .. sep .. "Expires: " .. ban_expiration_string(ban)

	if ban.action then
		str = str .. sep .. "Bans for"
		if ban.action < 0 then
			str = str .. "ever"
		else
			str = str .. " " .. base.tostring(ban.action) .. " minutes"
		end
	end

	return str
end

local function ban_added_string(ban)
	return ban_info_string(ban, ") (")
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
		if level < settings.oplevel.value then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(1, minutes_pos - 1)
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

		if base.tonumber(minutes) ~= 0 then
			local ban = make_ban(level, reason, minutes)
			bans.cids[victim_cid] = ban
			save_bans()
			dump_banned(victim, ban)
			autil.reply(c, "\"" .. nick .. "\" (CID: " .. victim_cid .. ") is now banned (" .. ban_added_string(ban) .. ")")
			return
		end

		if bans.cids[victim_cid] then
			bans.cids[victim_cid] = nil
			save_bans()
			autil.reply(c, "\"" .. nick .. "\" (CID: " .. victim_cid .. ") is now un-banned")
		else
			autil.reply(c, "\"" .. nick .. "\" (CID: " .. victim_cid .. ") is not in the banlist")
		end
	end,

	help = "nick [reason] [minutes] - ban an online user (set minutes to 0 to un-ban)",

	protected = is_op,

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
		if level < settings.oplevel.value then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(1, minutes_pos - 1)
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

		if base.tonumber(minutes) ~= 0 then
			local ban = make_ban(level, reason, minutes)
			bans.cids[cid] = ban
			save_bans()
			autil.reply(c, "The CID \"" .. cid .. "\" is now banned (" .. ban_added_string(ban) .. ")")
			return
		end

		if bans.cids[cid] then
			bans.cids[cid] = nil
			save_bans()
			autil.reply(c, "The CID \"" .. cid .. "\" is now un-banned")
		else
			autil.reply(c, "The CID \"" .. cid .. "\" is not in the banlist")
		end
	end,

	help = "CID [reason] [minutes] (set minutes to 0 to un-ban)",

	protected = is_op,

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
		if level < settings.oplevel.value then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(1, minutes_pos - 1)
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

		if base.tonumber(minutes) ~= 0 then
			local ban = make_ban(level, reason, minutes)
			bans.ips[ip] = ban
			save_bans()
			autil.reply(c, "The IP address \"" .. ip .. "\" is now banned (" .. ban_added_string(ban) .. ")")
			return
		end

		if bans.ips[ip] then
			bans.ips[ip] = nil
			save_bans()
			autil.reply(c, "The IP address \"" .. ip .. "\" is now un-banned")
		else
			autil.reply(c, "The IP address \"" .. ip .. "\" is not found in the banlist")
		end
	end,

	help = "IP [reason] [minutes] (set minutes to 0 to un-ban)",

	protected = is_op,

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
		if level < settings.oplevel.value then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(1, minutes_pos - 1)
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

		if base.tonumber(minutes) ~= 0 then
			local ban = make_ban(level, reason, minutes)
			bans.nicks[nick] = ban
			save_bans()
			autil.reply(c, "The nick \"" .. nick .. "\" is now banned (" .. ban_added_string(ban) .. ")")
			return
		end

		if bans.nicks[nick] then
			bans.nicks[nick] = nil
			save_bans()
			autil.reply(c, "The nick \"" .. nick .. "\" is now un-banned")
		else
			autil.reply(c, "The nick \"" .. nick .. "\" is not found in the banlist")
		end
	end,

	help = "nick [reason] [minutes] (set minutes to 0 to un-ban)",

	protected = is_op,

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
		if level < settings.oplevel.value then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(1, minutes_pos - 1)
			if #parameters <= 0 then
				autil.reply(c, "Bad arguments")
				return
			end
		end

                local action_pos, _, action = parameters:find("^(-?%d*) ")
		if action_pos then
			parameters = parameters:sub(action_pos + 2)
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

		if base.tonumber(minutes) ~= 0 then
			local ban = make_ban(level, reason, minutes)
			if action_pos then
				ban.action = base.tonumber(action)
			end
			bans.nicksre[re] = ban
			save_bans()
			autil.reply(c, "Nicks that match \"" .. re .. "\" will be blocked (" .. ban_added_string(ban) .. ")")
			return
		end

		if bans.nicksre[re] then
			bans.nicksre[re] = nil
			save_bans()
			autil.reply(c, "Nicks that match \"" .. re .. "\" won't be blocked anymore")
		else
			autil.reply(c, "Nicks that match \"" .. re .. "\" are not being blocked")
		end
	end,

	help = "[action] <nick-reg-exp> [reason] [expiration] - block nicks that match the given reg exp (must be within '<' and '>' brackets); action is optional, skip for simple block, set to -1 to ban forever or >= 0 to set how many minutes to ban for; expiration is also optional, defines when this rule expires (in minutes), skip for permanent rule, set to 0 to remove banre",

	protected = is_op,

	user_command = {
		name = "Hub management" .. autil.ucmd_sep .. "Punish" .. autil.ucmd_sep .. "Ban nick (reg exp)",
		params = {
			autil.ucmd_line("Ban duration (facultative, in minutes; -1 = forever)"),
			"<" .. autil.ucmd_line("Reg exp of nicks to forbid") .. ">",
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Rule expiration (facultative, in minutes)")
		}
	}
}

commands.banmsgre = {
	command = function(c, parameters)
		local level = access.get_level(c)
		if level < settings.oplevel.value then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(1, minutes_pos - 1)
			if #parameters <= 0 then
				autil.reply(c, "Bad arguments")
				return
			end
		end

                local action_pos, _, action = parameters:find("^(-?%d*) ")
		if action_pos then
			parameters = parameters:sub(action_pos + 2)
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

		if base.tonumber(minutes) ~= 0 then
			local ban = make_ban(level, reason, minutes)
			if action_pos then
				ban.action = base.tonumber(action)
			end
			re = string.lower(re)
			bans.msgsre[re] = ban
			save_bans()
			autil.reply(c, "Messages that match \"" .. re .. "\" will be blocked (" .. ban_added_string(ban) .. ")")
			return
		end

		if bans.msgsre[re] then
			bans.msgsre[re] = nil
			save_bans()
			autil.reply(c, "Messages that match \"" .. re .. "\" won't be blocked anymore")
		else
			autil.reply(c, "Messages that match \"" .. re .. "\" are not being blocked")
		end
	end,

	help = "[action] <chat-reg-exp> [reason] [expiration] - block chatmessages that match the given reg exp (must be within '<' and '>' brackets); action is optional, skip for simple block, set to -1 to ban forever or >= 0 to set how many minutes to ban for; expiration is also optional, defines when this rule expires (in minutes), skip for permanent rule, set to 0 to remove banre",

	protected = is_op,

	user_command = {
		name = "Hub management" .. autil.ucmd_sep .. "Punish" .. autil.ucmd_sep .. "Ban chat (reg exp)",
		params = {
			autil.ucmd_line("Ban duration (facultative, in minutes; -1 = forever)"),
			"<" .. autil.ucmd_line("Reg exp of chat messages to forbid") .. ">",
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Rule expiration (facultative, in minutes)")
		}
	}
}

commands.banschre = {
	command = function(c, parameters)
		local level = access.get_level(c)
		if level < settings.oplevel.value then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(1, minutes_pos - 1)
			if #parameters <= 0 then
				autil.reply(c, "Bad arguments")
				return
			end
		end

                local action_pos, _, action = parameters:find("^(-?%d*) ")
		if action_pos then
			parameters = parameters:sub(action_pos + 2)
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

		if base.tonumber(minutes) ~= 0 then
			local ban = make_ban(level, reason, minutes)
			if action_pos then
				ban.action = base.tonumber(action)
			end
			bans.schsre[re] = ban
			save_bans()
			autil.reply(c, "Searches that match \"" .. re .. "\" will be blocked (" .. ban_added_string(ban) .. ")")
			return
		end

		if bans.schsre[re] then
			bans.schsre[re] = nil
			save_bans()
			autil.reply(c, "Searches that match \"" .. re .. "\" won't be blocked anymore")
		else
			autil.reply(c, "Searches that match \"" .. re .. "\" are not being blocked")
		end
	end,

	help = "[action] <search-reg-exp> [reason] [expiration] - block searches that match the given reg exp (must be within '<' and '>' brackets); action is optional, skip for simple block, set to -1 to ban forever or >= 0 to set how many minutes to ban for; expiration is also optional, defines when this rule expires (in minutes), skip for permanent rule, set to 0 to remove banre",

	protected = is_op,

	user_command = {
		name = "Hub management" .. autil.ucmd_sep .. "Punish" .. autil.ucmd_sep .. "Ban search (reg exp)",
		params = {
			autil.ucmd_line("Ban duration (facultative, in minutes; -1 = forever)"),
			"<" .. autil.ucmd_line("Reg exp of search messages to forbid") .. ">",
			autil.ucmd_line("Reason (facultative)"),
			autil.ucmd_line("Rule expiration (facultative, in minutes)")
		}
	}
}

commands.listbans = {
	alias = { listban = true, listbanned = true, showban = true, showbans = true, showbanned = true, banlist = true, banslist = true },

	command = function(c)
		local level = access.get_level(c)
		if level < settings.oplevel.value then
			return
		end

		local str = "\nCID bans:"
		for cid, ban in base.pairs(bans.cids) do
			str = str .. "\n\tCID: " .. cid .. "\t | " .. ban_info_string(ban)
		end

		str = str .. "\n\nIP bans:"
		for ip, ban in base.pairs(bans.ips) do
			str = str .. "\n\tIP: " .. ip .. "\t | " .. ban_info_string(ban)
		end

		str = str .. "\n\nNick bans:"
		for nick, ban in base.pairs(bans.nicks) do
			str = str .. "\n\tNick: " .. nick .. "\t | " .. ban_info_string(ban)
		end

		str = str .. "\n\nNick bans (reg exp):"
		for nickre, ban in base.pairs(bans.nicksre) do
			str = str .. "\n\tReg exp: " .. nickre .. "\t | " .. ban_info_string(ban)
		end

		str = str .. "\n\nMessage bans (reg exp):"
		for msgre, ban in base.pairs(bans.msgsre) do
			str = str .. "\n\tReg exp: " .. msgre .. "\t | " .. ban_info_string(ban)
		end

		str = str .. "\n\nSearch bans (reg exp):"
		for schre, ban in base.pairs(bans.schsre) do
			str = str .. "\n\tReg exp: " .. schre .. "\t | " .. ban_info_string(ban)
		end

		str = str .. "\n\nMuted:"
		for cid, ban in base.pairs(bans.muted) do
			str = str .. "\n\tCID: " .. cid .. "\t | " .. ban_info_string(ban)
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
		if level < settings.oplevel.value then
			return
		end

		load_bans()

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
		if level < settings.oplevel.value then
			return
		end

		local minutes_pos, _, minutes = parameters:find(" (%d*)$")
		if minutes_pos then
			parameters = parameters:sub(1, minutes_pos - 1)
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

		if base.tonumber(minutes) ~= 0 then
			local ban = make_ban(level, reason, minutes)
			bans.muted[victim_cid] = ban
			save_bans()
			autil.reply(c, "\"" .. nick .. "\" (CID: " .. victim_cid .. ") is now muted (" .. ban_added_string(ban) .. ")")
			return
		end

		if bans.muted[victim_cid] then
			bans.muted[victim_cid] = nil
			save_bans()
			autil.reply(c, "\"" .. nick .. "\" (CID: " .. victim_cid .. ") is now removed from the mutelist")
		else
			autil.reply(c, "\"" .. nick .. "\" (CID: " .. victim_cid .. ") is not found in the mutelist")
		end
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
	local msg = string.lower(cmd:getParam(0))

	for re, reban in base.pairs(bans.msgsre) do
		if reban.level > level and msg:match(re) then
			local str = "Message blocked"
			if reban.reason then
				str = str .. ": " .. reban.reason
			end
			if reban.action then
				local ban = { level = reban.level, reason = str }
				if reban.action == 0 then
					ban.expires = 0
				else
					if reban.action > 0 then
						ban.expires = os.time() + reban.action * 60
					end
					bans.cids[c:getCID():toBase32()] = ban
					save_bans()
				end
				dump_banned(c, ban)
			else
				autil.reply(c, str)
			end
			return false
		end
	end

	return true
end

local function onSCH(c, cmd)
	local level = access.get_level(c)
	local sch

	local tr = cmd:getParam('TR', 0)
	if #tr > 0 then
		return true
	else
		local vars = {}
		local params = cmd:getParameters()
		local params_size = params:size()
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
		sch = table.concat(vars, ' ')
	end

	for re, reban in base.pairs(bans.schsre) do
		if reban.level > level and sch:match(re) then
			local str = "Search blocked"
			if reban.reason then
				str = str .. ": " .. reban.reason
			end
			if reban.action then
				local ban = { level = reban.level, reason = str }
				if reban.action == 0 then
					ban.expires = 0
				else
					if reban.action > 0 then
						ban.expires = os.time() + reban.action * 60
					end
					bans.cids[c:getCID():toBase32()] = ban
					save_bans()
				end
				dump_banned(c, ban)
			else
				autil.reply(c, str)
			end
			return false
		end
	end

	return true
end

local function onINF(c, cmd)
	local cid, nick

	if c:getState() == adchpp.Entity_STATE_NORMAL then
		cid = c:getCID():toBase32()
		nick = c:getField("NI")
	else
		cid = cmd:getParam("ID", 0)
		nick = cmd:getParam("NI", 0)
	end

	local ban = nil
	if bans.cids[cid] then
		ban = bans.cids[cid]
	elseif bans.ips[c:getIp()] then
		ban = bans.ips[c:getIp()]
	elseif bans.nicks[nick] then
		ban = bans.nicks[nick]
	else
		for re, reban in base.pairs(bans.nicksre) do
			if nick:match(re) and reban.level > access.get_level(c) then
			local str = "Nick blocked"
			if reban.reason then
				str = str .. ": " .. reban.reason
			end
				ban = { level = reban.level, reason = str }
				if reban.action and reban.action ~= 0 then
					if reban.action > 0 then
						ban.expires = os.time() + reban.action * 60
					end
					bans.cids[c:getCID():toBase32()] = ban
					save_bans()
				else
					ban.expires = 0
				end
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

load_bans()

access.register_handler(adchpp.AdcCommand_CMD_MSG, onMSG, true)
access.register_handler(adchpp.AdcCommand_CMD_SCH, onSCH, true)
access.register_handler(adchpp.AdcCommand_CMD_INF, onINF)

cancel_timer = sm:addTimedJob(1000, clear_expired_bans)
autil.on_unloading(_NAME, cancel_timer)
