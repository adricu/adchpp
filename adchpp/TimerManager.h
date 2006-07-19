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

#ifndef TIMERMANAGER_H
#define TIMERMANAGER_H

#include "Singleton.h"

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#ifndef _WIN32
#include <sys/time.h>
#endif

class TimerManager : public Singleton<TimerManager>
{
public:
#ifdef _WIN32
	static u_int32_t getTick() { 
		return GetTickCount(); 
	}

#else
	u_int32_t getTick() {
		timeval tv2;
		gettimeofday(&tv2, NULL);
		return (time_t)((tv2.tv_sec - tv.tv_sec) * 1000 ) + ( (tv2.tv_usec - tv.tv_usec) / 1000);
	}
#endif
	
	static time_t getTime() {
		return time(NULL);
	}
		
private:

	friend class Singleton<TimerManager>;
	static DLL TimerManager* instance;
	
	TimerManager() throw() { 
#ifndef _WIN32
		gettimeofday(&tv, NULL);
		tv.tv_sec -= 1000; // To make sure the timer doesn't start too close to 0...
#endif
	}
	
	virtual ~TimerManager() throw() { }
	
#ifndef _WIN32
	timeval tv;
#endif
};

#ifdef _WIN32
#define GET_TICK() TimerManager::getTick()
#else
#define GET_TICK() TimerManager::getInstance()->getTick()
#endif // WIN32

#define GET_TIME() TimerManager::getTime()

#endif // TIMERMANAGER_H
