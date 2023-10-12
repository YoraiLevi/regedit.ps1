function Test-Reg {
    # Tests if registry corresponds to reg file
    [CmdletBinding(DefaultParameterSetName = 'LiteralPath')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [string[]]$Path,
        [Parameter(Mandatory = $true, ParameterSetName = 'LiteralPath', Position = 0)]
        [string[]]$LiteralPath,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
        [psobject[]]$InputObject
    )
    begin {}
    process {
        switch ($PsCmdlet.ParameterSetName) {
            'Path' {
                Import-Reg -Path $Path | Test-Registry
            }
            'LiteralPath' {
                Import-Reg -LiteralPath $LiteralPath | Test-Registry
            }
            'Pipeline' {
                $InputObject | Import-Reg | Test-Registry
            }
        
        }
    }
    end {}
}