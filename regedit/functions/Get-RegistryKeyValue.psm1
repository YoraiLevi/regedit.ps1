function Get-RegistryKeyValue {
    # Check if registry key data exists or not and if it is the same as the arguments
    [CmdletBinding(DefaultParameterSetName = 'LiteralPath')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Path')]
        [string]$Path,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'LiteralPath', Position = 0)]
        [string]$LiteralPath,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Item', Position = 0)]
        [System.MarshalByRefObject]$Item,
        
        [AllowEmptyString()]
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'LiteralPath')]
        [switch]$LoadPSDrive,
        [switch]$Force

    )
    begin {}
    process {
        $Item = switch ($PsCmdlet.ParameterSetName) {
            'Path' {
                Get-RegistryKey -Path $Path -LoadPSDrive:$LoadPSDrive
            }
            'LiteralPath' {
                Get-RegistryKey -LiteralPath $LiteralPath -LoadPSDrive:$LoadPSDrive
            }
            'Item' {
                $Item
            }
        }
        if ($Item -isnot [System.MarshalByRefObject]) {
            throw 'Path provided is not a registry key'
        }
        $ExistingType = try { $Item.GetValueKind($Name) }catch { '' } #throws if no key exists, TODOnt better catch validation.
        $ExistingValue = $Item.GetValue($Name)
        Write-Debug "$($MyInvocation.InvocationName): $($Item.Name)`:$Name is of Type '$ExistingType' with Value '$ExistingValue'"
        if ($Force -or $ExistingType -ne '') {
            return @{Path = $Item.Name; Name = $Name; Type = $ExistingType; Value = $ExistingValue }
        }
    }
    end {}
}