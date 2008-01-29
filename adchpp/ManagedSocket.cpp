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

#include "ManagedSocket.h"

#include "SocketManager.h"
#include "TimerManager.h"
#include "PluginManager.h"
#include "SettingsManager.h"

namespace adchpp {
	
using namespace std;

FastMutex ManagedSocket::writeMutex;

ManagedSocket::ManagedSocket() throw() : overFlow(0), disc(0)
#ifndef _WIN32
, blocked(false)
#endif
{
}

ManagedSocket::~ManagedSocket() throw() {
	dcdebug("ManagedSocket deleted\n");
}

void ManagedSocket::write(const BufferPtr& buf) throw() {
	FastMutex::Lock l(writeMutex);
	fastWrite(buf);
}

static size_t sum(const BufferList& l) {
	size_t bytes = 0;
	for(BufferList::const_iterator i = l.begin(); i != l.end(); ++i) {
		bytes += (*i)->size();
	}
	return bytes;
}

size_t ManagedSocket::getQueuedBytes() const {
	return sum(outBuf);
}

void ManagedSocket::fastWrite(const BufferPtr& buf, bool lowPrio /* = false */) throw() {
	if((buf->size() == 0) || (disc > 0))
		return;
	
	size_t queued = getQueuedBytes();
	
	if(queued + buf->size() > (size_t)SETTING(MAX_BUFFER_SIZE)) {
		if(lowPrio && SETTING(KEEP_SLOW_USERS)) {
			return;
		} else if(overFlow > 0 && overFlow + SETTING(OVERFLOW_TIMEOUT) < GET_TICK()) {
			disconnect(Util::REASON_WRITE_OVERFLOW);
			return;
		} else {
			overFlow = GET_TICK();
		}
	}
	
	Stats::queueBytes += buf->size();
	Stats::queueCalls++;
	outBuf.push_back(buf);
}

void ManagedSocket::prepareWrite(BufferList& buffers) {
	if(isBlocked()) {
		return;
	}
	
	FastMutex::Lock l(writeMutex);		
	size_t queued = getQueuedBytes();
	if(queued == 0) {
		return;
	}
	
	size_t max_send = static_cast<size_t>(SETTING(MAX_SEND_SIZE));
	
	if((max_send > 0) && (queued > max_send)) {
		// Copy as many buffers as possible
		// TODO The last copied buffer should be split...
		size_t done = 0;
		BufferList::iterator i = outBuf.begin();
		do {
			buffers.push_back(*i);
			done += (*i)->size();
			++i;
		} while((i != outBuf.end()) && (done < max_send));

		outBuf.erase(outBuf.begin(), i);
	} else {
		buffers.swap(outBuf);
	}
}

bool ManagedSocket::completeWrite(BufferList& buffers, size_t written) throw() {

	Stats::sendBytes += written;
	Stats::sendCalls++;

	size_t done = 0;
	BufferList::iterator i = buffers.begin();
	for(; i != buffers.end(); ++i) {
		if(done + (*i)->size() > written) {
			break;
		}
		done += (*i)->size();
	}
	
	FastMutex::Lock l(writeMutex);
	
	if(done != written) {
		// i points to the first not fully written buffer..
		size_t diff = written - done;
		if(diff != 0) {
			(*i)->erase_first(diff);
		}
		
		dcdebug("Tried %u buffers, readding %u buffers, diff is %u\n", buffers.size(), std::distance(i, buffers.end()), diff);
		outBuf.insert(outBuf.begin(), i, buffers.end());
	}

	buffers.clear();
	
	size_t left = getQueuedBytes();
	if(overFlow > 0) {
		if(left < static_cast<size_t>(SETTING(MAX_BUFFER_SIZE))) {
			overFlow = 0;
		}
	}
	
	return left > 0 || disc > 0;
}

bool ManagedSocket::completeRead(const BufferPtr& buf) throw() {
	Stats::recvBytes += buf->size();
	Stats::recvCalls++;
	SocketManager::getInstance()->addJob(std::tr1::bind(&ManagedSocket::processData, this, buf));
	return true;
}

void ManagedSocket::completeAccept() throw() {
	SocketManager::getInstance()->addJob(connectedHandler);
}

void ManagedSocket::failSocket(int) throw() {
	sock.disconnect();
	SocketManager::getInstance()->addJob(failedHandler);
}

void ManagedSocket::disconnect(Util::Reason reason) throw() {
	if(disc) {
		return;
	}

	disc = GET_TICK() + SETTING(DISCONNECT_TIMEOUT);
	Util::reasons[reason]++;
}

void ManagedSocket::processData(const BufferPtr& buf) throw() {
	dataHandler(buf);
}

}
