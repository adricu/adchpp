/* 
 * Copyright (C) 2006-2007 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef ADCHPP_SIGNAL_H
#define ADCHPP_SIGNAL_H

#include "Util.h"

namespace adchpp {
	
template<typename F>
struct Signal {
	typedef std::tr1::function<F> Slot;
	typedef list<Slot> SlotList;
	typedef typename SlotList::iterator Connection;
	typedef F FunctionType;
	
	template<typename T0>
	void operator()(T0& t0) {
		typename SlotList::iterator end = slots.end();
		for(typename SlotList::iterator i = slots.begin(); i != end;) {
			(*i++)(t0);
		}
	}

	template<typename T0, typename T1>
	void operator()(T0& t0, T1& t1) {
		typename SlotList::iterator end = slots.end();
		for(typename SlotList::iterator i = slots.begin(); i != end;) {
			(*i++)(t0, t1);
		}
	}
	
	template<typename T0, typename T1, typename T2>
	void operator()(const T0& t0, const T1& t1, const T2& t2) {
		typename SlotList::iterator end = slots.end();
		for(typename SlotList::iterator i = slots.begin(); i != end;) {
			(*i++)(t0, t1, t2);
		}
	}

	template<typename T0, typename T1, typename T2>
	void operator()(const T0& t0, T1& t1, T2& t2) {
		typename SlotList::iterator end = slots.end();
		for(typename SlotList::iterator i = slots.begin(); i != end;) {
			(*i++)(t0, t1, t2);
		}
	}
	
	template<typename T0, typename T1, typename T2>
	void operator()(T0& t0, T1& t1, T2& t2) {
		typename SlotList::iterator end = slots.end();
		for(typename SlotList::iterator i = slots.begin(); i != end;) {
			(*i++)(t0, t1, t2);
		}
	}
	
	template<typename T>
	Connection connect(const T& f) { return slots.insert(slots.end(), f); }
	void disconnect(const Connection& i) { slots.erase(i); }
	
	~Signal() { }
private:
	SlotList slots;
};

template<typename Sig>
struct ManagedConnection : intrusive_ptr_base {
	ManagedConnection(Sig* signal_, const typename Sig::Connection& iter_) : signal(signal_), iter(iter_) { 
	}
	
	void disconnect() {
		if(signal) {
			signal->disconnect(iter);
			signal = 0;
		}
	}
	
	void release() {
		signal = 0;
	}
	
	~ManagedConnection() {
		disconnect();
	}
private:
	ManagedConnection(const ManagedConnection& rhs);
	ManagedConnection& operator=(const ManagedConnection& rhs);
	
	Sig* signal;
	typename Sig::SlotList::iterator iter;
};

template<typename Signal, typename F>
boost::intrusive_ptr<ManagedConnection<Signal> > manage(Signal* signal, const F& f) {
	return boost::intrusive_ptr<ManagedConnection<Signal> >(new ManagedConnection<Signal>(signal, signal->connect(f)));
}

template<typename F>
struct SignalTraits {
	typedef Signal<F> Signal;
	typedef typename Signal::Connection Connection;
	typedef boost::intrusive_ptr<ManagedConnection<Signal> > ManagedConnection;
};

}

#endif // SIGNAL_H
