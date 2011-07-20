#!/bin/bash

echo "Checking for OpenSSL"

if [ "$(which openssl)" ];
        then
        echo "OpenSSL was found, generating keys..."
        openssl genrsa -out privkey.pem 2048
        clear
        openssl dhparam -outform PEM -out dhparam.pem 1024
        openssl req -new -x509 -key privkey.pem -out cacert.pem -days 1095
        clear

        if [ -f certs/trusted ];
        then
                echo "No need create a directory that already exists"
        else
                mkdir -p certs/trusted
        fi

        mv *.pem certs

        echo "All done!"
else
        echo "Unable to locate OpenSSL, please make sure it is installed"
fi
