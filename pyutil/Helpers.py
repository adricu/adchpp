import pyadchpp as a

def recieveHandler(client, cmd, override, filter, callback):
    if override & a.ClientManager.DONT_DISPATCH:
        return 0
    
    if cmd.getCommand() != filter:
        return 0
    
    return callback(client, cmd, override)
    
def handleCommand(filter, callback):
    cm = a.getCM()
    return cm.signalReceive().connect(lambda clinet, cmd, override: receiveHandler(client, cmd, override, filter, callback))

def dump(c, code, msg):
    answer = a.AdcCommand(a.AdcCommand.CMD_STA, a.AdcCommand.TYPE_INFO, a.AdcCommand.HUB_SID)
    answer.addParam("" + adchpp.AdcCommand_SEV_FATAL + code).addParam(msg)
    c.send(answer)
    c.disconnect(0)

handled = a.ClientManager.DONT_DISPATCH + a.ClientManager.DONT_SEND
cm = a.getCM()

class InfVerifier(object):
    BASE32_CHARS = "[2-7a-zA-Z]"
    any = re.compile(".*")
    nonempty = re.compile(".+")
    sta_code = re.compile("[0,1,2][0-9]{2}")
    sid = re.compile(BASE32_CHARS + "{4}")
    tth = re.compile(BASE32_CHARS + "{39}")
    integer = re.compile("[\\-0-9]+")
    base32 = re.compile(BASE32_CHARS + "+");
    boolean = re.compile("[1]?")
    
    fields = {
        a.AdcCommand.CMD_INF : {
            "ID" : tth,
            "PD": tth,
            "I4": re.compile("(([0-1]?[0-9]{1,2}[.])|(2[0-4][0-9][.])|(25[0-5][.])){3}(([0-1]?[0-9]{1,2})|(2[0-4][0-9])|(25[0-5]))"),
            "I6": re.compile("[0-9a-fA-F:]+"), # This could be better
            "U4": integer,
            "U6": integer,
            "SS": integer,
            "SF": integer,
            "US": integer,
            "DS": integer,
            "SL": integer,
            "AS": integer,
            "AM": integer,
            "NI": nonempty,
            "HN": integer,
            "HR": integer,
            "HO": integer,
            "OP": boolean,
            "AW": re.compile("1|2"),
            "BO": boolean,
            "HI": boolean,
            "HU": boolean,
            "SU": re.compile("[0-9A-Z,]+"),
        },
        
        AdcCommand.CMD_MSG : {
            "PM": sid,
            "ME": boolean,
        },
         
        AdcCommand.CMD_SCH : {
            "AN": nonempty,
            "NO": nonempty,
            "EX": nonempty,
            "LE": integer,
            "GE": integer,
            "EQ": integer,
            "TO": nonempty,
            "TY": re.compile("1|2"),
            "TR": tth,
        },
        
        AdcCommand.CMD_RES : {
            "FN": nonempty,
            "SI": integer,
            "SL": integer,
            "TO": nonempty,
            "TR": tth,
            "TD": integer,
        }
    }
    
    params = {
        AdcCommand.CMD_STA: (sta_code, any),
        AdcCommand.CMD_MSG: (any,),
        AdcCommand.CMD_CTM: (any, integer, any),
        AdcCommand.CMD_RCM: (any, any),
        AdcCommand.CMD_PAS: (base32,)
    }
 
    def __init__(self, succeeded, failed):
        self.succeeded = succeeded or (lambda client: None)
        self.failed = failed or (lambda client, error: None)
        
    def validate(self, c, cmd, override):
        if cmd.getCommand() in params:
            self.validateParam(c, cmd, self.params[cmd.getCommand()])
        
        if cmd.getCommand() in fields:
            self.validateFields(c, cmd, self.fields[cmd.getCommand()])
            
        return 0
            
    def validateParam(self, c, cmd, params):
        if len(cmd.getParameters()) < len(params):
            dump(c, a.AdcCommand.ERROR_PROTOCOL_GENERIC, "Too few parameters for " + cmd.getCommand())
            return
        
        for i, param in enumerate(params):
            if not param.match(cmd.getParam(i)):
                dump(c, a.AdcCommand.ERROR_PROTOCOL_GENERIC, cmd.getParam(i) + " doesn't match " + param)
                return

    def validateFields(self, c, cmd, fields):
        for field in cmd.getParameters():
            if field[0:2] in fields:
                r = fields[field[0:2]]
                if not r.match(field[2:]):
                    dump(c, a.AdcCommand.ERROR_PROTOCOL_GENERIC, field + " doesn't match " + str(r))
        
class PasswordHandler(object):
    def __init__(self, getPassword, succeeded, failed):
        self.getPassword = getPassword or (lambda nick, cid: None)
        self.succeeded = succeeded or (lambda client: None)
        self.failed = failed or (lambda client, error: None)
        
        self.inf = handleCommand(pyadchpp.AdcCommand.CMD_INF, self.onINF)
        self.pas = handleCommand(pyadchpp.AdcCommand.CMD_PAS, self.OnPAS)
        
        self.salts = {}
        
    def onINF(self, c, cmd, override):
        if c.getState() != pyadchpp.Client.STATE_IDENTIFY:
            return 0
        
        password = self.getPassword(client)
        if not password:
            return 0
        
        self.salts[client.getSID()] = (cm.enterVerify(c, True), password)
        
        return handled
    
    def onPAS(self, client, cmd, override):
        if c.getState() != a.Client.STATE_VERIFY:
            dump(c, adchpp.AdcCommand.ERROR_PROTOCOL_GENERIC, "Not in VERIFY state")
            return handled
        
        salt, password = self.salts[c.getSID()]
        
        if not salt:
            dump(c, adchpp.AdcCommand.ERROR_PROTOCOL_GENERIC, "You didn't get any salt?")
            return handled
        
        del salts[c.getSID()]
        
        cid = c.getCID()
        nick = c.getField("NI")
        
        if not cm.verifyPassword(c, password, salt, cmd.getParam(0)):
            dump(c, adchpp.AdcCommand_ERROR_BAD_PASSWORD, "Invalid password")
            return handled

        self.succeeded(client)
        
        return 0