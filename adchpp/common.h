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

/**
 * @mainpage
 *
 * ADCH++ is a server application meant to be used in the Direct Connect network,
 * released under the GPL-2 license.
 *
 * There's a plugin API about which you can find some general
 * information on the @ref PluginAPI page.
 *
 * Copyright (C) 2006-2010 Jacek Sieka, arnetheduck on gmail point com
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * Please see License.txt for full details regarding licensing.
 */

#ifndef ADCHPP_COMMON_H
#define ADCHPP_COMMON_H

namespace adchpp {

extern ADCHPP_DLL const char compileTime[];
extern ADCHPP_DLL void logAssert(const char* file, int line, const char* exp);

#ifndef NDEBUG

inline void debugTrace(const char* format, ...)
{
	va_list args;
	va_start(args, format);

#ifdef _MSC_VER
	char buf[512];

	_vsnprintf(buf, sizeof(buf), format, args);
	OutputDebugStringA(buf);
	fputs(buf, stderr);
#else // _MSC_VER
	vfprintf(stdout, format, args);
#endif // _MSC_VER
	va_end(args);
}

#define dcdebug debugTrace
#define dcassert(exp) do { if(!(exp)) logAssert(__FILE__, __LINE__, #exp); } while(false)
//#define dcassert(exp) do { if(!(exp)) __asm { int 3}; } while(0)

#define dcasserta(exp) dcassert(exp)
#define dcdrun(exp) exp
#else //NDEBUG
#define dcdebug if(false) printf
//#define dcassert(exp) do { if(!(exp)) logAssert(__FILE__, __LINE__, #exp); } while(0)
#define dcassert(exp)
#ifdef _MSC_VER
#define dcasserta(exp) __assume(exp)
#else
#define dcasserta(exp)
#endif // WIN32
#define dcdrun(exp)
#endif //NDEBUG

// Make sure we're using the templates from algorithm...
#ifdef min
#undef min
#endif
#ifdef max
#undef max
#endif

typedef std::vector<std::string> StringList;
typedef StringList::iterator StringIter;
typedef StringList::const_iterator StringIterC;

typedef std::vector<uint8_t> ByteVector;
typedef ByteVector::iterator ByteIter;

/**
 * Initialize configuration.
 */ADCHPP_DLL void initialize(const std::string& path);

/**
 * Load plugins and start listening for incoming connections
 */ADCHPP_DLL void startup(void (*f)());

/**
 * Stop listening for incoming connections
 */ADCHPP_DLL void shutdown(void (*f)());

/**
 * Release any resources held by adchpp. Before using any library routines again, you must call initalialize.
 */
ADCHPP_DLL void cleanup();

}

#endif // COMMON_H
