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

#ifndef ADCHPP_THREAD_H
#define ADCHPP_THREAD_H

#ifndef _WIN32
# include <pthread.h>
# include <sched.h>
# include <sys/resource.h>
#endif

#include "Exception.h"

namespace adchpp { 

STANDARD_EXCEPTION(ThreadException);

class Thread  
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

	Thread() throw() : threadHandle(NULL) { }
	virtual ~Thread() { 
		if(threadHandle)
			CloseHandle(threadHandle);
	}
	
	void setThreadPriority(Priority p) throw() { ::SetThreadPriority(threadHandle, p); }
	
	bool isRunning() throw() { return (threadHandle != NULL); }

	static void sleep(uint32_t millis) { ::Sleep(millis); }
	static void yield() { ::Sleep(0); }

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
	
private:
	Thread(const Thread&);
	Thread& operator=(const Thread&);

#ifdef _WIN32
	HANDLE threadHandle;
	static DWORD WINAPI starter(void* p) {
		Thread* t = (Thread*)p;
		return (DWORD)t->run();
	}
#else
	pthread_t t;
	static void* starter(void* p) {
		Thread* t = (Thread*)p;
		return (void*)t->run();
	}
#endif
};

}

#endif // THREAD_H
