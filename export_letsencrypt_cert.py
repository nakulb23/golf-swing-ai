#!/usr/bin/env python3
"""
Export Let's Encrypt certificate from Windows Certificate Store to PEM files
"""

import subprocess
import sys

def export_letsencrypt_cert():
    """Export the Let's Encrypt certificate to PEM files"""
    
    # Certificate thumbprint from the Let's Encrypt cert
    thumbprint = "E455DBC970C93CF8E0100C5A33320EB1DA24A127"
    
    print("Exporting Let's Encrypt certificate from Windows Certificate Store...")
    
    try:
        # Export certificate (public key) to PEM
        cert_cmd = f'''
        $cert = Get-ChildItem -Path Cert:\\LocalMachine\\My\\{thumbprint}
        $certBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        $certPem = "-----BEGIN CERTIFICATE-----`n" + [System.Convert]::ToBase64String($certBytes, [System.Base64FormattingOptions]::InsertLineBreaks) + "`n-----END CERTIFICATE-----"
        $certPem | Out-File -FilePath "ssl_certs\\letsencrypt.crt" -Encoding ASCII
        Write-Output "Certificate exported to ssl_certs\\letsencrypt.crt"
        '''
        
        result = subprocess.run(["powershell", "-Command", cert_cmd], 
                              capture_output=True, text=True, cwd=".")
        
        if result.returncode == 0:
            print("✅ Certificate exported successfully")
            print("❌ Note: Private key cannot be exported (Let's Encrypt security)")
            print("🔧 You'll need to use the Windows Certificate Store binding or re-generate")
        else:
            print(f"❌ Error: {result.stderr}")
            
    except Exception as e:
        print(f"❌ Error exporting certificate: {e}")

if __name__ == "__main__":
    export_letsencrypt_cert()