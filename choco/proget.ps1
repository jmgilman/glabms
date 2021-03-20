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
   .\proget.ps1 -ConfigFile .\choco\config.psd1 -License mylicensekey
.NOTES
    Name: proget.ps1
    Author: Joshua Gilman (@jmgilman)
#>

# Parameters
param(
    [Parameter(
        Mandatory = $false,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 1
    )]
    [ValidateSet('ProGet', 'SQL')]
    [string]  $Install,
    [Parameter(
        Mandatory = $false,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 2
    )]
    [switch]  $Configure,
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 3
    )]
    [string]  $ConfigFile,
    [Parameter(
        Mandatory = $false,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 4
    )]
    [string]  $License,
    [Parameter(
        Mandatory = $false,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 5
    )]
    [string]  $ApiKey
)

function Install-SQL {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [string]  $FileFolder,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2
        )]
        [string]  $SqlFileName,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 3
        )]
        [string]  $SqlConfigFile,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 4
        )]
        [string]  $SqlExecutable
    )
    # Unzip SQL archive
    $sql_folder = Join-Path $FileFolder 'sql'
    Expand-Archive -Path (Join-Path $FileFolder $SqlFileName) -DestinationPath $sql_folder -Force

    # Run SQL installer
    $sql_installer_path = Join-Path $sql_folder $SqlExecutable
    $proc = Start-Process $sql_installer_path -ArgumentList "/ConfigurationFile=$SqlConfigFile", '/IAcceptSQLServerLicenseTerms' -PassThru -NoNewWindow -Wait
    return $proc.ExitCode -eq 0
}

function Install-ProGet {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [string]  $FileFolder,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2
        )]
        [string]  $ProGetFileName,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 3
        )]
        [string]  $ProGetExecutable,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 4
        )]
        [string]  $SqlInstance,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 5
        )]
        [string]  $License
    )
    # Unzip ProGet archive
    $proget_folder = Join-Path $FileFolder 'proget'
    Expand-Archive -Path (Join-Path $FileFolder $ProGetFileName) -DestinationPath $proget_folder -Force

    # Run ProGet installer
    $proget_installer_path = Join-Path $proget_folder $ProGetExecutable
    $proget_args = @('install', 
        'ProGet', 
        "--ConnectionString=`"Data Source=localhost\$SqlInstance; Integrated Security=True;`"",
        "--LicenseKey=$License")
    $proc = Start-Process $proget_installer_path -ArgumentList $proget_args -PassThru -NoNewWindow -Wait

    if ($proc.ExitCode -ne 0) {
        return $false
    }

    # Add firewall rule for ProGet web server
    New-NetFirewallRule -DisplayName 'ProGet Server' -Direction Inbound -LocalPort 8624 -Protocol TCP -Action Allow | Out-Null
    
    return $true
}

function Invoke-Api {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [string]  $ApiKey,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2
        )]
        [string]  $Endpoint,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 3
        )]
        [object[]]  $Data
    )
    $headers = @{
        'X-ApiKey' = $ApiKey
    }
    $params = @{
        Method      = 'Post'
        Uri         = $Endpoint
        ContentType = 'application/json'
        Headers     = $headers
        Body        = ($Data | ConvertTo-Json)
    }
    Invoke-RestMethod @params
}

# Don't let the script continue with errors
$ErrorActionPreference = 'Stop'

$CONFIG = Import-PowerShellDataFile $ConfigFile
$local_file_folder = Join-Path (Get-Location) 'files'
$sql_config_file = Join-Path $PSScriptRoot 'sql.ini'

# Check for files
if (!(Test-Path $local_file_folder)) {
    Write-Error 'Please run the download script before running this script'
    exit
}

switch ($Install) {
    'SQL' {
        # Install SQL Express
        $result = Install-SQL -FileFolder $local_file_folder -SqlFileName $CONFIG.sql.file_name -SqlConfigFile $sql_config_file -SqlExecutable $CONFIG.sql.executable
        if (!$result) {
            Write-Error 'Installation of SQL Express failed. Please check logs and try again.'
        }
        break
    }
    'ProGet' {
        # Determine SQL instance name
        [string](Get-Content -Path $sql_config_file) -match 'INSTANCENAME="(.*?)"'
        $sql_instance_name = $Matches[1]

        # Install ProGet
        $result = Install-ProGet -FileFolder $local_file_folder -ProGetFileName $CONFIG.proget.file_name -ProGetExecutable $CONFIG.proget.executable -SqlInstance $sql_instance_name -License $License
        if (!$result) {
            Write-Error 'Installation of ProGet failed. Please check the logs and try again.'
        
            # ProGet tends to leave artifacts behind, so we remove them just in case
            $proget_installer_path = Join-Path (Join-Path $local_file_folder 'proget') $ProGetExecutable
            Start-Process $proget_installer_path -ArgumentList 'uninstall', 'ProGet' -PassThru -NoNewWindow -Wait
            Exit
        }
        break
    }
}

if ($Configure) {
    # Check for API key
    if (!$PSBoundParameters.ContainsKey('ApiKey')) {
        Write-Error 'Please supply an API key to configure the ProGet server'
        exit
    }

    # Configure feeds
    $base_url = 'http://localhost:' + $CONFIG.proget.port + '/'
    $feeds_endpoint = $base_url + $CONFIG.proget.api.feeds_endpoint

    # Powershell feed
    $resp = Invoke-Api -ApiKey $ApiKey -Endpoint $feeds_endpoint -Data $CONFIG.proget.feeds.powershell

    # Chocolatey feed
    $resp = Invoke-Api -ApiKey $ApiKey -Endpoint $feeds_endpoint -Data $CONFIG.proget.feeds.chocolatey
}