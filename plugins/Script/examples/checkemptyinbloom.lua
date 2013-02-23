local base = _G

-- Notifies a user he may have empty files in his share according to his BLOOM
-- Requires that the Bloom plugin is loaded

module("motd")
base.require('luadchpp')
local adchpp = base.luadchpp
base.require('luadchppbloom')
local badchpp = base.luadchppbloom

local autil = base.require('autil')

local bm = badchpp.getBM()

motd_1 = adchpp.getCM():signalState():connect(function(entity)
	if entity:getState() == adchpp.Entity_STATE_NORMAL then
		if bm:hasBloom(entity) and bm:hasTTH(entity,"LWPNACQDBZRYXW3VHJVCJ64QBZNGHOHHHZWCLNQ") then
			autil.reply(entity, "It's possible you have empty files in your share")
		end
	end
end)
