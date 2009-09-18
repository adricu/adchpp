-- Script to display a Message Of The Day when users connect.

local base = _G

module("motd")
base.require('luadchpp')
local adchpp = base.luadchpp

-- Where to read MOTD file
local file = adchpp.Util_getCfgPath() .. "motd.txt"

local io = base.require('io')
local string = base.require('string')
local autil = base.require('autil')

local motd

local function load_motd()
	local fp = io.open(file, "r")
	if not fp then
		base.print("Unable to open " .. file ..", MOTD not loaded")
		return
	end
	motd = fp:read("*a")
	fp:close()
end

base.pcall(load_motd)

motd_1 = adchpp.getCM():signalState():connect(function(entity)
	if motd and entity:getState() == adchpp.Entity_STATE_NORMAL then
		autil.reply(entity, motd)
	end
end)
