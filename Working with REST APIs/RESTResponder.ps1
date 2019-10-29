#region Functions
$WorkspaceID = ''
$Key = ''
$LogType = 'MMSJazzRESTDemo'
$TimeStampField = 'DateValue'

function Build-Signature ($WorkspaceId, $Key, $Date, $ContentLength, $Method, $ContentType, $Resource){
    $Headers = "x-ms-date:" + $Date
    $StringToHash = "$($Method)`n$($ContentLength)`n$($ContentType)`n$($Headers)`n$($Resource)"
    $BytesToHash = [Text.Encoding]::UTF8.GetBytes($StringToHash)
    $KeyBytes = [Convert]::FromBase64String($Key)
    $SHA256 = [System.Security.Cryptography.HMACSHA256]::new()
    $SHA256.Key = $KeyBytes
    $CalculatedHash = $SHA256.ComputeHash($BytesToHash)
    $EncodedHash = [Convert]::ToBase64String($CalculatedHash)
    $Authorization = [string]::Format("SharedKey {0}:{1}", $WorkspaceId, $EncodedHash)
    return $Authorization
}

function Post-LogAnalyticsData($WorkspaceID, $Key, $Body, $LogType) {
    $Method = 'POST'
    $CType = 'application/json'
    $resource = '/api/logs'
    $rfc1123date = [DateTime]::UtcNow.ToString('r')
    $CLength = $Body.Length
    $Signature = Build-Signature -WorkspaceId $WorkspaceID -Key $Key -Date $rfc1123date -ContentLength $CLength -Method $Method -ContentType $CType -Resource $resource
    $URI = "https://$($WorkspaceID).ods.opinsights.azure.com$($resource)?api-version=2016-04-01"

    $headers = @{
        "Authorization" = $Signature;
        "Log-Type" = $LogType;
        "x-ms-date" = $rfc1123date;
        "time-generated-field" = $TimeStampField
    }

    $response = Invoke-RestMethod -Uri $URI -Method $Method -ContentType $CType -Headers $headers -Body $Body -UseBasicParsing
    return $response.StatusCode
}
#endregion

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
        $Result = Post-LogAnalyticsData -WorkspaceID $WorkspaceID -Key $Key -Body $Data -LogType $LogType
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($Result)
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