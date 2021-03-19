<#
.Synopsis
   Downloads install files from SMB share and performs a fully silent
   installation and configuration of a ProGet server.
.DESCRIPTION
   This script is intended to be run by a machine deployed within glab that is
   desired to be configured as a ProGet server. This helper script will perform
   all of the necessary steps to fully install and configure a ProGet server
   on the local machine. The installation files should have already been
   uploaded to the given SMB path using the setup script. 
.EXAMPLE
   .\proget.ps1 -MountPath \\path\to\mount -License mylicensekey
.NOTES
    Name: proget.ps1
    Author: Joshua Gilman (@jmgilman)
#>

# Parameters
param(
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 1
    )]
    [string]  $MountPath,
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 2
    )]
    [string]  $License
)

# Don't let the script continue with errors
$ErrorActionPreference = 'Stop'

# Modify the values below before running
$CONFIG = @{
    proget = @{
        file_name = 'proget.zip'
    }
    sql    = @{
        file_name = 'sql.zip'
    }
}

# Do not edit
$DRIVE_NAME = 'PROGET'
$SQL_FOLDER = 'SQLEXPR_x64_ENU'
$SQL_EXE = 'SETUP.EXE'
$SQL_CONFIG = 'ConfigurationFile.ini'
$PROGET_FOLDER = 'proget'
$PROGET_EXE = 'hub.exe'

# Connect to mount
$cred = Get-Credential -Message "Enter credentials to connect to $MountPath..."
New-PSDrive -Name $DRIVE_NAME -PSProvider 'FileSystem' -Root $MountPath -Credential $cred | Out-Null

# Download the installation files
$temp_folder = New-Item -Type Directory -Path $(Join-Path $Env:Temp $(New-Guid))
Copy-Item (Join-Path ($DRIVE_NAME + ':') $CONFIG.proget.file_name) $temp_folder 
Copy-Item (Join-Path ($DRIVE_NAME + ':') $CONFIG.sql.file_name) $temp_folder

# Unzip SQL archive
Expand-Archive -Path (Join-Path $temp_folder $CONFIG.sql.file_name) -DestinationPath $temp_folder

# Run SQL installer
$sql_installer_path = Join-Path $temp_folder $SQL_FOLDER | Join-Path -ChildPath $SQL_EXE
$sql_config_path = Join-Path $temp_folder $SQL_FOLDER | Join-Path -ChildPath $SQL_CONFIG
$proc = Start-Process $sql_installer_path -ArgumentList "/ConfigurationFile=$sql_config_path", '/IAcceptSQLServerLicenseTerms' -PassThru -NoNewWindow -Wait

if ($proc.ExitCode -ne 0) {
    Write-Error 'Installation of SQL Express failed. Please check logs and try again.'
    Exit
}

# Unzip ProGet archive
Expand-Archive -Path (Join-Path $temp_folder $CONFIG.proget.file_name) -DestinationPath $temp_folder

# Determine SQL instance name
[string](Get-Content -Path $sql_config_path) -match 'INSTANCENAME="(.*?)"'
$sql_instance_name = $Matches[1]

# Run ProGet installer
$proget_installer_path = Join-Path $temp_folder $PROGET_FOLDER | Join-Path -ChildPath $PROGET_EXE
$proget_args = @('install', 
    'ProGet', 
    "--ConnectionString=`"Data Source=localhost\$SQL_INSTANCE_NAME; Integrated Security=True;`"",
    "--LicenseKey=$License")
$proc = Start-Process $proget_installer_path -ArgumentList $proget_args -PassThru -NoNewWindow -Wait

if ($proc.ExitCode -ne 0) {
    Write-Error 'Installation of ProGet failed. Please check logs and try again.'

    # ProGet tends to leave artifacts behind, so we remove them just in case
    Start-Process $proget_installer_path -ArgumentList 'uninstall', 'ProGet' -PassThru -NoNewWindow -Wait
    Exit
}

# Add firewall rule for ProGet web server
New-NetFirewallRule -DisplayName 'ProGet Server' -Direction Inbound -LocalPort 8624 -Protocol TCP -Action Allow | Out-Null

# Get API key
$api_key = Read-Host 'Please create an API key with all permissions and enter it here:' -AsSecureString

$base_url = 'http://localhost:8624'
$feed_endpoint = $base_url + '/api/management/feeds/create'
$headers = @{
    'X-ApiKey' = $api_key
}

# Add the Powershell feed
$request = @{
    name        = 'internal-powershell'
    feedType    = 'powershell'
    description = 'Internal Powershell feed for hosting modules'
    active      = $true
}

try {
    Invoke-RestMethod -Method Post -Uri $feed_endpoint -ContentType 'application/json' -Headers $headers -Body ($request | ConvertTo-Json)
}
catch {
    Write-Error "Failed creating Powershell feed: $($error[0])"
}

# Add the Chocolatey feed
$request = @{
    name        = 'internal-chocolatey'
    feedType    = 'chocolatey'
    description = 'Internal Chocolatey feed for hosting programs'
    active      = $true
}

try {
    Invoke-RestMethod -Method Post -Uri $feed_endpoint -ContentType 'application/json' -Headers $headers -Body ($request | ConvertTo-Json)
}
catch {
    Write-Error "Failed creating Chocolatey feed: $($error[0])"
}