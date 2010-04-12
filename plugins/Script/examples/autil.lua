-- Various utilities for adchpp

local base = _G

module("autil")

base.require('luadchpp')
local adchpp = base.luadchpp

ucmd_sep = "/"

function ucmd_line(str)
	return "%[line:" .. str .. "]"
end

function info(m)
	return adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
	:addParam(m)
end

-- "from" and "to" are SIDs (numbers).
function pm(m, from, to)
	local command = adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_DIRECT, from)
	:addParam(m)
	:addParam("PM", adchpp.AdcCommand_fromSID(from))
	command:setTo(to)
	return command
end

function reply(c, m)
	local command
	if reply_from then
		command = pm(m, reply_from:getSID(), c:getSID())
	else
		command = info(m)
	end
	c:send(command)
end

-- params: either a message string or a function(AdcCommand QUI_command).
function dump(c, code, params)
	local msg

	local cmd = adchpp.AdcCommand(adchpp.AdcCommand_CMD_QUI, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
	:addParam(adchpp.AdcCommand_fromSID(c:getSID())):addParam("DI1")
	if base.type(params) == "function" then
		params(cmd)
		msg = cmd:getParam("MS", 1)
	else
		msg = params
		cmd:addParam("MS" .. msg)
	end

	c:send(adchpp.AdcCommand(adchpp.AdcCommand_CMD_STA, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
	:addParam(adchpp.AdcCommand_SEV_FATAL .. code):addParam(msg))

	c:send(cmd)
	c:disconnect(adchpp.Util_REASON_PLUGIN)
end
