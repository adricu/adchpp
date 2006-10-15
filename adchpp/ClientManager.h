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

#ifndef ADCHPP_CLIENTMANAGER_H
#define ADCHPP_CLIENTMANAGER_H

#include "Util.h"
#include "CID.h"
#include "AdcCommand.h"
#include "Signal.h"
#include "Client.h"

namespace adchpp {
	
class ManagedSocket;

/**
 * The ClientManager takes care of all protocol details, clients and so on. This is the very
 * heart of ADCH++ together with SocketManager and ManagedSocket.
 */
class ClientManager : public Singleton<ClientManager>, public CommandHandler<ClientManager>
{
public:
	enum SignalCommandOverride {
		DONT_DISPATCH = 1 << 0,
		DONT_SEND = 1 << 1
	};
	
	typedef HASH_MAP<uint32_t, Client*> ClientMap;
	typedef ClientMap::iterator ClientIter;
	
	/** Adds a string to SUP, propagating the change to all connected clients */
	ADCHPP_DLL void addSupports(const string& str) throw();
	/** Removes a string from SUP, propagating the change to all connected clients */
	ADCHPP_DLL void removeSupports(const string& str) throw();

	ADCHPP_DLL void updateCache() throw();
	
	/** @return SID of client or 0 if not found */
	ADCHPP_DLL uint32_t getSID(const string& nick) const throw();
	/** @return SID of client or 0 if not found */
	ADCHPP_DLL uint32_t getSID(const CID& cid) const throw();
	
	/** @return The client associated with a certain SID, NULL if not found */
	Client* getClient(uint32_t aSid) throw() {
		ClientIter i = clients.find(aSid);
		return (i == clients.end()) ? 0 : i->second;
	}
	/**
	 * Get a list of all currently connected clients. (Don't change it, it's non-const
	 * so that you'll be able to get non-const clients out of it...)!!!)
	 */
	ClientMap& getClients() throw() { return clients; }

	/** Send a command to the clients according to its type */
	ADCHPP_DLL void send(const AdcCommand& cmd, bool lowPrio = false) throw();
	/** Send command to all regardless of type */
	ADCHPP_DLL void sendToAll(const AdcCommand& cmd) throw();
	/** Send command to a single client regardless of type */
	ADCHPP_DLL void sendTo(const AdcCommand& cmd, const uint32_t& to) throw();

	/**
	 * Calling this function will increase the flood-counter and kick/ban the user
	 * if the counter exceeds the setting. 
	 * @return True if the user was flooding and was kicked, false otherwise.
	 */
	ADCHPP_DLL bool checkFlooding(Client& c, const AdcCommand&) throw();
	
	/**
	 * Enter IDENTIFY state.
	 * Call this if you stop the SUP command when in PROTOCOL state.
	 *
	 * @param sendData Send ISUP & IINF.
	 */
	ADCHPP_DLL void enterIdentify(Client& c, bool sendData) throw();

	/**
	 * Enter VERIFY state. Call this if you stop
	 * an INF in the IDENTIFY state and want to check a password.
	 *
	 * @param sendData Send GPA.
	 * @return The random data that was sent to the client (if sendData was true, undefined otherwise).
	 */
	ADCHPP_DLL vector<uint8_t> enterVerify(Client& c, bool sendData) throw();

	/**
	 * Enter NORMAL state. Call this if you stop an INF of a password-less
	 * client in IDENTIFY state or a PAS in VERIFY state. 
	 * 
	 * @param sendData Send all data as mandated by the protocol, including list of connected clients.
	 * @param sendOwnInf Set to true to broadcast the client's inf (i e when a plugin asks
	 *                   for password)
	 * @return false if the client was disconnected
	 */
	ADCHPP_DLL bool enterNormal(Client& c, bool sendData, bool sendOwnInf) throw();

	/**
	 * Do all SUP verifications and update client data. Call if you stop SUP but still want the default processing.
	 */
	ADCHPP_DLL bool verifySUP(Client& c, AdcCommand& cmd) throw();
	
	/**
	 * Do all INF verifications and update client data. Call if you stop INF but still want the default processing.
	 */
	ADCHPP_DLL bool verifyINF(Client& c, AdcCommand& cmd) throw();
	
	/**
	 * Verify nick on INF (check that its not a dupe etc...)
	 * @return false if the client was disconnected
	 */
	ADCHPP_DLL bool verifyNick(Client& c, const AdcCommand& cmd) throw();
	
	/**
	 * Verify password
	 */
	ADCHPP_DLL bool verifyPassword(Client& c, const string& password, const vector<uint8_t>& salt, const string& suppliedHash);

	/**
	 * Verify that IP is correct and replace any zero addresses.
	 */
	ADCHPP_DLL bool verifyIp(Client& c, AdcCommand& cmd) throw();

	ADCHPP_DLL bool verifyCID(Client& c, AdcCommand& cmd) throw();
	
	/** Verify the number of connected clients */
	ADCHPP_DLL bool verifyUsers(Client& c) throw();
	
	/** Update the state of c (this fires signalState as well) */
	ADCHPP_DLL void setState(Client& c, Client::State newState) throw();

	/**
	 * The SocketManager calls this when a new connection has been accepted.
	 * Don't touch.
	 */
	void incomingConnection(ManagedSocket* ms) throw();
	
	void startup() throw() { updateCache(); }
	void shutdown();
	
	typedef Signal<void (Client&)> SignalConnected;
	typedef Signal<void (Client&, AdcCommand&, int&)> SignalReceive;
	typedef Signal<void (Client&, const string&)> SignalBadLine;
	typedef Signal<void (Client&, AdcCommand&, int&)> SignalSend;
	typedef Signal<void (Client&, int)> SignalState;
	typedef Signal<void (Client&)> SignalDisconnected;

	SignalConnected& signalConnected() { return signalConnected_; }
	SignalReceive& signalReceive() { return signalReceive_; }
	SignalBadLine& signalBadLine() { return signalBadLine_; }
	SignalSend& signalSend() { return signalSend_; }
	SignalState& signalState() { return signalState_; }
	SignalDisconnected& signalDisconnected() { return signalDisconnected_; }

private:
	friend class Client;
	
	/**
	 * List of SUP items.
	 */
	StringList supports;

	deque<pair<Client*, time_t> > logins;

	ClientMap clients;
	typedef HASH_MAP<string, uint32_t> NickMap;
	NickMap nicks;
	typedef HASH_MAP_X(CID, uint32_t, CID::Hash, equal_to<CID>, less<CID>) CIDMap;
	CIDMap cids;

	// Temporary string to use whenever a temporary string is needed (to avoid (de)allocating memory all the time...)
	string strtmp;

	static const string className;

	// Strings used in various places along the pipeline...rebuilt in updateCache()...
	struct Strings {
		string sup;
		string inf;
	} strings;

	friend class Singleton<ClientManager>;
	ADCHPP_DLL static ClientManager* instance;
	
	friend class CommandHandler<ClientManager>;

	uint32_t makeSID();
	
	void removeLogins(Client& c) throw();
	void removeClient(Client& c) throw();

	bool handle(AdcCommand::SUP, Client& c, AdcCommand& cmd) throw();
	bool handle(AdcCommand::INF, Client& c, AdcCommand& cmd) throw();
	bool handleDefault(Client& c, AdcCommand& cmd) throw();
	
	template<typename T> bool handle(T, Client& c, AdcCommand& cmd) throw() { return handleDefault(c, cmd); }

	void onConnected(Client&) throw();
	void onReceive(Client&, AdcCommand&) throw();
	void onBadLine(Client&, const string&) throw();
	void onFailed(Client&) throw();
	
	void badState(Client& c) throw();
	
	SignalConnected signalConnected_;
	SignalReceive signalReceive_;
	SignalBadLine signalBadLine_;
	SignalSend signalSend_;
	SignalState signalState_;
	SignalDisconnected signalDisconnected_;

	ClientManager() throw() {
		supports.push_back("BASE");
	}

	virtual ~ClientManager() throw() { }

};

}

#endif // CLIENTMANAGER_H
