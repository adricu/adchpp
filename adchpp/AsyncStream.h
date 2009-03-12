
#include <boost/system/error_code.hpp>
#include "Buffer.h"
#include "Util.h"

namespace adchpp {

class AsyncStream : public intrusive_ptr_base<AsyncStream>, boost::noncopyable {
public:
	typedef std::tr1::function<void (const boost::system::error_code& ec, size_t)> Handler;

	virtual void read(const BufferPtr& buf, const Handler& handler) = 0;
	virtual void write(const BufferList& bufs, const Handler& handler) = 0;
	virtual void close() = 0;

	virtual ~AsyncStream() { }
};

typedef boost::intrusive_ptr<AsyncStream> AsyncStreamPtr;

}
