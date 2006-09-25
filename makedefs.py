import re
import codecs
import xml.sax.saxutils

def makename(oldname):
	name = "";
	nextBig = True;
	for x in oldname:
		if x == '_':
			nextBig = True;
		else:
			if nextBig:
				name += x.upper();
				nextBig = False;
			else:
				name += x.lower();
				
	return name;

	
version = re.search("VERSIONFLOAT (\S+)", file("adchpp/version.cpp").read()).group(1)

varstr = "";
strings = "";
varname = "";
names = "";

prolog = "";
epilog = "";

example = '<?xml version="1.0" encoding="utf-8" standalone="yes"?>\n';
example += '<Language Name="Example Language" Author="arnetheduck" Version=' + version + ' Revision="1">\n'
example += '\t<Strings>\n';

lre = re.compile('\s*(\w+),\s*//\s*\"(.+)\"\s*')

decoder = codecs.getdecoder('cp1252')
encoder = codecs.getencoder('utf8')
recodeattr = lambda s: encoder(decoder(xml.sax.saxutils.quoteattr(s))[0])[0]
recodeval = lambda s: encoder(decoder(xml.sax.saxutils.escape(s, {"\\t" : "\t"}))[0])[0]

for x in file("adchpp/StringDefs.h", "r"):
    if x.startswith("// @Strings: "):
        varstr = x[13:].strip();
    elif x.startswith("// @Names: "):
        varname = x[11:].strip();
    elif x.startswith("// @Prolog: "):
        prolog += x[12:];
    elif x.startswith("// @Epilog: "):
		epilog += x[12:];
    elif len(x) >= 5:
        match = lre.match(x);
        if match is not None:
            name , value = match.groups();
            strings += '"' + value + '", \n'
            newname = makename(name)
            names += '"' + newname + '", \n'
            example += '\t\t<String Name=%s>%s</String>\n' % (recodeattr(newname),  recodeval(value))

example += '\t</Strings>\n';
example += '</Language>\n';

file('adchpp/StringDefs.cpp', 'w').write(prolog + varstr + " = {\n" + strings + "};\n" + varname + " = {\n" + names + "};\n" + epilog);
file('etc/Example.adchpp.xml', 'w').write(example);
