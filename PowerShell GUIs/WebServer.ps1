$Server = [System.Net.HttpListener]::new()
[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
$Server.Prefixes.Add('http://localhost:8000/')
$Server.Start()

$RootDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$StopAt = (Get-Date).AddMinutes(5)

if ($Server.IsListening) {
    Write-Host "Ready..."
}
$AllDisks = [System.Collections.ArrayList]::new()
$AllPartitions = [System.Collections.ArrayList]::new()
$AllVolumes = [System.Collections.ArrayList]::new()

while (($Server.IsListening) -and ((Get-Date) -lt $StopAt)) {
    $Context = $Server.GetContext()

    $Action = $null
    $Payload = $null

    #Process Responces

    #Serve our app to the client
    $Context.Request.QueryString.AllKeys
    if (($Context.Request.QueryString.AllKeys) -contains "action") {
        $Action = $Context.Request.QueryString.GetValues("action")
        $TargetVolId = $Context.Request.QueryString.GetValues("VolumeId")
        $Payload = $Context.Request.QueryString.GetValues("payload")
        if ($null -ne $Action) {
            Write-Host "Action: $($Action)" -ForegroundColor Cyan
            Write-Host "$($Context.Request.UserHostAddress) => $($Context.Request.Url)"  -ForegroundColor Green
            switch (($Action.ToLower())) {
                "stop" {
                    $Server.Stop()
                }
                "ping" {
                    Write-Host "PING" -ForegroundColor Magenta
                    Test-Connection $Payload -OutVariable out | Out-Null
                    $lines = ""
                    foreach ($result in $out) {
                        $x = "$($result.Address) :: $($result.ResponseTime)ms :: $($result.StatusCode) :: $($result.BufferSize) Bytes :: $($result.IPV4Address)<br />"
                        $lines += $x
                    }
                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($lines)
                    $Context.Response.ContentLength64 = $buffer.Length
                    $Context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
                    $Context.Response.OutputStream.Close()
                }
                "drivestatus" {
                    Write-Host "DRIVE STATUS" -ForegroundColor Magenta
                    $ob = ""
                    $AllDisks.Clear()
                    $AllPartitions.Clear()
                    $AllVolumes.Clear()

                    $Disks = Get-Disk
                    foreach ($dsk in $Disks) {
                        [void]$AllDisks.Add($dsk)
                        #Create Table
                        $PDisk = Get-PhysicalDisk -UniqueId $dsk.UniqueId -ErrorAction SilentlyContinue -ErrorVariable ev
                        if ($ev.Count -ne 0) {
                            $DiskType = "Unknown"
                        } else {
                            $DiskType = $PDisk.MediaType
                        }
                        $ob += "<table border=`"0`" cellpadding=`"0`" cellspacing=`"10`">
                        <tr><td colspan=`"6`">Disk $($dsk.Number)</td><td>$($DiskType)</td></tr>
                        <tr><td width=`"128`">ID</td><td width=`"70`">Partition</td><td width=`"70`">Volume</td><td width=`"70`">Drive Letter</td><td width=`"70`">File System</td><td width=`"128`">Total Size</td><td width=`"128`">Free Space</td><td width=`"256`">Disk Usage</td></tr>"
                        $Partitions = Get-Partition -DiskNumber $dsk.Number
                        foreach ($par in $Partitions) {
                            [void]$AllPartitions.Add($par)
                            $Volumes = Get-Volume -Partition $par
                            $VolId = 0
                            foreach ($vol in $Volumes) {
                                [void]$AllVolumes.Add($vol)
                                if (($vol.UniqueId) -match "([0-9a-z]{8}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{12})") {
                                    $VolumeID = $Matches[0]
                                } else {
                                    $VolumeID = "00000000-0000-0000-0000-000000000000"
                                }
                                if ($vol.Size -gt 1073741824) {
                                    $Size = [string]::Format("{0:n2} GB", (($vol.Size) / 1073741824))
                                } else {
                                    $Size = [string]::Format("{0:n2} MB", (($vol.Size) / 1048576))
                                }
                                if ($vol.SizeRemaining -gt 1073741824) {
                                    $Free = [string]::Format("{0:n2} GB", (($vol.SizeRemaining) / 1073741824))
                                } else {
                                    $Free = [string]::Format("{0:n2} MB", (($vol.SizeRemaining) / 1048576))
                                }
                                $PFreeDecimal = (($vol.SizeRemaining) / ($vol.Size))
                                $PUsedDecimal = 1 - (($vol.SizeRemaining) / ($vol.Size))
                                $PUsedString = [string]::Format("{0:p2}", $PUsedDecimal)
                                $PUsedWidth = [int]($PUsedDecimal * 256);

                                if ($PUsedDecimal -gt 0.95) {
                                    $FGColor = "#FF0000"
                                    $BarColor = "crimson"
                                } elseif ($PUsedDecimal -gt 0.80) {
                                    $FGColor = "#FF8000"
                                    $BarColor = "darkorange"
                                } else {
                                    $FGColor = "#000000"
                                    $BarColor = "mediumseagreen"
                                }
                                
                                #$ob += "<tr style=`"color: $($FGColor);`"><td>$($par.PartitionNumber)</td><td>$($VolId)</td><td>$($vol.DriveLetter)</td><td>$($vol.FileSystem)</td><td>$($Size)</td><td>$($Free)</td><td>$($PFreeString)</td></tr>"
                                $ob += "<tr style=`"color: $($FGColor);`"><td><a href=`"#`" onClick=`"ShowVolume('$($VolumeID)');`">$($VolumeID)</a></td><td>$($par.PartitionNumber)</td><td>$($VolId)</td><td>$($vol.DriveLetter)</td><td>$($vol.FileSystem)</td><td>$($Size)</td><td>$($Free)</td><td><div class=`"FreeBorder`"><div class=`"FreeBar`" style=`"width: $($PUsedWidth)px; background-color: $($BarColor);`"><div class=`"FreeText`">$($PUsedString)</div></div></div></td></tr>"
                                $VolId++
                            }
                            #Close Partions Div and Volumes Table
                            #$ob += "</table></div>"
                        }
                        #Close Disk Div
                        #$ob += "</div>"
                        $ob += "</table>"
                    }

                    $buffer = [System.Text.Encoding]::UTF8.GetBytes($ob)
                    $Context.Response.ContentLength64 = $buffer.Length
                    $Context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
                    $Context.Response.OutputStream.Close()
                }
                "diskinfo" {
                    Write-Host "VolumeID: $($TargetVolId)" -ForegroundColor Cyan
                    $SelectedVolume = $null
                    foreach ($vol in $AllVolumes) {
                        if ($vol.UniqueId -match $TargetVolId) {
                            $SelectedVolume = $vol
                        }
                    }
                    if ($null -ne $SelectedVolume){
                        $ob = @"
                        <table cellpadding="0" cellspacing="0" border="0" style="color: #ffffff;">
                            <tr>
                                <td>Allocation Unit Size</td>
                                <td>$($SelectedVolume.AllocationUnitSize)</td>
                            </tr>
                            <tr>
                                <td>Drive Letter</td>
                                <td>$($SelectedVolume.DriveLetter)</td>
                            </tr>
                            <tr>
                                <td>File System</td>
                                <td>$($SelectedVolume.FileSystem)</td>
                            </tr>
                            <tr>
                                <td>File System Label</td>
                                <td>$($SelectedVolume.FileSystemLabel)</td>
                            </tr>
                            <tr>
                                <td>ObjectId</td>
                                <td>$($SelectedVolume.ObjectId)</td>
                            </tr>
                            <tr>
                                <td>Passthrough Class</td>
                                <td>$($SelectedVolume.PassThroughClass)</td>
                            </tr>
                            <tr>
                                <td>Passthrough IDs</td>
                                <td>$($SelectedVolume.PassThroughIds)</td>
                            </tr>
                            <tr>
                                <td>Passthrough Namespace</td>
                                <td>$($SelectedVolume.PassThroughNamespace)</td>
                            </tr>
                            <tr>
                                <td>Passthrough Server</td>
                                <td>$($SelectedVolume.PassThroughServer)</td>
                            </tr>
                            <tr>
                                <td>Path</td>
                                <td>$($SelectedVolume.Path)</td>
                            </tr>
                            <tr>
                                <td>PS Computer Name</td>
                                <td>$($SelectedVolume.PSComputerName)</td>
                            </tr>
                            <tr>
                                <td>Size</td>
                                <td>$($SelectedVolume.Size)</td>
                            </tr>
                            <tr>
                                <td>Size Remaining</td>
                                <td>$($SelectedVolume.SizeRemaining)</td>
                            </tr>
                            <tr>
                                <td>Unique ID</td>
                                <td>$($SelectedVolume.UniqueId)</td>
                            </tr>
                            <tr>
                                <td>Deduplication Mode</td>
                                <td>$($SelectedVolume.DedupMode)</td>
                            </tr>
                            <tr>
                                <td>Drive Type</td>
                                <td>$($SelectedVolume.DriveTpe)</td>
                            </tr>
                            <tr>
                                <td>File System Type</td>
                                <td>$($SelectedVolume.FileSystemType)</td>
                            </tr>
                            <tr>
                                <td>Health Status</td>
                                <td>$($SelectedVolume.HealthStatus)</td>
                            </tr>
                            <tr>
                                <td>Operational Status</td>
                                <td>$($SelectedVolume.OperationalStatus)</td>
                            </tr>
                        </table>
                        <br />
                        <button onClick="HideVolume();">Hide</button>
"@
                        $buffer = [System.Text.Encoding]::UTF8.GetBytes($ob)
                        $Context.Response.ContentLength64 = $buffer.Length
                        $Context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
                        $Context.Response.OutputStream.Close()
                    }
                }
                default {
                    Write-Host "UNKNOWN" -ForegroundColor Red
                }
            }
            $Action = $null
            $Payload = $null
        }
    } elseif($Context.Request.HttpMethod -eq 'GET' -and $Context.Request.RawUrl -eq '/') {
        Write-Host "$($Context.Request.UserHostAddress) => $($Context.Request.Url)"  -ForegroundColor Green
        $buffer = [System.Text.Encoding]::UTF8.GetBytes((Get-Content "$($RootDir)\index.html" -Raw))
        $Context.Response.ContentLength64 = $buffer.Length
        $Context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
        $Context.Response.OutputStream.Close()
    } else {
        $file = ($Context.Request.RawUrl).Substring(1)
        if ($null -eq $file) {
            Write-Host "RawURL"
            $Context.Request.RawUrl
            Write-Host "Request"
            $Context.Request
            Write-Host "Context"
            $Context
        } else {
            Write-Host $file -ForegroundColor Yellow
            Write-Host "$($Context.Request.UserHostAddress) => $($Context.Request.Url)" -ForegroundColor Green
            $buffer = [System.Text.Encoding]::UTF8.GetBytes((Get-Content "$($RootDir)\$($file)" -Raw))
            $Context.Response.ContentLength64 = $buffer.Length
            $Context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
            $Context.Response.OutputStream.Close()
        }
    } 
}

if ($Server.IsListening) {
    $Server.Stop()
}

