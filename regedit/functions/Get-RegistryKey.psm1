function Get-RegistryKey {
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
        try {
            Write-Debug "$($MyInvocation.InvocationName): Getting $Path"
            switch ($PsCmdlet.ParameterSetName) {
                'Path' {
                    Get-Item -Path $Path
                }
                'LiteralPath' {
                    Get-Item -LiteralPath $Path
                }
            
            }
        }
        catch {
            Write-Debug "$($MyInvocation.InvocationName): Failed to get $Path with error: $($PSItem.Exception.Message)"
            if ($PSItem.Exception.Message -like '*Cannot find path*because it does not exist.*') {
                Write-Debug "$($MyInvocation.InvocationName): $Path does not exist, return Null"
                return $null
            }
            else {
                Write-Debug "$($MyInvocation.InvocationName): unhandled error getting $Path rethrowing $($PSItem.Exception.Message))"
                throw $PSItem
            }
        }
    }
    end {}
}