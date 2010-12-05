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

#ifndef BLOOM_MANAGER_H
#define BLOOM_MANAGER_H

#include <tuple>
#include <adchpp/forward.h>
#include <adchpp/Exception.h>
#include <adchpp/ClientManager.h>
#include <adchpp/Plugin.h>

#include "HashBloom.h"

STANDARD_EXCEPTION(BloomException);

class BloomManager : public Plugin {
public:
	BloomManager(Core &core);
	virtual ~BloomManager();

	virtual int getVersion() { return 0; }

	void init();

	static const std::string className;
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
};

#endif //ACCESSMANAGER_H
