BeforeAll {
    Import-Module $PSScriptRoot
}

# Using $script is a workaround for 
# https://github.com/PowerShell/PSScriptAnalyzer/issues/946

Describe 'New-TempFolder' {
    Context 'Create multiple folders' {
        BeforeAll {
            $script:folder1 = New-TempFolder -TempPath 'TestDrive:\'
            $script:folder2 = New-TempFolder -TempPath 'TestDrive:\'
        }
        It 'Creates the folders' {
            Test-Path $script:folder1 | Should -Be $true
            Test-Path $script:folder2 | Should -Be $true
        }
        It 'Aliases FullName to Path' {
            Get-Member -InputObject $script:folder1 -Name 'Path' -MemberType AliasProperty | 
                Should -Be $true
        }
        It 'Uses unique folder names for each folder' {
            $script:folder1 | Select-Object FullName |
                Should -Not -Be ($script:folder2 | 
                        Select-Object FullName)
        }
    }
}

Describe 'Install-Chocolatey' {
    Context 'Download fake file' {
        BeforeAll {
            Mock Invoke-WebRequest { 
                # Create a test powershell script
                New-Item -Path 'TestDrive:\tools' -ItemType Directory
                '"test"' | Out-File -FilePath 'TestDrive:\tools\chocolateyInstall.ps1' -Force

                # Compress it
                Compress-Archive -Path 'TestDrive:\tools' -DestinationPath 'TestDrive:\choco.zip'

                # Cleanup
                Remove-Item -Path 'TestDrive:\tools' -Force -Recurse -Confirm:$false
            }

            # Run the test
            $script:result = Install-Chocolatey -NuGetURL 'none' -TempFolder 'TestDrive:\'
        }
        It 'Downloads the zip archive' {
            Test-Path 'TestDrive:\choco.zip' | Should -Be $true
        }
        It 'Extracts the archive' {
            Test-Path 'TestDrive:\tools\chocolateyInstall.ps1' | Should -Be $true
        }
        It 'Runs the install script' {
            $result[1] | Should -Be 'test'
        }
    }
}