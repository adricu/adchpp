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

#ifndef ADCHPP_CLIENTMANAGER_H
#define ADCHPP_CLIENTMANAGER_H

#include "CID.h"
#include "AdcCommand.h"
#include "Signal.h"
#include "Client.h"
#include "Singleton.h"
#include "Hub.h"
#include "Bot.h"

namespace adchpp {

class ManagedSocket;

/**
 * The ClientManager takes care of all protocol details, clients and so on. This is the very
 * heart of ADCH++ together with SocketManager and ManagedSocket.
 */
class ClientManager : public Singleton<ClientManager>, public CommandHandler<ClientManager>
{
public:
	typedef std::tr1::unordered_map<uint32_t, Entity*> EntityMap;
	typedef EntityMap::iterator EntityIter;

	/** @return SID of entity or 0 if not found */
	ADCHPP_DLL uint32_t getSID(const std::string& nick) const throw();
	/** @return SID of entity or 0 if not found */
	ADCHPP_DLL uint32_t getSID(const CID& cid) const throw();

	/** @return The entity associated with a certain SID, NULL if not found */
	ADCHPP_DLL Entity* getEntity(uint32_t aSid) throw();

	/** @return A new Bot instance in STATE_IDENTIFY, set nick etc and call enterNormal to make it appear */
	ADCHPP_DLL Bot* createBot(const Bot::SendHandler& handler);

	/**
	 * Get a list of all currently connected clients. (Don't change it, it's non-const
	 * so that you'll be able to get non-const clients out of it...)!!!)
	 */
	EntityMap& getEntities() throw() { return entities; }

	/** Send a command to according to its type */
	ADCHPP_DLL void send(const AdcCommand& cmd) throw();

	/** Send a buffer to all connected entities */
	ADCHPP_DLL void sendToAll(const BufferPtr& buffer) throw();

	/** Send buffer to a single client regardless of type */
	ADCHPP_DLL void sendTo(const BufferPtr& buffer, uint32_t to);

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
	ADCHPP_DLL void enterIdentify(Entity& c, bool sendData) throw();

	/**
	 * Enter VERIFY state. Call this if you stop
	 * an INF in the IDENTIFY state and want to check a password.
	 *
	 * @param sendData Send GPA.
	 * @return The random data that was sent to the client (if sendData was true, undefined otherwise).
	 */
	ADCHPP_DLL ByteVector enterVerify(Entity& c, bool sendData) throw();

	/**
	 * Enter NORMAL state. Call this if you stop an INF of a password-less
	 * client in IDENTIFY state or a PAS in VERIFY state.
	 *
	 * @param sendData Send all data as mandated by the protocol, including list of connected clients.
	 * @param sendOwnInf Set to true to broadcast the client's inf (i e when a plugin asks
	 *                   for password)
	 * @return false if the client was disconnected
	 */
	ADCHPP_DLL bool enterNormal(Entity& c, bool sendData, bool sendOwnInf) throw();

	/**
	 * Do all SUP verifications and update client data. Call if you stop SUP but still want the default processing.
	 */
	ADCHPP_DLL bool verifySUP(Entity& c, AdcCommand& cmd) throw();

	/**
	 * Do all INF verifications and update client data. Call if you stop INF but still want the default processing.
	 */
	ADCHPP_DLL bool verifyINF(Entity& c, AdcCommand& cmd) throw();

	/**
	 * Verify nick on INF (check that its not a dupe etc...)
	 * @return false if the client was disconnected
	 */
	ADCHPP_DLL bool verifyNick(Entity& c, const AdcCommand& cmd) throw();

	/**
	 * Verify password
	 */
	ADCHPP_DLL bool verifyPassword(Entity& c, const std::string& password, const ByteVector& salt, const std::string& suppliedHash);

	/**
	 * Verify that IP is correct and replace any zero addresses.
	 */
	ADCHPP_DLL bool verifyIp(Client& c, AdcCommand& cmd) throw();

	/**
	 * Verify that CID is correct and corresponds to PID
	 */
	ADCHPP_DLL bool verifyCID(Entity& c, AdcCommand& cmd) throw();

	/** Update the state of c (this fires signalState as well) */
	ADCHPP_DLL void setState(Entity& c, Entity::State newState) throw();

	ADCHPP_DLL size_t getQueuedBytes() throw();

	typedef SignalTraits<void (Entity&)> SignalConnected;
	typedef SignalTraits<void (Entity&, AdcCommand&, bool&)> SignalReceive;
	typedef SignalTraits<void (Entity&, const std::string&)> SignalBadLine;
	typedef SignalTraits<void (Entity&, const AdcCommand&, bool&)> SignalSend;
	typedef SignalTraits<void (Entity&, int)> SignalState;
	typedef SignalTraits<void (Entity&)> SignalDisconnected;

	SignalConnected::Signal& signalConnected() { return signalConnected_; }
	SignalReceive::Signal& signalReceive() { return signalReceive_; }
	SignalBadLine::Signal& signalBadLine() { return signalBadLine_; }
	SignalSend::Signal& signalSend() { return signalSend_; }
	SignalState::Signal& signalState() { return signalState_; }
	SignalDisconnected::Signal& signalDisconnected() { return signalDisconnected_; }

	void setLoginTimeout(uint32_t millis) { loginTimeout = millis; }
	uint32_t getLoginTimeout() { return loginTimeout; }

private:
	friend class Client;
	friend class Entity;
	friend class Bot;

	std::deque<std::pair<Client*, uint32_t> > logins;

	EntityMap entities;
	typedef std::tr1::unordered_map<std::string, Entity*> NickMap;
	NickMap nicks;
	typedef std::tr1::unordered_map<CID, Entity*> CIDMap;
	CIDMap cids;

	Hub hub;

	size_t loginTimeout;

	// Temporary string to use whenever a temporary string is needed (to avoid (de)allocating memory all the time...)
	std::string strtmp;

	static const std::string className;

	friend class Singleton<ClientManager>;
	ADCHPP_DLL static ClientManager* instance;

	friend class CommandHandler<ClientManager>;

	uint32_t makeSID();

	void maybeSend(Entity& c, const AdcCommand& cmd);

	void removeLogins(Entity& c) throw();
	void removeEntity(Entity& c) throw();

	bool handle(AdcCommand::SUP, Entity& c, AdcCommand& cmd) throw();
	bool handle(AdcCommand::INF, Entity& c, AdcCommand& cmd) throw();
	bool handleDefault(Entity& c, AdcCommand& cmd) throw();

	template<typename T> bool handle(T, Entity& c, AdcCommand& cmd) throw() { return handleDefault(c, cmd); }

	void handleIncoming(const ManagedSocketPtr& sock) throw();

	void onConnected(Client&) throw();
	void onReceive(Entity&, AdcCommand&) throw();
	void onBadLine(Client&, const std::string&) throw();
	void onFailed(Client&) throw();

	void badState(Entity& c, const AdcCommand& cmd) throw();

	SignalConnected::Signal signalConnected_;
	SignalReceive::Signal signalReceive_;
	SignalBadLine::Signal signalBadLine_;
	SignalSend::Signal signalSend_;
	SignalState::Signal signalState_;
	SignalDisconnected::Signal signalDisconnected_;

	ClientManager() throw();

	virtual ~ClientManager() throw();

};

}

#endif // CLIENTMANAGER_H
