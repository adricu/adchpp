/* vim:ts=4:sw=4:noet
 * Copyright (C) 2005 Walter Doekes, walter on djcvt dot net
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * 
 * Please see the readme or contact me for full details regarding
 * licensing.
 */

#ifndef ATOMICINT_H
#define ATOMICINT_H

#ifdef _WIN32
# if _MSC_VER > 1000
#  pragma once
# endif // _MSC_VER > 1000
# define WINDOWS_LEAN_AND_MEAN
# include <windows.h>
# define HAVE_ATOMIC_WINDOWS
#else //_WIN32
# if defined(HAVE_ASM_ATOMIC_H) && defined(HAVE_ASM_BITOPS_H)
#  include <pthread.h>
#  include <asm/atomic.h>
#  include <asm/bitops.h>
#  define HAVE_ATOMIC_LINUX
# elif HAVE_MACHINE_ATOMIC_H
#  include <pthread.h>
#  include <sys/types.h>
#  include <machine/atomic.h>
#  define HAVE_ATOMIC_BSD
# elif HAVE_STLPORT
#  include <memory>
#  define HAVE_ATOMIC_STLPORT
# else
#  error Atomic operations undefined
# endif
#endif //_WIN32

/*
 * Methods:
 * 
 * bool inc()
 * 		returns true if the result is 0
 * bool dec()
 * 		returns true if the result is 0
 * int exchange(int n)
 * 		returns the old value
 * bool testset()
 * 		assumes AtomicInt was initialized to 0, returns true if not set to true
 * 		and sets self to true
 * void unset()
 * 		sets self to false
 *
 * Notes:
 *
 * Avoid using exchange, as it is implemented with a mutex on some platforms
 */

class AtomicInt {

#if defined(HAVE_ATOMIC_WINDOWS)

private:
	long v;
public:
	inline AtomicInt(int n = 0) throw() : v((long)n) { }
	inline AtomicInt& operator=(volatile long n) throw() { (void)InterlockedExchange(&v, (long)n); return *this; }
	inline bool inc() throw() { return InterlockedIncrement(&v) == 0; }
	inline bool dec() throw() { return InterlockedDecrement(&v) == 0; }
	inline int exchange(int n) throw() { return (int)InterlockedExchange(&v, (long)n); }
	inline bool testset() throw() { return exchange(1) == 0; }
	inline void unset() throw() { dec(); }
	inline operator int() const throw() { return (int)v; }

#elif defined(HAVE_ATOMIC_LINUX)

private:
	atomic_t v;
	pthread_mutex_t mtx; // lacking test_and_set
# define ATOMICINT_H_LOCK(x) \
	pthread_mutex_lock(&mtx); x; pthread_mutex_unlock(&mtx)
public:
	inline AtomicInt(int n = 0) throw() { atomic_set(&v, n); pthread_mutex_init(&mtx, NULL); }
	inline ~AtomicInt() throw() { pthread_mutex_destroy(&mtx); }
	inline AtomicInt& operator=(int n) throw() { atomic_set(&v, n); return *this; }
	inline bool inc() throw() { return atomic_inc_and_test(&v); }
	inline bool dec() throw() { return atomic_dec_and_test(&v); }
	inline int exchange(int n) throw() { ATOMICINT_H_LOCK(int i = (int)*this; *this = n); return i; }
	inline bool testset() throw() { return test_and_set_bit(0, (volatile unsigned long*)&v.counter) == 0; }
	inline void unset() throw() { clear_bit(0, (volatile unsigned long*)&v.counter); }
	inline operator int() const throw() { return (int)atomic_read(&v); }
# undef ATOMICINT_H_LOCK

#elif defined(HAVE_ATOMIC_BSD)

private:
	// Using acq/rel semantics to make sure that 0 is reached last;
	// all acq operations happen before rel. Is this correct?
	mutable volatile unsigned int v;
	pthread_mutex_t mtx; // lacking test_and_set
# define ATOMICINT_H_LOCK(x) \
	pthread_mutex_lock(&mtx); x; pthread_mutex_unlock(&mtx)
public:
	inline AtomicInt(int n = 0) throw() { atomic_store_rel_int(&v, (unsigned int)n); pthread_mutex_init(&mtx, NULL); }
	inline ~AtomicInt() throw() { pthread_mutex_destroy(&mtx); }
	inline AtomicInt& operator=(int n) throw() { atomic_store_rel_int(&v, (unsigned int)n); return *this; }
	inline bool inc() throw() { atomic_add_acq_int(&v, 1); return (int)*this == 0; }
	inline bool dec() throw() { atomic_subtract_rel_int(&v, 1); return (int)*this == 0; }
	inline int exchange(int n) throw() { ATOMICINT_H_LOCK(int i = (int)*this; *this = n); return i; }
	inline bool testset() throw() { return atomic_cmpset_acq_int(&v, 0, 1) == 1; }
	inline void unset() throw() { atomic_store_rel_int(&v, (unsigned int)0); }
	inline operator int() const throw() { return (int)atomic_load_acq_int(&v); }
# undef ATOMICINT_H_LOCK

#elif defined(HAVE_ATOMIC_STLPORT)

private:
	volatile __stl_atomic_t v;
public:
	inline AtomicInt(int n = 0) throw() { (void)_STLP_ATOMIC_EXCHANGE(&v, n); }
	inline ~AtomicInt() throw() { }
	inline AtomicInt& operator=(int n) throw() { (void)_STLP_ATOMIC_EXCHANGE(&v, n); return *this; }
	inline void inc() throw() { _STLP_ATOMIC_INCREMENT(&v); }
	inline void dec() throw() { _STLP_ATOMIC_DECREMENT(&v); }
	inline int exchange(int n) throw() { return _STLP_ATOMIC_EXCHANGE(&v, n); }
	inline bool testset() throw() { return _STLP_ATOMIC_EXCHANGE(&v, 1) == 0; }
	inline void unset() throw() { (void)_STLP_ATOMIC_EXCHANGE(&v, 0); }
	inline operator int() const throw() { return (int)v; }

#else //if !defined(HAVE_ATOMIC_*)

# error Atomic operations undefined

#endif //HAVE_ATOMIC_*

	
private:
	// Undefined operators
	AtomicInt(AtomicInt const&) throw();
};


#endif //ATOMICINT_H
