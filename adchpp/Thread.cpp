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

#include "stdinc.h"
#include "common.h"

#include "Thread.h"

namespace adchpp {
	

#ifdef _WIN32

void Thread::start() throw(ThreadException) {
	DWORD threadId = 0;
	if( (threadHandle = ::CreateThread(NULL, 0, &starter, this, 0, &threadId)) == NULL) {
		throw ThreadException(STRING(UNABLE_TO_CREATE_THREAD));
	}
}

void Thread::join() throw() {
	if(threadHandle == NULL) {
		return;
	}

	::WaitForSingleObject(threadHandle, INFINITE);
	::CloseHandle(threadHandle);
	threadHandle = NULL;
}

#else // _WIN32

void Thread::start() throw(ThreadException) { 
	// Not all implementations may create threads as joinable by default.
	pthread_attr_t attr;
	pthread_attr_init(&attr);
	pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
	if(pthread_create(&t, &attr, &starter, this) != 0) {
		throw ThreadException(STRING(UNABLE_TO_CREATE_THREAD));
	}
	pthread_attr_destroy(&attr);
}

void Thread::join() throw() { 
	if(t == 0)
		return;
	
	void* x;
	pthread_join(t, &x);
	t = 0;
}

#endif
}
	
