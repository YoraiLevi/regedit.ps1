function Import-Reg {
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
                $Path | ForEach-Object { Get-Content -Path $_ | ConvertFrom-Reg }
            }
            'LiteralPath' {
                $LiteralPath | ForEach-Object { Get-Content -LiteralPath $_ | ConvertFrom-Reg }
            }
            'Pipeline' {
                $InputObject | Get-Content | ConvertFrom-Reg
            }

        }
    }
    end {}
}