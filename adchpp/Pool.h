/*
 * Copyright (C) 2006-2018 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef ADCHPP_POOL_H
#define ADCHPP_POOL_H

#include "Mutex.h"

namespace adchpp {

template<class T>
struct PoolDummy {
	void operator()(T&) { }
};

template<typename T, class Clear = PoolDummy<T> >
class SimplePool {
public:
	SimplePool() : busy(0) { }
	~SimplePool() { dcdebug("Busy pool objects: %d\n", (int)busy); }

	T* get() {
		busy++;
		if(!free.empty()) {
			T* tmp = free.back();
			free.pop_back();
			return tmp;
		} else {
			return new T;
		}
	}
	void put(T* item) {
		dcassert(busy > 0);
		busy--;
		Clear()(*item);
		// Remove some objects every now and then...
		if(free.size() > (2*busy) && free.size() > 32) {
			dcdebug("Clearing pool\n");
			while(free.size() > busy / 2) {
				delete free.back();
				free.pop_back();
			}
		}
		free.push_back(item);
	}

private:
	size_t busy;
	std::vector<T*> free;
};


/** A thread safe object pool */
template<class T, class Clear = PoolDummy<T> >
class Pool {
public:
	Pool() { }
	~Pool() { }

	T* get() {
		FastMutex::Lock l(mtx);
		return pool.get();
	}
	void put(T* obj) {
		FastMutex::Lock l(mtx);
		pool.put(obj);
	}

private:
	Pool(const Pool&);
	Pool& operator=(const Pool&);
	FastMutex mtx;

	SimplePool<T, Clear> pool;
};

}

#endif //POOL_H_
