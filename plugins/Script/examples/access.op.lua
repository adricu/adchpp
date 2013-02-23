-- This script contains a few useful op commands such as kick and redirect

local base=_G
module("access.op")

base.require("luadchpp")
local adchpp = base.luadchpp
local access = base.require("access")
local autil = base.require("autil")
local string = base.require("string")

local commands = access.commands
local settings = access.settings
local get_level = access.get_level
local is_op = access.is_op

local cm = adchpp.getCM()

commands.kick = {
	alias = { drop = true, dropuser = true, kickuser = true },

	command = function(c, parameters)
		local level = get_level(c)
		if level < settings.oplevel.value then
			return
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
		if level <= get_level(victim) then
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
			autil.ucmd_line("User"),
			autil.ucmd_line("Reason (facultative)")
		},
		name = "Hub management" .. autil.ucmd_sep .. "Punish" .. autil.ucmd_sep .. "Kick",
		user_params = {
			"%[userNI]",
			autil.ucmd_line("Reason (facultative)")
		}
	}
}

commands.mass = {
	alias = { massmessage = true },

	command = function(c, parameters)
		if not commands.mass.protected(c) then
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
		else
			level = 0
		end

		local entities = cm:getEntities()
		local size = entities:size()
		if size == 0 then
			return
		end

		local mass_cmd
		if access.bot then
			mass_cmd = autil.pm(message, access.bot.main_bot:getSID(), 0)
		else
			mass_cmd = autil.info(message)
		end

		local count = 0
		for i = 0, size - 1 do
			local other = entities[i]:asClient()
			if other then
				local ok = level <= 0
				if not ok then
					ok = get_level(other) >= level
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

	help = "message [min-level] -no min-level means send to everyone",

	protected = is_op,

	user_command = {
		name = "Hub management" .. autil.ucmd_sep .. "Mass message",
		params = {
			autil.ucmd_line("Message"),
			autil.ucmd_line("Minimum level (facultative)")
		}
	}
}

commands.redirect = {
	alias = { forward = true },

	command = function(c, parameters)
		local level = get_level(c)
		if level < settings.oplevel.value then
			return
		end

                local nick_pos, _, nick = parameters:find("^(%S+)")

		if nick_pos then
			parameters = parameters:sub(nick_pos + 2)
			if #parameters <= 0 then
				autil.reply(c, "Bad arguments")
				return
			end
		end

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

		local address, reason = parameters:match("<([^>]+)> ?(.*)")
		if not address then
			autil.reply(c, "You need to supply a redirect address (within '<' and '>' brackets)")
			return
		end

		local victim_cid = victim:getCID():toBase32()
		if level <= get_level(victim) then
			autil.reply(c, "You can't redirect users whose level is higher or equal than yours")
			return
		end

		local text = "You have been redirected"
		if string.len(reason) > 0 then
			text = text .. " (reason: " .. reason .. ")"
		end

		autil.dump(victim, adchpp.AdcCommand_ERROR_BANNED_GENERIC, function(cmd)
			cmd:addParam("ID" .. adchpp.AdcCommand_fromSID(c:getSID()))
			:addParam("MS" .. text)
			cmd:addParam("RD" .. address)
		end)

		autil.reply(c, "\"" .. nick .. "\" (CID: " .. victim_cid .. ") has been redirected to \"" .. address .. "\"")
	end,

	help = "nick <address> [reason] - redirects the user to the given address (must be within '<' and '>' brackets); reason is optional ", 

	protected = is_op,

	user_command = {
		hub_params = {
			autil.ucmd_line("Nick"),
			"<" .. autil.ucmd_line("Redirect Address") .. ">",
			autil.ucmd_line("Reason (facultative)")
		},
		name = "Hub management" .. autil.ucmd_sep .. "Punish" .. autil.ucmd_sep .. "Redirect",
		user_params = {
			"%[userNI]",
			"<" .. autil.ucmd_line("Redirect Address") .. ">",
			autil.ucmd_line("Reason (facultative)")
		}
	}
}
