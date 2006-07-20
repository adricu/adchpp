#ifndef MUTEX_H_
#define MUTEX_H_

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
