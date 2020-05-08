#!/bin/bash

PASS=${ADCHPP_PASS:-$(pwgen -s 12 1)}

if [ ! -z "$IPV6ADDR" ]; then
	echo  $IPV6ADDR
	ip -6 addr add "$IPV6ADDR" dev eth0
fi

sleep 2

if [ ! -z "$IPV6GW" ]; then
	echo $IPV6GW
	ip -6 route add  default via "$IPV6GW" dev eth0
fi

if [[ ! -f "/data/adchpp.xml" ]]
then
    cp /usr/src/adchpp/etc/adchpp.xml /data
fi

if [[ ! -f "/data/Script.xml" ]]
then
    cp /usr/src/adchpp/etc/Script.xml /data
    sed -i "s#\"/data/Scripts/\"#\"/data/Scripts/s\"#g" /data/Script.xml
fi

if [[ ! -d "/data/Scripts" ]]
then
    cp -rp /opt/adchpp/Scripts /data/Scripts
fi

if [[ ! -f "/data/users.txt" ]]
then
    echo -n "[{\"password\":\"${PASS}\",\"nick\":\"admin\",\"level\":10]" > /data/users.txt
    echo "Created admin user with username admin"
    echo "And password ${PASS}"
fi

/opt/adchpp/bin/adchppd -c /data
