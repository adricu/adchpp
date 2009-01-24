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

#include "adchpp.h"

#include "SocketManager.h"

#include "LogManager.h"
#include "TimerManager.h"
#include "SettingsManager.h"
#include "ManagedSocket.h"

namespace adchpp {

using namespace std;
using namespace std::tr1;
using namespace std::tr1::placeholders;

using namespace boost::asio;

SocketManager::SocketManager()  {
}

SocketManager::~SocketManager() {
}

SocketManager* SocketManager::instance = 0;
const string SocketManager::className = "SocketManager";

void SocketManager::handleAccept(const boost::system::error_code ec, const ManagedSocketPtr& s, ip::tcp::acceptor& acceptor) {
	incomingHandler(s);
	s->completeAccept(ec);

	ManagedSocketPtr p(new ManagedSocket(io));

	acceptor.async_accept(p->getSock(), bind(&SocketManager::handleAccept, this, _1, p, ref(acceptor)));
}

int SocketManager::run() {
	LOG(SocketManager::className, "Starting");

	ip::tcp::acceptor acceptor(io, ip::tcp::endpoint(ip::tcp::v4(), SETTING(SERVER_PORT)));

	ManagedSocketPtr p(new ManagedSocket(io));

	acceptor.async_accept(p->getSock(), bind(&SocketManager::handleAccept, this, _1, p, ref(acceptor)));

	io.run();

	return 0;
}

void SocketManager::addJob(const Callback& callback) throw() {
	io.post(callback);
}

void SocketManager::shutdown() {

	io.stop();
	join();
}

}
