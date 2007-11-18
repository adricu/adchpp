/* 
 * Copyright (C) 2006-2007 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef ADCHPP_RESOURCEMANAGER_H
#define ADCHPP_RESOURCEMANAGER_H

#include "Singleton.h"

namespace adchpp {
	
/**
 * This class takes care of internationalization, providing the correct strings.
 */
class ResourceManager : public Singleton<ResourceManager> {
public:
	
#include "StringDefs.h"

	void loadLanguage(const std::string& aFile);
	const std::string& getString(Strings x) const { return strings[x]; }

private:

	friend class Singleton<ResourceManager>;
	
	ADCHPP_DLL static ResourceManager* instance;
	
	ResourceManager() throw() { }
	virtual ~ResourceManager() throw() { }
	
	ADCHPP_DLL static std::string strings[LAST];
	static std::string names[LAST];

	static const std::string className;
};

#define STRING(x) ResourceManager::getInstance()->getString(ResourceManager::x)
#define CSTRING(x) ResourceManager::getInstance()->getString(ResourceManager::x).c_str()

}

#endif // RESOURCEMANAGER_H
