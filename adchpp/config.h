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

#ifndef ADCHPP_CONFIG_H
#define ADCHPP_CONFIG_H

namespace adchpp {
	
// Remove this line if hashes are not available in your stl
#define HAVE_HASH 1

// This enables stlport's debug mode (and slows it down to a crawl...)
//# define _STLP_DEBUG 1

// Set to zero to disable some old DC++ compatibility code
#define COMPATIBILITY 1

// --- Shouldn't have to change anything under here...

#ifndef _REENTRANT
# define _REENTRANT 1
#endif

#ifdef HAVE_STLPORT
# define _STLP_USE_PTR_SPECIALIZATIONS 1
# define _STLP_NO_ANACHRONISMS 1
# define _STLP_NO_CUSTOM_IO 1
# define _STLP_NO_IOSTREAMS 1
# define _STLP_USE_BOOST_SUPPORT 1
# ifndef _DEBUG
#  define _STLP_USE_TEMPLATE_EXPRESSION 1
#  define _STLP_DONT_USE_EXCEPTIONS 1
# endif
#endif

#ifdef _MSC_VER
# pragma warning(disable: 4711) // function 'xxx' selected for automatic inline expansion
# pragma warning(disable: 4786) // identifier was truncated to '255' characters in the debug information
# pragma warning(disable: 4290) // C++ Exception Specification ignored
# pragma warning(disable: 4127) // constant expression
# pragma warning(disable: 4710) // function not inlined
# pragma warning(disable: 4503) // decorated name length exceeded, name was truncated

typedef signed char int8_t;
typedef signed short int16_t;
typedef signed long int32_t;
typedef signed __int64 int64_t;

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned long uint32_t;
typedef unsigned __int64 uint64_t;

#endif

#if defined(_MSC_VER)
#define _LL(x) x##ll
#define _ULL(x) x##ull
#define I64_FMT "%I64d"
#elif defined(SIZEOF_LONG) && SIZEOF_LONG == 8
#define _LL(x) x##l
#define _ULL(x) x##ul
#define I64_FMT "%ld"
#else
#define _LL(x) x##ll
#define _ULL(x) x##ull
#define I64_FMT "%lld"
#endif

#ifdef _WIN32
# define ADCHPP_VISIBLE
# ifdef BUILDING_ADCHPP
#  define ADCHPP_DLL __declspec(dllexport)
# else
#  define ADCHPP_DLL __declspec(dllimport)
# endif // DLLEXPORT
#else
# define ADCHPP_DLL __attribute__ ((visibility("default")))
# define ADCHPP_VISIBLE __attribute__ ((visibility("default")))
#endif

}

#endif // CONFIG_H
