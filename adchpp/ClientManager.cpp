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

#include "ClientManager.h"

#include "File.h"
#include "Client.h"
#include "LogManager.h"
#include "TimerManager.h"
#include "SocketManager.h"
#include "TigerHash.h"
#include "Encoder.h"
#include "version.h"
#include "SettingsManager.h"

namespace adchpp {
	
ClientManager* ClientManager::instance = 0;
const string ClientManager::className = "ClientManager";

ClientManager::ClientManager() throw() {
	supports.push_back("BASE");
	supports.push_back("TIGR");
}

ClientManager::~ClientManager() throw() {
	
}

void ClientManager::send(const AdcCommand& cmd, bool lowPrio /* = false */) throw() {
	const string& txt = cmd.toString();

	switch(cmd.getType()) {
		case AdcCommand::TYPE_FEATURE:
		case AdcCommand::TYPE_BROADCAST:
		{
			bool all = (cmd.getType() == AdcCommand::TYPE_BROADCAST);
			FastMutex::Lock l(ManagedSocket::getWriteMutex());
			for(ClientIter i = clients.begin(); i != clients.end(); ++i) {
				if(all || !i->second->isFiltered(cmd.getFeatures()))
					i->second->fastSend(txt, lowPrio);
			}
		}
		SocketManager::getInstance()->addAllWriters();
		break;
		case AdcCommand::TYPE_DIRECT: // Fallthrough
		case AdcCommand::TYPE_ECHO:
			{
				ClientIter i = clients.find(cmd.getTo());
				if(i != clients.end()) {
					i->second->send(txt);
					if(COMPATIBILITY || cmd.getType() == AdcCommand::TYPE_ECHO) {
						i = clients.find(cmd.getFrom());
						if(i != clients.end()) {
							i->second->send(txt);
						}
					}
				}
			}
			break;
	}
}

void ClientManager::sendToAll(const string& cmd) throw() {
	{
		FastMutex::Lock l(ManagedSocket::getWriteMutex());
		for(ClientIter i = clients.begin(); i != clients.end(); ++i) {
			i->second->fastSend(cmd);
		}
	}
	SocketManager::getInstance()->addAllWriters();
}

size_t ClientManager::getQueuedBytes() throw() {
	size_t total = 0;
	
	FastMutex::Lock l(ManagedSocket::getWriteMutex());
	for(ClientIter i = clients.begin(); i != clients.end(); ++i) {
		total += i->second->getQueuedBytes();
	}
	return total;
}

void ClientManager::sendTo(const AdcCommand& cmd, const uint32_t& to) throw() {
	ClientIter i = clients.find(to);
	if(i != clients.end()) {
		i->second->send(cmd.toString());
	}
}

void ClientManager::updateCache() throw() {
	// Update static strings...
	AdcCommand s(AdcCommand::CMD_SUP);
	for(StringIter i = supports.begin(); i != supports.end(); ++i)
		s.addParam("AD" + *i);
	strings.sup = s.toString();

	strings.inf = AdcCommand(AdcCommand::CMD_INF)
		.addParam("NI", SETTING(HUB_NAME))
		.addParam("HI1")
		.addParam("DE", SETTING(DESCRIPTION))
		.addParam("VE", versionString)
		.addParam("CT5")
		.toString();
}

bool ClientManager::checkFlooding(Client& c, const AdcCommand& cmd) throw() {
	time_t add = ((cmd.getType() == AdcCommand::TYPE_BROADCAST || cmd.getType() == AdcCommand::TYPE_FEATURE) ? 1 : 0) * SETTING(FLOOD_ADD);
	if(c.isFlooding(add)) {
		c.disconnect(Util::REASON_FLOODING);
		return true;
	}
	
	return false;
}

void ClientManager::incomingConnection(const ManagedSocketPtr& ms) throw() {
	Client::create(ms);
}

uint32_t ClientManager::makeSID() {
	while(true) {
		union {
			uint32_t sid;
			char chars[4];
		} sid;
		sid.chars[0] = Encoder::base32Alphabet[Util::rand(sizeof(Encoder::base32Alphabet))];
		sid.chars[1] = Encoder::base32Alphabet[Util::rand(sizeof(Encoder::base32Alphabet))];
		sid.chars[2] = Encoder::base32Alphabet[Util::rand(sizeof(Encoder::base32Alphabet))];
		sid.chars[3] = Encoder::base32Alphabet[Util::rand(sizeof(Encoder::base32Alphabet))];
		if(sids.find(sid.sid) == sids.end()) {
			sids.insert(sid.sid);
			return sid.sid;
		}
	}
}

void ClientManager::onConnected(Client& c) throw() {
	// First let's check if any clients have passed the login timeout...
	time_t timeout = GET_TIME() - SETTING(LOGIN_TIMEOUT);
	while(!logins.empty() && (timeout > logins.front().second) ) {
		Client* cc = logins.front().first;

		dcdebug("ClientManager: Login timeout in state %d\n", cc->getState());
		cc->disconnect(Util::REASON_LOGIN_TIMEOUT);
		logins.pop_front();
	}

	logins.push_back(make_pair(&c, GET_TIME()));
	c.setSID(makeSID());
	signalConnected_(c);
}

void ClientManager::onReceive(Client& c, AdcCommand& cmd) throw() {
	int override = 0;
	if(!(
		cmd.getType() == AdcCommand::TYPE_BROADCAST || 
		cmd.getType() == AdcCommand::TYPE_DIRECT || 
		cmd.getType() == AdcCommand::TYPE_ECHO || 
		cmd.getType() == AdcCommand::TYPE_FEATURE || 
		cmd.getType() == AdcCommand::TYPE_HUB)) 
	{
		c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC, "Invalid command type"));
		c.disconnect(Util::REASON_INVALID_COMMAND_TYPE);
		return;
	}

	if(checkFlooding(c, cmd)) {
		return;
	}
	
	signalReceive_(c, cmd, override);

	if(!(override & DONT_DISPATCH)) {
		if(!dispatch(c, cmd)) {
			return;
		}
	}
	
	if(!(override & DONT_SEND)) {
		send(cmd);
	}
}

void ClientManager::onBadLine(Client& c, const string& aLine) throw() {
	signalBadLine_(c, aLine);
}

void ClientManager::badState(Client& c) throw() {
	c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_BAD_STATE, "Invalid state for command"));
	c.disconnect(Util::REASON_BAD_STATE);
}	

bool ClientManager::handleDefault(Client& c, AdcCommand&) throw() {
	if(c.getState() != Client::STATE_NORMAL) {
		badState(c);
		return false;
	}			
	return true; 
}

bool ClientManager::handle(AdcCommand::SUP, Client& c, AdcCommand& cmd) throw() {
	if(!verifySUP(c, cmd)) {
		return false;
	}

	if(c.getState() == Client::STATE_PROTOCOL) {
		enterIdentify(c, true);
	} else if(c.getState() != Client::STATE_NORMAL) {
		badState(c);
		return false;
	}
	return true;
}

bool ClientManager::verifySUP(Client& c, AdcCommand& cmd) throw() {
	c.updateSupports(cmd);
	if(!c.supports("BASE") && !c.supports("BAS0")) {
		c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC, "This hub requires BASE support"));
		c.disconnect(Util::REASON_NO_BASE_SUPPORT);
	}
	return true;
}

bool ClientManager::verifyINF(Client& c, AdcCommand& cmd) throw() {
	if(!verifyIp(c, cmd))
		return false;

	if(!verifyCID(c, cmd))
		return false;

	if(!verifyNick(c, cmd))
		return false;

	if(!verifyUsers(c))
		return false;

	c.updateFields(cmd);
	return true;
}

bool ClientManager::verifyPassword(Client& c, const string& password, const vector<uint8_t>& salt, const string& suppliedHash) {
	TigerHash tiger;
	tiger.update(&password[0], password.size());
	tiger.update(&salt[0], salt.size());
	uint8_t tmp[TigerHash::HASH_SIZE];
	Encoder::fromBase32(suppliedHash.c_str(), tmp, TigerHash::HASH_SIZE);
	if(memcmp(tiger.finalize(), tmp, TigerHash::HASH_SIZE) == 0)
		return true;
	
	TigerHash tiger2;
	// Support dc++ 0.69 for a while
	string cid = c.getCID().toBase32();
	tiger2.update(c.getCID().data(), CID::SIZE);
	tiger2.update(&password[0], password.size());
	tiger2.update(&salt[0], salt.size());
	if(memcmp(tiger2.finalize(), tmp, TigerHash::HASH_SIZE) == 0) {
		c.send(AdcCommand(AdcCommand::CMD_MSG).addParam("Your client uses an old PAS encoding, please upgrade"));
		return true;
	}
	return false;	
}

bool ClientManager::handle(AdcCommand::INF, Client& c, AdcCommand& cmd) throw() {
	if(c.getState() != Client::STATE_IDENTIFY && c.getState() != Client::STATE_NORMAL) {
		badState(c);
		return false;
	}
			
	if(!verifyINF(c, cmd))
		return false;

	if(c.getState() == Client::STATE_IDENTIFY) {
		enterNormal(c, true, false);
	}
	
	return true;
}

bool ClientManager::verifyIp(Client& c, AdcCommand& cmd) throw() {
	if(c.isSet(Client::FLAG_OK_IP))
		return true;
		
	for(StringIter j = cmd.getParameters().begin(); j != cmd.getParameters().end(); ++j) {
		if(j->compare(0, 2, "I4") == 0) {
			dcdebug("%s verifying ip\n", AdcCommand::fromSID(c.getSID()).c_str());
			if(j->size() == 2) {
				// Clearing is ok
			} else if(j->compare(2, j->size()-2, "0.0.0.0") == 0) {
				c.setField("I4", c.getIp());
				*j = "I4" + c.getIp();
				cmd.resetString();
			} else if(j->size()-2 != c.getIp().size() || j->compare(2, j->size()-2, c.getIp()) != 0) {
				c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_BAD_IP, "Your ip is " + c.getIp()).addParam("IP", c.getIp()));
				c.disconnect(Util::REASON_INVALID_IP);
				return false;
			}
		}
	}
	return true;
}

bool ClientManager::verifyCID(Client& c, AdcCommand& cmd) throw() {
	if(cmd.getParam("ID", 0, strtmp)) {
		dcdebug("%s verifying CID\n", AdcCommand::fromSID(c.getSID()).c_str());
		if(c.getState() != Client::STATE_IDENTIFY) {
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC, "CID changes not allowed"));
			c.disconnect(Util::REASON_CID_CHANGE);
			return false;			
		}
		
		string spid;
		if(!cmd.getParam("PD", 0, spid)) {
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_INF_MISSING, "PID missing").addParam("FLPD"));
			c.disconnect(Util::REASON_PID_MISSING);
			return false;
		}
		
		if(strtmp.size() != CID::BASE32_SIZE || spid.size() != CID::BASE32_SIZE) {
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC, "Invalid CID/PID length"));
			c.disconnect(Util::REASON_PID_CID_LENGTH);
			return false;
		}			
		
		CID cid(strtmp);
		CID pid(spid);

		TigerHash th;
		th.update(pid.data(), CID::SIZE);
		if(!(CID(th.finalize()) == cid)) {
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_INVALID_PID, "PID does not correspond to CID"));
			c.disconnect(Util::REASON_PID_CID_MISMATCH);
			return false;
		}
		CIDMap::iterator i = cids.find(cid);
		if(i != cids.end()) {
			ClientIter j = clients.find(i->second);
			if(j != clients.end()) {
				j->second->send("\n");
			}
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_CID_TAKEN, STRING(CID_TAKEN)));
			c.disconnect(Util::REASON_CID_TAKEN);
			return false;
		}

		c.setCID(cid);
		cids.insert(make_pair(c.getCID(), c.getSID()));
		cmd.delParam("PD", 0);
	}
	
	if(cmd.getParam("PD", 0, strtmp)) {
		c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_PROTOCOL_GENERIC, "PD but no ID"));
		c.disconnect(Util::REASON_PID_WITHOUT_CID);
		return false;
	}
	return true;
}

bool ClientManager::verifyNick(Client& c, const AdcCommand& cmd) throw() {

	if(cmd.getParam("NI", 0, strtmp)) {
		dcdebug("%s verifying nick\n", AdcCommand::fromSID(c.getSID()).c_str());
		for(string::size_type i = 0; i < strtmp.length(); ++i) {
			if((uint8_t)strtmp[i] < 33) {
				c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_NICK_INVALID, STRING(NICK_INVALID)));
				c.disconnect(Util::REASON_NICK_INVALID);
				return false;
			}
		}
		const string& oldNick = c.getField("NI");
		if(!oldNick.empty())
			nicks.erase(oldNick);
		
		if(nicks.find(strtmp) != nicks.end()) {
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_NICK_TAKEN, STRING(NICK_TAKEN)));
			c.disconnect(Util::REASON_NICK_TAKEN);
			return false;
		}

		nicks.insert(make_pair(strtmp, c.getSID()));
	}

	return true;
}

void ClientManager::setState(Client& c, Client::State newState) throw() {
	Client::State oldState = c.getState();
	c.setState(newState);
	signalState_(c, oldState);
}

bool ClientManager::verifyUsers(Client& c) throw() {
	if(c.isSet(Client::FLAG_OK_COUNT))
		return true;
	dcdebug("%s verifying user count\n", AdcCommand::fromSID(c.getSID()).c_str());

	if(SETTING(MAX_USERS) > 0 && clients.size() >= (size_t)SETTING(MAX_USERS)) {
		if(BOOLSETTING(REDIRECT_FULL)) {
			c.send(AdcCommand(AdcCommand::CMD_QUI).addParam("RD", SETTING(REDIRECT_SERVER)).addParam("MS", STRING(HUB_FULL)));
		} else {
			c.send(AdcCommand(AdcCommand::SEV_FATAL, AdcCommand::ERROR_HUB_FULL, STRING(HUB_FULL)));
		}
		c.disconnect(Util::REASON_HUB_FULL);
		return false;
	}
	c.setFlag(Client::FLAG_OK_COUNT);
	return true;
}

void ClientManager::enterIdentify(Client& c, bool sendData) throw() {
	dcassert(c.getState() == Client::STATE_PROTOCOL);
	dcdebug("%s entering IDENTIFY\n", AdcCommand::fromSID(c.getSID()).c_str());
	if(sendData) {
		c.send(strings.sup);
		c.send(AdcCommand(AdcCommand::CMD_SID).addParam(AdcCommand::fromSID(c.getSID())));
		c.send(strings.inf);
	}
	setState(c, Client::STATE_IDENTIFY);
}

vector<uint8_t> ClientManager::enterVerify(Client& c, bool sendData) throw() {
	dcassert(c.getState() == Client::STATE_IDENTIFY);
	dcdebug("%s entering VERIFY\n", AdcCommand::fromSID(c.getSID()).c_str());
	vector<uint8_t> challenge;
	if(sendData) {
		for(int i = 0; i < 32/4; ++i) {
			uint32_t r = Util::rand();
			challenge.insert(challenge.end(), (uint8_t*)&r, 4 + (uint8_t*)&r);
		}
		c.send(AdcCommand(AdcCommand::CMD_GPA).addParam(Encoder::toBase32(&challenge[0], challenge.size())));
	}
	setState(c, Client::STATE_VERIFY);
	return challenge;
}

bool ClientManager::enterNormal(Client& c, bool sendData, bool sendOwnInf) throw() {
	dcassert(c.getState() == Client::STATE_IDENTIFY || c.getState() == Client::STATE_VERIFY);
	dcdebug("%s entering NORMAL\n", AdcCommand::fromSID(c.getSID()).c_str());

	if(sendData) {
		string str;
		for(ClientIter i = clients.begin(); i != clients.end(); ++i) {
			str += i->second->getINF();
		}
		c.send(str);
		if(sendOwnInf) {
			sendToAll(c.getINF());
			c.send(c.getINF());
		}
	}

	removeLogins(c);
	setState(c, Client::STATE_NORMAL);

	clients.insert(make_pair(c.getSID(), &c));

	return true;
}

void ClientManager::removeLogins(Client& c) throw() {
	deque<pair<Client*, time_t> >::iterator i = find_if(logins.begin(), logins.end(), CompareFirst<Client*, time_t>(&c));
	if(i != logins.end()) {
		logins.erase(i);
	}
}

void ClientManager::removeClient(Client& c) throw() {
	signalDisconnected_(c);
	dcdebug("Removing %s\n", AdcCommand::fromSID(c.getSID()).c_str());
	if(c.getState() == Client::STATE_NORMAL) {
		clients.erase(c.getSID());
		sendToAll(AdcCommand(AdcCommand::CMD_QUI).addParam(AdcCommand::fromSID(c.getSID())));
	} else {
		removeLogins(c);
	}
	nicks.erase(c.getField("NI"));
	cids.erase(c.getCID());
	sids.erase(c.getSID());
}

void ClientManager::addSupports(const string& str) throw() {
	if(find(supports.begin(), supports.end(), str) != supports.end())
		return;
		
	supports.push_back(str);
	updateCache();
	sendToAll(AdcCommand(AdcCommand::CMD_SUP).addParam("AD" + str));
}

void ClientManager::removeSupports(const string& str) throw() {
	StringIter i = find(supports.begin(), supports.end(), str);
	if(i != supports.end()) {
		supports.erase(i);
		updateCache();
		sendToAll(AdcCommand(AdcCommand::CMD_SUP).addParam("RM" + str));
	}
}

uint32_t ClientManager::getSID(const string& aNick) const throw() {
	NickMap::const_iterator i = nicks.find(aNick);
	return (i == nicks.end()) ? 0 : i->second;
}

uint32_t ClientManager::getSID(const CID& cid) const throw() {
	CIDMap::const_iterator i = cids.find(cid);
	return (i == cids.end()) ? 0 : i->second;	
}

void ClientManager::shutdown() {
	
}

void ClientManager::onFailed(Client& c) throw() {
	removeClient(c);
}

}
