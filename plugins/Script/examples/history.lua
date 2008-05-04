-- Simple history script that displays the last n history items
-- History is persisted across restarts

-- Options

-- Number of messages to keep
local maxItems = 500

-- Number of messages to display if user doesn't select anthing else
local defaultItems = 50

-- Prefix to put before each message (as seen by 
local prefix = "[%Y-%m-%d %H:%M:%S] "

require('luadchpp')
adchpp = luadchpp
io = require('io')
os = require('os')
json = require('json')
string = require('string')

local pos = 0

local messages = {}

local function idx(p)
	return (p % maxItems) + 1
end

local function onHistory(c, params, override)
	local items = defaultItems
	
	print("sz " .. params:size() .. " " .. params[0] .. " " .. params[1])
	local s = 0
	
	if items < pos then
		s = pos - items
	end
	
	local e = pos 
	local msg = "Displaying last " .. (e - s) .. " messages"
	
	while s ~= e and messages[idx(s)] do
		msg = msg .. messages[idx(s)]
		s = s + 1
	end
	
	local answer = adchpp.AdcCommand(adchpp.AdcCommand_CMD_MSG, adchpp.AdcCommand_TYPE_INFO, adchpp.AdcCommand_HUB_SID)
	answer:addParam(msg)
	c:send(answer)
	
	return adchpp.ClientManager_DONT_DISPATCH + adchpp.ClientManager_DONT_SEND
end

local function onMSG(c, cmd)
	local nick = c:getField("NI")
	if #nick < 1 then
		return 0
	end
	
	local now = os.date(prefix)
	local message = '\r\n' .. now .. ' <' .. nick .. '> ' .. cmd:getParam(0)
	messages[idx(pos)] = message
	pos = pos + 1
	
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

c1 = adchpp.getPM():onCommand("history", onHistory)
c2 = adchpp.getCM():signalReceive():connect(onReceive)
