function ConvertFrom-RegFile {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $FilePath,
        [System.Management.Automation.ActionPreference]$OutputErrorAction,
        [switch]$Force,

        [switch]$SkipDriveLoad,
        [switch]$SkipKeyExistCheck,
        
        [switch]$OnlyMergeRegFile,
        [switch]$OnlyValidateRegistry,
        
        [switch]$SkipPreValidation,
        [switch]$SkipPostValidation,

        # [Parameter(Mandatory = $true)]
        [string]$ValidationValueOutVariable = 'ValidationValueOutVariable',
        # [Parameter(Mandatory = $true)]
        [string]$ValidationTypeOutVariable = 'ValidationTypeOutVariable'

    )
    begin {
        if ($OnlyMergeRegFile) {
            $SkipPreValidation = $true
            $SkipPostValidation = $true
        }

        $UseForce = if ($Force) { '-Force' } else { '' }
        $UseRecurse = if ($Force) { '-Recurse' } else { '' }
        $UseVerbose = if ($Verbose) { } else { '| Out-Null' }
        $UserErrorAction = if ($OutputErrorAction) { "-ErrorAction '$OutputErrorAction'" } else { '' }

        $PathPattern = '^\[(?<RemoveKey>-)?(?<Path>.*)\]$'
        $ValuePattern = '^(?:(?:\"(?<Name>.*)\")|(?:((?<Name>\@))))\s*=\s*(?:(?:\"(?<Value>.*)\")|(?:(?<Type>.*):(?<Value>.*))|(?<RemoveKey>-))$'
        
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
            'String' = 'String'
            'hex'    = 'Binary'
            'dword'  = 'DWord'
            'hex(b)' = 'QWord'
            'hex(7)' = 'MultiString'
            'hex(2)' = 'ExpandString'
            'hex(0)' = 'None'
        }
        $ValuesConversion = @{
            'String' = { param($value) "`"$($Value -replace '\\(.)', '$1' | Escape-String)`"" } 
            'hex'    = { param($value) "@($(($Value -split ',' | ForEach-Object { if($_){'0x'+$_ }}) -join ','))" }
            'dword'  = { param($value) [Convert]::ToUInt32($Value, 16) }
            'hex(b)' = { param($value) [BitConverter]::ToUInt64(($Value -split ',' | ForEach-Object { [CONVERT]::ToByte($_, 16) }), 0) }
            'hex(7)' = { param($value) if ($value -eq '00,00') { '$null' } else { "`"$([System.Text.Encoding]::Unicode.GetString(($Value -split ',' | ForEach-Object { [CONVERT]::ToByte($_, 16) })) -replace "`0{2}$" | Escape-String)`"" } }
            'hex(2)' = { param($value) "@($([System.Text.Encoding]::Unicode.GetString(($Value -split ',' | ForEach-Object { [CONVERT]::ToByte($_, 16) })) -replace "`0$" <# Remove Array termination null, before: String1`0String2`0`0 after String1`0String2`0 #> -split "`0" | Select-Object -SkipLast 1 <# Remove eftover null character #> | Escape-String | ForEach-Object{ '"'+$_+'"' } | JoinFromPipe-Array ','))" }
            'hex(0)' = { param($value) '([byte[]]@())' }
        }
        $RegistryDriveRoots = @{
            'HKCR:' = 'HKEY_CLASSES_ROOT'
            'HKCU:' = 'HKEY_CURRENT_USER'
            'HKLM:' = 'HKEY_LOCAL_MACHINE'
            'HKU:'  = 'HKEY_USERS'
            'HKCC:' = 'HKEY_CURRENT_CONFIG'
        }
        $RegistryDriveNames = @{
            'HKCR:' = 'HKCR'
            'HKCU:' = 'HKCU'
            'HKLM:' = 'HKLM'
            'HKU:'  = 'HKU'
            'HKCC:' = 'HKCC'
        }
    }
    Process {
        $Path = $null
        $Name = $null
        $Value = $null
        $Type = $null
        $Line = $null

        $RegistryValidation = @()
        $RegistryAssignment = @()

        Get-Content $FilePath | ForEach-Object {
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
                $Path = $Matches.Path -replace '^HKEY_CLASSES_ROOT', 'HKCR:' `
                    -replace '^HKEY_CURRENT_USER', 'HKCU:' `
                    -replace '^HKEY_LOCAL_MACHINE', 'HKLM:' `
                    -replace '^HKEY_USERS', 'HKU:' `
                    -replace '^HKEY_CURRENT_CONFIG', 'HKCC:'

                if ($SkipDriveLoad) {
                    $PSDrive = Split-Path -Path $Path -Qualifier
                    $RegistryAssignment += "if (!( '$PSDrive' | Test-Path)) { New-PSDrive -PSProvider Registry -Name '$($RegistryDriveNames[$PSDrive])' -Root '$($RegistryDriveRoots[$PSDrive]) $UserErrorAction' }"
                }
                if ($Matches.RemoveKey) {
                    $RegistryValidation = "try{'Expected registry key ''$($Matches.Path)'' to be missing but was found',(Get-Item -LiteralPath $Path -ErrorAction Stop) | Out-String | Write-Error }catch{if(!(`$PSItem.Exception.Message -like '*because it does not exist.*')){throw `$PSItem}}"
                    $RegistryAssignment += "Write-Error `"$($Line | Escape-String )`""
                    $RegistryAssignment += "Remove-Item -LiteralPath `'$Path`' $UseForce $UseRecurse $UserErrorAction $UseVerbose"
                }
                else {
                    $RegistryValidation += "`$RegistryKey = Get-Item -LiteralPath $Path -ErrorAction Stop"
                    $RegistryAssignment += "Write-Error `"$($Line | Escape-String )`""
                    $KeyActionString = "New-Item -Path `'$Path`' $UseForce $UserErrorAction $UseVerbose"
                    if (!$SkipKeyExistCheck) {
                        $RegistryAssignment += "if (!(Test-Path -LiteralPath `'$Path`')) { $KeyActionString }"
                    }
                    else {
                        $RegistryAssignment += $KeyActionString
                    }
                }
            }
            elseif ($Line -match $ValuePattern) {
                $Name = if ($Matches.Name -eq '@') { '(Default)' } else { $Matches.Name }
                $_Name = if ($Matches.Name -eq '@') { '' } else { $Matches.Name }
                $MatchedType = if ($Matches.Type) { $Matches.Type } else { 'String' }
                $Type = $Types[$MatchedType]
                $Value = &$ValuesConversion[$MatchedType] -Value $Matches.Value
                
                
                if ($Matches.RemoveKey) {
                    $RegistryValidation += "try{ 'Expected registry sub-key ''$($Matches.Name)'' to be missing but was found' , @{'Type'=`$RegistryKey.GetValueKind(`'$_Name`');'Value'=`$RegistryKey.GetValue(`'$_Name`')} | Out-String | Write-Error}catch{}"
                    if ($Matches.Name -eq '@') {
                        $RegistryAssignment += "Write-Error `"$($Line | Escape-String )`""
                        $RegistryAssignment += "(Get-Item -LiteralPath `'$Path`').OpenSubKey(`"`", `$true).DeleteValue(`"`") $UseForce $UserErrorAction $UseVerbose"
                    }
                    else {
                        $RegistryAssignment += "Write-Error `"$($Line | Escape-String )`""
                        $RegistryAssignment += "Remove-ItemProperty -LiteralPath `'$Path`' -Name `'$Name`' $UseForce $UserErrorAction $UseVerbose"
                    }
                }
                else {
                    $RegistryValidation += "if (!(!(Compare-Object @((`$RegistryKey.GetValueKind(`'$_Name`')) | Select-Object) @(`'$Type`' | Select-Object) -OutVariable `'$ValidationTypeOutVariable`') -and !(Compare-Object @((`$RegistryKey.GetValue(`'$_Name`')) | Select-Object) @($Value | Select-Object) -OutVariable `'$ValidationValueOutVariable`'))){ if(`$$ValidationTypeOutVariable){'Type are not Equal',`$$ValidationTypeOutVariable | Out-String | Write-Error};if(`$$ValidationValueOutVariable){'Values are not Equal',`$$ValidationValueOutVariable | Out-String | Write-Error} }"
                    $RegistryAssignment += "Write-Error `"$($Line | Escape-String )`""
                    $RegistryAssignment += "Set-ItemProperty -LiteralPath `'$Path`' -Name `'$Name`' -Value $Value -Type `'$Type`' $UseForce $UserErrorAction $UseVerbose"
                }
            }
            else {
                $RegistryAssignment += "# $Line"
            }
            $Name = $null
            $Value = $null
            $Type = $null
            $Line = $null
        }

        if (!$SkipPreValidation) {
            # Write-Output "try {"
            # Write-Output $RegistryValidation
            # Write-Output "} catch { Write-Warning Prevalidation Merge asserted that the system is in a different state than the registry file. }"
            # Write-Output ""
        }
        if (!$OnlyValidateRegistry) {
            Write-Output $RegistryAssignment
        }
        if (!$SkipPostValidation) {
            Write-Output '# Post Merge Validation'
            Write-Output $RegistryValidation
        }

        # Write-Host "echo Merged Registry Sucessfully"
    }
    end {}
}