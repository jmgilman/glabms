<#
.Synopsis
   Facilitates downloading and uploading the files needed for bootstrapping a
   machine with Chocolatey
.DESCRIPTION
   This script is intended to be run by a machine deployed within glab that has
   internet access. The script should first be run with the 'Download' operation
   and pointed to a local path. Once the files have been downloaded, depending
   on network access, the script should be re-run with the 'Upload' operation
   and pointed to the SMB share that will host the bootstrap files. It may be
   necessary to transfer the files to an offline machine that has access to the
   desired SMB share.
   Note that the script expects local copies of the ProGet and SQL Express
   installation files to be present. Refer to the lab documentation on how to
   obtain these files.
.EXAMPLE
   .\setup.ps1 -Operation Download -Path C:\my\temp\path -ProGetPath C:\path\to\proget -SqlPath C:\path\to\sql.exe
   .\setup.ps1 -Operation Upload -Path C:\my\temp\path -MountPath \\my.nas.io\path
.NOTES
    Name: setup.ps1
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
    [ValidateSet('Download', 'Upload')]
    [string]  $Operation,
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 2
    )]
    [string]  $Path,
    [Parameter(
        Mandatory = $false,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 3
    )]
    [string]  $MountPath,
    [Parameter(
        Mandatory = $false,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        Position = 4
    )]
    [string]  $ProGetPath,
    [Parameter(
        Mandatory = $false,
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
        file_name = 'sql.exe'
    }
}

# Do not edit
$DRIVE_NAME = 'UPLOAD'
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
    # Download source to temporary folder
    $temp_folder = New-Item -Type Directory -Path $(Join-Path $Env:Temp $(New-Guid))
    Invoke-WebRequest -Uri $Url -OutFile (Join-Path $temp_folder 'glab.zip')

    # Extract archive
    Expand-Archive -Path (Join-Path $temp_folder 'glab.zip') -DestinationPath $temp_folder

    # Copy the bootstrap script to the path
    Copy-Item (Join-Path $temp_folder $BootstrapPath) $Path
}

function Get-ProGet {
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [string]  $ProGetFolder,
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
    Compress-Archive -Path $ProGetFolder -DestinationPath (Join-Path $Path $ProGetFileName)
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
    # Copy SQL installer
    Copy-Item $SqlPath (Join-Path $Path $SqlFileName)
}

function Submit-Files {
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
        [string]  $Path
    )

    # Connect to mount
    $cred = Get-Credential -Message "Enter credentials to connect to $MountPath..."
    New-PSDrive -Name $DRIVE_NAME -PSProvider 'FileSystem' -Root $MountPath -Credential $cred | Out-Null

    # Copy files
    Copy-Item -Path (Join-Path $Path '*') -Destination ($DRIVE_NAME + ':\') -Recurse

    # Disconnect from mount
    Remove-PSDrive -Name $DRIVE_NAME
}

switch ($Operation) {
    'Download' {
        Get-Provider -Name $CONFIG.provider.name -FileName $CONFIG.provider.file_name -Version $CONFIG.provider.version -Path $Path
        Get-NuGet -Url $CONFIG.nuget.url -FileName $CONFIG.nuget.file_name -Path $Path
        Get-Bootstrap -Url $CONFIG.bootstrap.url -BootstrapPath $CONFIG.bootstrap.path -Path $Path

        if ($PSBoundParameters.ContainsKey('ProGetPath')) {
            Get-ProGet -ProGetFolder $ProGetPath -ProGetFileName $CONFIG.proget.file_name -Path $Path
        }

        if ($PSBoundParameters.ContainsKey('SqlPath')) {
            Get-Sql -SqlPath $SqlPath -SqlFileName $CONFIG.sql.file_name -Path $Path
        }
        break
    }
    'Upload' {
        if (!$PSBoundParameters.ContainsKey('MountPath')) {
            Write-Error 'You must pass a MountPath when uploading files'
            exit
        }
        Submit-Files -MountPath $MountPath -Path $Path
        break
    }
}