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

#ifndef ADCHPP_ADCHPP_H
#define ADCHPP_ADCHPP_H

#include "compiler.h"
#include "config.h"

#ifdef _WIN32

#include <winsock2.h>
#include <windows.h>
#include <tchar.h>

#else

#include <sys/time.h>

#endif

#include <cerrno>
#include <cstdarg>
#include <cstddef>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <ctime>

#include <string>
#include <vector>
#include <list>
#include <functional>
#include <memory>
#include <algorithm>
#include <map>
#include <unordered_map>
#include <unordered_set>

#include "shared_ptr.h"

#include "nullptr.h"

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

#if defined(max) || defined(min)
#error min/max defined
#endif

#endif // STDINC_H
