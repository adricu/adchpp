/*
 * Copyright (C) 2006-2012 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef ADCHPP_MUTEX_H_
#define ADCHPP_MUTEX_H_

#include "Thread.h"

namespace adchpp {

template<typename Mutex>
class ScopedLock {
public:	
	ScopedLock(Mutex& m_) : m(m_) { m.lock(); }
	~ScopedLock() { m.unlock(); }
private:
	Mutex& m;
	
};

#if defined(_WIN32)
class RecursiveMutex : private boost::noncopyable {
public:
	RecursiveMutex() { InitializeCriticalSection(&cs); }
	~RecursiveMutex() { DeleteCriticalSection(&cs); }
	
	void lock() { EnterCriticalSection(&cs); }
	void unlock() { LeaveCriticalSection(&cs); }
	
	typedef ScopedLock<RecursiveMutex> Lock;
private:
	CRITICAL_SECTION cs;
};

class FastMutex : private boost::noncopyable {
public:
	FastMutex() : val(0) { }
	~FastMutex() { }
	
	void lock() { while(InterlockedExchange(&val, 1) == 1) Thread::yield(); }
	void unlock() { InterlockedExchange(&val, 0); }

	typedef ScopedLock<FastMutex> Lock;
private:
	long val;
};

#elif defined(HAVE_PTHREAD)

class RecursiveMutex : private boost::noncopyable {
public:
	RecursiveMutex() throw() {
		pthread_mutexattr_t attr;
		pthread_mutexattr_init(&attr);
		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
		pthread_mutex_init(&mtx, &attr);
		pthread_mutexattr_destroy(&attr);
	}
	~RecursiveMutex() throw() { pthread_mutex_destroy(&mtx); }
	void lock() throw() { pthread_mutex_lock(&mtx); }
	void unlock() throw() { pthread_mutex_unlock(&mtx); }

	typedef ScopedLock<RecursiveMutex> Lock;
private:
	pthread_mutex_t mtx;
};

class FastMutex : private boost::noncopyable {
public:
	FastMutex() throw() {
		pthread_mutexattr_t attr;
		pthread_mutexattr_init(&attr);
		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
		pthread_mutex_init(&mtx, &attr);
		pthread_mutexattr_destroy(&attr);
	}
	~FastMutex() throw() { pthread_mutex_destroy(&mtx); }
	void lock() throw() { pthread_mutex_lock(&mtx); }
	void unlock() throw() { pthread_mutex_unlock(&mtx); }

	typedef ScopedLock<FastMutex> Lock;

private:
	pthread_mutex_t mtx;
};

#else
#error No mutex found
#endif

}

#endif /*MUTEX_H_*/
