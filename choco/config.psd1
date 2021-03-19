@{
    choco    = @{
        package_name = 'chocolatey'
    }
    nuget    = @{
        url       = 'https://aka.ms/psget-nugetexe'
        file_name = 'nuget.exe'
    }
    proget   = @{
        server     = 'http://proget.gilman.io:8624'
        file_name  = 'proget.zip'
        executable = 'hub.exe'
        feeds      = @{
            posh  = 'internal-powershell'
            choco = 'internal-chocolatey'
        }
    }
    provider = @{
        name      = 'NuGet'
        file_name = 'provider.zip'
        version   = '2.8.5.201'
        path      = 'PackageManagement\ProviderAssemblies'
    }
    sql      = @{
        file_name  = 'sql.zip'
        executable = 'SETUP.EXE'
    }
}