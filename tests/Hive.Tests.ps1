param (
    [Parameter(Mandatory)]
    [string]$Path
)

BeforeAll {
    Write-Host "-> Top-level BeforeAll"
    # get reg files in hive
    $regfiles = @()
    # get list of tests per reg file
    $TestableFunction = @{}
    # gather testable functions expected return values
    $TestableFunctionExpected = @{}
}

Describe "Test Hive functionality" {
    BeforeAll {
        Write-Host "-> Describe BeforeAll"
    }

    BeforeEach {
        Write-Host "-> Describe BeforeEach"
    }

    Context "Whitespace" {
        BeforeAll {
            Write-Host "-> Context BeforeAll"
        }

        BeforeEach {
            Write-Host "-> Context BeforeEach"
        }

        It "i" {
            # ...
        }

        AfterEach {
            Write-Host "-> Context AfterEach"
        }

        AfterAll {
            Write-Host "-> Context AfterAll"
        }
    }

    AfterEach {
        Write-Host "-> Describe AfterEach"
    }

    AfterAll {
        Write-Host "-> Describe AfterAll"
    }
}

AfterAll {
    Write-Host "-> Top-level AfterAll"
}
