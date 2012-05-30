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

#ifndef ADCHPP_ADCHPP_SHARED_PTR_H_
#define ADCHPP_ADCHPP_SHARED_PTR_H_

#ifdef __MINGW32__

/* the shared_ptr implementation provided by MinGW / GCC 4.5's libstdc++ consumes too many
semaphores, so we prefer boost's one. see <http://gcc.gnu.org/bugzilla/show_bug.cgi?id=46455>. */

// enabling this on newer GCC versions as well as handle leaks still appear when running scripts.
/// @todo hopefully remove this someday...

#define BOOST_ASIO_DISABLE_STD_SHARED_PTR 1

#include <boost/shared_ptr.hpp>
#include <boost/enable_shared_from_this.hpp>
#include <boost/make_shared.hpp>

#define SHARED_PTR_NS boost

#else

#include <memory>

#define SHARED_PTR_NS std

#endif

namespace adchpp {

using SHARED_PTR_NS::shared_ptr;
using SHARED_PTR_NS::make_shared;
using SHARED_PTR_NS::enable_shared_from_this;
using SHARED_PTR_NS::static_pointer_cast;

}

#undef SHARED_PTR_NS

#endif /* SHARED_PTR_H_ */
