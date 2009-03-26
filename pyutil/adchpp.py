import sys,os
sys.path.append(os.path.abspath('../build/debug-default/bin/'))
sys.path.append(os.path.abspath('../build/debug-mingw/bin/'))
print sys.path
import pyadchpp as a

def run():
    print "Starting"
    a.initialize(os.path.abspath('../etc/') + os.sep)

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
    

