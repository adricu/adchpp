/* 
 * Copyright (C) 2006-2009 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef LUASCRIPT_H_
#define LUASCRIPT_H_

#include "Script.h"

class Engine;
class LuaEngine;

class LuaScript : public Script {
public:
	LuaScript(Engine* engine);
	virtual ~LuaScript();

	void loadFile(const std::string& path, const std::string& filename);	
	
	void getStats(std::string& str) const;
	
	static const std::string className;

private:
	LuaEngine* getEngine() const;
	std::string filename;
};

#endif /*LUASCRIPT_H_*/
