
$:.unshift(File.expand_path('../build/debug-default/bin/'))
$:.unshift(File.expand_path('../build/release-default/bin/'))

puts "Loading module..."

require 'rbadchpp'

a = Rbadchpp

config_path = File.expand_path("../etc/") + '/'
puts "Configuration path is #{config_path}..."

core = a::Core.create(config_path)

sil = a::TServerInfoList.new
si = a::ServerInfo.create()
si.port= 2780
sil.push(si)

core.get_socket_manager().set_servers(sil)
cm = core.get_client_manager()

print "."
counter = 0
connected = cm.signal_connected().connect(Proc.new { counter = counter + 1 })
disconnected = cm.signal_disconnected().connect(Proc.new { counter = counter - 1 })
cb = core.add_timed_job(1000, Proc.new { puts counter })

trap("INT") { core.shutdown() }
core.run()

puts "Shutting down..."

disconnected = nil
connected = nil
puts cb
cb.call

cb = nil

core = nil
