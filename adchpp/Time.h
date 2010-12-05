#ifndef ADCHPP_ADCHPP_TIME_H_
#define ADCHPP_ADCHPP_TIME_H_

#include <boost/date_time/posix_time/posix_time.hpp>

namespace adchpp {
	namespace time {
		using namespace boost::posix_time;

		inline ptime now() { return microsec_clock::local_time(); }
	}
}

#endif /* TIME_H_ */
