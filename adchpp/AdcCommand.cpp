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

#include "stdinc.h"
#include "common.h"

#include "AdcCommand.h"

namespace adchpp {
	
AdcCommand::AdcCommand() : cmdInt(0), str(0), from(0), type(0) { }

AdcCommand::AdcCommand(Severity sev, Error err, const string& desc, char aType /* = TYPE_INFO */) : cmdInt(CMD_STA), str(&tmp), from(HUB_SID), type(aType) {
	addParam(Util::toString(sev * 100 + err));
	addParam(desc);
}

string AdcCommand::escape(const string& s) {
	string tmp;
	tmp.reserve(s.length() + 1);
	for(size_t i = 0; i < s.length(); ++i) {
		switch(s[i]) {
			case ' ': tmp += "\\s"; break;
			case '\n': tmp += "\\n"; break;
			case '\\': tmp += "\\\\"; break;
			default: tmp += s[i];
		}
	}
	return tmp;
}

void AdcCommand::parse(const string& aLine) throw(ParseException) {
	string::size_type i = 5;

	if(aLine.length() < 5) {
		throw ParseException("Command too short");
	}
	
	type = aLine[0];
	
	if(!(type == TYPE_BROADCAST || type == TYPE_DIRECT || type == TYPE_ECHO || type == TYPE_FEATURE || type == TYPE_HUB)) {
		throw ParseException("Invalid type");
	}
	
	cmd[0] = aLine[1];
	cmd[1] = aLine[2];
	cmd[2] = aLine[3];

	string::size_type len = aLine.length() - 1; // aLine contains trailing LF
	
	const char* buf = aLine.c_str();
	string cur;
	cur.reserve(128);

	bool toSet = false;
	bool fromSet = false;
	bool featureSet = false;

	while(i < len) {
		switch(buf[i]) {
		case '\\': 
			{
				++i;
				switch(buf[i]) {
				case 's': cur += ' '; break;
				case 'n': cur += '\n'; break;
				case '\\': cur += '\\'; break;
				default: throw ParseException("Invalid escape");
				}
			}
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
				} else if(type == TYPE_FEATURE && !featureSet) {
					if(cur.length() % 5 != 0) {
						throw ParseException("Invalid feature length");
					}
                    features = cur;
					featureSet = true;
				} else if((type == TYPE_DIRECT || type == TYPE_ECHO) && !toSet) {
					if(cur.length() != 4) {
						throw ParseException("Invalid SID length");
					}
					to = toSID(cur);
					toSet = true;
				} else {
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
		} else if(type == TYPE_FEATURE && !featureSet) {
			if(cur.length() % 5 != 0) {
				throw ParseException("Invalid feature length");
			}
			features = cur;
			featureSet = true;
		} else if((type == TYPE_DIRECT || type == TYPE_ECHO) && !toSet) {
			if(cur.length() != 4) {
				throw ParseException("Invalid SID length");
			}
			to = toSID(cur);
			toSet = true;
		} else {
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

const string& AdcCommand::toString() const {
	if(!str->empty())
		return *str;

	tmp.reserve(128);

	tmp += type;
	tmp += cmdChar;

	if(type != TYPE_INFO && type != TYPE_HUB) {
		tmp += ' ';
		appendSID(tmp, from);
	}

	if(type == TYPE_FEATURE) {
		tmp += ' ';
		tmp += features;
	}

	if(type == TYPE_DIRECT || type == TYPE_ECHO) {
		tmp += ' ';
		appendSID(tmp, to);
	}

	for(StringIterC i = getParameters().begin(); i != getParameters().end(); ++i) {
		tmp += ' ';
		tmp += escape(*i);
	}

	tmp += '\n';

	return tmp;
}

bool AdcCommand::getParam(const char* name, size_t start, string& ret) const {
	for(string::size_type i = start; i < getParameters().size(); ++i) {
		if(toCode(name) == toCode(getParameters()[i].c_str())) {
			ret = getParameters()[i].substr(2);
			return true;
		}
	}
	return false;
}

bool AdcCommand::delParam(const char* name, size_t start) {
	for(string::size_type i = start; i < getParameters().size(); ++i) {
		if(toCode(name) == toCode(getParameters()[i].c_str())) {
			getParameters().erase(getParameters().begin() + i);
			resetString();
			return true;
		}
	}
	return false;
}

bool AdcCommand::hasFlag(const char* name, size_t start) const {
	for(string::size_type i = start; i < getParameters().size(); ++i) {
		if(toCode(name) == toCode(getParameters()[i].c_str()) && 
			getParameters()[i].size() == 3 &&
			getParameters()[i][2] == '1')
		{
			return true;
		}
	}
	return false;
}

}
