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

/**
 * @mainpage
 * 
 * ADCH++ is a server application meant to be used in the Direct Connect network,
 * released under a yet to be decided licence. If you're reading this it means one
 * of two things, you got it from me (Jacek Sieka) directly, or you're not allowed 
 * to use it.
 * 
 * There's a rather powerful plugin API about which you can find some general
 * information on the @ref PluginAPI page.
 *
 * Copyright (C) 2006 Jacek Sieka, arnetheduck on gmail point com
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * 
 * Please see the readme or contact me for full details regarding
 * licensing.
 */

#ifndef COMMON_H
#define COMMON_H

namespace adchpp {
	
extern DLL const char compileTime[];
//DLL extern void logAssert(const char* file, int line, const char* exp);

#ifdef _DEBUG

extern DLL void logAssert(const char* file, int line, const char* exp);

inline void CDECL debugTrace(const char* format, ...)
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
#else //_DEBUG
#define dcdebug if(false) printf
//#define dcassert(exp) do { if(!(exp)) logAssert(__FILE__, __LINE__, #exp); } while(0)
#define dcassert(exp)
#ifdef _MSC_VER
#define dcasserta(exp) __assume(exp)
#else
#define dcasserta(exp)
#endif // WIN32
#define dcdrun(exp)
#endif //_DEBUG

// Make sure we're using the templates from algorithm...
#ifdef min
#undef min
#endif
#ifdef max
#undef max
#endif

typedef vector<string> StringList;
typedef StringList::iterator StringIter;
typedef StringList::const_iterator StringIterC;

typedef vector<wstring> WStringList;
typedef WStringList::iterator WStringIter;
typedef WStringList::const_iterator WStringIterC;

typedef vector<u_int8_t> ByteVector;
typedef ByteVector::iterator ByteIter;

/** 
 * First startup phase, this _must_ be done asap as nothing 
 * will work before it, relatively fast.
 */
DLL void adchppStartup();

/** 
 * Second startup phase, this can take quite some time as plugins and 
 * dynamic data are loaded.
 * @param f Unless NULL, this function is called after each step in the initialization
 */
DLL void adchppStartup2(void (*f)());

/** Shuts down the adchpp hub library (doh!). */
DLL void adchppShutdown(void (*f)());

}

#include <boost/bind.hpp>


#endif // COMMON_H
