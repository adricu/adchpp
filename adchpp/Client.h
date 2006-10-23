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

#ifndef ADCHPP_CLIENT_H
#define ADCHPP_CLIENT_H

#include "common.h"

#include "ManagedSocket.h"
#include "FastAlloc.h"
#include "Signal.h"
#include "AdcCommand.h"
#include "CID.h"
#include "SettingsManager.h"

namespace adchpp {

class ClientManager;

/**
 * The client represents one connection to a user.
 */
class Client : public Flags, public FastAlloc<Client>, public boost::noncopyable {
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
		FLAG_OP = 0x02,				
		FLAG_PASSWORD = 0x04,
		FLAG_HIDDEN = 0x08,
		FLAG_HUB = 0x10,
		/** Extended away, no need to send msg */
		FLAG_EXT_AWAY = 0x20,
		/** Plugins can use these flags to disable various checks */
		/** Bypass max users count */
		FLAG_OK_COUNT = 0x80,
		/** Bypass ip check */
		FLAG_OK_IP = 0x100
	};

	static Client* create(const ManagedSocketPtr& ms_) throw();
	
	const StringList& getSupportList() const throw() { return supportList; }
	bool supports(const string& feat) const throw() { return find(supportList.begin(), supportList.end(), feat) != supportList.end(); }

	void send(const char* command, size_t len) throw() {
		dcassert(socket != NULL);
		socket->write(command, len);
	}
	void send(const AdcCommand& cmd) throw() { send(cmd.toString()); }
	void send(const string& command) throw() { send(command.c_str(), command.length()); }
	void send(const char* command) throw() { socket->write(command, strlen(command)); }

	void fastSend(const string& command, bool lowPrio = false) throw() {
		socket->fastWrite(command.c_str(), command.length(), lowPrio);
	}

	/** @param reason The statistic to update */
	ADCHPP_DLL void disconnect(Util::Reason reason) throw();
	const ManagedSocketPtr& getSocket() throw() { return socket; }
	const ManagedSocketPtr& getSocket() const throw() { return socket; }
	const string& getIp() const throw() { dcassert(socket != NULL); return getSocket()->getIp(); }

	/** 
	 * Set data mode for aBytes bytes.
	 * May only be called from on(ClientListener::Command...).
	 */
	void setDataMode(boost::function<void (const uint8_t*, size_t)> handler, int64_t aBytes) { dataHandler = handler; dataBytes = aBytes; }

	/** Add any flags that have been updated to the AdcCommand (type etc is not set) */
	ADCHPP_DLL bool getChangedFields(AdcCommand& cmd) const throw();
	ADCHPP_DLL bool getAllFields(AdcCommand& cmd) const throw();

	void resetChanged() { changed.clear(); }

	const string& getField(const char* name) const throw() { InfMap::const_iterator i = info.find(*(uint16_t*)name); return i == info.end() ? Util::emptyString : i->second; }
	void setField(const char* name, const string& value) throw() { 
		if(value.empty()) {
			info.erase(*(uint16_t*)name);
		} else {
			info[*(uint16_t*)name] = value; 
		}
		changed[*(uint16_t*)name] = value;
	}

	ADCHPP_DLL void updateFields(const AdcCommand& cmd) throw();
	ADCHPP_DLL void updateSupports(const AdcCommand& cmd) throw();

	bool isUdpActive() const { return info.find(*(uint16_t*)"U4") != info.end(); }
	bool isTcpActive() const { return info.find(*(uint16_t*)"I4") != info.end(); }

	ADCHPP_DLL bool isFlooding(time_t addSeconds);
	
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
	void setSID(uint32_t sid_) { sid = sid_; }
	uint32_t getSID() const { return sid; }
	State getState() const { return state; }
	void setState(State state_) { state = state_; }

private:
	Client() throw();
	virtual ~Client() throw() { }

	StringList supportList;
	typedef pair<int, void*> PSDPair;
	typedef vector<PSDPair> PSDList;
	typedef PSDList::iterator PSDIter;

	typedef HASH_MAP<uint16_t, string> InfMap;
	typedef InfMap::iterator InfIter;

	InfMap info;
	InfMap changed;

	CID cid;
	uint32_t sid;
	State state;
	bool disconnecting;
	
	PSDList psd;
	string line;
	ManagedSocketPtr socket;
	int64_t dataBytes;
	
	time_t floodTimer;
	
	boost::function<void (const uint8_t*, size_t)> dataHandler;
	void setSocket(const ManagedSocketPtr& aSocket) throw();
	
	void onConnected() throw();
	void onData(const ByteVector&) throw();
	void onFailed() throw();
};

}

#endif // CLIENT_H
