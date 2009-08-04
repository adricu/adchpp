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

#ifndef ADCHPP_ADCHPP_H
#define ADCHPP_ADCHPP_H

// --- Shouldn't have to change anything under here...

#ifndef _REENTRANT
# define _REENTRANT 1
#endif

#ifdef _MSC_VER

//disable the deprecated warnings for the CRT functions.
# define _CRT_SECURE_NO_DEPRECATE 1
# define _ATL_SECURE_NO_DEPRECATE 1
# define _CRT_NON_CONFORMING_SWPRINTFS 1

# pragma warning(disable: 4711) // function 'xxx' selected for automatic inline expansion
# pragma warning(disable: 4786) // identifier was truncated to '255' characters in the debug information
# pragma warning(disable: 4290) // C++ Exception Specification ignored
# pragma warning(disable: 4127) // constant expression
# pragma warning(disable: 4710) // function not inlined
# pragma warning(disable: 4503) // decorated name length exceeded, name was truncated

typedef signed __int8 int8_t;
typedef signed __int16 int16_t;
typedef signed __int32 int32_t;
typedef signed __int64 int64_t;

typedef unsigned __int8 uint8_t;
typedef unsigned __int16 uint16_t;
typedef unsigned __int32 uint32_t;
typedef unsigned __int64 uint64_t;

#endif

#if defined(_MSC_VER)
# define _LL(x) x##ll
# define _ULL(x) x##ull
# define I64_FMT "%I64d"
#elif defined(SIZEOF_LONG) && SIZEOF_LONG == 8
# define _LL(x) x##l
# define _ULL(x) x##ul
# define I64_FMT "%ld"
#else
# define _LL(x) x##ll
# define _ULL(x) x##ull
# define I64_FMT "%lld"
#endif

#ifdef _WIN32

# ifndef _WIN32_WINNT
#  define _WIN32_WINNT 0x0500
# endif
# ifndef WINVER
#  define WINVER 0x0500
# endif
# ifndef STRICT
#  define STRICT 1
# endif
# ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN 1
# endif

# define ADCHPP_VISIBLE
# ifdef BUILDING_ADCHPP
#  define ADCHPP_DLL __declspec(dllexport)
# else
#  define ADCHPP_DLL __declspec(dllimport)
# endif // DLLEXPORT

#include <winsock2.h>

#include <windows.h>
#include <tchar.h>

#else

# define ADCHPP_DLL __attribute__ ((visibility("default")))
# define ADCHPP_VISIBLE __attribute__ ((visibility("default")))

#endif

#include <sys/time.h>
#include <cerrno>
#include <cstdarg>
#include <cstddef>
#include <cstdio>
#include <cstring>

#include <string>
#include <vector>
#include <deque>
#include <list>
#include <functional>
#include <memory>
#include <algorithm>
#include <map>
#include <unordered_map>
#include <unordered_set>

#include <boost/intrusive_ptr.hpp>
#include <boost/noncopyable.hpp>

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
