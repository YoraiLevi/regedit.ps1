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