-- Script to display a Message Of The Day when users connect.

local base = _G

module("motd")
base.require('luadchpp')
local adchpp = base.luadchpp

-- Where to read MOTD file
local file = adchpp.Util_getCfgPath() .. "motd.txt"

local io = base.require('io')
local string = base.require('string')
local aio = base.require('aio')
local autil = base.require('autil')

local motd

local function load_motd()
	local ok, str, err = aio.load_file(file)

	if err then
		adchpp.getLM():log(_NAME, 'MOTD loading: ' .. err)
	end
	if not ok then
		return
	end

	motd = str
end

load_motd()

motd_1 = adchpp.getCM():signalState():connect(function(entity)
	if motd and entity:getState() == adchpp.Entity_STATE_NORMAL then
		autil.reply(entity, motd)
	end
end)
