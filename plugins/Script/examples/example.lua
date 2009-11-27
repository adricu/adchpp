-- This is an example script that scripters might want to use as a basis for their work. It
-- documents the bare minimum needed to make an Lua script interface with ADCH++.

-- For more detailed information, peeking into other, more evolved (but less documented) example
-- scripts as well as the Doxygen documentation of ADCH++ <http://adchpp.sourceforge.net/doc> would
-- be a good idea.

-- Generally, to reach member "bar" of the class "foo" of ADCH++, one has to use: adchpp.foo_bar.
-- Examples: adchpp.Util_getCfgPath(), adchpp.AdcCommand_CMD_MSG, adchpp.Entity_STATE_NORMAL...

-- When manipulating Entity objects, it can be useful to convert them to Client objects (which
-- are aware of socket features such as a send method) by using:
-- local client = entity:asClient()

-- Feel free to use <https://answers.launchpad.net/adchpp> or <www.adcportal.com> if you need help.

-- The global functions of Lua are privately imported into "base"; therefore, be sure to always
-- reference it when calling these functions; eg base.print("blah"), base.pcall(protected_func)...
local base = _G

module("example") -- Give each module a unique name so they don't clash.

-- Import the ADCH++ Lua DLL (luadchpp.dll).
base.require('luadchpp')
local adchpp = base.luadchpp

-- Import various base sets of Lua methods. Only import those you need for your specific module.
local io = base.require('io')
local math = base.require('math')
local os = base.require('os')
local string = base.require('string')
local table = base.require('table')

-- Import some utilitary Lua Scripts; these don't need to be explicitly loaded by ADCH++ (eg if
-- using the adchppd daemon, they don't need to be referenced in Scripts.xml).
local autil = base.require('autil')
local json = base.require('json')

-- Cache pointers to some managers of ADCH++ that we frequently use.
local cm = adchpp.getCM() -- ClientManager
local pm = adchpp.getPM() -- PluginManager

-- Listeners to connect to ADCH++. Define one unique identifier for each listener (i chose to call
-- them example_1, example_2 and so on) to make sure the variable holding the listener doesn't get
-- collected by Lua's garbage collector until the program is over.

-- ClientManager::signalConnected: called after an Entity entity has connected.
example_1 = cm:signalConnected():connect(function(entity)
	-- Process signalConnected here.
end)

-- ClientManager::signalReceive: called when an AdcCommand cmd is received from Entity entity.
example_2 = cm:signalReceive():connect(function(entity, cmd, ok)
	local res = (function(entity, cmd, ok)
		if not ok then
			return ok
		end
		-- Process signalReceive here.
		-- Return true to let the command be dispatched, false to block it.
	end)(entity, cmd, ok)
	if not res then
		cmd:setPriority(adchpp.AdcCommand_PRIORITY_IGNORE)
	end
	return res
end)

-- ClientManager::signalState: called after the state of an online Entity entity has changed.
example_3 = cm:signalState():connect(function(entity)
	-- Process signalState here.
end)

-- ClientManager::signalDisconnected: called after an Entity entity has disconnected.
example_4 = cm:signalDisconnected():connect(function(entity)
	-- Process signalDisconnected here.
end)

-- PluginManager::getCommandSignal(string): called when a +command managed by another plugin is
-- being executed.
example_5 = pm:getCommandSignal("blah"):connect(function(entity, list, ok)
	if not ok then
		return ok
	end
	-- Process getCommandSignal here.
	-- Return true to let the command be executed, false to block it.
end)
