<#
.Synopsis
   Downloads the NuGet provider and executable and uploads them to an SMB share
.DESCRIPTION
   This script is intended to be run by a machine deployed within glab that has
   internet access. It will download the Powershell NuGet provider and the NuGet
   executable and upload them to the configured SMB share. These files are
   required by the bootstrap script for bootstrapping offline machines with
   Chocolatey.
.EXAMPLE
   .\upload.ps1
.NOTES
    Name: upload.ps1
    Author: Joshua Gilman (@jmgilman)
#>

# Don't let the script continue with errors
$ErrorActionPreference = 'Stop'

# Modify the values below before running
$CONFIG = @{
    mount    = @{
        address = '\\nas.gilman.io'
        share   = 'Software'
    }
    nuget    = @{
        url       = 'https://aka.ms/psget-nugetexe'
        file_name = 'nuget.exe'
    }
    provider = @{
        name      = 'NuGet'
        version   = '2.8.5.201'
        file_name = 'nuget.zip'
    }
}

# Do not edit
$DRIVE_NAME = 'UPLOAD'
$DRIVE_PATH = $DRIVE_NAME + ':\'
$PROVIDER_PATH = "$env:ProgramFiles\PackageManagement\ProviderAssemblies"

# Need the user credentials to attach to the SMB share
$cred = Get-Credential -Message "Enter credentials to connect to $($CONFIG.mount.address)"
$mount_path = Join-Path -Path $CONFIG.mount.address -ChildPath $CONFIG.mount.share
New-PSDrive -Name $DRIVE_NAME -PSProvider 'FileSystem' -Root $mount_path -Credential $cred | Out-Null

# Install the provider on the local machine
Write-Verbose 'Installing the NuGet provider to the local machine...'
Install-PackageProvider -Name $CONFIG.provider.name -RequiredVersion $CONFIG.provider.version -Force | Out-Null

Write-Verbose 'Uploading the provider...'
$provider_local_path = Join-Path $PROVIDER_PATH 'nuget'
$provider_remote_path = Join-Path -Path $DRIVE_PATH -ChildPath $CONFIG.provider.file_name
Compress-Archive -Path $provider_local_path -DestinationPath $provider_remote_path -Force

Write-Verbose 'Uploading NuGet.exe...'
$nugetNASPath = Join-Path -Path $DRIVE_PATH -ChildPath $CONFIG.nuget.file_name
Invoke-WebRequest -Uri $CONFIG.nuget.url -OutFile $nugetNASPath

Write-Verbose 'Cleaning up...'
Remove-PSDrive -Name $DRIVE_NAME