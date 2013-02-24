local base = _G

-- Notifies a user he may have empty files in his share according to his BLOOM
-- Requires that the Bloom plugin is loaded

module("checkempty")
base.require('luadchpp')
local adchpp = base.luadchpp
base.require('luadchppbloom')
local badchpp = base.luadchppbloom

local autil = base.require('autil')

local bm = badchpp.getBM()

checkempty = adchpp.getCM():signalState():connect(function(entity, oldstate)
	if oldstate == adchpp.Entity_STATE_DATA then
		if bm:hasBloom(entity) and bm:hasTTH(entity,"LWPNACQDBZRYXW3VHJVCJ64QBZNGHOHHHZWCLNQ") then
			autil.reply(entity, "It's possible you have empty files in your share")
		end
	end
end)
