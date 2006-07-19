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

#ifndef CRITICALSECTION_H
#define CRITICALSECTION_H

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

#include "Thread.h"
#include "AtomicInt.h"

class CriticalSection {
#ifdef _WIN32
public:
	void enter() throw() {
		EnterCriticalSection(&cs);
	}
	void leave() throw() {
		LeaveCriticalSection(&cs);
	}
	CriticalSection() throw() {
		InitializeCriticalSection(&cs);
	}
	~CriticalSection() throw() {
		DeleteCriticalSection(&cs);
	}
private:
	CRITICAL_SECTION cs;
#else
public:
	CriticalSection() throw() {
		pthread_mutexattr_t attr;
		pthread_mutexattr_init(&attr);
		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
		pthread_mutex_init(&mtx, &attr);
		pthread_mutexattr_destroy(&attr);
	}
	~CriticalSection() throw() { pthread_mutex_destroy(&mtx); }
	void enter() throw() { pthread_mutex_lock(&mtx); }
	void leave() throw() { pthread_mutex_unlock(&mtx); }
	pthread_mutex_t& getMutex() { return mtx; }
private:
	pthread_mutex_t mtx;
#endif
	CriticalSection(const CriticalSection&);
	CriticalSection& operator=(const CriticalSection&);
};

/**
 * A fast, non-recursive and unfair implementation of the Critical Section.
 * It is meant to be used in situations where the risk for lock conflict is very low, 
 * i e locks that are held for a very short time. The lock is _not_ recursive, i e if 
 * the same thread will try to grab the lock it'll hang in a never-ending loop. The lock
 * is not fair, i e the first to try to enter a locked lock is not guaranteed to be the
 * first to get it when it's freed...
 *
 * On linux it seems as fast or maybe a tiny bit slower than a mutex in case of few
 * conflicts, but on Windows and FreeBSD it seems to make quite a bit of difference.
 */
class FastCriticalSection {
public:
	FastCriticalSection() : state(0) { }

	void enter() {
		while(!state.testset()) {
			Thread::yield();
		}
	}
	void leave() {
		state.unset();
	}
private:
	AtomicInt state;
};

template<class T>
class LockBase {
public:
	LockBase(T& aCs) throw() : cs(aCs)  { cs.enter(); }
	~LockBase() throw() { cs.leave(); }
private:
	LockBase& operator=(const LockBase&);
	T& cs;
};
typedef LockBase<CriticalSection> Lock;
typedef LockBase<FastCriticalSection> FastLock;

template<class T = CriticalSection>
class RWLock
{
public:
	RWLock() throw() : cs(), readers(0) { }
	~RWLock() throw() { dcassert(readers==0); }

	void enterRead() throw() {
		Lock l(cs);
		readers.inc();
		dcassert(readers < 100);
	}

	void leaveRead() throw() {
		readers.dec();
		dcassert(readers >= 0);
	}
	void enterWrite() throw() {
		cs.enter();
		while(readers > 0) {
			cs.leave();
			Thread::yield();
			cs.enter();
		}
	}
	void leaveWrite() {
		cs.leave();
	}
private:
	T cs;
	AtomicInt readers;
};

template<class T>
class RLock {
public:
	RLock(RWLock<T>& aRwl) throw() : rwl(aRwl)  { rwl.enterRead(); }
	~RLock() throw() { rwl.leaveRead(); }
private:
	RWLock<T>& rwl;
};

template<class T>
class WLock {
public:
	WLock(RWLock<T>& aRwl) throw() : rwl(aRwl)  { rwl.enterWrite(); }
	~WLock() throw() { rwl.leaveWrite(); }
private:
	RWLock<T>& rwl;
};

#endif // CRITICALSECTION_H
