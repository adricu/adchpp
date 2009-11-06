/*
 * Copyright (C) 2006-2009 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef ADCHPP_INTRUSIVE_PTR_H
#define ADCHPP_INTRUSIVE_PTR_H

#include "Mutex.h"

namespace std { namespace tr1 {

template<typename T>
struct hash<boost::intrusive_ptr<T> > {
	size_t operator()(const boost::intrusive_ptr<T>& t) const { return hash<T*>()(t.get()); }
};

} }

namespace adchpp {

template<typename T>
class intrusive_ptr_base
{
public:
	bool unique() throw() {
		return (refs == 1);
	}

	boost::intrusive_ptr<T> from_this() { return boost::intrusive_ptr<T>(static_cast<T*>(this)); }

protected:
	intrusive_ptr_base() throw() : refs(0) { }

private:
	friend void intrusive_ptr_add_ref(intrusive_ptr_base* p) {
#ifdef _WIN32
		InterlockedIncrement(&p->refs);
#else
		FastMutex::Lock l(mtx);
		p->refs++;
#endif
	}

	friend void intrusive_ptr_release(intrusive_ptr_base* p) {
#ifdef _WIN32
		if(!InterlockedDecrement(&p->refs))
			delete static_cast<T*>(p);
#else
		FastMutex::Lock l(intrusive_ptr_base::mtx);
		if(!--p->refs)
			delete static_cast<T*>(p);
#endif
	}

#ifndef _WIN32
	ADCHPP_DLL static FastMutex mtx;
#endif

	volatile long refs;
};

#ifndef _WIN32
template<typename T>
FastMutex intrusive_ptr_base<T>::mtx;
#endif

}

#endif
