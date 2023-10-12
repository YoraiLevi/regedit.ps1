function Test-RegistryKey {
    # Check if registry key exists or not
    [CmdletBinding(DefaultParameterSetName = 'LiteralPath')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Path')]
        [string]$Path,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'LiteralPath', Position = 0)]
        [string]$LiteralPath,
        [switch]$LoadPSDrive
    )
    begin {
        $HivesDriveRoot = Get-HivesDriveRoot
    }
    process {
        $Path = switch ($PsCmdlet.ParameterSetName) {
            'Path' {
                $Path
            }
            'LiteralPath' {
                $LiteralPath
            }
        
        }
        $PSDrive = Split-Path -Path $Path -Qualifier
        if (!$PSDrive -in $HivesDriveRoot.Keys) {
            throw "Registry drive '$PSDrive' is not supported"
        }
        if ($LoadPSDrive) {
            Initialize-HiveDrive -Path $Path | Out-Null
        }
        Write-Debug "$($MyInvocation.InvocationName): Testing $Path"
        switch ($PsCmdlet.ParameterSetName) {
            'Path' {
                Test-Path -Path $Path
            }
            'LiteralPath' {
                Test-Path -LiteralPath $Path
            }
        
        }
    }
    end {}
}