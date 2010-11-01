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

#include "adchpp.h"

#include "Bot.h"

#include "ClientManager.h"
#include "SocketManager.h"

namespace adchpp {

// TODO replace with lambda
struct BotRemover {
	BotRemover(Bot* bot_) : bot(bot_) { }
	void operator()() {
		bot->die();
	}

	Bot* bot;
};

Bot::Bot(uint32_t sid, const Bot::SendHandler& handler_) : Entity(sid), handler(handler_), disconnecting(false) {
	setFlag(FLAG_BOT);

	// Fake a CID, the script can change this if it wants to
	setCID(CID::generate());
}

void Bot::disconnect(Util::Reason reason) throw() {
	if(!disconnecting) {
		handler = SendHandler();
		SocketManager::getInstance()->addJob(BotRemover(this));
	}
}

void Bot::die() {
	ClientManager::getInstance()->removeEntity(*this);
	delete this;
}

}

