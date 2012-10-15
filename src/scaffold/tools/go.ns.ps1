# this file should not be changed, will be replaced after upgrade
# use go.ext.ps1 to extend
param(
    $target, 
    $packageId="",
    $env="dev"
)

trap{
    write-host "Error found: $_" -f red
    exit 1
}

$error.clear()

$codeBaseRoot = $MyInvocation.MyCommand.Path | Split-Path -parent


$toolsRoot = "$codeBaseRoot\build\tools"
$scriptRoot = "$codeBaseRoot\build\scripts"
$libsRoot = "$scriptRoot\libs"
$buildScriptRoot = "$codeBaseRoot\build\scripts\build"

$env:EnableNuGetPackageRestore = "true"

Resolve-Path "$libsRoot\*.ps1" | 
    ? { -not ($_.ProviderPath.Contains(".Tests.")) } |
    % { . $_.ProviderPath }

. PS-Require "$libsRoot\functions\"

$nuget = "$codeBaseRoot\.nuget\nuget.exe"

# register ps-get packages
PS-Get "psake" "4.2.0.1" | % {
    $psakeModule = get-childitem $_ psake.psm1 -recurse
    Import-Module $psakeModule.FullName -Force
    $psake.use_exit_on_error = $true
}

PS-Get "yam" "0.0.2" -postInstall {
    param($pkgDir)
    . "$pkgDir\install.ps1" $codeBaseRoot
}

Import-Module WebAdministration -Force

$buildParmeters = @{ 
    "env" = "$env"
    "codeBaseRoot" = "$codeBaseRoot"
    "libsRoot" = "$libsRoot"
    "toolsRoot" = "$toolsRoot"
    "nuget" = $nuget
    "environmentsRoot" = "$buildScriptRoot\environments"
    "packageId" = $packageId
}

. Register-Extension $MyInvocation.MyCommand.Path

Invoke-Psake $scriptRoot\build\build.ns.ps1 $target -Framework "4.0x64" -parameters $buildParmeters

if(!$psake.build_success) {
    write-host "============================= Environment: $env ==============================" -f yellow
    $buildParmeters | format-table | Out-String | write-host -f yellow
    throw "Failed to execute Task $target."
}
