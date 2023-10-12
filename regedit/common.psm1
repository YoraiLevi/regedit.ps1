function Escape-String {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $String
    )
    process {
        $String -replace "`0", '`0' -replace '"', '`"' -replace "`a", '`a' -replace "`b", '`b' -replace "`f", '`f' -replace "`n", '`n' -replace "`r", '`r' -replace "`t", '`t' -replace "`v", '`v' -replace '\$', '`$'
    }
}
function JoinFromPipe-Array {
    param(
        $Separator = ','
    )
    @($input) -join $Separator
}
