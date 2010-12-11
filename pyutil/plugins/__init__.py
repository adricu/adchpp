import pyadchpp as a

class Echo(a.Plugin):
    def __init__(self, core):
        self.bot = core.getClientManager().createBot(lambda bot, cmd: self.handle(bot, cmd))
        
        cmd = a.AdcCommand(a.AdcCommand.CMD_SUP, a.AdcCommand.TYPE_HUB, 0)
        cmd.addParam("ADBASE").addParam("ADTIGR")
        
        self.bot.inject(cmd)

    def handle(self, bot, cmd):
        ac = a.AdcCommand(cmd)
        # TODO Continue logging in...
        print ac.toString()


reg = {}    

def init(core):
    for x in a.Plugin.__subclasses__():
        reg[x] = x(core)