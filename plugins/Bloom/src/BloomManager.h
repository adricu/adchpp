/*
 * Copyright (C) 2006-2013 Jacek Sieka, arnetheduck on gmail point com
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

#ifndef BLOOM_MANAGER_H
#define BLOOM_MANAGER_H

#include <tuple>
#include <adchpp/forward.h>
#include <adchpp/Exception.h>
#include <adchpp/ClientManager.h>
#include <adchpp/Plugin.h>
#include <adchpp/Signal.h>

#include "HashBloom.h"

STANDARD_EXCEPTION(BloomException);

class ADCHPP_VISIBLE BloomManager : public Plugin {
public:
	BloomManager(Core &core);
	virtual ~BloomManager();

	virtual int getVersion() { return 2; }

	void init();

        /*Check if the entity has a bloom filter*/
	bool hasBloom(Entity& c) const;
        
        /*Check if the entity may have the desired TTH according to the filter*/
	bool hasTTH(Entity& c,const TTHValue& tth) const;

	/*Get the number of searches sent (to clients)*/
	int64_t getSearches() const;
	/*Get the number of searches by TTH sent (to clients)*/
	int64_t getTTHSearches() const;
	/*Get the number of sent searches stopped*/
	int64_t getStoppedSearches() const;
        
	static const std::string className;
	
	/*This signal is sent when a BloomFilter has been received*/
	typedef SignalTraits<void (Entity&)> SignalBloomReady;
	/* Is this really necessary? */
	SignalBloomReady::Signal& signalBloomReady() { return signalBloomReady_; }
private:
	PluginDataHandle bloomHandle;
	PluginDataHandle pendingHandle;

	int64_t searches;
	int64_t tthSearches;
	int64_t stopped;

	ClientManager::SignalReceive::ManagedConnection receiveConn;
	ClientManager::SignalSend::ManagedConnection sendConn;
	ClientManager::SignalReceive::ManagedConnection statsConn;

	std::pair<size_t, size_t> getBytes() const;
	void onReceive(Entity& c, AdcCommand& cmd, bool&);
	void onSend(Entity& c, const AdcCommand& cmd, bool&);
	void onData(Entity& c, const uint8_t* data, size_t len);
	void onStats(Entity& c);

	Core &core;
	
	SignalBloomReady::Signal signalBloomReady_;
};

#endif //ACCESSMANAGER_H
