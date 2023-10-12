BeforeAll {
    Import-Module (Join-Path $PSScriptRoot Get-TestResources) -Force
}
AfterAll {
    Remove-Module Get-TestResources -Force
}
Describe 'Sanity Check Pester' {
    It 'Verifies that Pester test passes' {
        $true | Should -Be $true
    }
}
Describe 'Check resources available' {
    It 'Verifies that resources are available' {
        Get-TestResources | Should -Not -BeNullOrEmpty
    }
}
