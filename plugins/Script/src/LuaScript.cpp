/* 
 * Copyright (C) 2006-2012 Jacek Sieka, arnetheduck on gmail point com
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
#include "LuaScript.h"

#include "LuaEngine.h"

#include <adchpp/File.h>
#include <adchpp/LogManager.h>
#include <adchpp/Util.h>

#ifdef _WIN32
#include <direct.h>
#else
#ifndef MAX_PATH
#define MAX_PATH PATH_MAX
#endif

#endif

extern "C" {
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
}

using namespace std;

const string LuaScript::className = "LuaScript";

LuaScript::LuaScript(Engine* engine) : Script(engine) {
}

LuaScript::~LuaScript() {
	getEngine()->call("unloaded", filename);
}

void LuaScript::loadFile(const string& path, const string& filename_) {
	filename = filename_;
	char old_dir[MAX_PATH];
	if(!getcwd(old_dir, MAX_PATH)) {
		old_dir[0] = 0;
	}

	auto absPath = File::makeAbsolutePath(path);
	if(chdir(absPath.c_str()) != 0) {
		//LOG(className, "Unable to change to directory " + absPath);
	} else {
		int error = luaL_loadfile(getEngine()->l, filename.c_str()) || lua_pcall(getEngine()->l, 0, 0, 0);

		if(error) {
			fprintf(stderr, "Error loading file: %s\n", lua_tostring(getEngine()->l, -1));
			//LOG(className, string("Error loading file: ") + lua_tostring(getEngine()->l, -1));
		} else {
			//LOG(className, "Loaded " + filename);
			getEngine()->call("loaded", filename);
		}

		if(old_dir[0]) {
			chdir(old_dir);
		}
	}
}

void LuaScript::getStats(string& str) const {
	str += filename + "\n";
}

LuaEngine* LuaScript::getEngine() const {
	return static_cast<LuaEngine*>(engine);
}

