#!/usr/bin/python
import sys

sys.path.append('../build/debug-default/bin')

CLIENTS = 100

import socket, threading, time

from pyadchpp import ParseException, Util_initialize, CID, CID_generate, Encoder_toBase32, Encoder_fromBase32, AdcCommand, AdcCommand_toSID, TigerHash, CID

Util_initialize("")

class Client(object):
	def __init__(self, n):
		self.sock = socket.socket()
		self.pid = CID_generate()
		tiger = TigerHash()
		tiger.update(self.pid.data())
		self.cid = CID(Encoder_toBase32(tiger.finalize()))
		self.nick = "user_" + str(n) + "_" + self.cid.toBase32()
		self.running = True
		self.line = ""
	
	def connect(self, ipport):
		self.sock.connect(ipport)
	
	def command(self, cmd):
		s = cmd.toString()
		print self.nick, "sending", s
		self.sock.send(cmd.toString())
	
	def get_command(self):
		index = self.line.find('\n')
		while index == -1:
			line = self.sock.recv(4096)
			if len(line) == 0:
				return None
		
			self.line += line
			index = self.line.find('\n')
			if index==0:
				self.line = self.line[index+1:]
				index = -1
			
		self.lastline = self.line[:index + 1]
		self.line = self.line[index+1:]
		return AdcCommand(self.lastline)
	
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
		cmd.addParam("ADBASE").addParam("ADTIGR")
		self.command(cmd)
		self.expect(AdcCommand.CMD_SUP)
		sid = self.expect(AdcCommand.CMD_SID)
		self.sid = AdcCommand_toSID(sid.getParam(0))
		
		cmd = AdcCommand(AdcCommand.CMD_INF, AdcCommand.TYPE_BROADCAST, self.sid)
		cmd.addParam("ID" + self.cid.toBase32())
		cmd.addParam("PD" + self.pid.toBase32())
		cmd.addParam("NI" + self.nick)
		self.command(cmd)
	
#	def test_close(self):
#		self.sock.close()
		
	def test_error(self):
		cmd = AdcCommand(AdcCommand.CMD_MSG, AdcCommand.TYPE_BROADCAST, self.sid)
		cmd.addParam("+error")
		self.command(cmd)
	
	def test_test(self):
		cmd = AdcCommand(AdcCommand.CMD_MSG, AdcCommand.TYPE_BROADCAST, self.sid)
		cmd.addParam("+test")
		self.command(cmd)
	
	def test_msg(self):
		cmd = AdcCommand(AdcCommand.CMD_MSG, AdcCommand.TYPE_BROADCAST, self.sid)
		cmd.addParam("hello from " + self.nick)
		self.command(cmd)
		
	def test_nick(self):
		self.nick = "user_" + str(CID_generate())
		cmd = AdcCommand(AdcCommand.CMD_MSG, AdcCommand.TYPE_BROADCAST, self.sid)
		cmd.addParam("renaming myself to " + self.nick)
		self.command(cmd)
		cmd = AdcCommand(AdcCommand.CMD_INF, AdcCommand.TYPE_BROADCAST, self.sid)
		cmd.addParam("NI", self.nick)
		self.command(cmd)

	def __call__(self):
		try:
			while self.get_command():
				pass
			self.sock.close()
		except Exception, e:
			print "Client " + self.nick + " died:", e
		except ParseException, e:
			print "Client " + self.nick + " died, line was:", self.lastline
		self.running = False
try:
	import sys
	if len(sys.argv) > 2:
		ip = sys.argv[1]
		port = int(sys.argv[2])
	else:
		ip = "127.0.0.1"
		port = 2780
	
	clients = []
	for i in range(CLIENTS):
		if i > 0 and i % 10 == 0:
			#time.sleep(3)
			pass
		print "Logging in", i
		client = Client(i)
		clients.append(client)
		client.login((ip,port))
		t = threading.Thread(target = client, name = client.nick)
		t.setDaemon(True)
		t.start()
	
	time.sleep(5)
	import random
	tests = []
	for k,v in Client.__dict__.iteritems():
		if len(k) < 4 or k[0:4] != "test":
			continue
		tests.append(v)
	print tests
	while len(clients) > 0:
		time.sleep(1)
		for c in clients:
			if not c.running:
				clients.remove(c)
				
			if len(clients) == 0:
				break
				
			if random.random() > (5./len(clients)):
				continue
			try:
				random.choice(tests)(c)
			except Exception, e:
				pass
	print "No more clients"
except Exception, e:
	print e
