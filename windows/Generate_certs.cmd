@echo off
echo ADCH++ Certifcation Generator
echo.
echo This script reqires Win32 OpenSSL Installed
echo Win32 OpenSSL - http://www.slproweb.com/products/Win32OpenSSL.html
echo.

set SSL=C:\OpenSSL-Win32\bin\openssl.exe
set OPENSSL_CONF=C:\OpenSSL-Win32\bin\openssl.cfg

if not exist "%SSL%" (
   echo OpenSSL isn't found in %SSL%
   set SSL=%PROGRAMFILES%\OpenSSL\bin\openssl.exe
   set OPENSSL_CONF=%PROGRAMFILES%\OpenSSL\bin\openssl.cfg
)

if not exist "%SSL%" (
   echo.
   echo OpenSSL isn't found in %SSL%, exiting...
   pause
   exit
)

echo.
echo OpenSSL is found in %SSL%
pause

if not exist .\config goto notfound
if exist .\adchppd.exe goto found

:notfound
echo This script must be run from the ADCH++ program folder...
goto end 

:found
echo Proceeding with key generation
call "%SSL%" genrsa -out privkey.pem 2048
cls
call "%SSL%" dhparam -outform PEM -out dhparam.pem 1024
cls
call "%SSL%" req -new -x509 -key privkey.pem -out cacert.pem -days 1095
cls
mkdir certs
cd certs
mkdir trusted
cd..
move *.pem certs\

:end
pause
