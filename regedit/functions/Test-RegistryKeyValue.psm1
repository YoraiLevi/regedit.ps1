function Test-RegistryKeyValue {
    <# .EXAMPLE
    # -Value $Value -Type $Type
    # -Value $Value
    # -Type $Type
    # -Value $null

    # -Type $null
    # -isNotPreset

    # -Value $Value -Type $null ---invalid
    #>
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

        [nullable[Microsoft.Win32.RegistryValueKind]]$Type,
        [psobject]$Value,
        [switch]$isNotPreset,
        
        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'LiteralPath')]
        [switch]$LoadPSDrive

    )
    begin {
        if (('Value' -in $PSBoundParameters.Keys -or 'Type' -in $PSBoundParameters.Keys) -and $isNotPreset) {
            throw 'Value and Type are mutually exclusive with isNotPreset must be specified, not any of Value or Type and isNotPreset'
        }
        if ('Type' -in $PSBoundParameters.Keys -and $Type -eq '') {
            $isNotPreset = $true
        }
    }
    process {
        $RegistryKeyValue = switch ($PsCmdlet.ParameterSetName) {
            'Path' {
                Get-RegistryKeyValue -Path $Path -Name $Name -LoadPSDrive:$LoadPSDrive -Force
            }
            'LiteralPath' {
                Get-RegistryKeyValue -LiteralPath $LiteralPath -Name $Name -LoadPSDrive:$LoadPSDrive -Force
            }
            'Item' {
                Get-RegistryKeyValue -Item $Item -Name $Name -Force
            }
        }
        $RegistryKeyValueFullName = "$($RegistryKeyValue.Path)`:$($RegistryKeyValue.Name)"
        Write-Debug "$($MyInvocation.InvocationName): Testing $RegistryKeyValueFullName"
        $ExistingType = $RegistryKeyValue.Type
        $ExistingValue = $RegistryKeyValue.Value
        if ($ExistingType -eq '') {
            # Key doesn't exist.
            if (!$isNotPreset) {
                # That's not what we wanted
                Write-Debug "$($MyInvocation.InvocationName): $RegistryKeyValueFullName Expected to exist but it does not, returning $False"
                return $false
            }
            return $true
        }
        # Key exists for sure.
        if ($isNotPreset) {
            # That's not what we wanted
            Write-Debug "$($MyInvocation.InvocationName): $RegistryKeyValueFullName Expected to not exist but it does, returning $True"
            return $false
        }
        else {
            # Key exists, That's what we wanted
            # We care about the type
            if ('Type' -in $PSBoundParameters.Keys) {
                if ($ExistingType -ne $Type) {
                    Write-Debug "$($MyInvocation.InvocationName): $RegistryKeyValueFullName Expected to be of type $Type but it is of type $ExistingType, returning $False"
                    # early termination if type is not the same
                    return $false
                }
            }
            # We care about the value
            if ('Value' -in $PSBoundParameters.Keys) {
                # Keys always have a value, even if it's null. Compare-Object doesn't work with null values
                if ($null -eq $Value) {
                    Write-Debug "$($MyInvocation.InvocationName): Mismatched values, expected $RegistryKeyValueFullName to be `$null but it is not, returning $($ExistingValue -eq $Value)"
                    return ($ExistingValue -eq $Value)
                }
                elseif ($null -eq $ExistingValue) {
                    Write-Debug "$($MyInvocation.InvocationName): Mismatched values, expected $RegistryKeyValueFullName to be $Value but it is `$null, returning $($ExistingValue -eq $Value)"
                    return ($ExistingValue -eq $Value)
                }
                else {
                    # Both values are not null, compare them, if they are different, it's not ok
                    if ((Compare-Object $ExistingValue $Value -CaseSensitive -SyncWindow 0 -OutVariable 'compared')) {
                        Write-Information ("Mismatched values for $RegistryKeyValueFullName", $Compared | Out-String )
                        Write-Debug "$($MyInvocation.InvocationName): Mismatched values, expected $RegistryKeyValueFullName to be $Value but it is $ExistingValue, returning $False"
                        return $false
                    }
                }
            }
        }
        Write-Debug "$($MyInvocation.InvocationName): The value of $RegistryKeyValueFullName is as expected, returning $True"
        return $true
    }
    end {}
}