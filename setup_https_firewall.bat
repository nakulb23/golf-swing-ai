@echo off
echo Setting up Windows Firewall for HTTPS Golf Swing AI API...
echo This requires administrator privileges.
echo.

REM Add inbound rule for HTTPS port 8443
netsh advfirewall firewall add rule name="Golf Swing AI HTTPS - Inbound" dir=in action=allow protocol=TCP localport=8443

REM Add outbound rule for HTTPS port 8443
netsh advfirewall firewall add rule name="Golf Swing AI HTTPS - Outbound" dir=out action=allow protocol=TCP localport=8443

echo.
echo HTTPS Firewall rules added successfully!
echo Port 8443 is now open for Golf Swing AI HTTPS API
echo.
echo IMPORTANT: You also need to add port forwarding in your router:
echo - External Port: 8443
echo - Internal IP: 192.168.4.172
echo - Internal Port: 8443
echo - Protocol: TCP
echo.
pause