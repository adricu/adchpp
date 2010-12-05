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

#include <adchpp/LogManager.h>
#include <adchpp/Util.h>
#include <adchpp/version.h>
#include <adchpp/File.h>
#include <adchpp/Core.h>
#include <adchpp/shared_ptr.h>

#include <signal.h>
#include <limits.h>

#include "adchppd.h"

#define _(x) x

using namespace std;
using namespace adchpp;

static const string modName = "adchpp";

static FILE* pidFile;
static string pidFileName;
static bool asdaemon = false;
static shared_ptr<Core> core;

static void installHandler();

void breakHandler(int) {
	if(core) {
		core->shutdown();
	}

	installHandler();
}

static void init() {
	// Ignore SIGPIPE...
	struct sigaction sa = { 0 };

	sa.sa_handler = SIG_IGN;

	sigaction(SIGPIPE, &sa, NULL);
	sigaction(SIGHUP, &sa, NULL);

	sigset_t mask;

	sigfillset(&mask); /* Mask all allowed signals, the other threads should inherit
					   this... */
	sigdelset(&mask, SIGCONT);
	sigdelset(&mask, SIGFPE);
	sigdelset(&mask, SIGILL);
	sigdelset(&mask, SIGSEGV);
	sigdelset(&mask, SIGBUS);
	sigdelset(&mask, SIGINT);
	sigdelset(&mask, SIGTRAP);
	pthread_sigmask(SIG_SETMASK, &mask, NULL);

	installHandler();

	if(pidFile != NULL) {
		fprintf(pidFile, "%d", (int)getpid());
		fflush(pidFile);
	}

	loadXML(*core, File::makeAbsolutePath(core->getConfigPath(), "adchpp.xml"));
}

static void installHandler() {
	struct sigaction sa = { 0 };

	sa.sa_handler = breakHandler;

	sigaction(SIGINT, &sa, NULL);
}

static void uninit() {
	//LOG(modName, versionString + " shut down");
	if(!asdaemon)
		printf(_("Shutting down."));

	if(!asdaemon)
		printf(".\n");

	if(pidFile != NULL)
		fclose(pidFile);
	pidFile = NULL;
	if(!pidFileName.empty())
		unlink(pidFileName.c_str());
}

#include <fcntl.h>

static void daemonize() {
	switch(fork()) {
	case -1:
		//LOG(modName, string("First fork failed: ") + strerror(errno));
		exit(5);
	case 0: break;
	default: _exit(0);
	}

	if(setsid() < 0) {
		//LOG(modName, string("setsid failed: ") + strerror(errno));
		exit(6);
	}
	switch(fork()) {
		case -1:
			//LOG(modName, string("Second fork failed: ") + strerror(errno));
			exit(7);
		case 0: break;
		default: exit(0);
	}

	chdir("/");
	close(0);
	close(1);
	close(2);
	open("/dev/null", O_RDWR);
	dup(0); dup(0);
}

#include <sys/wait.h>

static void runDaemon(const string& configPath) {
	daemonize();

	try {
		core = Core::create(configPath);

		init();

		core->run();

		core->shutdown();
		core.reset();
	} catch(const adchpp::Exception& e) {
		//LOG(modName, "Failed to start: " + e.getError());
	}

	uninit();
}

static void runConsole(const string& configPath) {
	printf("Starting."); fflush(stdout);

	try {
		core = Core::create(configPath);

		printf("."); fflush(stdout);
		init();

		// LOG(modName, versionString + " starting from console");
		printf(_(".\n%s running, press ctrl-c to exit...\n"), versionString.c_str());
		core->run();

		core->shutdown();

		core.reset();
	} catch(const Exception& e) {
		printf(_("\n\nFATAL: Can't start ADCH++: %s\n"), e.getError().c_str());
	}

	uninit();
}

static void printUsage() {
	printf(_("Usage: adchpp [[-c <configdir>] [-d]] | [-v] | [-h]\n"));
}

int main(int argc, char* argv[]) {

	char buf[PATH_MAX + 1] = { 0 };
	char* path = buf;
	if (readlink("/proc/self/exe", buf, sizeof (buf)) == -1) {
		path = getenv("_");
	}

	Util::setApp(path == NULL ? argv[0] : path);
	string configPath = "/etc/adchpp/";

	for(int i = 1; i < argc; i++) {
		if(strcmp(argv[i], "-d") == 0) {
			asdaemon = true;
		} else if(strcmp(argv[i], "-v") == 0) {
			printf("%s\n", versionString.c_str());
			return 0;
		} else if(strcmp(argv[i], "-c") == 0) {
			if((i + 1) == argc) {
				fprintf(stderr, _("-c <directory>\n"));
				return 1;
			}
			i++;
			string cfg = argv[i];
			if(cfg[0] != '/') {
				fprintf(stderr, _("Config dir must be an absolute path\n"));
				return 2;
			}
			if(cfg[cfg.length() - 1] != '/') {
				cfg+='/';
			}
			configPath = cfg;
		} else if(strcmp(argv[i], "-p") == 0) {
			if((i+1) == argc) {
				fprintf(stderr, _("-p <pid-file>\n"));
				return 1;
			}
			i++;
			pidFileName = argv[i];
		} else if(strcmp(argv[i], "-h") == 0) {
			printUsage();
			return 0;
		} else {
			fprintf(stderr, _("Unknown parameter: %s\n"), argv[i]);
			return 4;
		}
	}

	if(!pidFileName.empty()) {
		pidFileName = File::makeAbsolutePath(configPath, pidFileName);
		pidFile = fopen(pidFileName.c_str(), "w");
		if(pidFile == NULL) {
			fprintf(stderr, _("Can't open %s for writing\n"), pidFileName.c_str());
			return 1;
		}
	}

	if(asdaemon) {
		runDaemon(configPath);
	} else {
		runConsole(configPath);
	}
}
