<#
.Synopsis
   Downloads and copies all required files into the current working directory
   under the 'files' folder. 
.DESCRIPTION
   This script is intended to be run by a machine deployed within glab that has
   internet access. The script will download required files as well as copy
   required installation files from the given paths (see README for instructions).
.EXAMPLE
   .\download.ps1 -ProGetPath C:\path\to\proget -SqlPath C:\path\to\sql
.NOTES
    Name: download.ps1
    Author: Joshua Gilman (@jmgilman)
#>

# Parameters
param(
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 4
    )]
    [string]  $ProGetPath,
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 5
    )]
    [string]  $SqlPath
)

# Don't let the script continue with errors
$ErrorActionPreference = 'Stop'

# Modify the values below before running
$CONFIG = @{
    bootstrap = @{
        url  = 'https://github.com/jmgilman/glabms/archive/main.zip'
        path = 'glabms-main\choco\bootstrap.ps1'
    }
    nuget     = @{
        url       = 'https://aka.ms/psget-nugetexe'
        file_name = 'nuget.exe'
    }
    proget    = @{
        file_name = 'proget.zip'
    }
    provider  = @{
        name      = 'NuGet'
        version   = '2.8.5.201'
        file_name = 'nuget.zip'
    }
    sql       = @{
        file_name = 'sql.zip'
    }
}

# Do not edit
$PROVIDER_PATH = "$env:ProgramFiles\PackageManagement\ProviderAssemblies"

function Get-Provider {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [string]  $Name,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2
        )]
        [string]  $FileName,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 3
        )]
        [string]  $Version,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 4
        )]
        [string]  $Path
    )

    # Check if the provider is already installed on the local system
    $full_provider_path = Join-Path $PROVIDER_PATH "nuget\$Version"
    if (!(Test-Path $full_provider_path)) {
        Write-Verbose 'Installing the NuGet provider to the local machine...'
        Install-PackageProvider -Name $Name -RequiredVersion $Version -Force | Out-Null
    }

    # Copy the provider to the path
    Compress-Archive -Path (Join-Path $PROVIDER_PATH 'nuget') -DestinationPath (Join-Path $Path $FileName) -Force
}

function Get-NuGet {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [string]  $Url,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2
        )]
        [string]  $FileName,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 3
        )]
        [string]  $Path
    )
    # Download the NuGet executable to the path
    Invoke-WebRequest -Uri $Url -OutFile (Join-Path $Path $FileName)
}

function Get-Bootstrap {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [string]  $Url,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2
        )]
        [string]  $BootstrapPath,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2
        )]
        [string]  $Path
    )
    # Copy the bootstrap script to the path
    Copy-Item (Join-Path $PSScriptRoot 'bootstrap.ps1') $Path
}

function Get-ProGet {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [string]  $ProGetPath,
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
        [string]  $Path
    )
    # Archive ProGet installation files
    Compress-Archive -Path $ProGetPath -DestinationPath (Join-Path $Path $ProGetFileName)
}

function Get-Sql {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [string]  $SqlPath,
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
        [string]  $Path
    )
    # Archive SQL installer
    Compress-Archive -Path $SqlPath -DestinationPath (Join-Path $Path $SqlFileName)
}

$local_path = Join-Path (Get-Location) 'files'

# Check if local path exists
if (Test-Path $local_path) {
    # Delete all contents before downloading
    Remove-Item (Join-Path $local_path '*') -Recurse -Force
}
else {
    # Create path
    New-Item -ItemType Directory -Path $local_path -Force
}

Get-Provider -Name $CONFIG.provider.name -FileName $CONFIG.provider.file_name -Version $CONFIG.provider.version -Path $local_path
Get-NuGet -Url $CONFIG.nuget.url -FileName $CONFIG.nuget.file_name -Path $local_path
Get-Bootstrap -Url $CONFIG.bootstrap.url -BootstrapPath $CONFIG.bootstrap.path -Path $local_path

if ($PSBoundParameters.ContainsKey('ProGetPath')) {
    Get-ProGet -ProGetPath $ProGetPath -ProGetFileName $CONFIG.proget.file_name -Path $local_path
}

if ($PSBoundParameters.ContainsKey('SqlPath')) {
    Get-Sql -SqlPath $SqlPath -SqlFileName $CONFIG.sql.file_name -Path $local_path
}