#region Parameters and Global Variables
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false)]
    [switch]$OutToFile
)
$BaseDir = (Split-Path -Parent $PSCommandPath)
$OutFileName = [string]::Format("$BaseDir\PSPerformance_{0}_{1}.{2}.txt", (Get-Date -Format "yyyyddMMHHmmss"), $host.Version.Major, $host.Version.Minor)
#
#Switches
#
$PauseBetweenTests = $false
$ClearBetweenTests = $false
$OutToFile = $false
#
#
#
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
    if ($ClearBetweenTests) {
        Clear-Host
    }

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
        $Faster = $BValue / $AValue
        if ($Faster -lt 1.05) {
            $Winner = "Tie"
            $AColor = [ConsoleColor]::White
            $BColor = [ConsoleColor]::White
        } else {
            $Winner = $AName
            $AColor = [ConsoleColor]::Green
            $BColor = [ConsoleColor]::Red
        }
    } elseif ($AValue -gt $BValue) {
        $Faster = $AValue / $BValue
        if ($Faster -lt 1.05) {
            $Winner = "Tie"
            $AColor = [ConsoleColor]::White
            $BColor = [ConsoleColor]::White
        } else {
            $Winner = $BName
            $AColor = [ConsoleColor]::Red
            $BColor = [ConsoleColor]::Green
        }
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
    if ($PauseBetweenTests -eq $true) {
        Pause
    }
}
#endregion



#region -Filter vs Where-Object
$f = Measure-Command {
    $objs = Get-ChildItem -Path C:\Windows\System32 -Filter '*.exe'
    $objs.Count
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
    $z | ForEach-Object {
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
        [void]$list.Add($i)
    }
}

Get-Winner 'Array' $a.TotalMilliseconds 'List' $l.TotalMilliseconds
#endregion

#region ArrayList vs List
$Iterations = 10000
#ArrayList
$al = Measure-Command {
    $ArrayList = [System.Collections.ArrayList]::new()
    for ($i = 0; $i -lt $Iterations; $i++) {
        [void]$ArrayList.Add($i)
    }
}

#List
$l = Measure-Command {
    $List = [System.Collections.Generic.List[Object]]::new()
    for ($i = 0; $i -lt $Iterations; $i++) {
        [void]$List.Add($i)
    }
}
Get-Winner 'ArrayList' $al.TotalMilliseconds 'List' $l.TotalMilliseconds
#endregion

#region ObjectList vs Typecast List
#List
$ol = Measure-Command {
    $ObjectList = [System.Collections.Generic.List[Object]]::new()
    for ($i = 0; $i -lt $Iterations; $i++) {
        [void]$ObjectList.Add($i)
    }
}

#TypeList
$tl = Measure-Command {
    $TypeList = [System.Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $Iterations; $i++) {
        [void]$TypeList.Add($i)
    }
}

Get-Winner 'TypeList' $tl.TotalMilliseconds 'Object List' $ol.TotalMilliseconds
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
Out-File "$BaseDir\Item1.txt" -Encoding utf8 -InputObject ""
Out-File "$BaseDir\Item2.txt" -Encoding utf8 -InputObject ""

#Pipes
$p = Measure-Command {
    Get-ChildItem -Path C:\Windows\System32 -Filter '*.exe' | Get-FileHash -Algorithm SHA1 | Out-File "$BaseDir\Item1.txt" -Append
}

#Long Format
$lf = Measure-Command {
    $Kids = Get-ChildItem -Path C:\Windows\System32 -Filter '*.exe'
    $Hash = Get-FileHash $Kids.FullName -Algorithm SHA1
    Out-File "$BaseDir\Item2.txt" -Append -InputObject $Hash.Hash
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
        $GcTrash = Get-Content "$BaseDir\Item3.txt" -Encoding UTF8
    }
}

#Stream Reader
$st = Measure-Command {
    for ($i = 0; $i -lt 100; $i++) {
        $StreamReader = [System.IO.StreamReader]::new("$BaseDir\Item3.txt", [System.Text.Encoding]::UTF8)
        $StTrash = $StreamReader.ReadToEndAsync()
    }
}

Get-Winner 'Get-Content' $gc.TotalMilliseconds '.NET Streams' $st.TotalMilliseconds
#endregion

#region [Void] vs. Out-Null
$vl = [System.Collections.Generic.List[Object]]::new()
$onl = [System.Collections.Generic.List[Object]]::new()
$Iterations = 10000

$v = Measure-Command {
    for ($i = 0; $i -lt $Iterations; $i++) {
        [void]$vl.Add((Get-Random))
    }
}

$on = Measure-Command {
    for ($i = 0; $i -lt $Iterations; $i++) {
        $onl.Add((Get-Random)) | Out-Null
    }
}

Get-Winner '[void]' $v.TotalMilliseconds 'Out-Null' $on.TotalMilliseconds
#endregion

#region Write-Host vs Write-Output
#Write-Host
$iterations = 1000
$wh = Measure-Command {
    for ($i = 0; $i -lt $iterations; $i++) {
        Write-Host "The quick brown fox jumps over the lazy dog"
    }
}

#Write-Output
$wo = Measure-Command {
    for ($i = 0; $i -lt $iterations; $i++) {
        Write-Output "The quick brown fox jumps over the lazy dog"
    }
}

Get-Winner 'Write-Host' $wh.TotalMilliseconds 'Write-Output' $wo.TotalMilliseconds
#endregion

#region Write-Output vs [Console]::WriteLine()
$iterations = 1000
$wo = Measure-Command {
    for ($i = 0; $i -lt $iterations; $i++) {
        Write-Output "The quick brown fox jumps over the lazy dog"
    }
}

$cwl = Measure-Command {
    for ($i = 0; $i -lt $iterations; $i++) {
        [System.Console]::WriteLine("The quick brown fox jumps over the lazy dog")
    }
}
Get-Winner '[Console]::WriteLine' $cwl.TotalMilliseconds 'Write-Output' $wo.TotalMilliseconds
#endregion


#region Write-Host vs [Console]::WriteLine() with Color
$iterations = 1000
$wh = Measure-Command {
    for ($i = 0; $i -lt $iterations; $i++) {
        Write-Host "The quick brown fox jumps over the lazy dog"
    }
}

$cwl = Measure-Command {
    for ($i = 0; $i -lt $iterations; $i++) {
        [System.Console]::WriteLine("The quick brown fox jumps over the lazy dog")
    }
}
Get-Winner '[Console]::WriteLine' $cwl.TotalMilliseconds 'Write-Host' $wh.TotalMilliseconds
#endregion

#region Function vs Code
$iterations = 1000
function Get-RandomSquare {
    $r = Get-Random
    return ($r * $r)
}

$f = Measure-Command {
    for ($i = 0; $i -lt $iterations; $i++) {
        $x = Get-RandomSquare
    }
}

$c = Measure-Command {
    for ($i = 0; $i -lt $iterations; $i++) {
        $r = Get-Random
        $y = ($r * $r)
    }
}
Get-Winner 'Function' $f.TotalMilliseconds 'Commands' $c.TotalMilliseconds
#endregion

#region Where-Object vs. For Loop
#Loop Filter with a Second Loop to copy to the new array
$f = Measure-Command {
    $Filtered = [System.Collections.ArrayList]::new()
    $all = Get-ChildItem -Path C:\Windows\System32
    for ($i = 0; $i -lt $all.Count; $i++)
    {
        if($all[$i].Extension -eq '.exe') {
            [void]$Filtered.Add($i)
        }
    }
    $objs = [System.Object[]]::new($Filtered.Count)
    
    for($i = 0; $i -lt $Filtered.Count; $i++) {
        $objs[$i] = $all[$Filtered[$i]]
    }
    $objs.Count
}

#Loop Filter utilizing the .ToArray method instead of a loop copy
$f2 = Measure-Command {
    $Filtered = [System.Collections.ArrayList]::new()
    $all = Get-ChildItem -Path C:\Windows\System32
    for ($i = 0; $i -lt $all.Count; $i++)
    {
        if($all[$i].Extension -eq '.exe') {
            [void]$Filtered.Add($all[$i])
        }
    }
    $2objs = $Filtered.ToArray()
    $2objs.Count
}
#Write-Host $objs.Count -ForegroundColor Magenta
$wo = Measure-Command {
    $wobjs = Get-ChildItem -Path C:\Windows\System32 | Where-Object {$_.Extension -eq '.exe'}
    $wobjs.Count
}
$objs.GetType()
$2objs.GetType()
$wobjs.GetType()
Get-Winner 'Loop Filter' $f.TotalMilliseconds 'Where-Object' $wo.TotalMilliseconds
Get-Winner 'Loop Filter w/ Loop Copy' $f.TotalMilliseconds 'Loop Filter w/ .ToArray() Method' $f2.TotalMilliseconds
#endregion

#region Get-ChildItem
#Path
$p = Measure-Command {
    Get-ChildItem c:\windows\inf\*.ini
}

#Filter
$f = Measure-Command {
    Get-ChildItem c:\windows\inf –Filter *.ini
}
Get-Winner 'Path' $p.TotalMilliseconds 'Filter' $f.TotalMilliseconds
#endregion

#region Classes
$co = Measure-Command {
    $x = 0
    ForEach ( $i in 1..5000000 )
    {
        $x = $x + 1
    }
    $x
}

$cl = Measure-Command {
    class MyMath
    {
        static [int] CountRealHigh()
        {
        $x = 0
        ForEach ( $i in 1..5000000 )
        {
            $x = $x + 1
        }
            return $x
        }
    }
    [MyMath]::CountRealHigh() 
} 

Get-Winner 'Code' $co.TotalMilliseconds 'Class' $cl.TotalMilliseconds
#endregion
