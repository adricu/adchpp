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

#include "adchpp.h"

#include "Bot.h"
#include "AdcCommand.h"
#include "ClientManager.h"

namespace adchpp {

Bot::Bot(uint32_t sid, const Bot::SendHandler& handler_) : Entity(sid), handler(handler_) {
	setFlag(FLAG_BOT);

	// Fake a CID (maybe this should be permanent?)
	setCID(CID::generate());
}

void Bot::disconnect(Util::Reason reason) throw() {
	//@todo, maby improve?
	ClientManager::getInstance()->removeEntity(*this);
	delete this;
}

void Bot::inject(AdcCommand& cmd) {
	// @todo maybe make async?
	ClientManager::getInstance()->onReceive(*this, cmd);
}

}

