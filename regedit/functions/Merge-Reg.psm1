function Merge-Reg {
    # Apply the regfile to the system
    [CmdletBinding(DefaultParameterSetName = 'LiteralPath', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [string[]]$Path,
        [Parameter(Mandatory = $true, ParameterSetName = 'LiteralPath', Position = 0)]
        [string[]]$LiteralPath,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
        [psobject[]]$InputObject,
        [switch]$LoadPSDrive,
        [switch]$PreMergeValidate,
        [switch]$PostMergeValidate,
        [switch]$Force
    )
    begin { 
        if ($Force -and -not $Confirm) {
            $ConfirmPreference = 'None'
        }
    }
    process {
        switch ($PsCmdlet.ParameterSetName) {
            'Path' {
                Import-Reg -Path $Path | Merge-Registry -LoadPSDrive:$LoadPSDrive -PreMergeValidate:$PreMergeValidate -PostMergeValidate:$PostMergeValidate
            }
            'LiteralPath' {
                Import-Reg -LiteralPath $LiteralPath | Merge-Registry -LoadPSDrive:$LoadPSDrive -PreMergeValidate:$PreMergeValidate -PostMergeValidate:$PostMergeValidate
            }
            'Pipeline' {
                $InputObject | Import-Reg | Merge-Registry -LoadPSDrive:$LoadPSDrive -PreMergeValidate:$PreMergeValidate -PostMergeValidate:$PostMergeValidate
            }
        }
    }
    end {}
}