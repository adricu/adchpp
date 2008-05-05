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

io = base.require('io')
os = base.require('os')
json = base.require('json')
string = base.require('string')
autil = base.require('autil')

local pos = 0

local messages = {}

local function idx(p)
	return (p % maxItems) + 1
end

local function onHistory(c, params, override)
	local items = defaultItems
	if(params:size() > 1) then
		items = tonumber(params[1])
		if not items then
			return autil.handled
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
	
	c:send(autil.info(msg))
	
	return autil.handled
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

local function onMSG(c, cmd)
	local nick = c:getField("NI")
	if #nick < 1 then
		return 0
	end
	
	local now = os.date(prefix)
	local message = now .. '<' .. nick .. '> ' .. cmd:getParam(0)
	messages[idx(pos)] = message
	pos = pos + 1
	
	base.pcall(save_messages)
	
	return 0
end

local function onReceive(c, cmd, override)

	-- Skip messages that have been handled by others
	if override ~= 0 then
		return 0
	end
	
	if cmd:getCommand() == adchpp.AdcCommand_CMD_MSG and cmd:getType() == adchpp.AdcCommand_TYPE_BROADCAST then
		return onMSG(c, cmd)
	end
end

base.pcall(load_messages)

c1 = adchpp.getPM():onCommand("history", onHistory)
c2 = adchpp.getCM():signalReceive():connect(onReceive)
