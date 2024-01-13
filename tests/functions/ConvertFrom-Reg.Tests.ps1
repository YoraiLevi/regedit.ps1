param (
    [Parameter(Mandatory)]
    [string] $File
)
BeforeDiscovery { # <- this will run during Discovery
    Write-Host '-> Top-level BeforeDiscovery'

}
BeforeAll {
    Write-Host '-> Top-level BeforeAll'
}

Describe 'd' {
    BeforeAll {
        Write-Host '-> Describe BeforeAll'
    }

    BeforeEach {
        Write-Host '-> Describe BeforeEach'
    }

    Context 'Whitespace' {
        BeforeAll {
            Write-Host '-> Context BeforeAll'
        }

        BeforeEach {
            Write-Host '-> Context BeforeEach'
        }

        It 'i' {
            # ...
        }

        AfterEach {
            Write-Host '-> Context AfterEach'
        }

        AfterAll {
            Write-Host '-> Context AfterAll'
        }
    }

    AfterEach {
        Write-Host '-> Describe AfterEach'
    }

    AfterAll {
        Write-Host '-> Describe AfterAll'
    }
}

AfterAll {
    Write-Host '-> Top-level AfterAll'
}







# BeforeAll {
#     # $content = Get-Content $File
# }




# Describe "File - <file>" {
#     BeforeEach {}
#     AfterEach {}
#     Context "Whitespace" {
#         It "There is no extra whitespace following a line" {
#             # ...
#         }

#         It "File ends with an empty line" {
#             # ...
#         }
#     }
# }


# BeforeAll {
#     Import-Module (Join-Path $PSScriptRoot '..' Get-TestResources) -Force
#     Import-Module $PSCommandPath.Replace('tests', 'regedit').Replace('.Tests.ps1', '') -Force
#     Install-Module PesterMatchHashtable
#     $Resources = Get-TestResources
# }
# AfterAll {
#     Remove-Module Get-TestResources -Force
#     Remove-Module (Split-Path $PSCommandPath -Leaf).Replace('.Tests.ps1', '') -Force
# }

# Describe 'ConvertFrom-Reg' {
#     It 'Convert reg file contents empty' {
#         $Resource = $Resources['Empty.reg']
#         $Result = [ordered]@{}
#         Get-Content $Resource | ConvertFrom-Reg | Should -MatchHashtable  $Result
#     }
# }
