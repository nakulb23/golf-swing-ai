@echo off
echo Setting up Windows Firewall for Golf Swing AI API...
echo This requires administrator privileges.
echo.

REM Add inbound rule for port 8000
netsh advfirewall firewall add rule name="Golf Swing AI API - Inbound" dir=in action=allow protocol=TCP localport=8000

REM Add outbound rule for port 8000
netsh advfirewall firewall add rule name="Golf Swing AI API - Outbound" dir=out action=allow protocol=TCP localport=8000

echo.
echo Firewall rules added successfully!
echo Port 8000 is now open for Golf Swing AI API
echo.
pause