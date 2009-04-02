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
class Client : public Entity, public FastAlloc<Client>, public boost::noncopyable {
public:
	enum State {
		/** Initial protocol negotiation (wait for SUP) */
		STATE_PROTOCOL,
		/** Identify the connecting client (wait for INF) */
		STATE_IDENTIFY,
		/** Verify the client (wait for PAS) */
		STATE_VERIFY,
		/** Normal operation */
		STATE_NORMAL,
		/** Binary data transfer */
		STATE_DATA
	};

	enum {
		FLAG_BOT = 0x01,
		FLAG_REGISTERED = 0x02,
		FLAG_OP = 0x04,
		FLAG_SU = 0x08,
		FLAG_OWNER = 0x10,
		FLAG_HUB = 0x20,
		MASK_CLIENT_TYPE = FLAG_BOT | FLAG_REGISTERED | FLAG_OP | FLAG_SU | FLAG_OWNER | FLAG_HUB,
		FLAG_PASSWORD = 0x100,
		FLAG_HIDDEN = 0x101,
		/** Extended away, no need to send msg */
		FLAG_EXT_AWAY = 0x102,
		/** Plugins can use these flags to disable various checks */
		/** Bypass ip check */
		FLAG_OK_IP = 0x104
	};

	static Client* create(const ManagedSocketPtr& ms_, uint32_t sid_) throw();

	using Entity::send;

	virtual void send(const BufferPtr& command) throw() { socket->write(command); }

	size_t getQueuedBytes() throw() { return socket->getQueuedBytes(); }

	/** @param reason The statistic to update */
	ADCHPP_DLL void disconnect(Util::Reason reason) throw();
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

	bool isSet(size_t aFlag) const { return flags.isSet(aFlag); }
	bool isAnySet(size_t aFlag) const { return flags.isAnySet(aFlag); }
	void setFlag(size_t aFlag);
	void unsetFlag(size_t aFlag);

	/**
	 * Set PSD (plugin specific data). This allows a plugin to store arbitrary
	 * per-client data, and retrieve it later on. Each plugin is only allowed
	 * to store one single item, and the plugin must make sure that this
	 * item will be properly deallocated when ClientQuit is received by the
	 * plugin. If an item already exists, it will be replaced.
	 * @param id Id as retrieved from PluginManager::getPluginId()
	 * @param data Data to store, this can be pretty much anything
	 * @return Old value if any was associated with the plugin already, NULL otherwise
	 */
	ADCHPP_DLL void* setPSD(int id, void* data) throw();

	/**
	 * @param id Plugin id
	 * @return Value stored, NULL if none found
	 */
	ADCHPP_DLL void* getPSD(int id) throw();

	const CID& getCID() const { return cid; }
	void setCID(const CID& cid_) { cid = cid_; }
	State getState() const { return state; }
	void setState(State state_) { state = state_; }

private:
	Client(uint32_t sid_) throw();
	virtual ~Client() throw() { }

	typedef std::pair<int, void*> PSDPair;
	typedef std::vector<PSDPair> PSDList;
	typedef PSDList::iterator PSDIter;

	Flags flags;

	CID cid;
	State state;
	bool disconnecting;

	PSDList psd;
	BufferPtr buffer;
	ManagedSocketPtr socket;
	int64_t dataBytes;

	time_t floodTimer;

	DataFunction dataHandler;
	void setSocket(const ManagedSocketPtr& aSocket) throw();

	void onConnected() throw();
	void onData(const BufferPtr&) throw();
	void onFailed() throw();

};

}

#endif // CLIENT_H
