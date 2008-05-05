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

handled = adchpp.ClientManager_DONT_DISPATCH + adchpp.ClientManager_DONT_SEND
