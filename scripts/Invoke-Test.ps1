Import-Module Pester -Force
# $testFile = 'C:\PowerShell\MyTests\'

# $tr = 'C:\PowerShell\MyTests\TEST-MyTests.xml'

$Container = New-PesterContainer -Path $testFile -Data @{ 
#    testurl  = 'https://urlyouwanttotest.com/'
}

$configuration = [PesterConfiguration]@{
  Run = @{
#    PassThru = $true
   Container = $Container
  }
#   Output = @{
#      Verbosity = 'Detailed'
#   }

#   TestResult = @{
#      Enabled = $true
#      OutputFormat = "NUnitXml"
#      OutputPath   = $tr
#      }
  }       

  Invoke-Pester -Configuration $configuration