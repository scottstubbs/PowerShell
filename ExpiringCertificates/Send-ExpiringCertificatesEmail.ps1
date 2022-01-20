<#
    .SYNOPSIS
        Sends an email if any of the host certificates are about to expire.

    .PARAMETER Hosts
        The list of remote hosts to inspect.

    .PARAMETER Days
        The number of days in the expiration window.
    
    .PARAMETER From
        The sender's email address.

    .PARAMETER To
        The recipient's email address. If there are multiple recipients, separate them with a comma.

    .PARAMETER Subject
        The subject of the email message.

    .PARAMETER SmtpServer
        The name of the SMTP server that sends the email message.

    .EXAMPLE
        Send-ExpiringCertificatesEmail -Hosts "apple.com","google.com","microsoft.com" -Days 60 -From "no-reply@some.org" -To "me@some.org" -SmtpServer "smtp.some.org"

        This will send an email if any of the certificates for the given hosts are about to expire in the next sixty days.

    .NOTES
        Author: Scott Stubbs
#>

function Send-ExpiringCertificatesEmail {
    param (
        [string[]]
        $Hosts,

        [int]
        $Days = 60,

        [string]
        $From,

        [string]
        $To,

        [string]
        $Subject = "Certificates Expiring Soon",

        [string]
        $SmtpServer
    )
    process {
        $remoteCertificates = @()

        $protocols = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13

        # Download the public X.509 certificate from each remote host.
        foreach ($remoteHost in $Hosts) {
            try {
                $socket = New-Object System.Net.Sockets.TcpClient -Argument $remoteHost, 443
                $stream = New-Object System.Net.Security.SslStream -Argument $socket.GetStream(), $true
                $stream.AuthenticateAsClient($remoteHost, $null, $protocols, $true)

                if ($stream.RemoteCertificate) {
                    $remoteCertificates += [PSCustomObject]@{
                        Host = $remoteHost
                        Expires = [DateTime]$stream.RemoteCertificate.GetExpirationDateString()
                        Days = ([DateTime]$stream.RemoteCertificate.GetExpirationDateString() - (Get-Date)).Days
                    }
                }
            } catch {
                throw "Could not authenticate with the remote host '$remoteHost'."
            }
        }

        # Filter the results to certificates that are expiring soon.
        $expiringCertificates = $remoteCertificates | Where-Object -Property Days -LE -Value $Days | Sort-Object -Property Expires

        # Format and send email with the list of hosts containing expiring certificates.
        if ($expiringCertificates) {
            $body = $expiringCertificates | ConvertTo-Html -Fragment

            $html = "<html>
                <style>
                    table { border-collapse: collapse; }
                    th { padding: 8px; text-align: left; }
                    td { border: 1px solid #dddddd; padding: 8px; text-align: left; }
                </style>
                <body>
                    $body
                </body>
                </html>"

            Send-MailMessage -From $From -To $To -Subject $Subject -SmtpServer $SmtpServer -Body $html -BodyAsHtml -WarningAction:SilentlyContinue
        }
    }
}