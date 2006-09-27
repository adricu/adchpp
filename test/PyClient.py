import sys

sys.path.append('../build/debug-mingw/bin')
sys.path.append('../build/debug-default/bin')

import socket, threading, time

from pyadchpp import CID, CID_generate, Encoder_toBase32, Encoder_fromBase32, AdcCommand, AdcCommand_toSID, TigerHash, CID

class Client(object):
	def __init__(self, n):
		self.sock = socket.socket()
		self.pid = CID_generate()
		tiger = TigerHash()
		tiger.update(self.pid.data())
		self.cid = CID(Encoder_toBase32(tiger.finalize()))
		self.nick = "user_" + str(n) + "_" + self.cid.toBase32()
		
		self.line = ""
	
	def connect(self, ipport):
		self.sock.connect(ipport)
	
	def command(self, cmd):
		self.sock.send(cmd.toString())
	
	def get_command(self):
		index = self.line.find('\n')
		while index == -1:
			line = self.sock.recv(4096)
			if len(line) == 0:
				return None
		
			self.line += line
			index = self.line.find('\n')
			
		cmdline = self.line[:index + 1]
		self.line = self.line[index+1:]
		return AdcCommand(cmdline)
	
	def expect(self, command):
		cmd = self.get_command()
		if not cmd or cmd.getCommand() != command:
			if not cmd:
				error = "expect: connection closed"
			else:
				error = "expect: " + cmd.getCommandString()
			raise Exception, error
		return cmd
		
	def login(self, ipport):
		self.connect(ipport)
		cmd = AdcCommand(AdcCommand.CMD_SUP, AdcCommand.TYPE_HUB, 0)
		cmd.addParam("ADBASE")
		self.command(cmd)
		self.expect(AdcCommand.CMD_SUP)
		sid = self.expect(AdcCommand.CMD_SID)
		self.sid = AdcCommand_toSID(sid.getParam(0))
		
		cmd = AdcCommand(AdcCommand.CMD_INF, AdcCommand.TYPE_BROADCAST, self.sid)
		cmd.addParam("ID" + self.cid.toBase32())
		cmd.addParam("PD" + self.pid.toBase32())
		cmd.addParam("NI" + self.nick)
		self.command(cmd)
	
	def __call__(self):
		try:
			while self.get_command():
				pass
		except Exception, e:
			print "Client " + self.nick + " died:", e
try:
	
	for i in range(200):
		if i > 0 and i % 10 == 0:
			#time.sleep(3)
			pass
		print "Logging in", i
		client = Client(i)
		client.login(("127.0.0.1", 2780))
		threading.Thread(target = client, name = client.nick).start()
except Exception, e:
	print e
