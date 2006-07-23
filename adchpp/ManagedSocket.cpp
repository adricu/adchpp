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

#include "adchpp.h"

#include "ManagedSocket.h"

#include "SocketManager.h"
#include "TimerManager.h"
#include "PluginManager.h"
#include "SettingsManager.h"

namespace adchpp {
	
FastMutex ManagedSocket::outbufCS;

ManagedSocket::ManagedSocket() throw() : outBuf(0), overFlow(0), disc(0), refCount(1)
#ifdef _WIN32
, writeBuf(0)
#endif
{
}

ManagedSocket::~ManagedSocket() throw() {
	if(outBuf) {
		dcdebug("Left (%d): %.*s\n", outBuf->size(), outBuf->size(), &(*outBuf)[0]);
		Util::freeBuf = outBuf;
	}
	
#ifdef _WIN32
	if(writeBuf) {
		dcdebug("Left2 (%d): %.*s\n", writeBuf->size(), writeBuf->size(), &(*writeBuf)[0]);
		Util::freeBuf = writeBuf;
	}
#endif
}

void ManagedSocket::write(const char* buf, size_t len) throw() {
	{
		FastMutex::Lock l(outbufCS);
		fastWrite(buf, len);
	}
	SocketManager::getInstance()->addWriter(this);
}

void ManagedSocket::fastWrite(const char* buf, size_t len, bool lowPrio /* = false */) throw() {
	if((len == 0) || (disc > 0))
		return;
	
	if(outBuf == 0) {
		outBuf = Util::freeBuf;
	}
	
	if(outBuf->size() + len > (uint32_t)SETTING(MAX_BUFFER_SIZE)) {
		if(lowPrio && SETTING(KEEP_SLOW_USERS)) {
			return;
		} else if(overFlow + SETTING(OVERFLOW_TIMEOUT) < GET_TICK()) {
			disconnect();
			return;
		} else {
			overFlow = GET_TICK();
		}
	}
	
	outBuf->insert(outBuf->end(), buf, buf + len);
}

ByteVector* ManagedSocket::prepareWrite() {
	ByteVector* buffer = 0;

	{
		FastMutex::Lock l(outbufCS);

		if(outBuf == 0) {
			return 0;
		}		

		if(SETTING(MAX_SEND_SIZE) > 0 && (outBuf->size() > (size_t)SETTING(MAX_SEND_SIZE))) {
			// Damn, we take a copy and leave the rest...
			buffer = Util::freeBuf;
			buffer->insert(buffer->end(), outBuf->begin(), outBuf->begin() + SETTING(MAX_SEND_SIZE));
			outBuf->erase(outBuf->begin(), outBuf->begin() + SETTING(MAX_SEND_SIZE));
		} else {
			buffer = outBuf;
			outBuf = 0;
		}
	}
	return buffer;
}

bool ManagedSocket::completeWrite(ByteVector* buf, size_t written) throw() {

	Util::stats.totalUp += written;

	FastMutex::Lock l(outbufCS);
	
	if(written == buf->size()) {
		// Everything written, good...
		Util::freeBuf = buf;
	} else {
		if(outBuf == 0) {
			buf->erase(buf->begin(), buf->begin() + written);
			outBuf = buf;
			buf = 0;
		} else {
			outBuf->insert(outBuf->begin(), buf->begin() + written, buf->end());
			Util::freeBuf = buf;
		}
	} 
	
	if( (outBuf == 0) || (outBuf->size() < (size_t)SETTING(MAX_BUFFER_SIZE)) )
		overFlow = 0;

	return outBuf != 0;
}

bool ManagedSocket::completeRead(ByteVector* buf) throw() {
	Util::stats.totalDown += buf->size();
	SocketManager::getInstance()->addJob(boost::bind(&ManagedSocket::processData, this, buf));
	return true;
}

void ManagedSocket::disconnect() throw() {
	if(disc) {
		return;
	}

	disc = GET_TICK();
	SocketManager::getInstance()->addDisconnect(this);
}

void ManagedSocket::processIncoming() throw() {
	connectedHandler();
}

void ManagedSocket::processData(ByteVector* buf) throw() {
	dataHandler(*buf);
	Util::freeBuf = buf;
}

void ManagedSocket::processFail() throw() {
	failedHandler();
	SocketManager::getInstance()->addDeref(this);
}

}
