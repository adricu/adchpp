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

local onINF -- forward declaration.

local function log(message)
	lm:log(_NAME, message)
end

local function recheck_info()
	local entities = adchpp.getCM():getEntities()
	local size = entities:size()
	if size > 0 then
		for i = 0, size - 1 do
			local c = entities[i]:asClient()
			if c then
				onINF(c, adchpp.AdcCommand(c:getINF()))
			end
		end
	end
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

onINF = function(c, cmd)
	if c:getLevel() >= level_op then
		return true
	end

	local ss = base.tonumber(cmd:getParam("SS", 0)) or base.tonumber(c:getField("SS"))
	if ss then
		if settings.minsharesize.value > 0 and ss < settings.minsharesize.value then
			autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Your share size (" .. adchpp.Util_formatBytes(ss) .. ") is too low, the minimum required size is " .. adchpp.Util_formatBytes(settings.minsharesize.value))
			return false
		end

		if settings.maxsharesize.value > 0 and ss > settings.minsharesize.value then
			autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Your share size (" .. adchpp.Util_formatBytes(ss) .. ") is too high, the maximum allowed size is " .. adchpp.Util_formatBytes(settings.minsharesize.value))
			return false
		end
	end

	local sl = base.tonumber(cmd:getParam("SL", 0)) or base.tonumber(c:getField("SL"))
	if sl then
		if settings.minslots.value > 0 and sl < settings.minslots.value then
			autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Your have too few upload slots open (" .. base.tostring(sl) .. "), the minimum required is " .. base.tostring(settings.minslots.value))
			return false
		end

		if settings.maxslots.value > 0 and sl > settings.maxslots.value then
			autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Your have too many upload slots open (" .. base.tostring(sl) .. "), the maximum allowed is " .. base.tostring(settings.maxslots.value))
			return false
		end
	end

	local h1 = base.tonumber(cmd:getParam("HN", 0)) or base.tonumber(c:getField("HN"))
	local h2 = base.tonumber(cmd:getParam("HR", 0)) or base.tonumber(c:getField("HR"))
	local h3 = base.tonumber(cmd:getParam("HO", 0)) or base.tonumber(c:getField("HO"))
	local h
	if (h1 and h2 and h3) then
		h = h1 + h2 + h3
		if settings.maxhubscount.value > 0 and h > settings.maxhubscount.value then
			autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "The number of hubs you're connected to (" .. base.tostring(h) .. ") is too high, the maximum allowed is " .. base.tostring(settings.maxhubscount.value))
			return false
		end
	end

	if sl and h and sl > 0 and h > 0 then -- The count may not be correct on the first INF
		local r = sl / h
		if settings.minhubslotratio.value > 0 and r < settings.minhubslotratio.value then
			autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Your hubs/slots ratio (" .. base.tostring(r) .. ") is too low, you must open up more upload slots or disconnect from some hubs to achieve a ratio of " .. base.tostring(settings.minhubslotratio.value))
			return false
		end

		if settings.maxhubslotratio.value > 0 and r > settings.minhubslotratio.value then
			autil.dump(c, adchpp.AdcCommand_ERROR_PROTOCOL_GENERIC, "Your hubs/slots ratio (" .. base.tostring(r) .. ") is too high, you must reduce your open upload slots or connect to more hubs to achieve a ratio of " .. base.tostring(settings.maxhubslotratio.value))
			return false
		end
	end

	return true
end

access.register_handler(adchpp.AdcCommand_CMD_INF, onINF)

