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

#ifndef SEMAPHORES_H
#define SEMAPHORES_H

namespace adchpp {
	
#ifndef _WIN32
#include <semaphore.h>
#endif

class Semaphore  
{
#ifdef _WIN32
public:
	Semaphore() throw() {
		h = CreateSemaphore(NULL, 0, MAXLONG, NULL);
	};

	void signal() throw() {
		ReleaseSemaphore(h, 1, NULL);
	}

	enum Results {
		RESULT_OK,
		RESULT_TIMEOUT,
		RESULT_MESSAGE
	};
	Results waitMsg(u_int32_t millis = INFINITE) throw() { 
		switch(MsgWaitForMultipleObjects(1, &h, FALSE, millis, QS_ALLEVENTS)) {
		case WAIT_TIMEOUT: return RESULT_TIMEOUT;
		case WAIT_OBJECT_0: return RESULT_OK;
		case WAIT_OBJECT_0 + 1: return RESULT_MESSAGE;
		default: dcasserta(false);
		}
#ifdef _DEBUG
		return RESULT_TIMEOUT;
#endif
	};
	bool wait(u_int32_t millis = INFINITE) throw() { return WaitForSingleObject(h, millis) == WAIT_OBJECT_0; };
	
	~Semaphore() throw() {
		CloseHandle(h);
	};

private:
	HANDLE h;
#else
public:
	Semaphore() throw() { sem_init(&sem, 0, 0); };
	~Semaphore() throw() { sem_destroy(&sem); };
	void signal() throw() { sem_post(&sem); };
	bool wait() throw() { sem_wait(&sem); return true; };
	bool wait(u_int32_t millis) throw() {
		/** @todo This is an ugly poll...it seems like there's no sem_timedwait... */
		u_int32_t w = 0;
		while(w < millis) {
			if(sem_trywait(&sem) == 0)
				return true;
			w += 100;
			Thread::sleep(100);
		}
		return false;
	}
private:
	sem_t sem;
#endif
};

}

#endif // SEMAPHORES_H
