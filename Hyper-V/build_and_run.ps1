Param(
    [string]$branchName='master',
    [string]$buildFor='',
    [string]$isDebug='no',
    [string]$zuulChange=''
)

$ErrorActionPreference = "Stop"

if ($isDebug -eq  'yes') {
    Write-Host "Debug info:"
    Write-Host "branchName: $branchName"
    Write-Host "buildFor: $buildFor"
}

$projectName = $buildFor.split('/')[-1]

$scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
. "$scriptLocation\config.ps1"
. "$scriptLocation\utils.ps1"

$hasProject = Test-Path $buildDir\$projectName

Add-Type -AssemblyName System.IO.Compression.FileSystem

$pip_conf_content = @"
[global]
index-url = http://10.20.1.8:8080/cloudbase/CI/+simple/
[install]
trusted-host = 10.20.1.8
"@

if ($hasBuildDir -eq $false){
   mkdir $buildDir
}

if ($hasProject -eq $false){
    Get-ChildItem $buildDir
    Get-ChildItem ( Get-Item $buildDir ).Parent.FullName
    Throw "$projectName repository was not found. Please run gerrit-git-prep.sh for this project first"
}

git config --global user.email "hyper-v_ci@microsoft.com"
git config --global user.name "Hyper-V CI"

pushd C:\
if (Test-Path $pythonArchive) {
    Remove-Item -Force $pythonArchive
}

Invoke-WebRequest -Uri http://10.20.1.14:8080/python.zip -OutFile $pythonArchive
if (Test-Path $pythonDir)
{
    Cmd /C "rmdir /S /Q $pythonDir"
    #Remove-Item -Recurse -Force $pythonDir
}
Write-Host "Ensure Python folder is up to date"
Write-Host "Extracting archive.."
[System.IO.Compression.ZipFile]::ExtractToDirectory("C:\$pythonArchive", "C:\")

$hasPipConf = Test-Path "$env:APPDATA\pip"
if ($hasPipConf -eq $false){
    mkdir "$env:APPDATA\pip"
}
else 
{
    Remove-Item -Force "$env:APPDATA\pip\*"
}
Add-Content "$env:APPDATA\pip\pip.ini" $pip_conf_content

$ErrorActionPreference = "Continue"

& easy_install -U pip
& pip install setuptools==26.0.0
& pip install pymi

$ErrorActionPreference = "Stop"

popd

$hasPipConf = Test-Path "$env:APPDATA\pip"
if ($hasPipConf -eq $false) {
    mkdir "$env:APPDATA\pip"
} else {
    Remove-Item -Force "$env:APPDATA\pip\*"
}

Add-Content "$env:APPDATA\pip\pip.ini" $pip_conf_content

cp $templateDir\distutils.cfg "$pythonDir\Lib\distutils\distutils.cfg"

ExecRetry {
    pushd $buildDir\$projectName
    & pip install -r $buildDir\$projectName\test-requirements.txt
    & pip install -e $buildDir\$projectName
    if ($LastExitCode) { Throw "Failed to install $projectNameInstall from repo" }
    popd
}

$currDate = (Get-Date).ToString()
Write-Host "$currDate running unit tests."

# Try {
#     pushd $buildDir\$projectName
#     $proc = Start-Process -PassThru -RedirectStandardError "$openstackLogs\process_error.txt" -RedirectStandardOutput "$openstackLogs\process_output.txt" -FilePath "$pythonDir\python.exe" -ArgumentList "-m unittest discover"
# } Catch {
#     Throw "Could not start the process manually."
# }

# Start-Sleep -s 300
# if (! $proc.HasExited) {
#     Stop-Process -Id $proc.Id -Force
#     Throw "Unit tests exceeded time linit of 300 seconds."
# }

& "$pythonDir\python.exe -m unittest discover"

popd

}