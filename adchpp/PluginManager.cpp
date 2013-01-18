/*
 * Copyright (C) 2006-2013 Jacek Sieka, arnetheduck on gmail point com
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include "adchpp.h"

#include "PluginManager.h"

#include "SimpleXML.h"
#include "LogManager.h"
#include "SocketManager.h"
#include "version.h"
#include "File.h"
#include "Text.h"
#include "Core.h"

#ifdef _WIN32

#define PLUGIN_EXT _T(".dll")

#define PM_LOAD_LIBRARY(filename) ::LoadLibrary(filename)
#define PM_UNLOAD_LIBRARY(lib) ::FreeLibrary(lib)
#define PM_GET_ADDRESS(lib, name) ::GetProcAddress(lib, name)
#define PM_GET_ERROR_STRING() Util::translateError(GetLastError())

#else

#include "dlfcn.h"

#define PLUGIN_EXT ".so"

#define PM_LOAD_LIBRARY(filename) ::dlopen(filename, RTLD_LAZY | RTLD_GLOBAL)
#define PM_UNLOAD_LIBRARY(lib) ::dlclose(lib)
#define PM_GET_ADDRESS(lib, name) ::dlsym(lib, name)
#define PM_GET_ERROR_STRING() ::dlerror()

#endif

namespace adchpp {

using namespace std;
using std::placeholders::_1;

const string PluginManager::className = "PluginManager";

PluginManager::PluginManager(Core &core) throw() : core(core) {

}

void PluginManager::attention(const function<void()>& f) {
	core.addJob(f);
}

void PluginManager::load() {
	for(StringIter i = plugins.begin(); i != plugins.end(); ++i) {
		loadPlugin(*i + PLUGIN_EXT);
	}
}

bool PluginManager::loadPlugin(const string& file) {
	if(file.length() < 3) {
		return false;
	}
	plugin_t h;

#ifndef _WIN32
	if(!File::isAbsolutePath(file)) {
		h = PM_LOAD_LIBRARY((pluginPath + file).c_str());
	} else {
		h = PM_LOAD_LIBRARY(file.c_str());
	}
#else
	if(!File::isAbsolutePath(file)) {
		h = LoadLibraryEx((pluginPath + file).c_str(), NULL, DONT_RESOLVE_DLL_REFERENCES);
	} else {
		h = LoadLibraryEx(file.c_str(), NULL, DONT_RESOLVE_DLL_REFERENCES);
	}
#endif

	if(h == NULL) {
		LOG(className, "Failed to load " + Text::utf8ToAcp(file) + ": " + PM_GET_ERROR_STRING());
		return false;
	}

	PLUGIN_GET_VERSION v = (PLUGIN_GET_VERSION)PM_GET_ADDRESS(h, "pluginGetVersion");
	if(v != NULL) {
		double ver = v();
		if(ver == PLUGINVERSION) {
#ifdef _WIN32
			// Reload plugin with references resolved...
			FreeLibrary(h);
			if(!File::isAbsolutePath(file)) {
				h = PM_LOAD_LIBRARY((pluginPath + file).c_str());
			} else {
				h = PM_LOAD_LIBRARY(file.c_str());
			}
			if(h == NULL) {
				LOG(className, "Failed to load " + Text::utf8ToAcp(file) + ": " + PM_GET_ERROR_STRING());
				return false;
			}
#endif
			PLUGIN_LOAD l = (PLUGIN_LOAD)PM_GET_ADDRESS(h, "pluginLoad");
			PLUGIN_UNLOAD u = (PLUGIN_UNLOAD)PM_GET_ADDRESS(h, "pluginUnload");

			if(l != NULL && u != NULL) {
				int i = l(this);
				if(i != 0) {
					LOG(className, "Failed to load plugin " + Text::utf8ToAcp(file) + " (Error " + Util::toString(i) + ")");
				} else {
					// Wonderful, we have a plugin...
					active.push_back(PluginInfo(h, v, l, u));
					LOG(className, Text::utf8ToAcp(file) + " loaded");
					return true;
				}
			} else {
				LOG(className, Text::utf8ToAcp(file) + " is not a valid ADCH++ plugin");
			}
		} else {
			LOG(className, Text::utf8ToAcp(file) + " is for another version of ADCH++ (" + Util::toString(ver) + "), please get the correct one from the author");
		}
	} else {
		LOG(className, Text::utf8ToAcp(file) + " is not a valid ADCH++ plugin");
	}

	PM_UNLOAD_LIBRARY(h);
	return false;
}

void PluginManager::shutdown() {
	registry.clear();

	for(PluginList::reverse_iterator i = active.rbegin(); i != active.rend(); ++i)
		i->pluginUnload();
#ifndef HAVE_BROKEN_MTALLOC
	for(PluginList::reverse_iterator i = active.rbegin(); i != active.rend(); ++i)
		PM_UNLOAD_LIBRARY(i->handle);
#endif
	active.clear();
}

PluginManager::CommandDispatch::CommandDispatch(PluginManager& pm, const std::string& name_, const PluginManager::CommandSlot& f_) :
name('+' + name_),
f(f_),
pm(&pm)
{
}

void PluginManager::CommandDispatch::operator()(Entity& e, AdcCommand& cmd, bool& ok) {
	if(e.getState() != Entity::STATE_NORMAL) {
		return;
	}

	if(cmd.getCommand() != AdcCommand::CMD_MSG) {
		return;
	}

	if(cmd.getParameters().size() < 1) {
		return;
	}

	StringList l;
	Util::tokenize(l, cmd.getParameters()[0], ' ');
	if(l[0] != name) {
		return;
	}

	l[0] = name.substr(1);

	if(!pm->handleCommand(e, l)) {
		return;
	}

	cmd.setPriority(AdcCommand::PRIORITY_IGNORE);
	f(e, l, ok);
}

ClientManager::SignalReceive::Connection PluginManager::onCommand(const std::string& commandName, const CommandSlot& f) {
	return core.getClientManager().signalReceive().connect(CommandDispatch(*this, commandName, f));
}

PluginManager::CommandSignal& PluginManager::getCommandSignal(const std::string& commandName) {
	CommandHandlers::iterator i = commandHandlers.find(commandName);
	if(i == commandHandlers.end())
		return commandHandlers.insert(make_pair(commandName, CommandSignal())).first->second;

	return i->second;
}

bool PluginManager::handleCommand(Entity& e, const StringList& l) {
	CommandHandlers::iterator i = commandHandlers.find(l[0]);
	if(i == commandHandlers.end())
		return true;

	bool ok = true;
	i->second(e, l, ok);
	return ok;
}

Core &PluginManager::getCore() { return core; }
}
