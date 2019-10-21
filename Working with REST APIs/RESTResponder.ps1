#Setup the server
$Path = Split-Path $MyInvocation.MyCommand.Path  -Parent
Set-Location $Path
$Server = [System.Net.HttpListener]::new()
$Server.Prefixes.Add('http://localhost:8001/')
$Server.Start()

#Make the server stop after 30 seconds
$StopAt = (Get-Date).AddSeconds(60)

while (($Server.IsListening) -and ((Get-Date) -le $StopAt)) {
    Write-Output "Listening..."
    $Context = $Server.GetContext()
    
    Write-Host "$($Context.Request.UserHostAddress) => $($Context.Request.Url)"  -ForegroundColor Green
    $RequestData = $Context.Request.Headers.GetValues('RequestData')
    if ($Context.Request.HttpMethod -eq 'POST') {
        if ($Context.Request.HasEntityBody) {
            $Body = [System.IO.StreamReader]::new($Context.Request.InputStream, $Context.Request.ContentEncoding)
            $Data = $Body.ReadToEnd()
            $Body.Close()
        }
    } elseif ($Context.Request.HttpMethod -eq 'GET' -and $null -ne $RequestData) {
        switch($RequestData) {
            "Process" {
                $Processes = Get-Process
                $JSON = ConvertTo-Json $Processes
            }
            default {
                $BadRequest = "" | Select Response,ExitCode
                $BadRequest.Response = "Invalid Request"
                $BadRequest.ExitCode = 1
                $JSON = ConvertTo-Json $BadRequest
            }
        }
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($JSON)
        $Context.Response.ContentLength64 = $buffer.Length
        $Context.Response.OutputStream.Write($buffer, 0, $buffer.length)
        $Context.Response.OutputStream.Close()
    } elseif ($Context.Request.HttpMethod -eq 'PUT') {
        #Process the Body and Convert it to an Object
        $Body = [System.IO.StreamReader]::new($Context.Request.InputStream, $Context.Request.ContentEncoding)
        $Data = $Body.ReadToEnd()
        $Obj = ConvertFrom-Json $Data

        #Write the body parts out
        Write-Host -NoNewline -ForegroundColor Magenta "$($Obj.Number)`t"
        Write-Host -NoNewline -ForegroundColor Yellow "$($Obj.Name)`t"
        Write-Host -ForegroundColor Cyan "$($Obj.Message)"

        #Respond to the client so that they can close the connection
        $buffer = [System.Text.Encoding]::UTF8.GetBytes("OK")
        $Context.Response.ContentLength64 = $buffer.Length
        $Context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
        $Context.Response.OutputStream.Close()        
    } else {
        $file = ($Context.Request.RawUrl).Substring(1)
        $file
        if ($null -eq $file) {
            Write-Host "RawURL"
            $Context.Request.RawUrl
            Write-Host "Request"
            $Context.Request
            Write-Host "Context"
            $Context
        } else {
            #$FLength = ([System.IO.FileInfo]::new("$($Path)\$($file)")).Length
            if ((Test-Path -Path $file) -and ((([System.IO.FileInfo]::new("$($Path)\$($file)")).Length) -gt 0)) {
                $buffer = [System.Text.Encoding]::UTF8.GetBytes((Get-Content $file -Raw))
                $Context.Response.ContentLength64 = $buffer.Length
                $Context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
                $Context.Response.OutputStream.Close()
            } else {
                Write-Warning -Message "$($file) not found or was 0 length.  Will not serve."
                $Context.Response.OutputStream.Close()
            }
        }
    }
}
Write-Output "'`$StopAt' reached,  Stopping Server."
$Server.Stop()