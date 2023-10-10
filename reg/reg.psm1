
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
function Export-Reg {
    # TODO
    # accepts the output of import regfile and reproduces the reg file back
    # exports registry object into reg file, saves file.
    # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/export-csv?view=powershell-7.3
    # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/export-csv?view=powershell-5.1

}
function ConvertFrom-Reg {
    # ConvertFrom-Reg $FilePath
    # Get-Content $FilePath | ConvertFrom-Reg 
    # Get-Content $FilePath -Raw | ConvertFrom-Reg -NoEnumerate
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]$InputObject,
        [switch]$NoEnumerate
    )
    begin {
        Write-Debug '###############################################################################################'
        $PathPattern = '^\[(?<RemoveKey>-)?(?<Path>.*)\]$'
        $ValuePattern = '^(?:(?:\"(?<Name>.*)\")|(?:((?<Name>\@))))\s*=\s*(?:(?:\"(?<Data>.*)\")|(?:(?<Type>.*):(?<Data>.*))|(?<RemoveKey>-))$'
        $IfPattern = '^\s*IF\s+(?<EnviromentVariable>\S*)(?:\s*=\s*(?<EnviromentVariableValue>\S*)\s*)*(?:\s*(?<Not>\s!)\s*)*$'
        $EndIfPattern = 'ENDIF'
        # $CommentPattern = '^\s*;.*$'
        # function Escape-String {
        #     param(
        #         [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        #         $String
        #     )
        #     process {
        #         $String -replace "`0", '`0' -replace '"', '`"' -replace "`a", '`a' -replace "`b", '`b' -replace "`f", '`f' -replace "`n", '`n' -replace "`r", '`r' -replace "`t", '`t' -replace "`v", '`v' -replace '\$', '`$'
        #     }
        # }
        # function JoinFromPipe-Array {
        #     param(
        #         $Separator = ','
        #     )
        #     @($input) -join $Separator
        # }
        $Types = @{
            # 'REG_SZ' = 'String'
            # 'REG_DWORD' = 'DWord'
            # 'REG_MULTI_SZ' = 'MultiString'
            # 'REG_BINARY' = 'Binary'
            'String' = 'String'
            'hex'    = 'Binary'
            'dword'  = 'DWord'
            'hex(b)' = 'QWord'
            'hex(7)' = 'MultiString'
            'hex(2)' = 'ExpandString'
            'hex(0)' = 'None'
        }
        $DataConversions = @{
            ''             = { param($Data) $null } # RemoveKey
            'String'       = { param($Data) $($Data -replace '\\(.)', '$1') } 
            'Binary'       = { param($Data) if ($Data -eq '') { $null } else { $(($Data -split ',' -ne '' | ForEach-Object { [CONVERT]::ToByte($_, 16) })) } }
            'DWord'        = { param($Data) [Convert]::ToUInt32($Data, 16) }
            'QWord'        = { param($Data) [BitConverter]::ToUInt64(($Data -split ',' | ForEach-Object { [CONVERT]::ToByte($_, 16) }), 0) }
            'MultiString'  = { param($Data) $([System.Text.Encoding]::Unicode.GetString(($Data -split ',' | ForEach-Object { [CONVERT]::ToByte($_, 16) })) -replace "`0$" <# Remove Array termination null, before: String1`0String2`0`0 after String1`0String2`0 #> -split "`0" | Select-Object -SkipLast 1 <# Remove eftover null character #> ) }
            'ExpandString' = { param($Data) $([System.Text.Encoding]::Unicode.GetString(($Data -split ',' | ForEach-Object { [CONVERT]::ToByte($_, 16) })) -replace "`0$") }
            'None'         = { param($Data) $null }
        }
        $Path = $null
        $Name = $null
        $Data = $null
        $Type = $null
        $Line = $null
        $output = [ordered]@{}
    }
    Process {
        # TODO: Implement if statements support
        <#
        Terminilogy based on https://learn.microsoft.com/en-us/windows/win32/sysinfo/structure-of-the-registry
        #Specification https://learn.microsoft.com/en-us/previous-versions/windows/embedded/gg469889(v=winembedded.80)
        # https://docs.fileformat.com/executable/reg/
        # https://www.wikiwand.com/en/Windows_Registry#.REG_files
        {
            KeyPath OR EnvironmentVariable = {
                Type = IF, IFNOT, Key
                Present = $true $false
                Values = {
                    ValueName = {
                        Data = *
                        Type = 'String' 'Binary' 'DWord' 'QWord' 'MultiString' 'ExpandString' 'None' if $null it is a removal
                    }
                }
            }
        }
        #>
        
        $(if ($NoEnumerate) { $InputObject -split '\r?\n' }else { $InputObject }) | ForEach-Object {
            if (($null -ne $Line) -or ($_ -match ',\\$')) {
                # More data on the next line
                $Line = if ($null -eq $Line) { '' } else { $Line }
                $Line = $Line + ($_ -replace '\\$', '').Trim()
                if ($_ -match ',\\$') {
                    return # this is a continue
                }
            }
            else {
                $Line = $_.Trim()
            }
            if ($Line -match $PathPattern) {
                $Path = $Matches.Path; foreach ($DriveRoot in (Get-HivesDriveRoot).GetEnumerator()) { $Path = $Path -replace "^$($DriveRoot.Value)", $DriveRoot.Key }
                $Present = !$Matches.RemoveKey
                $RegistryKey = @{
                    $Type   = 'Key'
                    Present = $Present
                    Values  = [ordered]@{}
                }
                $output[$Path] = $RegistryKey
                Write-Debug "$($MyInvocation.InvocationName): $Line was Decoded into Key '$Path' Present: '$Present'"
            }
            elseif ($Line -match $ValuePattern) {
                $Name = if ($Matches.Name -eq '@') { '' } else { $Matches.Name }
                $MatchedType = if ($Matches.Type) { $Matches.Type } else { 'String' }
                $Type = if ($Matches.RemoveKey) { '' } else { $Types[$MatchedType] }
                $Data = &$DataConversions[$Type] -Data $Matches.Data
                
                $RegistryValue = @{
                    Data = $Data
                    Type = $Type
                }
                Write-Debug "$($MyInvocation.InvocationName): $Line was Decoded into Key: '$Path' Value: '$Name' Type: '$Type' Data: '$Data'"
                $output[$Path]['Values'][$Name] = $RegistryValue
            }
            elseif ($Line -match $IfPattern) {
                $Type = 'IF'
            }
            elseif ($Line -match $EndIfPattern) {
                $Type = 'ENDIF'
            }
            else {
                Write-Debug "$($MyInvocation.InvocationName): Skipped processing line: $Line, doesn't fit patterns"

            }
            $Name = $null
            $Data = $null
            $Type = $null
            $Line = $null
        }
    }
    end {
        Write-Debug '###############################################################################################'
        return $output
    }
}
function ConvertTo-Reg {
    # TODO convert back to reg file
    # Undo function for convertfrom-Reg
}
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
function Test-Registry {
    # Import-Reg $file.FullName | Test-Registry -Verbose
    [CmdletBinding(DefaultParameterSetName = 'Registry')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Registry', Position = 0)]
        [System.Collections.Specialized.OrderedDictionary]$Registry,
        [switch]$LoadPSDrive
    )
    begin {}
    process {
        $output = $Registry.GetEnumerator() | ForEach-Object {
            $Path = $_.Key
            $Present = $_.Value.Present
            $Values = $_.Value.Values
            $Item = Get-RegistryKey -LiteralPath $Path -LoadPSDrive:$LoadPSDrive # -ErrorAction SilentlyContinue
            if ($Present -and $null -eq $Item) {
                Write-Debug "$($MyInvocation.InvocationName): $Path Expected to exist but it does not, returning $false"
                return $false
            }
            elseif (!$Present -and $null -ne $Item) {
                Write-Debug "$($MyInvocation.InvocationName): $Path Expected to not exist but it does, returning $false"
                return $false
            }
            else {
                $TestedKeyValues = $Values.GetEnumerator() | ForEach-Object {
                    $Name = $_.Key
                    $Data = $_.Value.Data
                    $Type = $_.Value.Type
                    $KeyValueTest = Test-RegistryKeyValue -Item $Item -Name $Name -Type $Type -Value $Data
                    if (!$KeyValueTest) {
                        Write-Debug "$($MyInvocation.InvocationName): $Path`:$Name Expected to be of Type '$Type`' with Data '$Data' but it is not or doesn't exist, returning $false"
                        return $false
                    }
                }
                return !($TestedKeyValues -contains $false)
            }
        }
        return !($output -contains $false)
    }
    end {}
}
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
function Get-HivesDriveRoot {
    $HivesDriveRoot = @{
        'HKCR:' = 'HKEY_CLASSES_ROOT'
        'HKCU:' = 'HKEY_CURRENT_USER'
        'HKLM:' = 'HKEY_LOCAL_MACHINE'
        'HKU:'  = 'HKEY_USERS'
        'HKCC:' = 'HKEY_CURRENT_CONFIG'
    }
    return $HivesDriveRoot
}
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
