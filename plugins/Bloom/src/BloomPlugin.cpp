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

#include "stdinc.h"
#include "BloomManager.h"

#include <adchpp/PluginManager.h>

#ifdef _WIN32

BOOL APIENTRY DllMain(HANDLE /*hModule */, DWORD /* reason*/, LPVOID /*lpReserved*/) {
    return TRUE;
}

#endif

extern "C" {

int PLUGIN_API pluginGetVersion() { return PLUGINVERSION; }

int PLUGIN_API pluginLoad(PluginManager *pm) {
	auto bm = make_shared<BloomManager>(pm->getCore());
	bm->init();
	pm->registerPlugin("BloomManager", bm);
	return 0;
}

void PLUGIN_API pluginUnload() {

}

}

