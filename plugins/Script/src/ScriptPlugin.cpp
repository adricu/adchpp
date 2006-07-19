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
#include "ScriptManager.h"

#include <adchpp/PluginManager.h>

#ifdef _WIN32

BOOL APIENTRY DllMain(HANDLE /*hModule */, DWORD /* reason*/, LPVOID /*lpReserved*/) {
    return TRUE;
}

#endif

extern "C" {
double PLUGIN_API pluginGetVersion() { return PLUGINVERSIONFLOAT; }

int PLUGIN_API pluginLoad() {
	ScriptManager::newInstance();
	return 0;
}

void PLUGIN_API pluginUnload() {
	ScriptManager::deleteInstance();
}
}
