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

#ifndef ADCHPP_SIGNAL_H
#define ADCHPP_SIGNAL_H

namespace adchpp {
	
template<typename F>
struct Signal {
	typedef std::tr1::function<F> Slot;
	typedef list<Slot> SlotList;
	typedef typename SlotList::iterator Connection;
	
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
struct ManagedConnection {
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

template<typename Sig, typename F>
std::tr1::shared_ptr<ManagedConnection<Sig> > manage(Sig* signal, const F& f) {
	return std::tr1::shared_ptr<ManagedConnection<Sig> >(new ManagedConnection<Sig>(signal, signal->connect(f)));
}
}

#endif // SIGNAL_H
