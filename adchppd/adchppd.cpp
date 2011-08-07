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

#include <adchpp/adchpp.h>
#include <adchpp/common.h>

#include "adchppd.h"

#include <adchpp/Util.h>
#include <adchpp/ClientManager.h>
#include <adchpp/LogManager.h>
#include <adchpp/SocketManager.h>
#include <adchpp/PluginManager.h>
#include <adchpp/Entity.h>
#include <adchpp/File.h>
#include <adchpp/SimpleXML.h>
#include <adchpp/Core.h>

using namespace adchpp;
using namespace std;

void loadXML(Core &core, const string& aFileName)
{
	try {
		SimpleXML xml;

		xml.fromXML(File(aFileName, File::READ, File::OPEN).read());

		xml.resetCurrentChild();

		xml.stepIn();

		while(xml.findChild(Util::emptyString)) {
			if(xml.getChildName() == "Settings") {
				xml.stepIn();

				while(xml.findChild(Util::emptyString)) {

					printf("Processing %s\n", xml.getChildName().c_str());
					if(xml.getChildName() == "HubName") {
						core.getClientManager().getEntity(AdcCommand::HUB_SID)->setField("NI", xml.getChildData());
					} else if(xml.getChildName() == "Description") {
						core.getClientManager().getEntity(AdcCommand::HUB_SID)->setField("DE", xml.getChildData());
					} else if(xml.getChildName() == "Log") {
						core.getLogManager().setEnabled(xml.getChildData() == "1");
					} else if(xml.getChildName() == "LogFile") {
						core.getLogManager().setLogFile(xml.getChildData());
					} else if(xml.getChildName() == "MaxCommandSize") {
						core.getClientManager().setMaxCommandSize(Util::toInt(xml.getChildData()));
					} else if(xml.getChildName() == "BufferSize") {
						core.getSocketManager().setBufferSize(Util::toInt(xml.getChildData()));
					} else if(xml.getChildName() == "MaxBufferSize") {
						core.getSocketManager().setMaxBufferSize(Util::toInt(xml.getChildData()));
					} else if(xml.getChildName() == "OverflowTimeout") {
						core.getSocketManager().setOverflowTimeout(Util::toInt(xml.getChildData()));
					} else if(xml.getChildName() == "LogTimeout") {
						core.getClientManager().setLogTimeout(Util::toInt(xml.getChildData()));
					}
				}

				xml.stepOut();
			} else if(xml.getChildName() == "Servers") {
				xml.stepIn();

				ServerInfoList servers;

				while(xml.findChild("Server")) {
					ServerInfoPtr server = make_shared<ServerInfo>();
					server->port = xml.getChildAttrib("Port", Util::emptyString);

					if(xml.getBoolChildAttrib("TLS")) {
						server->TLSParams.cert = File::makeAbsolutePath(xml.getChildAttrib("Certificate"));
						server->TLSParams.pkey = File::makeAbsolutePath(xml.getChildAttrib("PrivateKey"));
						server->TLSParams.trustedPath = File::makeAbsolutePath(xml.getChildAttrib("TrustedPath"));
						server->TLSParams.dh = File::makeAbsolutePath(xml.getChildAttrib("DHParams"));
					}

#ifndef HAVE_OPENSSL
					if(server->secure())
						fprintf(stderr, "Error listening on port %d: This ADCH++ hasn't been compiled with support for secure connections\n", server->port);
					else
#endif
					servers.push_back(server);
				}

				core.getSocketManager().setServers(servers);

				xml.stepOut();
			} else if(xml.getChildName() == "Plugins") {
				core.getPluginManager().setPluginPath(xml.getChildAttrib("Path"));
				xml.stepIn();
				StringList plugins;
				while(xml.findChild("Plugin")) {
					plugins.push_back(xml.getChildData());
				}

				core.getPluginManager().setPluginList(plugins);
				xml.stepOut();
			}
		}

		xml.stepOut();
	} catch(const Exception& e) {
		printf("Unable to load adchpp.xml, using defaults: %s\n", e.getError().c_str());
	}
}
