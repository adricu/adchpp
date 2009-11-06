/*
 * Copyright (C) 2006-2009 Jacek Sieka, arnetheduck on gmail point com
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

#include "SimpleXML.h"

namespace adchpp {

using namespace std;

SimpleXML::SimpleXML(int numAttribs) : attribs(numAttribs), found(false) {
	root = current = new Tag("BOGUSROOT", Util::emptyString, NULL);
}

SimpleXML::~SimpleXML() {
	delete root;
}

void SimpleXML::escape(string& aString, bool aAttrib, bool aLoading /* = false */) {
	string::size_type i = 0;
	const char* chars = aAttrib ? "<&>'\"" : "<&>";

	if(aLoading) {
		while((i = aString.find('&', i)) != string::npos) {
			if(aString.compare(i+1, 3, "lt;") == 0) {
				aString.replace(i, 4, 1, '<');
			} else if(aString.compare(i+1, 4, "amp;") == 0) {
				aString.replace(i, 5, 1, '&');
			} else if(aString.compare(i+1, 3, "gt;") == 0) {
				aString.replace(i, 4, 1, '>');
			} else if(aAttrib) {
				if(aString.compare(i+1, 5, "apos;") == 0) {
					aString.replace(i, 6, 1, '\'');
				} else if(aString.compare(i+1, 5, "quot;") == 0) {
					aString.replace(i, 6, 1, '"');
				}
			}
			i++;
		}
		i = 0;
		if( (i = aString.find('\n')) != string::npos) {
			if(i > 0 && aString[i-1] != '\r') {
				// This is a unix \n thing...convert it...
				i = 0;
				while( (i = aString.find('\n', i) ) != string::npos) {
					if(aString[i-1] != '\r')
						aString.insert(i, 1, '\r');

					i+=2;
				}
			}
		}
	} else {
		while( (i = aString.find_first_of(chars, i)) != string::npos) {
			switch(aString[i]) {
			case '<': aString.replace(i, 1, "&lt;"); i+=4; break;
			case '&': aString.replace(i, 1, "&amp;"); i+=5; break;
			case '>': aString.replace(i, 1, "&gt;"); i+=4; break;
			case '\'': aString.replace(i, 1, "&apos;"); i+=6; break;
			case '"': aString.replace(i, 1, "&quot;"); i+=6; break;
			default: dcasserta(0);
			}
		}
	}
}

void SimpleXML::Tag::appendAttribString(string& tmp) {
	for(AttribIter i = attribs.begin(); i!= attribs.end(); ++i) {
		tmp.append(i->first);
		tmp.append("=\"", 2);
		if(needsEscape(i->second, true)) {
			string tmp2(i->second);
			escape(tmp2, true);
			tmp.append(tmp2);
		} else {
			tmp.append(i->second);
		}
		tmp.append("\" ", 2);
	}
	tmp.erase(tmp.size()-1);
}

string SimpleXML::Tag::toXML(int indent) {
	if(children.empty() && data.empty()) {
		string tmp;
		tmp.reserve(indent + name.length() + 30);
		tmp.append(indent, '\t');
		tmp.append(1, '<');
		tmp.append(name);
		tmp.append(1, ' ');
		appendAttribString(tmp);
		tmp.append("/>\r\n", 4);
		return tmp;
	} else {
		string tmp;
		tmp.append(indent, '\t');
		tmp.append(1, '<');
		tmp.append(name);
		tmp.append(1, ' ');
		appendAttribString(tmp);
		if(children.empty()) {
			tmp.append(1, '>');
			if(needsEscape(data, false)) {
				string tmp2(data);
				escape(tmp2, false);
				tmp.append(tmp2);
			} else {
				tmp.append(data);
			}
		} else {
			tmp.append(">\r\n", 3);
			for(Iter i = children.begin(); i!=children.end(); ++i) {
				tmp.append((*i)->toXML(indent + 1));
			}
			tmp.append(indent, '\t');
		}
		tmp.append("</", 2);
		tmp.append(name);
		tmp.append(">\r\n", 3);
		return tmp;
	}
}

bool SimpleXML::findChild(const string& aName) const throw() {
	dcassert(current != NULL);

	if(found && currentChild != current->children.end())
		currentChild++;

	while(currentChild!=current->children.end()) {
		if(aName.empty() || (*currentChild)->name == aName) {
			found = true;
			return true;
		} else
			currentChild++;
	}
	return false;
}

void SimpleXML::stepIn() const throw(SimpleXMLException) {
	checkChildSelected();
	current = *currentChild;
	currentChild = current->children.begin();
	found = false;
}

void SimpleXML::stepOut() const throw(SimpleXMLException) {
	if(current == root)
		throw SimpleXMLException("Already at lowest level");

	dcassert(current->parent != NULL);

	currentChild = find(current->parent->children.begin(), current->parent->children.end(), current);

	current = current->parent;
	found = true;
}

string::size_type SimpleXML::Tag::loadAttribs(const string& tmp, string::size_type start) throw(SimpleXMLException) {
	string::size_type i = start;
	string::size_type j;
	for(;;) {
		j = tmp.find('=', i);
		if(j == string::npos) {
			throw SimpleXMLException("Missing '=' in " + name);
		}
		if(tmp[j+1] != '"' && tmp[j+1] != '\'') {
			throw SimpleXMLException("Invalid character after '=' in " + name);
		}
		string::size_type x = j + 2;
		string::size_type y = tmp.find(tmp[j+1], x);
		if(y == string::npos) {
			throw SimpleXMLException("Missing '" + string(1, tmp[j+1]) + "' in " + name);
		}
		// Ok, we have an attribute...
		attribs.push_back(make_pair(tmp.substr(i, j-i), tmp.substr(x, y-x)));
		escape(attribs.back().second, true, true);

		i = tmp.find_first_not_of("\r\n\t ", y + 1);
		if(tmp[i] == '/' || tmp[i] == '>')
			return i;
	}
}

string::size_type SimpleXML::Tag::fromXML(const string& tmp, string::size_type start, int aa, bool isRoot /* = false */) throw(SimpleXMLException) {
	string::size_type i = start;
	string::size_type j;

	bool hasChildren = false;
	dcassert(tmp.size() > 0);

	for(;;) {
		j = tmp.find('<', i);
		if(j == string::npos) {
			if(isRoot) {
				throw SimpleXMLException("Invalid XML file, missing root tag");
			} else {
				throw SimpleXMLException("Missing end tag in " + name);
			}
		}

		// Check that we have at least 3 more characters as the shortest valid xml tag is <a/>...
		if((j + 3) > tmp.size()) {
			throw SimpleXMLException("Missing end tag in " + name);
		}

		Ptr child = NULL;

		i = j + 1;

		if(tmp[i] == '?') {
			// <? processing instruction ?>, ignore...
			i = tmp.find("?>", i);
			if(i == string::npos) {
				throw SimpleXMLException("Missing '?>' in " + name);
			}
			i+= 2;
			continue;
		}

		if(tmp[i] == '!' && tmp[i+1] == '-' && tmp[i+2] == '-') {
			// <!-- comment -->, ignore...
			i = tmp.find("-->", i);
			if(i == string::npos) {
				throw SimpleXMLException("Missing '-->' in " + name);
			}
			continue;
		}

		// Check if we reached the end tag
		if(tmp[i] == '/') {
			i++;
			if( (tmp.compare(i, name.length(), name) == 0) &&
				(tmp[i + name.length()] == '>') )
			{
				if(!hasChildren) {
					data = tmp.substr(start, i - start - 2);
					escape(data, false, true);
				}
				return i + name.length() + 1;
			} else {
				throw SimpleXMLException("Missing end tag in " + name);
			}
		}

		// Alright, we have a real tag for sure...now get the name of it.
		j = tmp.find_first_of("\r\n\t />", i);
		if(j == string::npos) {
			throw SimpleXMLException("Missing '>' in " + name);
		}

		child = new Tag(tmp.substr(i, j-i), Util::emptyString, this, aa);
		// Put it here immideately to avoid mem leaks
		children.push_back(child);

		if(tmp[j] == ' ')
			j = tmp.find_first_not_of("\r\n\t ", j+1);

		if(j == string::npos) {
			throw SimpleXMLException("Missing '>' in " + name);
		}

		if(tmp[j] != '/' && tmp[j] != '>') {
			// We have attribs...
			j = child->loadAttribs(tmp, j);
		}

		if(tmp[j] == '>') {
			// This is a real tag with data etc...
			hasChildren = true;
			j = child->fromXML(tmp, j+1, aa);
		} else {
			// A simple tag (<xxx/>
			j++;
		}
		i = j;
		if(isRoot) {
			if(tmp.find('<', i) != string::npos) {
				throw SimpleXMLException("Invalid XML file, multiple root tags");
			}
			return tmp.length();
		}
	}
}

void SimpleXML::addTag(const string& aName, const string& aData /* = "" */) throw(SimpleXMLException) {
	if(aName.empty()) {
		throw SimpleXMLException("Empty tag names not allowed");
	}

	if(current == root) {
		if(current->children.empty()) {
			current->children.push_back(new Tag(aName, aData, root, attribs));
			currentChild = current->children.begin();
		} else {
			throw SimpleXMLException("Only one root tag allowed");
		}
	} else {
		current->children.push_back(new Tag(aName, aData, current, attribs));
		currentChild = current->children.end() - 1;
	}
}

void SimpleXML::addAttrib(const string& aName, const string& aData) throw(SimpleXMLException) {
	if(current==root)
		throw SimpleXMLException("No tag is currently selected");

	current->attribs.push_back(make_pair(aName, aData));
}

void SimpleXML::addChildAttrib(const string& aName, const string& aData) throw(SimpleXMLException) {
	checkChildSelected();

	(*currentChild)->attribs.push_back(make_pair(aName, aData));
}

void SimpleXML::fromXML(const string& aXML) throw(SimpleXMLException) {
	if(root) {
		delete root;
	}
	root = new Tag("BOGUSROOT", Util::emptyString, NULL, 0);

	root->fromXML(aXML, 0, attribs, true);

	if(root->children.size() != 1) {
		throw SimpleXMLException("Invalid XML file, missing or multiple root tags");
	}

	current = root;
	resetCurrentChild();
}

}
