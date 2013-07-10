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

-- Checking function
local checker = (function(entity)
	-- Only run the check in NORMAL state
	if entity:getState() == adchpp.Entity_STATE_NORMAL then
		-- If no bloom is available hasTTH has undefined behaviour
		if bm:hasBloom(entity) and bm:hasTTH(entity,"LWPNACQDBZRYXW3VHJVCJ64QBZNGHOHHHZWCLNQ") then
			autil.reply(entity, "It's possible you have empty files in your share")
		end
	end
end)

-- Checks for possible bllom update that may happen before getting into NORMAL
checkold = bm:signalBloomReady():connect(checker)

-- Checks for bloom updates happening after getting into NORMAL
checkempty = bm:signalBloomReady():connect(checker)
