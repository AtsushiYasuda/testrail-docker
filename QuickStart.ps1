@'

##################################################################################
 TestRail quickstart

 This script will help you to quickly start a TestRail instance and will
 populate a '.env' file with the neccessary configuration values.
 For more advanced configuration please directly modify the .env file and utilize
 docker-compose directly.

 Please be aware that you will need 'sudo' installed to run this script.
###################################################################################

'@

Write-Host -NoNewline 'Press any key to continue (or Ctrl+C to abort)'
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
Write-Host

#variables definition
$optFolder = '_opt'
$backupDir = 'backup'
$dbFolder = '_mysql'
$envFile = '.env'
$configFile = '_config/config.php'
$httpPort = 8000

#####################################
# check if TestRail is already running
$timeStamp = Get-Date -UFormat '+%Y.%m.%d-%H.%M.%S'
$dockerPSOutput = docker ps | Select-String testrail

New-Item -ItemType Directory $backupDir -ErrorAction SilentlyContinue

if ($dockerPSOutput) {

    Write-Host ' ### Seems like a TestRail instance is already running'
    Write-Host "   To shut it down run 'docker-compose down -v' in this folder and then call this script again."
    Write-Host
    $key = read-key "   Press 'c' to continue or any other key to abort..."

    if ($key[0] -ne 'c') {
        exit -1
    }
}
Write-Host

#####################################
# port
while ($true) {

    $port = Read-Host "  Please enter the port number testrail use (default 8000) or press 'c' to continue"

    if ($port -eq 'c') {
        Write-Host '  --> Using port 8000 (default value)'
        Write-Host
        break
    } elseif ($port -notmatch '^[0-9]+$') {
        Write-Host '  --> Sorry integers only!'
        continue
    } else {
        Write-Host "  --> Using port $port"
        $httpPort = $port
        break
    }
}

Write-Host ''

#####################################
# testrail version

Write-Host 'These TestRail versions are available'
Invoke-RestMethod https://registry.hub.docker.com/v1/repositories/testrail/apache/tags | Out-String | Write-Host
Write-Host
$version = Read-Host "Press 'l' to use 'latest', 'b' for 'beta' or type in the version you want to use"
Write-Host

if ($version -eq 'l') {
    $testrailVersion = 'latest'
} elseif ($version -eq 'b') {
    $testrailVersion = 'beta'
} else {
    $testrailVersion = $version
}

#####################################
# database

Write-Host
Write-Host "An empty database named 'testrail' is automatically created together with the user 'testrail'."
Write-Host "In succession, please enter a password for this user.
During the installation, use 'testrail' for the database name and the database-user and utilize the password you'll enter now."
Write-Host
$password = Read-Host '  Enter a password for the database user'

Write-Host
Write-Host 'The database also needs a secure root password (needed for debugging/emergency cases)'
Write-Host
$root_pwd = Read-Host '  Enter a database root password'

Write-Host
Write-Host
Write-Host "The database will be stored in the local folders '_mysql' and files created by TestRail will be placed in '_opt'."

if (Get-ChildItem $dbFolder -Exclude .gitignore) {
    Write-Host "  ... The db-folder already contains files  -- moving it to '$backupDir'"

    Move-Item $dbFolder $backupDir/"${dbFolder}_${timeStamp}"
    New-Item -ItemType Directory $dbFolder
}

#####################################
# opt
if (Get-ChildItem $optFolder -Exclude .gitignore) {
    Write-Host "  ... The opt-folder already contains files -- moving it to '$backupDir'"

    Move-Item $optFolder $backupDir/"${optFolder}_${timeStamp}"
    New-Item -ItemType Directory $optFolder
}

#####################################
# .env
if (Test-Path -PathType Leaf $envFile) {
    Write-Host "  ... A '.env' file already exists -- moving it to '$backupDir'"

    Move-Item .env $backupDir/.env_$timeStamp
}

@"
HTTP_PORT=${httpPort}
DB_USER=testrail
DB_NAME=testrail
DB_PWD=${password}
DB_ROOT_PWD=${root_pwd}
OPT_PATH=${optFolder}
MYSQL_PATH=${dbFolder}
TESTRAIL_VERSION=${testrailVersion}
"@ | Out-File -Encoding default .env

#####################################
# config.php

if (Test-Path -PathType Leaf $configFile) {
    Write-Host "A 'config.php' file already exists -- it will be saved and a new one will be created during the installation"

    Move-Item $configFile $backupDir/config.php_$timeStamp
}

#####################################
# starting TestRail

Write-Host
Write-Host "TestRail will be started now with HTTP and will listen on port ${httpPort}."


docker-compose up -d
Start-Sleep 5

Write-Host
Write-Host ' -------------  Looks good  ------------- '
Write-Host
Write-Host "TestRail should be available now on http://localhost:${httpPort}"
Write-Host
Write-Host 'If your firewall is not blocking the port, it should also be reachable via:'

#####################################
# getting network adapters IPs to quickly provide TestRail links

$ip = Get-NetIPConfiguration |
    Where-Object InterfaceDescription -NotMatch 'Virtual' |
        Select-Object -Expand IPv4Address |
            Where-Object IPAddress -NotLike '169.254.*' |
                Select-Object -ExpandProperty IPAddress -First 1

Write-Host "  -->  http://${ip}:${httpPort}"

Write-Host @'

Please use the following values during TestRail setup:

  DATABASE SETTINGS
    Server:     'db:3306'
    Database:   'testrail'
    User:       'testrail'
    Password:    <The user password you've entered for the db-user>

  Application Settings
    - Simply leave the default values for the folders 'logs, reports, attachments and audit'.

  The TestRail background task is also automatically started 60s after the installation is done.


To shut down TestRail again run the following command in this folder:
docker-compose down -v
'@
