BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' Get-TestResources) -Force
    Import-Module $PSCommandPath.Replace('tests', 'regedit').Replace('.Tests.ps1', '') -Force
    Install-Module PesterMatchHashtable
    $Resources = Get-TestResources
}
AfterAll {
    Remove-Module Get-TestResources -Force
    Remove-Module (Split-Path $PSCommandPath -Leaf).Replace('.Tests.ps1', '') -Force
}

Describe 'ConvertFrom-Reg' {
    It 'Convert reg file contents empty' {
        $Resource = $Resources['Empty.reg']
        $Result = [ordered]@{}
        Get-Content $Resource | ConvertFrom-Reg | Should -MatchHashtable  $Result
    }
}
