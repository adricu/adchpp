
$:.unshift(File.expand_path('../build/debug-default/bin/'))
$:.unshift(File.expand_path('../build/release-default/bin/'))

puts "Loading module..."

require 'rbadchpp'

a = Rbadchpp

config_path = File.expand_path("../etc/") + '/'
puts "Configuration path is #{config_path}..."

a.initialize(config_path)

sil = a::TServerInfoList.new
si = a::ServerInfo.create()
si.port= 2780
sil.push(si)
a.get_sm().set_servers(sil)

print "."
    
a.startup()

c = ''
while c != "\n" do
  c = STDIN.getc.chr
  puts c
end
    
a.shutdown()
 
a.cleanup()

