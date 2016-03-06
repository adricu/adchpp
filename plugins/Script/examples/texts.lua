-- Script to display the contents of text files:
-- * When users connect.
-- * On user commands.

-- TODO Command to reload texts.
-- TODO Allow customizing the texts via user commands.

local base = _G
module('texts')
local this = _NAME
base.require('luadchpp')
local adchpp = base.luadchpp
local aio = base.require('aio')
local autil = base.require('autil')

for _, dep in base.ipairs({ 'access' }) do
	base.assert(base[dep], dep .. '.lua must be loaded and running before ' .. this .. '.lua')
end

-- Store the texts and their settings here. Fields:
-- * label: The user-friendly title of this text.
-- * path: Where the text resides.
-- * user_command: Add a user-command for this text.
-- * user_connect: Display contents to users when they connect.
-- * text: The contents.
local texts = {}

texts.about = {
	label = 'About this hub',
	path = adchpp.Util_getCfgPath() .. 'about.txt',
	user_command = true,
	user_connect = true,
}

texts.motd = {
	label = 'Message of the day',
	path = adchpp.Util_getCfgPath() .. 'motd.txt',
	user_command = true,
	user_connect = true,
}

texts.rules = {
	label = 'Rules',
	path = adchpp.Util_getCfgPath() .. 'rules.txt',
	user_command = true,
	user_connect = true,
}

-- Load texts when the hub starts.
for text_name, text_info in base.pairs(texts) do
	local ok, str, err = aio.load_file(text_info.path)

	if not ok then
		adchpp.getLM():log(_NAME, 'Could not load the text for "' .. text_name .. '": ' .. err)
	end

	text_info.text = str
end

-- Register user commands.
for text_name, text_info in base.pairs(texts) do
	if text_info.user_command then
		base.access.commands[text_name] = {
			command = function(c)
				if text_info.text then
					autil.reply(c, text_info.text)
				else
					autil.reply(c, 'Sorry, this information is unavailable.')
				end
			end,
			help = 'Display "' .. text_info.label .. '"',
			user_command = { name = text_info.label },
		}
	end
end

-- Send texts when users connect.
texts_signal_state = adchpp.getCM():signalState():connect(function(entity)
	if entity:getState() == adchpp.Entity_STATE_NORMAL then
		for _, text_info in base.pairs(texts) do
			if text_info.user_connect and text_info.text then
				autil.reply(entity, text_info.text)
			end
		end
	end
end)
