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

#ifndef LUACOMMON_H_
#define LUACOMMON_H_

namespace {
	
template<typename T>
struct pointer_wrapper {
	pointer_wrapper() : t(0) { }
	explicit pointer_wrapper(T* t_) : t(t_) { }
	
	operator T*() { return t; }
	T* t;
};
}
namespace luabind {
	template<typename T>
	pointer_wrapper<const T>*
	get_const_holder(pointer_wrapper<T>*) { return 0; }
	template<typename T>
	T* get_pointer(pointer_wrapper<T>& p) {
		return (T*)p;
	}
}

#include <luabind/luabind.hpp>

#endif /*LUACOMMON_H_*/
