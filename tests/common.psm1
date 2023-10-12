function ConvertTo-Hashtable {
    <#
    .LINK
    https://gist.github.com/YoraiLevi/292bb8d0e2ce0f87d37e5d5d735fff16

    .LINK
    https://stackoverflow.com/questions/77265408/powershell-array-to-hashtable-cannot-get-keys-value-with-bracket-notation-but-d

    .LINK
    https://peps.python.org/pep-0274/

    .SYNOPSIS
    Converts input objects into a hashtable.
    
    .DESCRIPTION
    The ConvertTo-Hashtable function converts input objects into a hashtable. It can be used to create a hashtable from an array of values or from pipeline input. The function takes a scriptblock that is used to generate the hashtable values. The scriptblock is executed for each input object and must output a single hashtable. The function can handle duplicate keys in the input objects and provides options for how to handle them.
    
    .PARAMETER ScriptBlock
    The scriptblock that is used to generate the hashtable values. The scriptblock is executed for each input object and must output a single hashtable.
    
    .PARAMETER InputArray
    An array of input objects to convert to a hashtable.
    
    .PARAMETER InputObject
    An input object to convert to a hashtable.
    
    .PARAMETER DuplicateKeyAction
    Specifies how to handle duplicate keys in the input objects. Valid values are 'Stop', 'Ignore', 'Overwrite', 'Append', and 'Prepend'. The default value is 'Stop'.
    
    .EXAMPLE
    ConvertTo-Hashtable 1, 2, 3
    
    Name                           Value
    ----                           -----
    3                              3
    2                              2
    1                              1
    
    .EXAMPLE
    1, 2, 3 | ConvertTo-Hashtable
    
    Name                           Value
    ----                           -----
    3                              3
    2                              2
    1                              1
    
    .EXAMPLE
    1, 2, 3 | ConvertTo-Hashtable { @{($_ + 1) = $_ } }
    
    Name                           Value
    ----                           -----
    4                              3
    3                              2
    2                              1
    
    .EXAMPLE
    1, 2, 3 | ConvertTo-Hashtable { @{($PSItem + 1) = $PSItem } }
    
    Name                           Value
    ----                           -----
    4                              3
    3                              2
    2                              1
    
    .EXAMPLE
    1, 2, 3 | ConvertTo-Hashtable { @{($args[0] + 1) = $args[0] } }
    
    Name                           Value
    ----                           -----
    4                              3
    3                              2
    2                              1
    
    .EXAMPLE
    1, 2, 3 | ConvertTo-Hashtable { @{($input[0] + 1) = $input[0] } }
    
    Name                           Value
    ----                           -----
    4                              3
    3                              2
    2                              1
    
    .EXAMPLE
    1, '2', 3 | ConvertTo-Hashtable { if ($_ -is [int]) { @{$_ = $_ } } else { [pscustomobject]@{} } }
    
    Scriptblock execution resulted in an error/exception: 'Provided scriptblock must only output a single hashtable, but output type was System.Management.Automation.PSCustomObject'
    
    .EXAMPLE
    1, '2', 3 | ConvertTo-Hashtable { if ($_ -is [int]) { @{$_ = $_ } } else { Write-Error 'Write-Error example' } }
    
    Scriptblock execution resulted in an error/exception: 'Write-Error example'
    
    .EXAMPLE
    1, '2', '3' | ConvertTo-Hashtable { if ($_ -is [int]) { @{$_ = $_ } }else { throw 'throw example' } }
    
    Scriptblock execution resulted in an error/exception: 'throw example'
    
    .EXAMPLE
    1, $null, 3 | ConvertTo-Hashtable { @{$_ = $_ } }
    
    Scriptblock execution resulted in an error/exception: 'A null key is not allowed in a hash literal.'
    
    .EXAMPLE
    $i = 0
    ConvertTo-Hashtable 1, 1, 1, 2 { @{$_ = ($_ + $i) } ; $i++; }
    
    Scriptblock execution resulted in an error/exception: Key '1' was found multiple times
    
    .EXAMPLE
    $i = 0
    ConvertTo-Hashtable 1, 1, 1, 2 { @{$_ = $_ + $i } ; $i++; } -DuplicateKeyAction Stop
    
    Scriptblock execution resulted in an error/exception: Key '1' was found multiple times
    
    .EXAMPLE
    $i = 0
    ConvertTo-Hashtable 1, 1, 1, 2 { @{$_ = $_ + $i } ; $i++; } -DuplicateKeyAction Ignore
    
    Name                           Value
    ----                           -----
    2                              5
    1                              1
    
    .EXAMPLE
    $i = 0
    ConvertTo-Hashtable 1, 1, 1, 2 { @{$_ = $_ + $i } ; $i++; } -DuplicateKeyAction Overwrite
    
    Name                           Value
    ----                           -----
    2                              5
    1                              3
    
    .EXAMPLE
    $i = 0
    ConvertTo-Hashtable 1, 1, 1, 2 { @{$_ = $_ + $i } ; $i++; } -DuplicateKeyAction Append
    
    Name                           Value
    ----                           -----
    2                              {5}
    1                              {1, 2, 3}
    
    .EXAMPLE
    $i = 0
    ConvertTo-Hashtable 1, 1, 1, 2 { @{$_ = $_ + $i } ; $i++; } -DuplicateKeyAction Prepend
    
    Name                           Value
    ----                           -----
    2                              {5}
    1                              {3, 2, 1}

    #>
    [CmdletBinding( DefaultParameterSetName = 'Pipeline')]
    param(
        [ValidateNotNull()]
        [Parameter(ParameterSetName = 'Call', Position = 1)]
        [Parameter(ParameterSetName = 'Pipeline', Position = 0)]
        [scriptblock]$ScriptBlock = { @{$_ = $_ } }, 
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Call')]
        [array]$InputArray,
        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'Pipeline')]
        [psobject]$InputObject,
        [ValidateSet('Stop', 'Ignore', 'Overwrite', 'Append', 'Prepend')]
        [string]$DuplicateKeyAction = 'Stop'
    )
    begin {
        $ht = @{}
    }
    process {
        try {
            $InputObject = switch ($PsCmdlet.ParameterSetName) {
                'Call' {
                    $InputArray
                }
                'Pipeline' {
                    @($InputObject)
                }
            }
            $tables = $InputObject | ForEach-Object {
                try {
                    $PreviousErrorActionPreference = $ErrorActionPreference
                    $ErrorActionPreference = 'Stop'
                    $table = Invoke-Command -NoNewScope -ScriptBlock $ScriptBlock -InputObject $_ -ArgumentList $_
                    $ErrorActionPreference = $PreviousErrorActionPreference
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError(
                        [System.Management.Automation.ErrorRecord]::new(
                                ([System.ArgumentException]::New("Scriptblock execution resulted in an error/exception: '$($PSItem.Exception.Message)'", $_)),
                            'ScriptBlockException',
                            [System.Management.Automation.ErrorCategory]::InvalidResult,
                            $ScriptBlock
                        )
                    )
                }
                if ($table -isnot [System.Collections.IDictionary]) {
                    $PSCmdlet.ThrowTerminatingError(
                        [System.Management.Automation.ErrorRecord]::new(
                                ([System.ArgumentException]::New("Provided scriptblock must only output a single hashtable, but output type was $($table.GetType())")),
                            'ArgumentException',
                            [System.Management.Automation.ErrorCategory]::InvalidResult,
                            $ScriptBlock
                        )
                    )
                }
                $table
            }
            $tables | ForEach-Object {
                $table = $_
                $table.GetEnumerator() | ForEach-Object {
                    $Key = $_.Key
                    switch ($DuplicateKeyAction) {
                        'Stop' {
                            if (!$ht.ContainsKey($Key)) {
                                $Value = $table.$key
                            }
                            else {
                                $PSCmdlet.ThrowTerminatingError(
                                    [System.Management.Automation.ErrorRecord]::new(
                                                ([System.ArgumentException]::New("Key '$($Key)' was found multiple times")),
                                        'ArgumentException',
                                        [System.Management.Automation.ErrorCategory]::InvalidData,
                                        $Key
                                    )
                                )
                            }
                        }
                        'Ignore' {
                            if (!$ht.ContainsKey($Key)) {
                                $Value = $table.$key
                            }
                            else {
                                $Value = $ht.$key
                            }
                        }
                        'Overwrite' { $Value = $table.$key }
                        'Append' {
                            if (!$ht.ContainsKey($Key)) {
                                $Value = @(, $table.$key)

                            }
                            else {
                                $Value = ($ht.$key + @(, $table.$key))
                            }
                        }
                        'Prepend' {
                            if (!$ht.ContainsKey($Key)) {
                                $Value = @(, $table.$key)
                            }
                            else {
                                $Value = (@(, $table.$key) + $ht.$key)
                            }
                        }
                    }
                    $ht.$Key = $Value
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
    end {
        return $ht
    }
}