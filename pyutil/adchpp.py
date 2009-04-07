import sys,os
sys.path.append(os.path.abspath('../build/debug-default/bin/'))
sys.path.append(os.path.abspath('../build/debug-mingw/bin/'))
print sys.path
import pyadchpp as a

from Helpers import *

users = { 'arnetheduck' : 'test' }

def findUser(nick, cid):
	if nick in users:
		return users[nick]
	
	return None

def run():
    print "Starting"
    a.initialize(os.path.abspath('../etc/') + os.sep)
    sil = a.TServerInfoList(1)
    si = a.ServerInfo.create()
    si.port=2780
    sil[0] = si
    a.getSM().setServers(sil)
    pw = PasswordHandler(findUser, None, None)
    iv = InfVerifier(None, None)
    print "."
    
    try:
        a.startup()
        raw_input("Running...")
    except:
        print "\n\nFATAL: Can't start ADCH++: %s\n"
    
    a.shutdown()
    
    a.cleanup()

if __name__ == '__main__':
    run()
    

