$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = resolve-path "$here\..\.."
$fixturesTemplate = "$root\test\test-fixtures"
. "$root\src\scaffold\tools\build\scripts\deploy\deploy-website\health-check.fn.ns.ps1"

Describe "Test-MatchPackage" {
    It "should return true when the package matches with the health check page" {
        $healthCheckPage = "Name=packageId`nVersion=1.0.0.3603931`nServerName=DEV-107`nStatus=Success"
        $packageInfo = @{
            packageId = "packageId"
            version = "1.0.0.3603931"
        }
        $match = Test-MatchPackage $healthCheckPage $packageInfo
        $match.should.be($true)
    }
    It "should return false when the package version doesn't match with the health check page" {
        $healthCheckPage = "ServerName=DEV-107`nVersion=1.0.0.3603931`nStatus=Success"
        $packageInfo = @{
            packageId = "packageId"
            version = "1.0.0.3603"
        }
        $match = Test-MatchPackage $healthCheckPage $packageInfo
        $match.should.be($false)
    }
    It "should return false when the package version doesn't match with the health check page 2" {
        $healthCheckPage = "ServerName=DEV-107`nVersion=1.0.0.3603931`nStatus=Success"
        $packageInfo = @{
            packageId = "packageId"
            version = "1.0.0.36039311"
        }
        $match = Test-MatchPackage $healthCheckPage $packageInfo
        $match.should.be($false)
    }

    It "should return false when the package name doesn't match with the health check page 2" {
        $healthCheckPage = "Name=packageId1`nVersion=1.0.0.3603931`nServerName=DEV-107`nStatus=Success"
        $packageInfo = @{
            packageId = "packageId"
            version = "1.0.0.3603931"
        }
        $match = Test-MatchPackage $healthCheckPage $packageInfo
        $match.should.be($false)
    }
}

Describe "Test-DependencyFailure" {
    It "should return true when health page contains failures" {
        $healthCheckPage = @"
ServerName=DEV-107
Version=1.0.0.3603931
Status=Success
DB=Failure
"@
        $result = Test-DependencyFailure $healthCheckPage
        $result.should.be($true)
    }
    It "should return false when health page contains NO failures" {
        $healthCheckPage = @"
ServerName=DEV-107
Version=1.0.0.3603931
Status=Success
DB=Success
"@
        $result = Test-DependencyFailure $healthCheckPage
        $result.should.be($false)
    }
}

function Get-UNCPath($path){    
    $drive = Split-Path -qualifier $path
    $logicalDisk = Gwmi Win32_LogicalDisk -filter "DriveType = 4 AND DeviceID = '$drive'"
    if($logicalDisk){
        $path.Replace($drive, $logicalDisk.ProviderName)
    }
    else {
        $path
    }
}

Describe "Test-WebsiteMatch" {
    $testSiteName = "TestWebsiteMatchSite"
    $port = 1005
    It "should return true when website matches with the artifact version" {
        try{
            Remove-Website -Name $testSiteName -ErrorAction SilentlyContinue
            $physicalPath = Get-UNCPath("$fixturesTemplate\healthchecksite")
            New-Website $testSiteName -Port $port -IPAddress "*" -physicalPath $physicalPath -Force            
            $config = @{
                siteName= $testSiteName
                healthCheckPath = "/health.aspx?check=all"
            }
            $packageInfo = @{
                packageId = "MyPackageApi"
                version = "1.0.123.0"
            }
            $match = Test-WebsiteMatch $config $packageInfo

            $match.should.be($true)
        }finally{
            Remove-Website -Name $testSiteName
        }
    }
    It "should return false when website does NOT match with the artifact version" {
        try{
            Remove-Website -Name $testSiteName -ErrorAction SilentlyContinue
            $physicalPath = Get-UNCPath("$fixturesTemplate\healthchecksite")
            New-Website $testSiteName -Port $port -IPAddress "*" -physicalPath $physicalPath -Force
            $config = @{
                siteName= $testSiteName
                healthCheckPath = "/health.aspx?check=all"
            }
            $packageInfo = @{
                packageId = "MyPackageApi"
                version = "1.0.123.1"
            }
            
            $match = Test-WebsiteMatch $config $packageInfo

            $match.should.be($false)
        }finally{
            Remove-Website -Name $testSiteName
        }
    }
}
