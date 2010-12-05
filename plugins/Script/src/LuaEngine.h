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

#ifndef LUAENGINE_H_
#define LUAENGINE_H_

#include <adchpp/forward.h>

#include "Engine.h"

struct lua_State;
class LuaScript;

class LuaEngine : public Engine {
public:
	LuaEngine(adchpp::Core &core);
	virtual ~LuaEngine();

	virtual Script* loadScript(const std::string& path, const std::string& filename, const ParameterMap& parameters);
	virtual void unloadScript(Script* script, bool force = false);

	virtual void getStats(std::string& str) const;

private:
	friend class LuaScript;

	bool call(const std::string& f, const std::string& arg);
	void loadScript_(const std::string& path, const std::string& filename, LuaScript* script);

	lua_State* l;

	std::vector<LuaScript*> scripts;
	adchpp::Core &core;
};
#endif /*LUAENGINE_H_*/
