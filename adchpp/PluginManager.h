/* 
 * Copyright (C) 2006 Jacek Sieka, arnetheduck on gmail point com
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

/**
 * @page PluginAPI Plugin API Information
 * @section General General
 * 
 * ADCH++ contains a rather powerful plugin API that can be used to create advanced
 * plugins that change or add to ADCH++'s behaviour. Most plugins will need
 * PluginManager.h, ClientManager. and Client.h included to work, even though the 
 * other header files are available as well (they're more likely to change in future 
 * versions though). You can use any method that is declared as DLL or is inline, the 
 * others are meant to be internal to ADCH++, very likely to change/disappear and will
 * generate link errors (when compiling under windows anyway). When starting a plugin
 * project I strongly recommend that you take one of the existing plugins and modify
 * it to your needs (to get all compiler settings and base code right).
 * 
 * @section Versions Versions
 *
 * Due to C++ name mangling, plugins are generally valid only for a certain version
 * of the ADCH++ plugin API. This version usually follows the main ADCH++ version,
 * unless a small update is made that I judge shouldn't affect plugins in any way.
 * Most of the time, recompiling the plugin should be enough, unless any major changes
 * have been made, and your plugin doesn't rely on the nasty internals. As to compilers,
 * the windows version is compiled using Visual C++ 7.1 (.NET), with various optimizations
 * enabled. In theory, VC6 should work as well, as I haven't seen any information about
 * changes in the name mangling scheme, but if you get strange linker errors, don't
 * blame me. For best results, make sure you have the same settings. The Linux version
 * is compiled with G++ 3.4.x, and I don't have a clue if older versions will work
 * (probably not...).
 *
 * @section Threads Threads
 *
 * ADCH++ has two main threads running when operating. One handles all network
 * communication while the other does all other work (handle protocol data and
 * so on). All plugins are run in the worker thread, which is the only thread 
 * visible to the API. You are only allowed to interact with ADCH++ from this
 * thread, as none of the API is thread safe (this is a performance issue, this way
 * no locks are taken), unless otherwise noted. This has a few important 
 * consequences. First off, you can assume that your plugin will only be called
 * by this thread, which means that you don't have to worry about multithreading
 * issues unless you start threads by yourself. Second, any work you do in a plugin
 * halts <b>all</b> of ADCH++'s processing (apart from receiving/sending buffered
 * data), in other words, don't do any lengthy processing in the on methods, as
 * the whole of ADCH++ will suffer. Third, if you indeed start another thread, make
 * sure you don't use any API functions from it apart from those explicitly marked
 * as thread safe. To indicate from a plugin that you have work to do in the main
 * worker thread, call PluginManager::attention(). This will generate an 
 * Attention event in the near future, where your thread can do its work (be
 * careful though, the Attention event might be raised by other plugins).
 */

#ifndef ADCHPP_PLUGINMANAGER_H
#define ADCHPP_PLUGINMANAGER_H

#include "Singleton.h"
#include "version.h"
#include "Signal.h"

namespace adchpp {
	
class SimpleXML;

#ifdef _WIN32

#ifdef BUILDING_ADCHPP
#define PLUGIN_API 
#else
#define PLUGIN_API __declspec(dllexport)
#endif

typedef HMODULE plugin_t;

#else // WIN32

#ifdef BUILDING_ADCHPP
#define PLUGIN_API
#else
#define PLUGIN_API __attribute__ ((visibility("default")))
#endif

typedef void* plugin_t;

#endif // WIN32

/**
 * Public plugin interface, for plugin intercom.
 * Plugins that register a public interface must inherit from this class.
 * Plugins requesting another plugins interface will get a pointer to this
 * class and must upcast it (using dynamic_cast<> and check NULL to be safe).
 */
class Plugin {
public:
	Plugin() { }
	virtual ~Plugin() { }
	/** @return API version for a plugin (incremented every time API changes) */
	virtual int getVersion() = 0;
};

/**
 * PLUGIN_API double pluginGetVersion()
 * This function should just return the constant PLUGINVERSIONFLOAT
 * so that the pluginmanager can determine if this plugin should
 * be loaded or not
 */
typedef int (*PLUGIN_GET_VERSION)();

/**
 * PLUGIN_API void pluginLoad()
 * This function is called when the hub is starting up and loading the plugin.
 * Here you should load any data your plugin might need and connect to any
 * Managers you might be interested in. Note; you also have to connect to
 * PluginManager itself to receive its events.
 * @return 0 if the plugin was loaded ok, != 0 otherwise (the number will be logged, 
 * use as error code). Plugin dll will get unloaded without calling pluginUnload if the return
 * value is not 0 here.
 * @see pluginUnload
 */
typedef int (*PLUGIN_LOAD)();

/**
 * PLUGIN_API void pluginUnload()
 * Called when the hub is shutting down
 * @see pluginLoad
 */
typedef void (*PLUGIN_UNLOAD)();

class PluginManager : public Singleton<PluginManager>
{
public:
	typedef HASH_MAP<string, Plugin*> Registry;
	typedef Registry::iterator RegistryIter;

	/**
	 * Get a list of currently loaded plugins
	 */
	const StringList& getPluginList() const {
		return plugins;
	}

	/**
	 * Get the plugin path as set in adchpp.xml
	 */
	const string& getPluginPath() const {
		return pluginPath;
	}

	/**
	 * This function returns a unique identifier for a plugin, to
	 * be used in other parts of ADCH++, PSD's in Client for example.
	 * Note; Only call this once per plugin, the internal routines
	 * are optimised for low memory usage, not handling many different
	 * plugin id's (I might add a check in the future...).
	 */
	int getPluginId() { return pluginIds++; }

	/**
	 * Register a plugin interface under a name.
	 * @return false if name was already registered and call fails
	 */
	bool registerPlugin(const string& name, Plugin* ptr) {
		return 	registry.insert(make_pair(name, ptr)).second;
	}
	
	/** @return True if the plugin existed and was thus unregistered */
	bool unregisterPlugin(const string& name) {
		return registry.erase(name) > 0;
	}
	
	/**
	 * @return Plugin interface, or NULL if not found
	 */
	Plugin* getPlugin(const string& name) {
		RegistryIter i = registry.find(name);
		return i == registry.end() ? NULL : i->second;
	}
	
	/**
	 * The full map of registered plugins.
	 */
	const Registry& getPlugins() {
		return registry;
	}
		
	/** @internal */
	void load() {
		for(StringIter i = plugins.begin(); i != plugins.end(); ++i) {
			loadPlugin(*i);
		}
	}
	/** @internal */
	void shutdown();

private:
	virtual ~PluginManager() throw();

	class PluginInfo {
	public:

		PluginInfo(plugin_t h, PLUGIN_GET_VERSION v, PLUGIN_LOAD l, PLUGIN_UNLOAD u) :
		handle(h), pluginGetVersion(v), pluginLoad(l), pluginUnload(u) { }
		
		plugin_t handle;
		PLUGIN_GET_VERSION pluginGetVersion;
		PLUGIN_LOAD pluginLoad;
		PLUGIN_UNLOAD pluginUnload;
	};

	friend class Singleton<PluginManager>;
	ADCHPP_DLL static PluginManager* instance;

	typedef vector<PluginInfo> PluginList;
	typedef PluginList::iterator PluginIter;

	PluginList active;
	Registry registry;

	StringList plugins;
	string pluginPath;

	int pluginIds;
	
	static const string className;
	
	PluginManager() throw();
	
	bool loadPlugin(const string& file);
	
	void onLoad(const SimpleXML& xml) throw();
};

}

#endif // PLUGINMANAGER_H
