<#

.SYNOPSIS

    Configures RSAT and Windows administrative management tools.



.DESCRIPTION

    Uses an embedded configuration definition to ensure that

    configured Windows RSAT capabilities and Windows Optional Features

    are Installed, Removed, or Ignored.



    Supports:

        Install

        Remove

        Ignore



    RSAT components are handled through:

        Get-WindowsCapability

        Add-WindowsCapability

        Remove-WindowsCapability



    Windows Optional Features such as Hyper-V Management Tools are handled

    separately through:

        Get-WindowsOptionalFeature

        Enable-WindowsOptionalFeature

        Disable-WindowsOptionalFeature



    Hyper-V management components can therefore be installed without

    enabling the Hyper-V platform itself.



.NOTES

    Intended for Windows 11 / Intune deployment.



    Run in 64-bit PowerShell as SYSTEM when deployed through Intune.



    Script version history

    -----------------------------------------------------------

    1.0     Mark Cattaneo       14-Sep-2026     Inital Build - untested



#>



param (

    [Parameter(Mandatory = $false)]

    [ValidateSet(

        "AllTools",

        "ActiveDirectory",

        "GPMC",

        "DHCP",

        "DFS",

        "DNS",

        "AzureStackHCI",

        "BitLocker",

        "CertificateServices",

        "FailoverClustering",

        "IPAM",

        "DataCenterBridging",

        "NetworkController",

        "NetworkLoadBalancing",

        "RemoteAccess",

        "RemoteDesktopServices",

        "ServerManager",

        "StorageMigrationService",

        "StorageReplica",

        "SystemInsights",

        "VolumeActivation",

        "WSUS",

        "HypervManagement"

    )]

    [string]$ToolsetSelection,



    [Parameter(Mandatory = $false)]

    [ValidateSet(

        "All",

        "SOE"

    )]

    [string]$RoleSelection

)



Set-StrictMode -Version 1

$LogfilePath = "c:\Windows\SOELogs"

$LogFileName = "Tools installer - $ToolsetSelection"

$LogFileExtension = ".log"

$Logfile = $LogfilePath + "\" + $LogFileName + $LogFileExtension





# Create the log directory if it doesn't exist

if (-not (Test-Path -Path $LogfilePath)) {

    New-Item -Path $LogfilePath -ItemType Directory -Force | Out-Null

}





#region the script functions





################## with truncation and colour validation #####################

function WriteLogEntry
{
    #ver 20260810



    param(

        [Parameter(Mandatory = $true)]

        [string]$LogText,



        [Parameter(Mandatory = $false)]

        [string]$AlternateLogPathandFile = $LogFile,



        [Parameter(Mandatory = $false)]

        [bool]$LogToBothLogFiles = $false,



        [Parameter(Mandatory = $false)]

        [ValidateSet("Black", "DarkBlue", "DarkGreen", "DarkCyan", "DarkRed", "DarkMagenta", "DarkYellow", "Gray", "DarkGray", "Blue", "Green", "Cyan", "Red", "Magenta", "Yellow", "White")][string]$TextColour = "White",



        [Parameter(Mandatory = $false)]

        [switch]$DontWriteToSTDOUTPUT,



        [Parameter(Mandatory = $false)]

        [switch]$ScreenOnly,



        [Parameter(Mandatory = $false)]

        [int]$MaxLogLines = 2000,



        [Parameter(Mandatory = $false)]

        [switch]$IntuneDetectMode

    )



    # Initialise second-chance buffer

    if (-not (Test-Path Variable:\GlobalMsgNotLogged))

    { $Global:GlobalMsgNotLogged = "" }



    try
    {

        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        $LogEntry = "$FormattedDate  $LogText"

       

        if ($IntuneDetectMode -or $Global:DetectOnly -eq $true)
        {

            # $DontWriteToSTDOUTPUT = $true

            $ScreenOnly = $true

        }



        if ($IntuneDetectMode)
        {

            # $DontWriteToSTDOUTPUT = $true

            $ScreenOnly = $true

        }



        if (-not $DontWriteToSTDOUTPUT)
        {

            Write-Host $LogEntry -ForegroundColor $TextColour

        }



        if ($ScreenOnly)
        {

            return

        }



        # Determine log targets

        $TargetFiles = @($AlternateLogPathandFile)



        if ($LogToBothLogFiles -and $LogFile -and ($LogFile -ne $AlternateLogPathandFile))
        {

            $TargetFiles += $LogFile

        }



        foreach ($File in ($TargetFiles | Select-Object -Unique))
        {



            # Create folder if required

            $Folder = Split-Path $File -Parent



            if ($Folder -and !(Test-Path $Folder))
            {

                New-Item -Path $Folder -ItemType Directory -Force | Out-Null

            }



            # Second-chance logging

            if ($Global:GlobalMsgNotLogged -ne "")
            {

                "$($Global:GlobalMsgNotLogged) (warning: previous log write failed)" |

                Out-File $File -Append -Encoding UTF8



                $Global:GlobalMsgNotLogged = ""

            }



            # Write current entry

            $LogEntry | Out-File $File -Append -Encoding UTF8



            # Optional truncation

            if ($MaxLogLines -gt 0)
            {

                $Content = Get-Content $File



                if ($Content.Count -gt $MaxLogLines)
                {

                    $KeepLines = $KeepLines = [Math]::Max([Math]::Floor($MaxLogLines * 0.9), 1)



                    $Content |

                    Select-Object -Last $KeepLines |

                    Set-Content $File -Encoding UTF8

                }

            }

        }

    }

    catch
    {

        # Don't let logging failures impact the script

        if ($LogEntry) { $Global:GlobalMsgNotLogged = $LogEntry }



        Write-Host "Error writing to log file: $LogEntry" -ForegroundColor Red

        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

        Write-Host "Error on line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red

        Write-Host "Target: $AlternateLogPathandFile" -ForegroundColor Red

    }

}



#######################################

Function StandardErrorHandler
{
    #ver 20260921



    param(

        [Parameter(Mandatory = $false)]

        [String]$AdditionalErrorText = ""

    )



    $ExceptionMsg = $_.Exception.Message

    $ExceptionType = $_.Exception.GetType().FullName

    $LineNumber = $_.InvocationInfo.ScriptLineNumber

    $CommandName = $_.InvocationInfo.MyCommand.Name

    $ErrorStatement = $_.InvocationInfo.Line

    $PositionMessage = $_.InvocationInfo.PositionMessage

    $CategoryInfo = $_.CategoryInfo

    $FullyQualifiedErrorId = $_.FullyQualifiedErrorId



    try
    {

        if ($AdditionalErrorText.Length -gt 0) {

            WriteLogEntry -LogText "Error: $AdditionalErrorText" -TextColour "red"

        }



        WriteLogEntry -LogText "Exception: $ExceptionMsg" -TextColour "red"

        WriteLogEntry -LogText "Exception Type: $ExceptionType" -TextColour "red"

        WriteLogEntry -LogText "Error on line: $LineNumber" -TextColour "red"



        if (![string]::IsNullOrWhiteSpace($CommandName)) {

            WriteLogEntry -LogText "Command: $CommandName" -TextColour "red"

        }



        if (![string]::IsNullOrWhiteSpace($ErrorStatement)) {

            WriteLogEntry -LogText "Statement: $($ErrorStatement.Trim())" -TextColour "red"

        }



        if (![string]::IsNullOrWhiteSpace($PositionMessage)) {

            WriteLogEntry -LogText "Position: $($PositionMessage.Trim())" -TextColour "red"

        }



        WriteLogEntry -LogText "Category: $CategoryInfo" -TextColour "red"

        WriteLogEntry -LogText "Error ID: $FullyQualifiedErrorId" -TextColour "red"

    }

    catch
    {

        # In case WriteLogEntry function is not defined yet or itself fails.

        Write-Host -Object "Function StandardErrorHandler falling back to 'Write-Host' instead of function 'WriteLogEntry' due to error." -ForegroundColor "yellow"



        if ($AdditionalErrorText.Length -gt 0) {

            Write-Host -Object "Error: $AdditionalErrorText" -ForegroundColor "red"

        }



        Write-Host -Object "Exception: $ExceptionMsg" -ForegroundColor "red"

        Write-Host -Object "Exception Type: $ExceptionType" -ForegroundColor "red"

        Write-Host -Object "Error on line: $LineNumber" -ForegroundColor "red"



        if (![string]::IsNullOrWhiteSpace($CommandName)) {

            Write-Host -Object "Command: $CommandName" -ForegroundColor "red"

        }



        if (![string]::IsNullOrWhiteSpace($ErrorStatement)) {

            Write-Host -Object "Statement: $($ErrorStatement.Trim())" -ForegroundColor "red"

        }



        if (![string]::IsNullOrWhiteSpace($PositionMessage)) {

            Write-Host -Object "Position: $($PositionMessage.Trim())" -ForegroundColor "red"

        }



        Write-Host -Object "Category: $CategoryInfo" -ForegroundColor "red"

        Write-Host -Object "Error ID: $FullyQualifiedErrorId" -ForegroundColor "red"

    }

}



#######################################

function Get-ScriptPathandName
{
    #ver 20180524

    #Get the script path and file name, or just the path



    param([Parameter(Mandatory = $false)][switch]$PathOnly = $false)



    If ($PathOnly -eq $false)

    { Return $MyInvocation.PSCommandPath }

    else

    { Return $PSScriptRoot }

}



#######################################

function Test-PendingReboot
{
    # 20260924 - needs testing

    $Reasons = @()



    if (

        Test-Path `

        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"

    )

    {

        $Reasons += "Component Based Servicing"

    }





    if (

        Test-Path `

        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"

    )

    {

        $Reasons += "Windows Update"

    }





    $PendingFileRenameOperations = (

        Get-ItemProperty `

        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `

        -Name PendingFileRenameOperations `

        -ErrorAction SilentlyContinue

    ).PendingFileRenameOperations





    if ($null -ne $PendingFileRenameOperations)
    {

        $Reasons += "Pending File Rename Operations"

    }





    [PSCustomObject]@{

        RebootPending = ($Reasons.Count -gt 0)

        Reasons       = @($Reasons)

    }

}



#######################################

function Resolve-Toolset
{

    param(

        [Parameter(Mandatory = $true)]

        [string]$Name,



        [Parameter(Mandatory = $false)]

        [string[]]$ResolutionStack = @()

    )





    # Prevent circular composite definitions



    if ($ResolutionStack -contains $Name)
    {

        throw (

            "Circular Toolset/CompositeToolset reference detected: " +

            (($ResolutionStack + $Name) -join " -> ")

        )

    }





    # Atomic Toolset



    if ($Config.Toolsets.PSObject.Properties.Name -contains $Name)
    {

        return @($Name)

    }





    # Composite Toolset



    if ($Config.CompositeToolsets.PSObject.Properties.Name -contains $Name)
    {

        $Resolved = @()



        $NewStack = @(

            $ResolutionStack

            $Name

        )





        foreach ($Member in @($Config.CompositeToolsets.$Name))
        {

            $Resolved += @(

                Resolve-Toolset `

                -Name $Member `

                -ResolutionStack $NewStack

            )

        }





        return @($Resolved)

    }





    throw "Unknown Toolset or CompositeToolset '$Name'."

}



#endregion the script functions







# ============== RUN CODE =====================



# Auto-detects if run as Intune custom detection script ...

$TestPath_IntuneDetection = "C:\Program Files (x86)\Microsoft Intune Management Extension\Content\DetectionScripts*"

if ($PSScriptRoot -like "$TestPath_IntuneDetection")

{ $Global:DetectOnly = $true; WriteLogEntry -LogText "Assuming run as Intune Custom Detection Script due to run path [$PSScriptRoot]. Set [`$Global:DetectOnly = `$true]" }

else

{ $Global:DetectOnly = $false; WriteLogEntry -LogText "Assuming not run as Intune Custom Detection Script." }



$thisHost = hostname

$LoggedOnUser = (Get-CimInstance -ClassName Win32_ComputerSystem).UserName



WriteLogEntry -LogText "######################"

WriteLogEntry -LogText "Starting script $(Get-ScriptPathandName) ..."

WriteLogEntry -LogText "HOSTNAME: $thisHost"

WriteLogEntry -LogText "USERNAME(runas): $env:USERNAME"

WriteLogEntry -LogText "USERNAME(logged in): $LoggedOnUser"



$lastModified = (Get-Item -Path $(Get-ScriptPathandName)).LastWriteTime

WriteLogEntry -LogText "Script last modified date: [$lastModified]" # can change to see that deployed package updates if this is updated.



if ([Environment]::Is64BitProcess)

{ WriteLogEntry -LogText "Running in 64-bit PowerShell" }

else

{ WriteLogEntry -LogText "Running in 32-bit PowerShell" }



### MAIN CODE GOES HERE...





if (

    [string]::IsNullOrWhiteSpace($ToolsetSelection) -and

    [string]::IsNullOrWhiteSpace($RoleSelection)

)
{

    WriteLogEntry -LogText "ERROR: At least one selection is required. Specify -ToolsetSelection, -RoleSelection, or both." -TextColour Red

    exit 1

}





WriteLogEntry -LogText "------------------------------------------------------------"

WriteLogEntry -LogText "Requested configuration"

WriteLogEntry -LogText "------------------------------------------------------------"



if (-not [string]::IsNullOrWhiteSpace($RoleSelection))
{

    WriteLogEntry -LogText "RoleSelection: $RoleSelection"

}

else
{

    WriteLogEntry -LogText "RoleSelection: <none>"

}



if (-not [string]::IsNullOrWhiteSpace($ToolsetSelection))
{

    WriteLogEntry -LogText "ToolsetSelection: $ToolsetSelection"

}

else
{

    WriteLogEntry -LogText "ToolsetSelection: <none>"

}





# ============================================================================

# Variables

# ============================================================================



$RestartRequired = $false

$ErrorsDetected = $false

$ChangesMade = $false





# ============================================================================

# Load configuration (Embedded JSON)

# ============================================================================



$JsonConfig = @"
{
    "Toolsets": {
        "ActiveDirectory": {
            "RSAT": [
                "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "GPMC": {
            "RSAT": [
                "Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "DHCP": {
            "RSAT": [
                "Rsat.DHCP.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "DFS": {
            "RSAT": [
                "Rsat.FileServices.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "DNS": {
            "RSAT": [
                "Rsat.Dns.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "AzureStackHCI": {
            "RSAT": [
                "Rsat.AzureStack.HCI.Management.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "BitLocker": {
            "RSAT": [
                "Rsat.BitLocker.Recovery.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "CertificateServices": {
            "RSAT": [
                "Rsat.CertificateServices.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "FailoverClustering": {
            "RSAT": [
                "Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "IPAM": {
            "RSAT": [
                "Rsat.IPAM.Client.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "DataCenterBridging": {
            "RSAT": [
                "Rsat.LLDP.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "NetworkController": {
            "RSAT": [
                "Rsat.NetworkController.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "NetworkLoadBalancing": {
            "RSAT": [
                "Rsat.NetworkLoadBalancing.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "RemoteAccess": {
            "RSAT": [
                "Rsat.RemoteAccess.Management.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "RemoteDesktopServices": {
            "RSAT": [
                "Rsat.RemoteDesktop.Services.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "ServerManager": {
            "RSAT": [
                "Rsat.ServerManager.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "StorageMigrationService": {
            "RSAT": [
                "Rsat.StorageMigrationService.Management.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "StorageReplica": {
            "RSAT": [
                "Rsat.StorageReplica.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "SystemInsights": {
            "RSAT": [
                "Rsat.SystemInsights.Management.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "VolumeActivation": {
            "RSAT": [
                "Rsat.VolumeActivation.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "WSUS": {
            "RSAT": [
                "Rsat.WSUS.Tools~~~~0.0.1.0"
            ],
            "WindowsFeatures": []
        },
        "HypervManagement": {
            "RSAT": [],
            "WindowsFeatures": [
                "Microsoft-Hyper-V-Management-Clients",
                "Microsoft-Hyper-V-Management-PowerShell"
            ]
        }
    },
    "CompositeToolsets": {
        "AllTools": [
            "ActiveDirectory",
            "GPMC",
            "DHCP",
            "DFS",
            "DNS",
            "AzureStackHCI",
            "BitLocker",
            "CertificateServices",
            "FailoverClustering",
            "IPAM",
            "DataCenterBridging",
            "NetworkController",
            "NetworkLoadBalancing",
            "RemoteAccess",
            "RemoteDesktopServices",
            "ServerManager",
            "StorageMigrationService",
            "StorageReplica",
            "SystemInsights",
            "VolumeActivation",
            "WSUS",
            "HypervManagement"
        ]
    },
    "Roles": {
        "All": [
            "AllTools"
        ],
        "XXXX": [
            "ActiveDirectory",
            "GPMC",
            "DHCP",
            "DFS",
            "DNS"
        ]
    },
    "Settings": {
        "AllowRestart": false,
        "VerifyAfterChanges": true,
        "IgnoreUnavailableComponents": true,
        "FailOnInstallationError": true
    }
}
"@

try
{

    $Config = $JsonConfig | ConvertFrom-Json -ErrorAction Stop

    WriteLogEntry `

    -LogText "Embedded JSON configuration loaded successfully." `

    -TextColour Green

}
catch
{

    StandardErrorHandler `

    -AdditionalErrorText "Unable to read embedded JSON configuration."



    exit 1

}









# ============================================================================

# Validate configuration structure

# ============================================================================



if ($null -eq $Config.Toolsets)
{

    WriteLogEntry `

    -LogText "ERROR: JSON configuration contains no Toolsets section." `

    -TextColour Red



    exit 1

}





if ($null -eq $Config.CompositeToolsets)
{

    WriteLogEntry `

    -LogText "ERROR: JSON configuration contains no CompositeToolsets section." `

    -TextColour Red



    exit 1

}





if ($null -eq $Config.Roles)
{

    WriteLogEntry `

    -LogText "ERROR: JSON configuration contains no Roles section." `

    -TextColour Red



    exit 1

}







# ============================================================================

# Validate requested selection exists in configuration

# ============================================================================



if (-not [string]::IsNullOrWhiteSpace($ToolsetSelection))
{

    $ToolsetExists =

    ($Config.Toolsets.PSObject.Properties.Name -contains $ToolsetSelection) -or

    ($Config.CompositeToolsets.PSObject.Properties.Name -contains $ToolsetSelection)



    if (-not $ToolsetExists)
    {

        WriteLogEntry `

        -LogText "ERROR: ToolsetSelection '$ToolsetSelection' was not found in Toolsets or CompositeToolsets." `

        -TextColour Red



        exit 1

    }

}





if (-not [string]::IsNullOrWhiteSpace($RoleSelection))
{

    if ($Config.Roles.PSObject.Properties.Name -notcontains $RoleSelection)
    {

        WriteLogEntry `

        -LogText "ERROR: RoleSelection '$RoleSelection' was not found in Roles." `

        -TextColour Red



        exit 1

    }

}





# ============================================================================

# Get settings

# ============================================================================



$AllowRestart = $false

$VerifyAfterChanges = $true

$IgnoreUnavailableComponents = $true

$FailOnInstallationError = $true





if ($null -ne $Config.Settings)
{

    if ($null -ne $Config.Settings.AllowRestart)
    {

        $AllowRestart = [bool]$Config.Settings.AllowRestart

    }



    if ($null -ne $Config.Settings.VerifyAfterChanges)
    {

        $VerifyAfterChanges =

        [bool]$Config.Settings.VerifyAfterChanges

    }



    if ($null -ne $Config.Settings.IgnoreUnavailableComponents)
    {

        $IgnoreUnavailableComponents =

        [bool]$Config.Settings.IgnoreUnavailableComponents

    }



    if ($null -ne $Config.Settings.FailOnInstallationError)
    {

        $FailOnInstallationError =

        [bool]$Config.Settings.FailOnInstallationError

    }

}





# ============================================================================

# Resolve Role and Toolset selections

# ============================================================================



WriteLogEntry -LogText "------------------------------------------------------------"

WriteLogEntry -LogText "Resolving requested Toolsets"

WriteLogEntry -LogText "------------------------------------------------------------"





$SelectedToolsets = @()





# Resolve Role



if (-not [string]::IsNullOrWhiteSpace($RoleSelection))
{

    WriteLogEntry `

    -LogText "Resolving Role [$RoleSelection]..."





    foreach ($RoleMember in @($Config.Roles.$RoleSelection))
    {

        WriteLogEntry `

        -LogText "Role [$RoleSelection] includes [$RoleMember]"



        try
        {

            $SelectedToolsets += @(

                Resolve-Toolset -Name $RoleMember

            )

        }

        catch
        {

            StandardErrorHandler `

            -AdditionalErrorText "Unable to resolve Role member [$RoleMember]"



            exit 1

        }

    }

}





# Resolve explicitly requested Toolset



if (-not [string]::IsNullOrWhiteSpace($ToolsetSelection))
{

    WriteLogEntry `

    -LogText "Resolving explicit Toolset selection [$ToolsetSelection]..."



    try
    {

        $SelectedToolsets += @(

            Resolve-Toolset -Name $ToolsetSelection

        )

    }

    catch
    {

        StandardErrorHandler `

        -AdditionalErrorText "Unable to resolve ToolsetSelection [$ToolsetSelection]"



        exit 1

    }

}





# Remove duplicate atomic Toolsets



$SelectedToolsets = @(

    $SelectedToolsets |

    Select-Object -Unique

)





if ($SelectedToolsets.Count -eq 0)
{

    WriteLogEntry `

    -LogText "ERROR: Selection resolved to zero Toolsets." `

    -TextColour Red



    exit 1

}





WriteLogEntry -LogText "Resolved atomic Toolsets:"



foreach ($Toolset in $SelectedToolsets)
{

    WriteLogEntry `

    -LogText "  - $Toolset" `

    -TextColour Cyan

}









# ============================================================================

# Resolve actual RSAT capabilities and Windows Optional Features

# ============================================================================



$SelectedRSAT = @()

$SelectedWindowsFeatures = @()





foreach ($Toolset in $SelectedToolsets)
{

    $ToolsetConfiguration = $Config.Toolsets.$Toolset





    if ($null -ne $ToolsetConfiguration.RSAT)
    {

        $SelectedRSAT += @(

            $ToolsetConfiguration.RSAT

        )

    }





    if ($null -ne $ToolsetConfiguration.WindowsFeatures)
    {

        $SelectedWindowsFeatures += @(

            $ToolsetConfiguration.WindowsFeatures

        )

    }

}





# Remove duplicates



$SelectedRSAT = @(

    $SelectedRSAT |

    Where-Object {

        -not [string]::IsNullOrWhiteSpace($_)

    } |

    Select-Object -Unique

)





$SelectedWindowsFeatures = @(

    $SelectedWindowsFeatures |

    Where-Object {

        -not [string]::IsNullOrWhiteSpace($_)

    } |

    Select-Object -Unique

)







WriteLogEntry -LogText "------------------------------------------------------------"

WriteLogEntry -LogText "Resolved RSAT capabilities: $($SelectedRSAT.Count)"

WriteLogEntry -LogText "------------------------------------------------------------"



foreach ($CapabilityName in $SelectedRSAT)
{

    WriteLogEntry -LogText "  - $CapabilityName"

}





WriteLogEntry -LogText "------------------------------------------------------------"

WriteLogEntry -LogText "Resolved Windows Features: $($SelectedWindowsFeatures.Count)"

WriteLogEntry -LogText "------------------------------------------------------------"



foreach ($FeatureName in $SelectedWindowsFeatures)
{

    WriteLogEntry -LogText "  - $FeatureName"

}





# ============================================================================

# Operating system information

# ============================================================================



try
{

    $OS = Get-CimInstance `

    -ClassName Win32_OperatingSystem `

    -ErrorAction Stop



    WriteLogEntry -LogText "Operating System: $($OS.Caption)"

    WriteLogEntry -LogText "Version: $($OS.Version)"

    WriteLogEntry -LogText "Build: $($OS.BuildNumber)"

}

catch
{

    StandardErrorHandler `

    -AdditionalErrorText "Unable to retrieve OS information"

}





# ============================================================================

# Discover RSAT capabilities

# ============================================================================



$AvailableRSAT = @()





if ($SelectedRSAT.Count -gt 0)
{

    WriteLogEntry `

    -LogText "Discovering available RSAT capabilities..."



    try
    {

        $AvailableRSAT = @(

            Get-WindowsCapability `

            -Online `

            -Name "Rsat.*" `

            -ErrorAction Stop

        )



        WriteLogEntry `

        -LogText "Discovered $($AvailableRSAT.Count) RSAT capabilities."

    }

    catch
    {

        StandardErrorHandler `

        -AdditionalErrorText "Unable to enumerate RSAT capabilities"



        exit 1

    }

}

else
{

    WriteLogEntry `

    -LogText "No RSAT capabilities selected. RSAT discovery not required."

}





# ============================================================================

# Process selected RSAT capabilities

# ============================================================================

if (-not $Global:DetectOnly)
{

WriteLogEntry -LogText "------------------------------------------------------------"

WriteLogEntry -LogText "Processing selected RSAT capabilities"

WriteLogEntry -LogText "------------------------------------------------------------"





foreach ($CapabilityName in $SelectedRSAT)
{

    WriteLogEntry -LogText "Processing: $CapabilityName"





    $Capability = @(

        $AvailableRSAT |

        Where-Object {

            $_.Name -eq $CapabilityName

        }

    )





    if ($Capability.Count -eq 0)
    {

        $Message =

        "Capability is not available on this Windows installation: " +

        $CapabilityName





        if ($IgnoreUnavailableComponents)
        {

            WriteLogEntry `

            -LogText "WARNING: $Message" `

            -TextColour Yellow



            continue

        }

        else
        {

            WriteLogEntry `

            -LogText "ERROR: $Message" `

            -TextColour Red



            $ErrorsDetected = $true



            continue

        }

    }





    # Ensure only a single matching capability is processed



    $Capability = $Capability |

    Select-Object -First 1





    WriteLogEntry `

    -LogText "Current state: $($Capability.State)"





    if ($Capability.State -eq "Installed")
    {

        WriteLogEntry `

        -LogText "$CapabilityName is already installed." `

        -TextColour Green



        continue

    }





    WriteLogEntry `

    -LogText "Installing $CapabilityName..." `

    -TextColour Cyan





    try
    {

        $Result = Add-WindowsCapability `

        -Online `

        -Name $CapabilityName `

        -ErrorAction Stop





        $ChangesMade = $true





        if ($Result.RestartNeeded)
        {

            $RestartRequired = $true



            WriteLogEntry `

            -LogText "WARNING: $CapabilityName requires a restart." `

            -TextColour Yellow

        }





        if ($VerifyAfterChanges)
        {

            $Verification = Get-WindowsCapability `

            -Online `

            -Name $CapabilityName `

            -ErrorAction Stop





            if ($Verification.State -eq "Installed")
            {

                WriteLogEntry `

                -LogText "$CapabilityName installed successfully." `

                -TextColour Green

            }

            else
            {

                WriteLogEntry `

                -LogText "ERROR: Verification failed for $CapabilityName. Current state: $($Verification.State)" `

                -TextColour Red



                $ErrorsDetected = $true

            }

        }

        else
        {

            WriteLogEntry `

            -LogText "$CapabilityName installation completed." `

            -TextColour Green

        }

    }

    catch
    {

        StandardErrorHandler `

        -AdditionalErrorText "Failed to install RSAT capability [$CapabilityName]"



        $ErrorsDetected = $true

    }

}





# ============================================================================

# Process selected Windows Optional Features

# ============================================================================



WriteLogEntry -LogText "------------------------------------------------------------"

WriteLogEntry -LogText "Processing selected Windows Optional Features"

WriteLogEntry -LogText "------------------------------------------------------------"





foreach ($FeatureName in $SelectedWindowsFeatures)
{

    WriteLogEntry -LogText "Processing: $FeatureName"





    try
    {

        $Feature = Get-WindowsOptionalFeature `

        -Online `

        -FeatureName $FeatureName `

        -ErrorAction Stop

    }

    catch
    {

        $Feature = $null

    }





    if ($null -eq $Feature)
    {

        $Message =

        "Windows Optional Feature is unavailable: $FeatureName"





        if ($IgnoreUnavailableComponents)
        {

            WriteLogEntry `

            -LogText "WARNING: $Message" `

            -TextColour Yellow



            continue

        }

        else
        {

            WriteLogEntry `

            -LogText "ERROR: $Message" `

            -TextColour Red



            $ErrorsDetected = $true



            continue

        }

    }





    WriteLogEntry `

    -LogText "Current state: $($Feature.State)"





    if ($Feature.State -eq "Enabled")
    {

        WriteLogEntry `

        -LogText "$FeatureName is already enabled." `

        -TextColour Green



        continue

    }





    if ($Feature.State -eq "EnablePending")
    {

        $RestartRequired = $true



        WriteLogEntry `

        -LogText "WARNING: $FeatureName is already pending enablement after restart." `

        -TextColour Yellow



        continue

    }





    WriteLogEntry `

    -LogText "Enabling $FeatureName..." `

    -TextColour Cyan





    try
    {

        $Result = Enable-WindowsOptionalFeature `

        -Online `

        -FeatureName $FeatureName `

        -NoRestart `

        -ErrorAction Stop





        $ChangesMade = $true





        if ($Result.RestartNeeded)
        {

            $RestartRequired = $true



            WriteLogEntry `

            -LogText "WARNING: $FeatureName requires a restart." `

            -TextColour Yellow

        }





        if ($VerifyAfterChanges)
        {

            $Verification = Get-WindowsOptionalFeature `

            -Online `

            -FeatureName $FeatureName `

            -ErrorAction Stop





            if ($Verification.State -eq "Enabled")
            {

                WriteLogEntry `

                -LogText "$FeatureName enabled successfully." `

                -TextColour Green

            }

            elseif ($Verification.State -eq "EnablePending")
            {

                $RestartRequired = $true



                WriteLogEntry `

                -LogText "WARNING: $FeatureName is pending enablement after restart." `

                -TextColour Yellow

            }

            else
            {

                WriteLogEntry `

                -LogText "ERROR: Verification failed for $FeatureName. Current state: $($Verification.State)" `

                -TextColour Red



                $ErrorsDetected = $true

            }

        }

        else
        {

            WriteLogEntry `

            -LogText "$FeatureName enable operation completed." `

            -TextColour Green

        }

    }

    catch
    {

        StandardErrorHandler `

        -AdditionalErrorText "Failed to enable Windows Optional Feature [$FeatureName]"



        $ErrorsDetected = $true

    }

}









}

# ============================================================================

# Final status of selected RSAT capabilities

# ============================================================================



WriteLogEntry -LogText "------------------------------------------------------------"

WriteLogEntry -LogText "Final selected RSAT status"

WriteLogEntry -LogText "------------------------------------------------------------"





foreach ($CapabilityName in $SelectedRSAT)
{

    try
    {

        $FinalCapability = Get-WindowsCapability `

        -Online `

        -Name $CapabilityName `

        -ErrorAction Stop



        WriteLogEntry (

            -LogText "{0} = {1}" -f $FinalCapability.Name, $FinalCapability.State

        )

    }

    catch
    {

        WriteLogEntry `

        -LogText "WARNING: Unable to retrieve final state for $CapabilityName" `

        -TextColour Yellow

    }

}







# ============================================================================

# Final status of selected Windows Features

# ============================================================================



WriteLogEntry -LogText "------------------------------------------------------------"

WriteLogEntry -LogText "Final selected Windows Feature status"

WriteLogEntry -LogText "------------------------------------------------------------"





foreach ($FeatureName in $SelectedWindowsFeatures)
{

    try
    {

        $FinalFeature = Get-WindowsOptionalFeature `

        -Online `

        -FeatureName $FeatureName `

        -ErrorAction Stop



        WriteLogEntry `

        -LogText "$($FinalFeature.FeatureName) = $($FinalFeature.State)"

    }

    catch
    {

        WriteLogEntry `

        -LogText "WARNING: Unable to retrieve final state for $FeatureName" `

        -TextColour Yellow

    }

}





# ============================================================================

# Summary

# ============================================================================



WriteLogEntry -LogText "============================================================"

WriteLogEntry -LogText "Deployment Summary"

WriteLogEntry -LogText "============================================================"



if (-not [string]::IsNullOrWhiteSpace($RoleSelection))
{

    WriteLogEntry -LogText "Role selection: $RoleSelection"

}

else
{

    WriteLogEntry -LogText "Role selection: <none>"

}





if (-not [string]::IsNullOrWhiteSpace($ToolsetSelection))
{

    WriteLogEntry -LogText "Toolset selection: $ToolsetSelection"

}

else
{

    WriteLogEntry -LogText "Toolset selection: <none>"

}





WriteLogEntry `

-LogText "Resolved Toolsets: $($SelectedToolsets -join ', ')"



WriteLogEntry `

-LogText "RSAT capabilities selected: $($SelectedRSAT.Count)"



WriteLogEntry `

-LogText "Windows Features selected: $($SelectedWindowsFeatures.Count)"



WriteLogEntry `

-LogText "Changes made: $ChangesMade"



WriteLogEntry `

-LogText "Restart required: $RestartRequired"



WriteLogEntry `

-LogText "Errors detected: $ErrorsDetected"







# ============================================================================

# Registry Tagging and Intune Detection

# ============================================================================



if (-not $Global:DetectOnly -and -not $ErrorsDetected)
{
    $RegPath = "HKLM:\SOFTWARE\CustomSOE\AdminTools"
    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }
    if (-not [string]::IsNullOrWhiteSpace($RoleSelection)) {
        Set-ItemProperty -Path $RegPath -Name "RoleSelection" -Value $RoleSelection -Force
    }
    if (-not [string]::IsNullOrWhiteSpace($ToolsetSelection)) {
        Set-ItemProperty -Path $RegPath -Name "ToolsetSelection" -Value $ToolsetSelection -Force
    }
    Set-ItemProperty -Path $RegPath -Name "LastInstallDate" -Value (Get-Date -Format "s") -Force

    WriteLogEntry -LogText "Registry tagging completed successfully at $RegPath" -TextColour Green
}

if ($Global:DetectOnly)
{
    WriteLogEntry -LogText "Performing Intune custom detection check..."
    $RegPath = "HKLM:\SOFTWARE\CustomSOE\AdminTools"
    $IsDetected = $false
    
    if (Test-Path $RegPath) {
        $RegRole = Get-ItemPropertyValue -Path $RegPath -Name "RoleSelection" -ErrorAction SilentlyContinue
        $RegToolset = Get-ItemPropertyValue -Path $RegPath -Name "ToolsetSelection" -ErrorAction SilentlyContinue
        
        # Verify components are actually installed
        $MissingComponents = $false
        
        foreach ($CapabilityName in $SelectedRSAT) {
            $Check = Get-WindowsCapability -Online -Name $CapabilityName -ErrorAction SilentlyContinue
            if ($Check.State -ne "Installed") {
                $MissingComponents = $true
                WriteLogEntry -LogText "Detection failed: Missing RSAT $CapabilityName" -TextColour Yellow
                break
            }
        }
        
        if (-not $MissingComponents) {
            foreach ($FeatureName in $SelectedWindowsFeatures) {
                $Check = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue
                if ($Check.State -ne "Enabled") {
                    $MissingComponents = $true
                    WriteLogEntry -LogText "Detection failed: Missing Windows Feature $FeatureName" -TextColour Yellow
                    break
                }
            }
        }
        
        if (-not $MissingComponents) {
            $IsDetected = $true
        }
    }
    
    if ($IsDetected) {
        Write-Host "Detected"
        exit 0
    } else {
        exit 1
    }
}


# ============================================================================

# Handle restart

# ============================================================================



if ($RestartRequired)
{

    WriteLogEntry `

    -LogText "WARNING: One or more components require a restart." `

    -TextColour Yellow





    if ($AllowRestart)
    {

        WriteLogEntry `

        -LogText "WARNING: Automatic restart permitted by configuration." `

        -TextColour Yellow



        Restart-Computer -Force



        exit 0

    }

    else
    {

        WriteLogEntry `

        -LogText "Automatic restart is disabled. Device will not be restarted by this script." `

        -TextColour Yellow



        # ERROR_SUCCESS_REBOOT_REQUIRED

        exit 3010

    }

}





WriteLogEntry -LogText "Completed script successfully." -TextColour Green



exit 0