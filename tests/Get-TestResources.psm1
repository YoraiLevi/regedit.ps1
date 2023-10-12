Import-Module (Join-Path $PSScriptRoot 'common')
function Get-TestResources {
    $ResourcesFolder = (Join-Path $PSScriptRoot 'resources')
    $Resources = Get-ChildItem -Recurse $ResourcesFolder -File | ForEach-Object { $_.FullName } | ConvertTo-Hashtable { @{ ([System.IO.Path]::GetRelativePath($ResourcesFolder, $_)) = $_ } }
    return $Resources
}