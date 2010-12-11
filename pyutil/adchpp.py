import sys,os
sys.path.append(os.path.abspath('../build/debug-default/bin/'))
sys.path.append(os.path.abspath('../build/debug-mingw/bin/'))

import pyadchpp as a

from Helpers import *
from Hub import *

hub = Hub()
op = Profile('op', hub)
vip = Profile('vip', hub)

profiles = dict([(x.name, x) for x in (op, vip)])

users = [User(profile=op, nick='arnetheduck', password='test')]

nicks = dict([(x.nick, x) for x in users if x.nick])
cids = dict([(x.cid, x) for x in users if x.cid])

configPath = os.path.abspath('../etc/') + os.sep
core = a.Core.create(configPath)

def findUser(nick, cid):
	print "looking for", nick, cid
	if nick in nicks:
		return nicks[nick].password
	if cid in cids:
		return cids[cid].password
	
	return None

def handler(signum, frame):
    core.shutdown()

def run():
    print "Starting"
    sil = a.TServerInfoList(1)
    si = a.ServerInfo.create()
    si.port = 2780
    sil[0] = si
    core.getSocketManager().setServers(sil)
    pw = PasswordHandler(core, findUser, None, None)
    iv = InfVerifier(core, None, None)
    print "."
    import signal
    signal.signal(signal.SIGINT, handler)

    try:
        import plugins
        plugins.init(core)
        core.run()
    except Exception as e:
        print "\n\nFATAL: Can't start ADCH++: %s\n" % e

if __name__ == '__main__':
    run()

core = None