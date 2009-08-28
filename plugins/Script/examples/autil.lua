-- Various utilities for adchpp

local base = _G

module("autil")

base.require('luadchpp')
local adchpp = base.luadchpp

-- Settings loaded and saved by the main script. Possible fields each setting can contain:
-- * alias: other names that can also be used to reach this setting.
-- * change: function called when the value has changed.
-- * help: information about this setting, displayed in +help cfg.
-- * value: the value of this setting. [compulsory]
settings = { }

-- List of +commands handled by the main script. Possible fields each command can contain:
-- * alias: other names that can also trigger this command.
-- * command: function(Client c, string parameters). [compulsory]
-- * help: information about this command, displayed in +help.
-- * helplong: detailed information about this command, displayed in +help command-name.
-- * protected: function(Client c) returning whether the command is to be shown in +help.
commands = { }

function info(m)
	local answer = adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
	answer:addParam(m)
	return answer
end

function reply(c, m)
	c:send(info(m))
end

function dump(c, code, msg)
	local answer = adchpp.AdcCommand(adchpp.AdcCommand_CMD_STA, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
	answer:addParam(adchpp.AdcCommand_SEV_FATAL .. code):addParam(msg)
	c:send(answer)
	c:disconnect(0)
end
