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

#include "stdinc.h"
#include "LuaEngine.h"

#include "LuaScript.h"

#include <adchpp/Util.h>
#include <lua.h>

LuaEngine::LuaEngine() {
	
}

LuaEngine::~LuaEngine() {
	for_each(scripts.begin(), scripts.end(), DeleteFunction());
}

Script* LuaEngine::loadScript(const string& path, const string& filename, const ParameterMap&) {
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
