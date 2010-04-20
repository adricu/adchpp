/* 
 * Copyright (C) 2006-2010 Jacek Sieka, arnetheduck on gmail point com
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

#include "stdinc.h"
#include "LuaEngine.h"

#include "LuaScript.h"

#include <adchpp/PluginManager.h>
#include <adchpp/File.h>
#include <adchpp/Util.h>

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

using namespace std;

namespace {
	void prepare_cpath(lua_State* L, const string& path) {
		lua_getfield(L, LUA_GLOBALSINDEX, "package");
		if (!lua_istable(L, -1)) {
			lua_pop(L, 1);
			return;
		}
		lua_getfield(L, -1, "cpath");
		if (!lua_isstring(L, -1)) {
			lua_pop(L, 2);
			return;
		}
		
		string oldpath = lua_tostring(L, -1);
		oldpath += ";" + path + "?.so";
		lua_pushstring(L, oldpath.c_str());
		lua_setfield(L, -3, "cpath");
		
		// Pop table
		lua_pop(L, 2);
	}

	void setScriptPath(lua_State* L, const string& path) {
		lua_pushstring(L, path.c_str());
		lua_setglobal(L, "scriptPath");
	}
}

LuaEngine::LuaEngine() {
	l = lua_open();
	luaL_openlibs(l);

	prepare_cpath(l, PluginManager::getInstance()->getPluginPath());

	setScriptPath(l, Util::emptyString);
}

LuaEngine::~LuaEngine() {
	for_each(scripts.begin(), scripts.end(), DeleteFunction());

	if(l)
		lua_close(l);
}

Script* LuaEngine::loadScript(const string& path, const string& filename, const ParameterMap&) {
	setScriptPath(l, File::makeAbsolutePath(path));

	LuaScript* script = new LuaScript(this);
	script->loadFile(path, filename);
	scripts.push_back(script);
	return script;
}

void LuaEngine::unloadScript(Script* s) {
	scripts.erase(remove(scripts.begin(), scripts.end(), s), scripts.end());
	delete s;
}

void LuaEngine::getStats(string& str) const {
	str += "The following LUA scripts are loaded:\n";
	for(vector<LuaScript*>::const_iterator i = scripts.begin(); i != scripts.end(); ++i) {
		(*i)->getStats(str);
	}
}
