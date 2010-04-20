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

#include "AdcCommand.h"

namespace adchpp {

#ifdef __GNUC__ /// @todo go figure why some GCCs need these...
const char AdcCommand::TYPE_BROADCAST;
const char AdcCommand::TYPE_CLIENT;
const char AdcCommand::TYPE_DIRECT;
const char AdcCommand::TYPE_ECHO;
const char AdcCommand::TYPE_FEATURE;
const char AdcCommand::TYPE_INFO;
const char AdcCommand::TYPE_HUB;
const char AdcCommand::TYPE_UDP;
#endif

using namespace std;

AdcCommand::AdcCommand() : cmdInt(0), priority(PRIORITY_NORMAL), from(0), type(0) { }

AdcCommand::AdcCommand(Severity sev, Error err, const string& desc, char aType /* = TYPE_INFO */) : cmdInt(CMD_STA), priority(PRIORITY_NORMAL), from(HUB_SID), type(aType) {
	addParam(Util::toString(sev * 100 + err));
	addParam(desc);
}

void AdcCommand::escape(const string& s, string& out) {
	out.reserve(out.length() + static_cast<size_t>(s.length() * 1.1));

	for(string::const_iterator i = s.begin(), iend = s.end(); i != iend; ++i) {
		switch(*i) {
			case ' ': out += '\\'; out += 's'; break;
			case '\n': out += '\\'; out += 'n'; break;
			case '\\': out += '\\'; out += '\\'; break;
			default: out += *i;
		}
	}
}

void AdcCommand::parse(const char* buf, size_t len) throw(ParseException) {
	if(len < 5) {
		throw ParseException("Command too short");
	}

	type = buf[0];

	if(type != TYPE_BROADCAST && type != TYPE_CLIENT && type != TYPE_DIRECT && type != TYPE_ECHO && type != TYPE_FEATURE && type != TYPE_INFO && type != TYPE_HUB && type != TYPE_UDP) {
		throw ParseException("Invalid type");
	}

	cmd[0] = buf[1];
	cmd[1] = buf[2];
	cmd[2] = buf[3];

	if(buf[4] != ' ') {
		throw ParseException("Missing space after command");
	}

	// Skip trailing LF
	len--;

	parameters.reserve(8);

	string cur;
	cur.reserve(64);

	bool toSet = false;
	bool featureSet = false;
	bool fromSet = false;

	string::size_type i = 5;
	while(i < len) {
		switch(buf[i]) {
		case '\\':
			++i;
			if(i == len)
				throw ParseException("Escape at eol");
			if(buf[i] == 's')
				cur += ' ';
			else if(buf[i] == 'n')
				cur += '\n';
			else if(buf[i] == '\\')
				cur += '\\';
			else
				throw ParseException("Unknown escape");
			break;
		case ' ':
			// New parameter...
			{
				if((type == TYPE_BROADCAST || type == TYPE_DIRECT || type == TYPE_ECHO || type == TYPE_FEATURE) && !fromSet) {
					if(cur.length() != 4) {
						throw ParseException("Invalid SID length");
					}
					from = toSID(cur);
					fromSet = true;
				} else if((type == TYPE_DIRECT || type == TYPE_ECHO) && !toSet) {
					if(cur.length() != 4) {
						throw ParseException("Invalid SID length");
					}
					to = toSID(cur);
					toSet = true;
				} else if(type == TYPE_FEATURE && !featureSet) {
					if(cur.length() % 5 != 0) {
						throw ParseException("Invalid feature length");
					}
                    features = cur;
					featureSet = true;
				} else {
					if(!Util::validateUtf8(cur)) {
						throw ParseException("Invalid UTF-8 sequence");
					}
					parameters.push_back(cur);
				}
				cur.clear();
			}
			break;
		default:
			cur += buf[i];
		}
		++i;
	}

	if(!cur.empty()) {
		if((type == TYPE_BROADCAST || type == TYPE_DIRECT || type == TYPE_ECHO || type == TYPE_FEATURE) && !fromSet) {
			if(cur.length() != 4) {
				throw ParseException("Invalid SID length");
			}
			from = toSID(cur);
			fromSet = true;
		} else if((type == TYPE_DIRECT || type == TYPE_ECHO) && !toSet) {
			if(cur.length() != 4) {
				throw ParseException("Invalid SID length");
			}
			to = toSID(cur);
			toSet = true;
		} else if(type == TYPE_FEATURE && !featureSet) {
			if(cur.length() % 5 != 0) {
				throw ParseException("Invalid feature length");
			}
            features = cur;
			featureSet = true;
		} else {
			if(!Util::validateUtf8(cur)) {
				throw ParseException("Invalid UTF-8 sequence");
			}
			parameters.push_back(cur);
		}
	}

	if((type == TYPE_BROADCAST || type == TYPE_DIRECT || type == TYPE_ECHO || type == TYPE_FEATURE) && !fromSet) {
		throw ParseException("Missing from_sid");
	}

	if(type == TYPE_FEATURE && !featureSet) {
		throw ParseException("Missing feature");
	}

	if((type == TYPE_DIRECT || type == TYPE_ECHO) && !toSet) {
		throw ParseException("Missing to_sid");
	}
}

const BufferPtr& AdcCommand::getBuffer() const {
	if(!buffer) {
		buffer = BufferPtr(new Buffer(toString()));
	}
	return buffer;
}

string AdcCommand::toString() const {
	if(buffer) {
		return string((char*)buffer->data(), buffer->size());
	}
	string tmp;

	tmp.reserve(128);

	tmp += type;
	tmp += cmdChar;

	if(type == TYPE_BROADCAST || type == TYPE_DIRECT || type == TYPE_ECHO || type == TYPE_FEATURE) {
		tmp += ' ';
		appendSID(tmp, from);
	}

	if(type == TYPE_DIRECT || type == TYPE_ECHO) {
		tmp += ' ';
		appendSID(tmp, to);
	}

	if(type == TYPE_FEATURE) {
		tmp += ' ';
		tmp += features;
	}

	for(StringIterC i = getParameters().begin(); i != getParameters().end(); ++i) {
		tmp += ' ';
		escape(*i, tmp);
	}

	tmp += '\n';

	return tmp;
}

bool AdcCommand::getParam(const char* name, size_t start, string& ret) const {
	for(string::size_type i = start; i < getParameters().size(); ++i) {
		if(toField(name) == toField(getParameters()[i].c_str())) {
			ret = getParameters()[i].substr(2);
			return true;
		}
	}
	return false;
}

bool AdcCommand::delParam(const char* name, size_t start) {
	for(string::size_type i = start; i < getParameters().size(); ++i) {
		if(toField(name) == toField(getParameters()[i].c_str())) {
			getParameters().erase(getParameters().begin() + i);
			resetBuffer();
			return true;
		}
	}
	return false;
}

bool AdcCommand::hasFlag(const char* name, size_t start) const {
	for(string::size_type i = start; i < getParameters().size(); ++i) {
		if(toField(name) == toField(getParameters()[i].c_str()) &&
			getParameters()[i].size() == 3 &&
			getParameters()[i][2] == '1')
		{
			return true;
		}
	}
	return false;
}

}
