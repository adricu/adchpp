-- Simple history script that displays the last n history items
-- History is persisted across restarts

local base = _G

module("history")
base.require('luadchpp')
local adchpp = base.luadchpp

base.assert(base['access'], 'access.lua must be loaded and running before history.lua')
local access = base.access

-- Where to read/write history file - set to nil to disable persistent history
local history_file = adchpp.Util_getCfgPath() .. "history.txt"

local cm = adchpp.getCM()

local io = base.require('io')
local os = base.require('os')
local json = base.require('json')
local string = base.require('string')
local autil = base.require('autil')
local table = base.require('table')
local json = base.require('json')

local sm = adchpp.getSM()

local pos = 1
local messages_saved = true

local messages = {}

access.add_setting('history_max', {
	help = "number of messages to keep for +history",

	value = 500
})

access.add_setting('history_default', {
	help = "number of messages to display in +history if the user doesn't select anything else",

	value = 50
})

access.add_setting('history_method', {
	help = "strategy used by the +history script to record messages, restart the hub after the change, 1 = use a hidden bot, 0 = direct ADCH++ interface",

	value = 1
})

access.add_setting('history_prefix', {
	help = "prefix to put before each message in +history",

	value = "[%Y-%m-%d %H:%M:%S] "
})

local function get_items(c)
	local items = 1
	local user = access.get_user_c(c)
	local from = user.lastofftime
	if from then
		for hist, data in base.pairs(messages) do
			if data.htime > from then
				items = items + 1
			end
		end
	end
	return items
end

access.commands.history = {
	alias = { hist = true },

	command = function(c, parameters)
		local items
		if #parameters > 0 then
			items = base.tonumber(parameters) + 1
			if not items then
				return
			end
		else
			if access.get_level(c) > 0 then
				items = get_items(c)
			end
		end
		if not items then
			items = access.settings.history_default.value + 1
		end
		if items > access.settings.history_max.value then
			items = access.settings.history_max.value + 1
		end

		local s = 1

		if table.getn(messages) > access.settings.history_max.value then
			s = pos - access.settings.history_max.value + 1
		end

		if items < pos then
			s = pos - items + 1
		end

		local e = pos

		local msg = "Displaying the last " .. (e - s) .. " messages"

		while s <= e and messages[s] do
			msg = msg .. "\r\n" .. messages[s].message
			s = s + 1
		end

		autil.reply(c, msg)
	end,

	help = "[lines] - display main chat messages logged by the hub",

	user_command = {
		name = "Chat history",
		params = { autil.ucmd_line("Number of msg's to display (' ' means default or hist since last logoff for a regged user)") }
	}
}

local function save_messages()
	if not history_file then
		return
	end

	local s = 1
	local e = pos
	
	if table.getn(messages) >= access.settings.history_max.value then
		s = pos - access.settings.history_max.value
		e = table.getn(messages)
	end

	local f = io.open(history_file, "w")

	local list = {}
	while s <= e and messages[s] do
		table.insert(list, messages[s])
		s = s + 1
	end
	f:write(json.encode(list))
	f:close()
	messages = list
	pos = table.getn(messages) + 1
	messages_saved = true
end

local function load_messages()
	if not history_file then
		return
	end

	local f = io.open(history_file, "r")

	local str = f:read("*a")
	f:close()

	if #str == 0 then
		return false
	end

	local ok, list = base.pcall(json.decode, str)
	if not ok then
		log("Unable to decode history file: " .. list)
		return false
	end

	for k, v in base.pairs(list) do
		messages[k] = v
		pos = pos + 1
	end

end

local function to_save_messages()
	if not messages_saved then
		base.pcall(save_messages)
	end
end

local function parse(cmd)
	if cmd:getCommand() ~= adchpp.AdcCommand_CMD_MSG or cmd:getType() ~= adchpp.AdcCommand_TYPE_BROADCAST then
		return
	end

	local from = cm:getEntity(cmd:getFrom())
	if not from then
		return
	end

	local nick = from:getField("NI")
	if #nick < 1 then
		return
	end

	local now = os.date(access.settings.history_prefix.value)
	local message = now .. '<' .. nick .. '> ' .. cmd:getParam(0)
	messages[pos] = { message = message, htime = os.time() }
	pos = pos + 1

	messages_saved = false
end

base.pcall(load_messages)

if access.settings.history_method.value == 0 then
	history_1 = cm:signalReceive():connect(function(entity, cmd, ok)
		if not ok then
			return ok
		end

		parse(cmd)

		return true
	end)

else
	hidden_bot = cm:createBot(function(bot, buffer)
		parse(adchpp.AdcCommand(buffer))
	end)
	hidden_bot:setField('ID', hidden_bot:getCID():toBase32())
	hidden_bot:setField('NI', _NAME .. '-hidden_bot')
	hidden_bot:setField('DE', 'Hidden bot used by the ' .. _NAME .. ' script')
	hidden_bot:setFlag(adchpp.Entity_FLAG_HIDDEN)
	cm:regBot(hidden_bot)

	autil.on_unloaded(_NAME, function()
		hidden_bot:disconnect(adchpp.Util_REASON_PLUGIN)
	end)
end

save_messages_timer = sm:addTimedJob(900000, to_save_messages)
autil.on_unloading(_NAME, save_messages_timer)
