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

#ifndef ADCHPP_CLIENT_H
#define ADCHPP_CLIENT_H

#include "common.h"

#include "ManagedSocket.h"
#include "FastAlloc.h"
#include "AdcCommand.h"
#include "CID.h"
#include "Entity.h"

namespace adchpp {

/**
 * The client represents one connection to a user.
 */
class ADCHPP_VISIBLE Client : public Entity, public FastAlloc<Client>, public boost::noncopyable {
public:
	static Client* create(const ManagedSocketPtr& ms_, uint32_t sid_) throw();

	using Entity::send;

	virtual void send(const BufferPtr& command) throw() { socket->write(command); }

	size_t getQueuedBytes() throw() { return socket->getQueuedBytes(); }

	/** @param reason The statistic to update */
	ADCHPP_DLL virtual void disconnect(Util::Reason reason) throw();
	const ManagedSocketPtr& getSocket() throw() { return socket; }
	const ManagedSocketPtr& getSocket() const throw() { return socket; }
	const std::string& getIp() const throw() { dcassert(socket != NULL); return getSocket()->getIp(); }

	/**
	 * Set data mode for aBytes bytes.
	 * May only be called from on(ClientListener::Command...).
	 */
	typedef std::tr1::function<void (Client&, const uint8_t*, size_t)> DataFunction;
	void setDataMode(const DataFunction& handler, int64_t aBytes) { dataHandler = handler; dataBytes = aBytes; }

	bool isUdpActive() const { return hasField("U4"); }
	bool isTcpActive() const { return hasField("I4"); }

	ADCHPP_DLL bool isFlooding(time_t addSeconds);

	void setDefaultMaxCommandSize(size_t newSize) { defaultMaxCommandSize = newSize; }
	size_t getDefaultMaxCommandSize() { return defaultMaxCommandSize; }

	void setMaxCommandSize(size_t newSize) { maxCommandSize = newSize; }
	size_t getMaxCommandSize() { return maxCommandSize; }
private:
	static size_t defaultMaxCommandSize;

	Client(uint32_t sid_) throw();
	virtual ~Client();

	bool disconnecting;

	BufferPtr buffer;
	ManagedSocketPtr socket;
	int64_t dataBytes;

	time_t floodTimer;

	size_t maxCommandSize;

	DataFunction dataHandler;
	void setSocket(const ManagedSocketPtr& aSocket) throw();

	void onConnected() throw();
	void onData(const BufferPtr&) throw();
	void onFailed() throw();

};

}

#endif // CLIENT_H
