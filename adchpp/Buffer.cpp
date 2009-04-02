#include "adchpp.h"

#include "Buffer.h"

namespace adchpp {

size_t Buffer::defaultBufferSize = 128;

Pool<ByteVector, Buffer::Clear> Buffer::free;

void Buffer::Clear::operator()(ByteVector& v) {
	if(v.capacity() > static_cast<size_t>(getDefaultBufferSize())) {
		ByteVector().swap(v);
	} else {
	 	v.clear();
	}
}

}
