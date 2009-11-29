-- Various utilities for adchpp

local base = _G

module("autil")

base.require('luadchpp')
local adchpp = base.luadchpp

-- Settings loaded and saved by the main script. Possible fields each setting can contain:
-- * alias: other names that can also be used to reach this setting.
-- * change: function called when the value has changed.
-- * help: information about this setting, displayed in +help cfg.
-- * value: the value of this setting, either a number or a string. [compulsory]
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

ucmd_sep = "\\" -- TODO should be '/' per the spec but DC++ uses '\'...

function ucmd_line(str)
	return "%[line:" .. str .. "]"
end

function info(m)
	return adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
	:addParam(m)
end

function reply(c, m)
	c:send(info(m))
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
