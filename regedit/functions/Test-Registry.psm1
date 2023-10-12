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