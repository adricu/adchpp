/*
 * Copyright (C) 2006-2012 Jacek Sieka, arnetheduck on gmail point com
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

#include "Core.h"

#include "LogManager.h"
#include "SocketManager.h"
#include "ClientManager.h"
#include "PluginManager.h"

namespace adchpp {

shared_ptr<Core> Core::create(const std::string &configPath) {
	auto ret = shared_ptr<Core>(new Core(configPath));
	ret->init();
	return ret;
}

Core::Core(const std::string &configPath) : configPath(configPath), startTime(time::now())
{
}

Core::~Core() {
	lm->log("core", "Shutting down...");
	// Order is significant...
	pm.reset();
	cm.reset();
	sm.reset();
	lm.reset();
}

void Core::init() {
	lm.reset(new LogManager(*this));
	sm.reset(new SocketManager(*this));
	cm.reset(new ClientManager(*this));
	pm.reset(new PluginManager(*this));

	sm->setIncomingHandler(std::bind(&ClientManager::handleIncoming, cm.get(), std::placeholders::_1));
	lm->log("core", "Core initialized");
}

void Core::run() {
	pm->load();

	sm->run();
}

void Core::shutdown() {
	sm->shutdown();
	pm->shutdown();
}

const std::string &Core::getConfigPath() const { return configPath; }
LogManager &Core::getLogManager() { return *lm; }
SocketManager &Core::getSocketManager() { return *sm; }
PluginManager &Core::getPluginManager() { return *pm; }
ClientManager &Core::getClientManager() { return *cm; }

void Core::addJob(const Callback& callback) throw() { sm->addJob(callback); }

void Core::addJob(const long msec, const Callback& callback) { sm->addJob(msec, callback); }

void Core::addJob(const std::string& time, const Callback& callback) { sm->addJob(time, callback); }

Core::Callback Core::addTimedJob(const long msec, const Callback& callback) { return sm->addTimedJob(msec, callback); }

Core::Callback Core::addTimedJob(const std::string& time, const Callback& callback) { return sm->addTimedJob(time, callback); }

}
