@echo off
echo ADCH++ Certifcation Generator
echo.
echo This script reqires Win32 OpenSSL Installed
echo Win32 OpenSSL - http://www.slproweb.com/products/Win32OpenSSL.html
pause

set SSL=%PROGRAMFILES%\OpenSSL\bin\openssl.exe
if not exist "%SSL%" (
   echo OpenSSL isnt found make sure path is correct, exiting...
   pause
   exit
)

echo OpenSSL is found

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
set SSL=
pause
