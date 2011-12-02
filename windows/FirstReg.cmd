@echo off
echo FirstReg for ADCH++
echo -------------------
echo.
echo Script for creating the initial (admin) account in a new ADCH++ installation.
echo.

if not exist .\config goto notfound
if exist .\adchppd.exe goto found

:notfound
echo This script must be run from the ADCH++ program folder...
goto end

:found
echo *** !!!BEWARE!!! ***
echo 1. Proceeding will result in all of the existing user registrations being DELETED!!
echo    This script will (re)create the file %CD%\config\users.txt !!
echo 2. The ADCH++ process can NOT be running in order for changes to take effect.
echo.
set /p userinp=Are you sure you want to continue? Press 'Y' to proceed, press any other key to exit : 
if "%userinp%"=="y" goto ok
if "%userinp%"=="Y" goto ok
goto end

:ok
echo.
echo Enter the admin account information
set /p USER=Username : 
set /p PWD=Password : 
set /p LEVEL=Admin user level : 

echo [{"password":"%PWD%","nick":"%USER%","level":%LEVEL%,"regby":"%USER%","regtime":1322835912}] > .\config\users.txt || goto err

echo Account successfully created.
goto end

:err
echo Error while trying to modify %CD%\config\users.txt

:end
pause
