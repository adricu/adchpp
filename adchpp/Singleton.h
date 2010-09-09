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

#ifndef ADCHPP_SINGLETON_H
#define ADCHPP_SINGLETON_H

#include "common.h"

namespace adchpp {
	
/**
 * @bug
 * Plugins instantiating this class must provide the instance variable manually because
 * of DLL linking issues on mingw (otherwise it seems each DLL gets their own instance).
 */
template<typename T>
class Singleton {
public:
	Singleton() { }
	virtual ~Singleton() { }

	static T* getInstance() {
		dcassert(T::instance);
		return T::instance;
	}
	
	static void newInstance() {
		if(T::instance)
			delete T::instance;
		
		T::instance = new T();
	}
	
	static void deleteInstance() {
		delete T::instance;
		T::instance = NULL;
	}
private:
	Singleton(const Singleton&);
	Singleton& operator=(const Singleton&);

};

}

#endif // SINGLETON_H
