#include "adchpp.h"

#include "Buffer.h"
#include "SettingsManager.h"

namespace adchpp {

Pool<ByteVector, Buffer::Clear> Buffer::free;

void Buffer::Clear::operator()(ByteVector& v) {
	if(v.capacity() > static_cast<size_t>(SETTING(BUFFER_SIZE))) {
		ByteVector().swap(v);
	} else {
	 	v.clear();
	}
}

}
