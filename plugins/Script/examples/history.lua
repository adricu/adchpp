-- Simple history script that displays the last n history items
-- History is persisted across restarts

local base = _G

module("history")
base.require('luadchpp')
local adchpp = base.luadchpp

-- Options

-- Number of messages to keep
local maxItems = 500

-- Number of messages to display if user doesn't select anthing else
local defaultItems = 50

-- Prefix to put before each message (as seen by 
local prefix = "[%Y-%m-%d %H:%M:%S] "

-- Where to read/write history file - set to nil to disable persistent history
local history_file = adchpp.Util_getCfgPath() .. "history.txt"

local io = base.require('io')
local os = base.require('os')
local json = base.require('json')
local string = base.require('string')
local autil = base.require('autil')

local pos = 0

local messages = {}

local function idx(p)
	return (p % maxItems) + 1
end

local function onHistory(entity, params, ok)
	if not ok then
		return ok
	end

	local c = entity:asClient()
	if not c then
		return false
	end

	local items = defaultItems
	if params:size() > 1 then
		items = base.tonumber(params[1])
		if not items then
			return false
		end
	end

	local s = 0

	if items < pos then
		s = pos - items
	end

	local e = pos 
	local msg = "Displaying last " .. (e - s) .. " messages"

	while s ~= e and messages[idx(s)] do
		msg = msg .. "\r\n" .. messages[idx(s)]
		s = s + 1
	end

	autil.reply(c, msg)

	return false
end

local function save_messages()
	if not history_file then
		return
	end

	local s = 0
	local e = pos

	if pos >= maxItems then
		s = pos + 1
		e = pos + maxItems
	end

	local f = io.open(history_file, "w")

	while s ~= e and messages[idx(s)] do
		f:write(messages[idx(s)] .. "\n")
		s = s + 1
	end
	f:close()
end

local function load_messages()
	if not history_file then
		return
	end

	for line in io.lines(history_file) do
		messages[idx(pos)] = line
		pos = pos + 1
	end
end

local function onMSG(entity, cmd)
	local nick = entity:getField("NI")
	if #nick < 1 then
		return true
	end

	local now = os.date(prefix)
	local message = now .. '<' .. nick .. '> ' .. cmd:getParam(0)
	messages[idx(pos)] = message
	pos = pos + 1

	base.pcall(save_messages)

	return true
end

local function onReceive(entity, cmd, ok)
	-- Skip messages that have been handled by others
	if not ok then
		return ok
	end

	if cmd:getCommand() == adchpp.AdcCommand_CMD_MSG and cmd:getType() == adchpp.AdcCommand_TYPE_BROADCAST then
		return onMSG(entity, cmd)
	end
end

base.pcall(load_messages)

history_1 = adchpp.getPM():onCommand("history", onHistory)
history_2 = adchpp.getCM():signalReceive():connect(onReceive)
