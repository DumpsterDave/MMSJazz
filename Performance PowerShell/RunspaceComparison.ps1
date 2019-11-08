<#
    Let's comapre the performance of a default runspace vs one with the bare essentials

    https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.runspacefactory.createrunspace?view=pscore-6.2.0
    http://www.codecodex.com/wiki/Calculate_digits_of_pi
#>

$Diet = Measure-Command {
    #Create a Diet Runspace (Empty InitialSessionState)
    #https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.runspacefactory.createrunspace?view=pscore-6.2.0#System_Management_Automation_Runspaces_RunspaceFactory_CreateRunspace_System_Management_Automation_Runspaces_InitialSessionState_
    #https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.initialsessionstate.create?view=pscore-6.2.0
    $DietSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::Create()
    $DietRunspace = [runspacefactory]::CreateRunspace($DietSessionState)
    $DietRunspace.Name = "Diet Runspace"
    $DietPowerShell = [PowerShell]::Create()
    $DietPowerShell.runspace = $DietRunspace
    $DietRunspace.Open()
    $DietRunspace.LanguageMode = [System.Management.Automation.PSLanguageMode]::FullLanguage
    [void]$DietPowerShell.AddScript({
        #Calculate 10,000 digits of pi
        $Places = 1000
        $Digits = ""
        [int]$Carry = 0
        $Array = [int[]]::new($Places + 1)
        for ($i = 0; $i -le $Places; $i++) {
            #Initialize the Array
            $Array[$i] = 2000
        }
        for ($i = $Places; $i -gt 0; $i-=14) {
            [int]$sum = 0
            for ($j = $i; $j -gt 0; --$j) {
                $sum = $sum * $j + 10000 * $Array[$j]
                $Array[$j] = $sum % ($j * 2 -1)
                $sum /= $j * 2 -1
            }
            $digit = [int]($carry + $sum / 10000)
            $Digits += $digit
            $carry = $sum % 10000
        }
        Write-Information -MessageData ($Digits.Insert(1, '.'))
    })
    $DietAsync = $DietPowerShell.Invoke()
    #$DietData = $DietPowerShell.EndInvoke($DietAsync)
}

#Create a default Runspace (Microsoft.PowerShell.DefaultHost)
#https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.runspaces.runspacefactory.createrunspace?view=pscore-6.2.0#System_Management_Automation_Runspaces_RunspaceFactory_CreateRunspace
$DefaultSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$DefaultRunspace = [runspacefactory]::CreateRunspace($DefaultSessionState)
$DefaultRunspace.Name = "Default Runspace"
$DefaultPowerShell = [PowerShell]::Create()
$DefaultPowerShell.runspace = $DefaultRunspace


$Default = Measure-Command {
    $DefaultRunspace.Open()
    [void]$DefaultPowerShell.AddScript({
        #Calculate 10,000 digits of pi
        $Places = 1000
        $Digits = ""
        [int]$Carry = 0
        $Array = [int[]]::new($Places + 1)
        for ($i = 0; $i -le $Places; $i++) {
            #Initialize the Array
            $Array[$i] = 2000
        }
        for ($i = $Places; $i -gt 0; $i-=14) {
            [int]$sum = 0
            for ($j = $i; $j -gt 0; --$j) {
                $sum = $sum * $j + 10000 * $Array[$j]
                $Array[$j] = $sum % ($j * 2 -1)
                $sum /= $j * 2 -1
            }
            $digit = [int]($carry + $sum / 10000)
            $Digits += $digit
            $carry = $sum % 10000
        }
        Write-Information -MessageData ($Digits.Insert(1, '.'))
    })
    $DefaultAsync = $DefaultPowerShell.BeginInvoke()
    $DefaultData = $DefaultPowerShell.EndInvoke($DefaultAsync)
}

Write-Host ([string]::Format("Default Runspace: {0}ms", $Default.TotalMilliseconds)) -ForegroundColor Cyan
Write-Host ([string]::Format("Diet Runspace:    {0}ms", $Diet.TotalMilliseconds)) -ForegroundColor Magenta

$DefaultPowerShell.Dispose()
$DietPowerShell.Dispose()