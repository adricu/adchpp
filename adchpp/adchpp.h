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

#ifndef ADCHPP_ADCHPP_H
#define ADCHPP_ADCHPP_H

#include "config.h"

#ifdef _WIN32

#ifndef STRICT
#define STRICT 1
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN 1
#endif

#include <Winsock2.h>

#include <windows.h>
#include <tchar.h>

#else
#include <unistd.h>
#endif

#include <stdio.h>
#include <stdarg.h>
#include <memory.h>
#include <sys/types.h>
#include <time.h>
#include <sys/stat.h>
#include <errno.h>
#include <string.h>

#include <algorithm>
#include <vector>
#include <string>
#include <map>
//#include <set>
#include <list>
#include <deque>
#include <functional>

#include <boost/function.hpp>
#include <boost/utility.hpp>

// Use maps if hash_maps aren't available
#ifdef HAVE_HASH
# ifdef _STLPORT_VERSION
#  define HASH_MAP_X(key, type, hfunc, eq, order) hash_map<key, type, hfunc, eq >
#  define HASH_MULTIMAP_X(key, type, hfunc, eq, order) hash_multimap<key, type, hfunc, eq >
# elif defined(__GLIBCPP__) || defined(__GLIBCXX__)  // Using GNU C++ library?
#  define HASH_MAP_X(key, type, hfunc, eq, order) hash_map<key, type, hfunc, eq >
#  define HASH_MULTIMAP_X(key, type, hfunc, eq, order) hash_multimap<key, type, hfunc, eq >
# elif defined(_MSC_VER)  // Assume the msvc 7.x stl
#  define HASH_MAP_X(key, type, hfunc, eq, order) hash_map<key, type, hfunc >
#  define HASH_MULTIMAP_X(key, type, hfunc, eq, order) hash_multimap<key, type, hfunc >
# else
#  error Unknown STL, hashes need to be configured
# endif

# define HASH_SET hash_set
# define HASH_MAP hash_map
# define HASH_MULTIMAP hash_multimap

#else // HAVE_HASH

# define HASH_SET set
# define HASH_MAP map
# define HASH_MAP_X(key, type, hfunc, eq, order) map<key, type, order >
# define HASH_MULTIMAP multimap
# define HASH_MULTIMAP_X(key, type, hfunc, eq, order) multimap<key, type, order >

#endif // HAVE_HASH

#ifdef _STLPORT_VERSION
using namespace std;
#include <hash_set>
#include <hash_map>

#elif defined(__GLIBCPP__) || defined(__GLIBCXX__)  // Using GNU C++ library?
#include <ext/hash_set>
#include <ext/hash_map>
                                                                                
using namespace std;
using namespace __gnu_cxx;
                                                                                
// GNU C++ library doesn't have hash(std::string) or hash(long long int)
namespace __gnu_cxx {
	template<> struct hash<std::string> {
		size_t operator()(const std::string& x) const
			{ return hash<const char*>()(x.c_str()); }
	};
	template<> struct hash<long long int> {
		size_t operator()(long long int x) const { return x; }
	};
}
#else // __GLIBCPP__

#include <hash_set>
#include <hash_map>
using namespace std;
using namespace stdext;

#endif // __GLIBCPP__

#ifdef _UNICODE
# ifndef _T
#  define _T(s) L##s
# endif
#else
# ifndef _T
#  define _T(s) s
# endif
#endif

#endif // STDINC_H
