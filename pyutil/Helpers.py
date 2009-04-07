import pyadchpp as a
import re
def receiveHandler(client, cmd, ok, filter, callback):
    if not ok:
        return ok
    
    if cmd.getCommand() != filter:
        return ok
    
    return callback(client, cmd, ok)
    
def handleCommand(filter, callback):
    cm = a.getCM()
    return cm.signalReceive().connect(lambda client, cmd, ok: receiveHandler(client, cmd, ok, filter, callback))

def dump(c, code, msg):
    answer = a.AdcCommand(a.AdcCommand.CMD_STA, a.AdcCommand.TYPE_INFO, a.AdcCommand.HUB_SID)
    answer.addParam("" + a.AdcCommand.SEV_FATAL + code).addParam(msg)
    c.send(answer)
    c.disconnect(0)

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
        
        a.AdcCommand.CMD_MSG : {
            "PM": sid,
            "ME": boolean,
        },
         
        a.AdcCommand.CMD_SCH : {
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
        
        a.AdcCommand.CMD_RES : {
            "FN": nonempty,
            "SI": integer,
            "SL": integer,
            "TO": nonempty,
            "TR": tth,
            "TD": integer,
        }
    }
    
    params = {
        a.AdcCommand.CMD_STA: (sta_code, any),
        a.AdcCommand.CMD_MSG: (any,),
        a.AdcCommand.CMD_CTM: (any, integer, any),
        a.AdcCommand.CMD_RCM: (any, any),
        a.AdcCommand.CMD_PAS: (base32,)
    }
 
    def __init__(self, succeeded, failed):
        self.succeeded = succeeded or (lambda client: None)
        self.failed = failed or (lambda client, error: None)
        
    def validate(self, c, cmd, ok):
        if cmd.getCommand() in params:
            self.validateParam(c, cmd, self.params[cmd.getCommand()])
        
        if cmd.getCommand() in fields:
            self.validateFields(c, cmd, self.fields[cmd.getCommand()])
            
        return ok
            
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
        
        self.inf = handleCommand(a.AdcCommand.CMD_INF, self.onINF)
        self.pas = handleCommand(a.AdcCommand.CMD_PAS, self.onPAS)
        
        self.salts = {}
        self.cm = a.getCM()
        
    def onINF(self, e, cmd, ok):
        c = e.asClient()
        if not c:
            return ok
        
        if c.getState() != a.Client.STATE_IDENTIFY:
            return ok
        
        foundn, nick = cmd.getParam("NI", 0)
        foundc, cid = cmd.getParam("ID", 0)
        
        if not foundn or not foundc:
            dump(c, a.AdcCommand.ERROR_PROTOCOL_GENERIC, "No valid nick/CID supplied")

        password = self.getPassword(nick, cid)
        if not password:
            return ok
        
        self.salts[c.getSID()] = (self.cm.enterVerify(c, True), password)
        
        return handled
    
    def onPAS(self, c, cmd, ok):
        if c.getState() != a.Client.STATE_VERIFY:
            dump(c, adchpp.AdcCommand.ERROR_PROTOCOL_GENERIC, "Not in VERIFY state")
            return handled
        
        salt, password = self.salts[c.getSID()]
        
        if not salt:
            dump(c, adchpp.AdcCommand.ERROR_PROTOCOL_GENERIC, "You didn't get any salt?")
            return handled
        
        del self.salts[c.getSID()]
        
        cid = c.getCID()
        nick = c.getField("NI")
        
        if not self.cm.verifyPassword(c, password, salt, cmd.getParam(0)):
            dump(c, adchpp.AdcCommand_ERROR_BAD_PASSWORD, "Invalid password")
            return handled

        self.succeeded(c)
        
        return ok
