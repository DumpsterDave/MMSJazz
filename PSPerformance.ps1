#region Parameters and Global Variables
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false)]
    [switch]$OutToFile
)
$OutFileName = [string]::Format("C:\Temp\PSPerformance_{0}_{1}.{2}.txt", (Get-Date -Format "yyyyddMMHHmmss"), $host.Version.Major, $host.Version.Minor)
if ($OutToFile) {
    Out-File -FilePath $OutFileName -Encoding utf8 -Force -InputObject ([string]::Format("Running under PSVersion: {0}.{1}", $host.Version.Major, $host.Version.Minor))
}
#endregion

#region Winner Function
Function Get-Winner {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullOrEmpty()]
        [string]$AName,
        [Parameter(Mandatory=$true,Position=2)]
        [ValidateNotNullOrEmpty()]
        [int]$AValue,
        [Parameter(Mandatory=$true,Position=3)]
        [ValidateNotNullOrEmpty()]
        [string]$BName,
        [Parameter(Mandatory=$true,Position=4)]
        [ValidateNotNullOrEmpty()]
        [string]$BValue
    )
    Clear-Host

    $blen = $AName.Length + $BName.Length + 12
    $Border = ""
    for ($i = 0; $i -lt $blen; $i++) {
        $Border += "#"
    }

    if ($OutToFile) {
        Out-File -FilePath $OutFileName -Append -Encoding utf8 -InputObject $Border
        Out-File -FilePath $OutFileName -Append -Encoding utf8 -InputObject ([string]::Format("##  {0} vs {1}  ##", $AName, $BName))
        Out-File -FilePath $OutFileName -Append -Encoding utf8 -InputObject $Border
    }
    Write-Host $Border -ForegroundColor White
    Write-Host ([string]::Format("##  {0} vs {1}  ##", $AName, $BName)) -ForegroundColor White
    Write-Host $Border -ForegroundColor White

    if ($AValue -lt $BValue) {
        $Winner = $AName
        $AColor = [ConsoleColor]::Green
        $BColor = [ConsoleColor]::Red
        $Faster = $BValue / $AValue
    } elseif ($AValue -gt $BValue) {
        $Winner = $BName
        $AColor = [ConsoleColor]::Red
        $BColor = [ConsoleColor]::Green
        $Faster = $AValue / $BValue
    } else {
        $Winner = "Tie"
        $AColor = [ConsoleColor]::White
        $BColor = [ConsoleColor]::White
        $Faster = 0
    }
    
    $APad = ""
    $BPad = ""
    if ($AName.Length -gt $BName.Length) {
        $LenDiff = $AName.Length - $BName.Length
        for ($i = 0; $i -lt $LenDiff; $i++) {
            $BPad += " "
        }
    } else {
        $LenDiff = $BName.Length - $AName.Length
        for ($i = 0; $i -lt $LenDiff; $i++) {
            $APad += " "
        }
    }
    
    if ($OutToFile) {
        Out-File -FilePath $OutFileName -Append -Encoding utf8 -InputObject ([string]::Format("{0}:  {1}{2:0}ms", $AName, $APad, $AValue))
        Out-File -FilePath $OutFileName -Append -Encoding utf8 -InputObject ([string]::Format("{0}:  {1}{2:0}ms", $BName, $BPad, $BValue))
        Out-File -FilePath $OutFileName -Append -Encoding utf8 -InputObject ([string]::Format("WINNER: {0} {1:0.00}x Faster`r`n", $Winner, $Faster))
    }
    Write-Host ([string]::Format("{0}:  {1}{2:0}ms", $AName, $APad, $AValue)) -ForegroundColor $AColor
    Write-Host ([string]::Format("{0}:  {1}{2:0}ms", $BName, $BPad, $BValue)) -ForegroundColor $BColor
    Write-Host ([string]::Format("WINNER: {0} {1:0.00}x Faster`r`n", $Winner, $Faster)) -ForegroundColor Yellow
    Pause
}
#endregion

#region -Filter vs Where-Object
$f = Measure-Command {
    $objs = Get-ChildItem -Path C:\Windows\System32 -Filter '*.exe'
}
#Write-Host $objs.Count -ForegroundColor Magenta
$wo = Measure-Command {
    $objs = Get-ChildItem -Path C:\Windows\System32 | Where-Object {$_.Extension -eq '.exe'}
    $objs.Count
}
#Write-Host $objs.Count -ForegroundColor Cyan
Get-Winner 'Filter' $f.TotalMilliseconds 'Where-Object' $wo.TotalMilliseconds
#endregion

#region foreach vs for
$x = 1..10000

$fe = Measure-Command {
    foreach ($i in $x) {
        $i = ((Get-Random) * (Get-Random))
    }
}

$f = Measure-Command {
    for ($i = 0; $i -lt 10000; $i++) {
        $x[$i] = ((Get-Random) * (Get-Random))
    }
}
Get-Winner 'Foreach' $fe.TotalMilliseconds 'For' $f.TotalMilliseconds
#endregion

#region foreach vs .ForEach
$x = 1..10000

$fe2 = Measure-Command {
    foreach ($i in $x) {
        $i = ((Get-Random) * (Get-Random))
    }
}

$dfe = Measure-Command {
    $x.Foreach{$_ = ((Get-Random) * (Get-Random))}
}
Get-Winner 'Foreach' $fe2.TotalMilliseconds '.ForEach' $dfe.TotalMilliseconds
#endregion

#region foreach vs piped foreach
#foreach
$fe = Measure-Command {
    $x = 1..10000
    foreach($y in $x) {
        $x = Get-Random
    }
}

$fep = Measure-Command {
    $z = 1..10000
    $z | foreach {
        $_ = Get-Random
    }
}

Get-Winner 'ForEach' $fe.TotalMilliseconds 'ForEach Pipe' $fep.TotalMilliseconds
#endregion

#region array vs list
#Array
$a = Measure-Command {
    $array = @()
    for ($i = 0; $i -lt 10000; $i++) {
        $array += $i
    }
}

#List
$l = Measure-Command {
    $list = [System.Collections.ArrayList]::new()
    for ($i = 0; $i -lt 10000; $i++) {
        $list.Add($i)
    }
}

Get-Winner 'Array' $a.TotalMilliseconds 'List' $l.TotalMilliseconds
#endregion

#region Match vs .NET RegEx
$m = Measure-Command { 
    $Haystack = "The Quick Brown Fox Jumped Over the Lazy Brown Dog 5 Times"
    $Needle = "\ ([\d]*)\ "
    for ($i = 0; $i -lt 10000; $i++) {
        $Haystack -replace $Needle, " $(Get-Random) "
        $Haystack
    }
}

$nr = Measure-Command {
    $Haystack = "The Quick Brown Fox Jumped Over the Lazy Brown Dog 5 Times"
    $Needle = "\ ([\d]*)\ "
    for ($i = 0; $i -lt 10000; $i++) {
        [regex]::Replace($Haystack, $Needle, " $(Get-Random) ")
    }  
}

Get-Winner "RegEx" $m.TotalMilliseconds '.NET RegEx' $nr.TotalMilliseconds
#endregion

#region Pipes vs Long Form
#Pipes
$p = Measure-Command {
    for ($i = 0; $i -lt 1000; $i++) {
        Get-Item C:\Temp\Item1.txt | Get-Content -Raw | Out-File C:\Temp\Item1_2.txt -Force
    }
}

#Long Format
$lf = Measure-Command {
    for ($i = 0; $i -lt 1000; $i++) {
        $ci = Get-Item C:\Temp\Item1.txt
        $c = Get-Content $ci -Raw
        Out-File -InputObject $c -FilePath C:\Temp\Item2.txt -Force
    }
}

Get-Winner "Pipes" $p.TotalMilliseconds "Long Format" $lf.TotalMilliseconds
#endregion

#region String.Insert vs +=
#Concat
$c = Measure-Command {
    [string]$TypeCastString1 = ""
    for ($i = 0; $i -lt 10000; $i++) {
        $TypeCastString1 = $TypeCastString1.Insert($TypeCastString1.Length, '1')
        
    }
}

$pe = Measure-Command {
    [string]$TypeCastString2 = ""
    for ($i = 0; $i -lt 10000; $i++) {
        $TypeCastString2 += '1'
    }
}

Get-Winner 'String.Insert' $c.TotalMilliseconds 'Plus/Equals' $pe.TotalMilliseconds
#endregion

#region String.Format vs "" -f
$sf = Measure-Command {
    [string]$TypeCastString3 = ""
    for ($i = 0; $i -lt 10000; $i++) {
        $TypeCastString3 = [string]::Format("{0} {1}", (Get-Random), (Get-Random))
    }
}

$sdf = Measure-Command {
    [string]$TypeCastString4 = ""
    for ($i = 0; $i -lt 10000; $i++) {
        $TypeCastString4 = "{0} {1}" -f (Get-Random), (Get-Random)
    }
}

Get-Winner 'String.Format' $sf.TotalMilliseconds 'String -f' $sdf.TotalMilliseconds
#endregion

#region Get-Content vs .NET Streams
#Get-Content
$gc = Measure-Command {
    for ($i = 0; $i -lt 100; $i++) {
        $GcTrash = Get-Content C:\Temp\Item3.txt -Encoding UTF8
    }
}

$st = Measure-Command {
    for ($i = 0; $i -lt 100; $i++) {
        $StreamReader = [System.IO.StreamReader]::new('C:\Temp\Item3.txt', [System.Text.Encoding]::UTF8)
        $StTrash = $StreamReader.ReadToEndAsync()
    }
}

Get-Winner 'Get-Content' $gc.TotalMilliseconds '.NET Streams' $st.TotalMilliseconds
#endregion