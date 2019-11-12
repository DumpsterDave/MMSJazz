Function Check-Cert {
    <#
        Pulls basic certificate information. isRaw flag will pull the raw certificate object.

        Example usage:
            Check-Cert pln-dccorp-04 636
            Check-Cert pln-dccorp-04 636 $true

        Parameters:
            $ip - Ip (direct or resolved) of host to check
            $port - Port number to check
            $isRaw - boolean to tell the function to return the raw object or not

    #>
        Param (
            $ip,
            [int] $port,
            [boolean] $isRaw
        )
    
        $tcpClient = New-Object -TypeName System.Net.Sockets.TcpClient

        Try {
            $tcpSocket = New-Object Net.Sockets.TcpClient($ip,$port)
            $tcpStream = $tcpSocket.GetStream()
            $callBack = {
                Param (
                    $sender,
                    $cert,
                    $chain,
                    $errors
                )

                return $True

                }
        
            $sslStream = New-Object -TypeName System.Net.Security.SslStream -ArgumentList @($tcpStream, $True, $callBack)

            Try {
                $sslStream.AuthenticateAsClient($ip)
                $targetCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($sslStream.RemoteCertificate)
            } Finally {
                $sslStream.Dispose()
            }
        } Finally {
            $tcpClient.Dispose()
        }

    If ($isRaw) {
        Return $targetCert
    } Else {
        $returnCertObj = [PSCustomObject]@{
            SerialNumber = $targetCert.SerialNumber
            Subject = $targetCert.Subject
            #SubjectAltName = $targetCert.SubjectName.Name
            DNSNameList = $targetCert.DnsNameList
            ValidStart = $targetCert.NotBefore.ToString()
            Expiry = $targetCert.NotAfter.ToString()
            Issuer = $targetCert.Issuer
            Algorithm = $targetCert.SignatureAlgorithm.FriendlyName
            IsValid = $targetCert.Verify()
        }        
        
        Return $returnCertObj
    }
}
