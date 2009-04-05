-- Various utilities for adchpp

local base = _G

module("autil")

base.require('luadchpp')
local adchpp = base.luadchpp

function info(m)
	local answer = adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
	answer:addParam(m)
	return answer
end

function reply(c, m)
	c:send(info(m))
end

function dump(c, code, msg)
	answer = adchpp.AdcCommand(adchpp.AdcCommand_CMD_STA, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
	answer:addParam("" .. tostring(adchpp.AdcCommand_SEV_FATAL) .. code):addParam(msg)
	c:send(answer)
	c:disconnect(0)
end

handled = false
