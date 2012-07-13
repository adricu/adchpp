-- This script contains settings and commands related to the bot. If this script is not loaded, the bot will not appear...
-- The main bot managed by this script is stored in the public "main_bot" variable.

local base=_G
module("access.bot")

base.require("luadchpp")
local adchpp = base.luadchpp
local access = base.require("access")
local autil = base.require("autil")

local settings = access.settings
local commands = access.commands
local cm = adchpp.getCM()

main_bot = nil

access.add_setting('botcid', {
	alias = { botid = true },

	help = "CID of the bot, restart the hub after the change",

	value = adchpp.CID_generate():toBase32(),

	validate = function(new)
		if adchpp.CID(new):isZero() then
			return "the CID must be a valid 39-byte base32 representation"
		end
	end
})

access.add_setting('botname', {
	alias = { botnick = true, botni = true },

	change = function()
		if main_bot then
			main_bot:setField("NI", settings.botname.value)
			cm:sendToAll(adchpp.AdcCommand(adchpp.AdcCommand_CMD_INF, adchpp.AdcCommand_TYPE_BROADCAST, main_bot:getSID()):addParam("NI", settings.botname.value):getBuffer())
		end
	end,

	help = "name of the hub bot",

	value = "Bot",

	validate = access.validate_ni
})

access.add_setting('botdescription', {
	alias = { botdescr = true, botde = true },

	change = function()
		if main_bot then
			main_bot:setField("DE", settings.botdescription.value)
			cm:sendToAll(adchpp.AdcCommand(adchpp.AdcCommand_CMD_INF, adchpp.AdcCommand_TYPE_BROADCAST, main_bot:getSID()):addParam("DE", settings.botdescription.value):getBuffer())
		end
	end,

	help = "description of the hub bot",

	value = "",

	validate = access.validate_de
})

access.add_setting('botemail', {
	alias = { botmail = true, botem = true },

	change = function()
		if main_bot then
			main_bot:setField("EM", settings.botemail.value)
			cm:sendToAll(adchpp.AdcCommand(adchpp.AdcCommand_CMD_INF, adchpp.AdcCommand_TYPE_BROADCAST, main_bot:getSID()):addParam("EM", settings.botemail.value):getBuffer())
		end
	end,

	help = "e-mail of the hub bot",

	value = ""
})

local function onMSG(c, cmd)
	if autil.reply_from and autil.reply_from:getSID() == main_bot:getSID() then

		local msg = cmd:getParam(0)
		if access.handle_plus_command(c, msg) then
			return false
		end

		autil.reply(c, 'Invalid command, send "+help" for a list of available commands')
		return false
	end

	return true
end

local function makeBot()
	local bot = cm:createSimpleBot()
	bot:setCID(adchpp.CID(settings.botcid.value))
	bot:setField("ID", settings.botcid.value)
	bot:setField("NI", settings.botname.value)
	bot:setField("DE", settings.botdescription.value)
	bot:setField("EM", settings.botemail.value)
	bot:setFlag(adchpp.Entity_FLAG_OP)
	bot:setFlag(adchpp.Entity_FLAG_SU)
	bot:setFlag(adchpp.Entity_FLAG_OWNER)
	return bot
end

main_bot = makeBot()
cm:regBot(main_bot)

autil.on_unloaded(_NAME, function()
	main_bot:disconnect(adchpp.Util_REASON_PLUGIN)
end)

access.register_handler(adchpp.AdcCommand_CMD_MSG, onMSG)
