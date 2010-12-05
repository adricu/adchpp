/*
 * Copyright (C) 2006-2010 Jacek Sieka, arnetheduck on gmail point com
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

struct Connection : private boost::noncopyable {
public:
	Connection() { }
	virtual ~Connection() { }

	virtual void disconnect() = 0;
};

typedef std::unique_ptr<Connection> ConnectionPtr;

template<typename F>
class Signal {
public:
	typedef std::function<F> Slot;
	typedef std::list<Slot> SlotList;
	typedef F FunctionType;

	template<typename T0>
	void operator()(T0&& t0) {
		for(auto i = slots.begin(), iend = slots.end(); i != iend;) {
			(*i++)(std::forward<T0>(t0));
		}
	}

	template<typename T0, typename T1>
	void operator()(T0&& t0, T1&& t1) {
		for(auto i = slots.begin(), iend = slots.end(); i != iend;) {
			(*i++)(std::forward<T0>(t0), std::forward<T1>(t1));
		}
	}

	template<typename T0, typename T1, typename T2>
	void operator()(T0&& t0, T1&& t1, T2&& t2) {
		for(auto i = slots.begin(), iend = slots.end(); i != iend;) {
			(*i++)(std::forward<T0>(t0), std::forward<T1>(t1), std::forward<T2>(t2));
		}
	}

	template<typename T>
	ConnectionPtr connect(const T& f) { return ConnectionPtr(new SlotConnection(this, slots.insert(slots.end(), f))); }

	~Signal() { }
private:
	SlotList slots;

	void disconnect(const typename SlotList::iterator& i) {
		slots.erase(i);
	}

	struct SlotConnection : public Connection {
		SlotConnection(Signal<F>* sig_, const typename SlotList::iterator& i_) : sig(sig_), i(i_) { }

		virtual void disconnect() { if(sig) sig->disconnect(i), sig = 0; }
		Signal<F>* sig;
		typename Signal<F>::SlotList::iterator i;
	};
};

struct ManagedConnection : private boost::noncopyable {
	ManagedConnection(ConnectionPtr&& conn_) : conn(move(conn_)) {
	}

	void disconnect() {
		if(conn.get()) {
			conn->disconnect();
			conn.reset();
		}
	}

	void release() {
		conn.reset();
	}

	~ManagedConnection() {
		disconnect();
	}
private:
	ConnectionPtr conn;
};

typedef shared_ptr<ManagedConnection> ManagedConnectionPtr;

template<typename F1, typename F2>
inline ManagedConnectionPtr manage(Signal<F1>* signal, const F2& f) {
	return make_shared<ManagedConnection>(signal->connect(f));
}

inline ManagedConnectionPtr manage(ConnectionPtr && conn) {
	return make_shared<ManagedConnection>(move(conn));
}

template<typename F>
struct SignalTraits {
	typedef adchpp::Signal<F> Signal;
	typedef adchpp::ConnectionPtr Connection;
	typedef adchpp::ManagedConnectionPtr ManagedConnection;
};

}

#endif // SIGNAL_H
