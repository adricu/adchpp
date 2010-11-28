-- This script contains basic login right limits such as min/max slots, hubs, share etc

local base = _G

module("access.limits.lua")

base.require("luadchpp")
local adchpp = base.luadchpp
local access = base.require("access")
local autil = base.require("autil")

local settings = access.settings
local commands = access.commands
local level_op = access.level_op

local function log(message)
	lm:log(_NAME, message)
end

access.add_setting('maxhubscount', {
	alias = { maxhubs = true },

	change = recheck_info,

	help = "maximum number of connected hubs allowed, 0 = disabled",

	value = 0
})

access.add_setting('maxhubslotratio', {
	alias = { maxhsr = true },

	change = recheck_info,

	help = "maximum hub/slot ratio allowed, 0 = disabled",

	value = 0
})

access.add_setting('maxsharesize', {
	alias = { maxss = true },

	change = recheck_info,

	help = "maximum share size allowed in bytes, 0 = disabled",

	value = 0
})

access.add_setting('maxslots', {
	alias = { maxsl = true },

	change = recheck_info,

	help = "maximum number of opened upload slots allowed, 0 = disabled",

	value = 0
})

access.add_setting('minhubslotratio', {
	alias = { minhsr = true },

	change = recheck_info,

	help = "minimum hub/slot ratio required, 0 = disabled",

	value = 0
})

access.add_setting('minsharesize', {
	alias = { minss = true },

	change = recheck_info,

	help = "minimum share size allowed in bytes, 0 = disabled",

	value = 0
})

access.add_setting('minslots', {
	alias = { minsl = true },

	change = recheck_info,

	help = "minimum number of opened upload slots required, 0 = disabled",

	value = 0
})

local function onINF(c, cmd)
	if c:getLevel() >= level_op then
		return true
	end

	local ss = base.tonumber(c:getField("SS"))
	if ss then
		if settings.minsharesize.value > 0 and ss < settings.minsharesize.value then
			autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Your share size (" .. c:getField("SS") .. " B) is too low, the minimum required size is " .. base.tostring(settings.minsharesize.value) .. " bytes")
			return false
		end

		if settings.maxsharesize.value > 0 and ss > settings.minsharesize.value then
			autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Your share size (" .. c:getField("SS") .. " B) is too high, the maximum allowed size is " .. base.tostring(settings.minsharesize.value) .. " bytes")
			return false
		end
	end

	local sl = base.tonumber(c:getField("SL"))
	if sl then
		if settings.minslots.value > 0 and sl < settings.minslots.value then
			autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Your number of opened upload slots (" .. c:getField("SL") .. ") is too few, the minimum required number of slots is " .. base.tostring(settings.minslots.value))
			return false
		end

		if settings.maxslots.value > 0 and sl > settings.maxslots.value then
			autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Your number of opened upload slots (" .. c:getField("SL") .. ") is too high, the maximum allowed number of slots is " .. base.tostring(settings.maxslots.value))
			return false
		end
	end

	local h1 = base.tonumber(c:getField("HN"))
	local h2 = base.tonumber(c:getField("HR"))
	local h3 = base.tonumber(c:getField("HO"))
	local h
	if (h1 and h2 and h3) then
		h = base.tonumber(h1) + base.tonumber(h2) + base.tonumber(h3)
		if settings.maxhubscount.value > 0 and h > settings.maxhubscount.value then
			autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "The number of hubs you're connected to (" .. base.tostring(h) .. ") is too high, the maximum allowed hubs count is " .. base.tostring(settings.maxhubscount.value))
			return false
		end
	end

	if sl and h and sl > 0 and h > 0 then -- Correct hubcount may not arrive with the first info
		local r = sl / h
		if settings.minhubslotratio.value > 0 and r < settings.minhubslotratio.value then
			autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Your hubs/slots ratio (" .. base.tostring(r) .. ") is too low, you must open up more upload slots or disconnect from some hubs to achieve ratio " .. base.tostring(settings.minhubslotratio.value))
			return false
		end

		if settings.maxhubslotratio.value > 0 and r > settings.minhubslotratio.value then
			autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Your hubs/slots ratio (" .. base.tostring(r) .. ") is too high, you must lower your number of opened upload slots or connect to more hubs to achieve ratio " .. base.tostring(settings.maxhubslotratio.value))
			return false
		end
	end

	return true
end

access.register_handler(adchpp.AdcCommand_CMD_INF, onINF, true)

