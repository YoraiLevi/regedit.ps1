function Merge-Registry {
    # Apply the registry object to the system
    [CmdletBinding(DefaultParameterSetName = 'Registry', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Registry', Position = 0)]
        [System.Collections.Specialized.OrderedDictionary]$Registry,
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
        $Registry.GetEnumerator() | ForEach-Object {
            $Path = $_.Key
            $Present = $_.Value.Present
            $Values = $_.Value.Values
            try {
                $Item = $null
                if ($PreMergeValidate) {
                    $Item = Get-RegistryKey -LiteralPath $Path -LoadPSDrive:$LoadPSDrive -ErrorAction Stop
                }
                if ($Present -and (!$PreMergeValidate -or ($null -eq $Item))) {
                    if ($PreMergeValidate) {
                        Write-Debug "$($MyInvocation.InvocationName): $Path Expected to exist but it does not, creating"
                    }
                    else {
                        Write-Debug "$($MyInvocation.InvocationName): $Path skipped validation, creating"
                    }
                    $Item = New-Item -Path $Path -Force -ErrorAction Stop
                    if ($PostMergeValidate) {
                        $Item = Get-RegistryKey -LiteralPath $Path -LoadPSDrive:$LoadPSDrive -ErrorAction SilentlyContinue
                        if ($null -eq $Item) {
                            Write-Debug "$($MyInvocation.InvocationName): $Path Post validating merge value FAILED!! Expected to exist but it does not"
                            Write-Error "Failed to create $Path"
                        }
                        else {
                            Write-Debug "$($MyInvocation.InvocationName): $Path Post validating merge value succeeded"
                        }
                    }
                }
                elseif (!$Present -and (!$PreMergeValidate -or ($null -ne $Item))) {
                    if ($PreMergeValidate) {
                        Write-Debug "$($MyInvocation.InvocationName): $Path Expected to not exist but it does, deleting"
                    }
                    else {
                        Write-Debug "$($MyInvocation.InvocationName): $Path skipped validation, deleting"
                    }
                    try {
                        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
                    }
                    catch {
                        if ($PSItem.Exception.Message -like '*Cannot find path*because it does not exist*') {}
                        elseif ($PSItem.Exception.Message -like '*Cannot delete a subkey tree because the subkey does not exist*') {}
                        else {
                            Write-Error $PSItem
                        }
                    }
                    if ($PostMergeValidate) {
                        $Item = Get-RegistryKey -LiteralPath $Path -LoadPSDrive:$LoadPSDrive -ErrorAction SilentlyContinue
                        if ($null -ne $Item) {
                            Write-Debug "$($MyInvocation.InvocationName): $Path Post validating merge value FAILED!! Expected to not exist but it does"
                            Write-Error "Failed to delete $Path"
                        }
                        else {
                            Write-Debug "$($MyInvocation.InvocationName): $Path Post validating merge value succeeded"
                        }
                    }
                }
            }
            catch {
                Write-Debug "$($MyInvocation.InvocationName): Failed to get $Path with error: $($PSItem.Exception.Message)"
                Write-Error $PSItem
                return
            }
            $Values.GetEnumerator() | ForEach-Object {
                $Name = $_.Key
                $Data = $_.Value.Data
                $Type = $_.Value.Type
                if ($PreMergeValidate) {
                    $KeyValueTest = Test-RegistryKeyValue -Item $Item -Name $Name -Type $Type -Value $Data
                }
                if (!$PreMergeValidate -or !$KeyValueTest) {
                    $TARGET = "Item: '$Path' Value: '$Name'"
                    if ($Type -eq '') {
                        $OPERATION = 'Remove Value'
                        if ($PreMergeValidate) {
                            Write-Debug "$($MyInvocation.InvocationName): $TARGET Expected to not exist but it does, deleting"
                        }
                        else {
                            Write-Debug "$($MyInvocation.InvocationName): $TARGET skipped validation, deleting"
                        }
                        if ($PSCmdlet.ShouldProcess($TARGET, $OPERATION)) {
                            try {
                                $Item.OpenSubKey('', $true).DeleteValue($Name)
                            }
                            catch {
                                if ($PSItem.Exception.Message -like '*No value exists with that name*') {}
                                else {
                                    Write-Error $PSItem
                                }
                            }
                        }
                    }
                    else {
                        $OPERATION = 'Set Value'
                        if ($PreMergeValidate) {
                            Write-Debug "$($MyInvocation.InvocationName): $TARGET Expected to be of Type '$Type`' with Data '$Data' but it is not or doesn't exist, setting"
                        }
                        else {
                            Write-Debug "$($MyInvocation.InvocationName): $TARGET skipped validation, setting value to Type '$Type`' with Data '$Data'"
                        }
                        $TARGET = $TARGET + " Type: '$Type' Data: '$Data'"
                        if ($PSCmdlet.ShouldProcess($TARGET, $OPERATION)) {
                            if ($null -eq $Data) {
                                if ($Type -in @('Binary', 'None')) {
                                    $Data = ([byte[]]@())
                                }
                                elseif ($Type -in @('ExpandString')) {
                                    $Data = ''
                                }
                                elseif ($Type -in @('MultiString')) {
                                    $Data = [string[]]@()
                                }
                            }
                            elseif ($Type -in @('Binary', 'None')) {
                                $Data = [byte[]]$Data
                            }
                            elseif ($Type -in @('ExpandString')) {
                                $Data = [string]$Data
                            }
                            elseif ($Type -in @('MultiString')) {
                                $Data = [string[]]$Data
                            }
                            $Item.OpenSubKey('', $true).SetValue($Name, $Data, $Type)
                        }
                    }
                }
                if ($PostMergeValidate) {
                    $KeyValueTest = Test-RegistryKeyValue -Item $Item -Name $Name -Type $Type -Value $Data
                    if (!$KeyValueTest) {
                        Write-Debug "$($MyInvocation.InvocationName): $TARGET Post validating merge value FAILED!! Expected to be of Type '$Type`' with Data '$Data' but it is not or doesn't exist"
                        Write-Error "Failed to set $Path`:$Name to Type '$Type' with Data '$Data'"
                    }
                    else {
                        Write-Debug "$($MyInvocation.InvocationName): $TARGET Post validating merge value succeeded"
                    }
                }
            }
        }
    }
    end {}
}