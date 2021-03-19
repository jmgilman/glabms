@{
    bootstrap = @{
        url  = 'https://github.com/jmgilman/glabms/archive/main.zip'
        path = 'glabms-main\choco\bootstrap.ps1'
    }
    choco     = @{
        package_name = 'chocolatey'
    }
    mount     = @{
        address = '\\nas.gilman.io'
        share   = 'Software'
    }
    nuget     = @{
        url       = 'https://aka.ms/psget-nugetexe'
        file_name = 'nuget.exe'
    }
    proget    = @{
        server    = 'http://proget.gilman.io:8624'
        file_name = 'proget.zip'
        feeds     = @{
            posh  = 'internal-powershell'
            choco = 'internal-chocolatey'
        }
    }
    provider  = @{
        name      = 'NuGet'
        file_name = 'nuget.zip'
        version   = '2.8.5.201'
    }
    sql       = @{
        file_name = 'sql.zip'
    }
}