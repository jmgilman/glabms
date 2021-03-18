Function New-TempFolder {
    <#
    .SYNOPSIS
        Creates a unique temporary folder on the local machine and returns it


    .NOTES
        Name: New-TempFolder
        Author: Joshua Gilman
        Version: 1.0
        DateCreated: 2021-03-15


    .EXAMPLE
        New-TempFolder | New-Item -Name "tempfile.txt"
    #>

    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string[]]  $TempPath = $Env:Temp
    )

    BEGIN {}

    PROCESS {
        $folder = New-Item -Type Directory -Path $(Join-Path $TempPath $(New-Guid))
        Add-Member -InputObject $folder -MemberType AliasProperty -Name Path -Value FullName
        
        $folder
    }

    END {}
}

Function Get-LatestNuGetPackage {
    <#
    .SYNOPSIS
        Queries a NuGet server for the latest version of a package and returns the source URL


    .NOTES
        Name: Get-LatestNuGetPackage
        Author: Joshua Gilman
        Version: 1.0
        DateCreated: 2021-03-13


    .EXAMPLE
        Get-LatestNuGetPackage -FeedURL "http://proget.my.domain/nuget/feed" -PackageName "mypackage"

    #>

    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string]  $FeedURL,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [string]  $PackageName
    )

    BEGIN {}

    PROCESS {
        $url = ($FeedURL.Trim('/'), "Packages()?\\`$filter=(Id%20eq%20%27$PackageName%27)%20and%20IsLatestVersion") -join '/'
        [xml]$res = Invoke-WebRequest -Uri $url -UseBasicParsing
        $res.feed.entry.content.src
    }

    END {}
}

Function Install-Chocolatey {
    <#
    .SYNOPSIS
        Downloads and installs Chocolatey from the given NuGet URL


    .NOTES
        Name: Install-Chocolatey
        Author: Joshua Gilman
        Version: 1.0
        DateCreated: 2021-03-13


    .EXAMPLE
        Install-Chocolatey -NuGetURL "http://proget.my.domain/nuget/feed/chocolatey/10.15.2" -TempFolder New-TempFolder

    #>

    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0
        )]
        [string]  $NuGetURL,
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1
        )]
        [string]  $TempFolder
    )

    BEGIN {}

    PROCESS {
        # Download the NuGet package
        $outFile = Join-Path $TempFolder 'choco.zip'
        Invoke-WebRequest -Uri $NuGetURL -OutFile $outFile

        # Unzip package
        Expand-Archive -Path $outFile -DestinationPath $TempFolder

        # Run install file
        $installFile = Join-Path $TempFolder 'tools' | Join-Path -ChildPath 'chocolateyInstall.ps1'

        & $installFile
    }

    END {}
}