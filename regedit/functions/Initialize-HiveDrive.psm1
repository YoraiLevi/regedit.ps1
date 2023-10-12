function Initialize-HiveDrive {
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Path', ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Path', Position = 0)]
        [string]$Path,
        [switch]$Force
    )

    if ($Force -and -not $Confirm) {
        $ConfirmPreference = 'None'
    }
    $HivesDriveRoot = Get-HivesDriveRoot

    $PSDrive = Split-Path -Path $Path -Qualifier
    $PSDriveName = Split-Path -Path $Path -Qualifier -replace ':$'
    if ($PSDrive -in $HivesDriveRoot.Keys) {
        if (!( $PSDrive | Test-Path)) { 
            Write-Debug "$($MyInvocation.InvocationName): Couldn't find $PSDrive, initializing"
            New-PSDrive -PSProvider Registry -Name $PSDriveName -Root $($HivesDriveRoot[$PSDrive]) -Scope Script
        }
    }
    else {
        throw "Registry drive '$PSDrive' is not supported"
    }
}