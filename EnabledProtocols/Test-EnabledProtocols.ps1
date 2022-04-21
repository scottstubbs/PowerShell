<#
    .SYNOPSIS
        Test each host for enabled SSL/TLS protocols.

    .PARAMETER Hosts
        The list of remote hosts to inspect.

    .EXAMPLE
        Test-EnabledProtocols -Hosts "apple.com","google.com","microsoft.com"
#>


function Test-EnabledProtocols {
    param (
        [string[]]
        $Hosts
    )
    process {
        $protocols = @("Ssl2", "Ssl3", "Tls", "Tls11", "Tls12", "Tls13")

        foreach ($remoteHost in $Hosts) {
            Write-Host $remoteHost -ForegroundColor White -BackgroundColor Blue

            foreach ($protocol in $protocols) {
                try {
                    $socket = New-Object System.Net.Sockets.TcpClient -Argument $remoteHost, 443
                    $stream = New-Object System.Net.Security.SslStream -Argument $socket.GetStream(), $true
                    $stream.AuthenticateAsClient($remoteHost, $null, $protocol, $false)

                    Write-Host $protocol -ForegroundColor White -BackgroundColor Green
                } catch {
                    Write-Host $protocol -ForegroundColor White -BackgroundColor Red
                }
            }

            Write-Host
        }
    }
}