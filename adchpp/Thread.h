/* 
 * Copyright (C) 2006-2013 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef ADCHPP_THREAD_H
#define ADCHPP_THREAD_H

#ifndef _WIN32
# include <pthread.h>
# include <sched.h>
# include <sys/resource.h>
#include <unistd.h>
#endif

#include "Exception.h"
#include "nullptr.h"

namespace adchpp { 

STANDARD_EXCEPTION(ThreadException);

class Thread : private boost::noncopyable
{
public:

	ADCHPP_DLL void start() throw(ThreadException);
	ADCHPP_DLL void join() throw();

#ifdef _WIN32
	enum Priority {
		LOW = THREAD_PRIORITY_BELOW_NORMAL,
		NORMAL = THREAD_PRIORITY_NORMAL,
		HIGH = THREAD_PRIORITY_ABOVE_NORMAL
	};

	Thread() throw() : threadHandle(INVALID_HANDLE_VALUE) { }
	virtual ~Thread() { 
		if(threadHandle != INVALID_HANDLE_VALUE)
			CloseHandle(threadHandle);
	}
	
	void setThreadPriority(Priority p) throw() { ::SetThreadPriority(threadHandle, p); }
	
	bool isRunning() throw() { return (threadHandle != INVALID_HANDLE_VALUE); }

	static void sleep(uint32_t millis) { ::Sleep(millis); }
	static void yield() { ::Sleep(1); }

#elif defined(HAVE_PTHREAD)

	enum Priority {
		LOW = 1,
		NORMAL = 0,
		HIGH = -1
	};
	Thread() throw() : t(0) { }
	virtual ~Thread() { 
		if(t != 0) {
			pthread_detach(t);
		}
	}

	void setThreadPriority(Priority p) { setpriority(PRIO_PROCESS, 0, p); }
	bool isRunning() { return (t != 0); }
	
	static void sleep(uint32_t millis) { ::usleep(millis*1000); }
	static void yield() { ::sched_yield(); }

#else
#error No threading support found
#endif

protected:
	virtual int run() = 0;
	
#ifdef _WIN32
	HANDLE threadHandle;
	static DWORD WINAPI starter(void* p) {
		return static_cast<DWORD>(reinterpret_cast<Thread*>(p)->run());
	}
#else
	pthread_t t;
	static void* starter(void* p) {
		// ignore the return value.
		reinterpret_cast<Thread*>(p)->run();
		return nullptr;
	}
#endif
};

}

#endif // THREAD_H
