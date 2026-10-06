<#
.SYNOPSIS
    CouchDB Initialization Script for Obsidian LiveSync (PowerShell)
.DESCRIPTION
    Creates required system databases (_users, _replicator, _global_changes)
    and the target vault database.
#>

[CmdletBinding()]
param (
    [string]$EnvFile = ".env"
)

# Load .env file if it exists
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $key, $val = $line.Split("=", 2)
            [Environment]::SetEnvironmentVariable($key.Trim(), $val.Trim(), "Process")
        }
    }
}

$user = $env:COUCHDB_USER
if (-not $user) { $user = "admin" }

$pass = $env:COUCHDB_PASSWORD
if (-not $pass) {
    Write-Error "COUCHDB_PASSWORD is not set. Please create/configure .env before running."
    exit 1
}

$port = $env:COUCHDB_PORT
if (-not $port) { $port = "5984" }

$dbName = $env:COUCHDB_DB
if (-not $dbName) { $dbName = "obsidian-livesync" }

$hostUrl = "http://127.0.0.1:$port"
$auth = "${user}:${pass}"

Write-Host "Waiting for CouchDB to become ready at $hostUrl..."
$ready = $false
while (-not $ready) {
    try {
        $res = curl.exe -s -u $auth "$hostUrl/"
        if ($res -match "Welcome") {
            $ready = $true
        } else {
            Start-Sleep -Seconds 1
        }
    } catch {
        Start-Sleep -Seconds 1
    }
}

Write-Host "CouchDB is online!" -ForegroundColor Green

function Create-Database {
    param([string]$Database)
    Write-Host "Ensuring database '$Database' exists..."
    $check = curl.exe -s -o /dev/null -w "%{http_code}" -u $auth -X GET "$hostUrl/$Database"
    if ($check -eq "404") {
        Write-Host "Creating database: $Database"
        curl.exe -s -u $auth -X PUT "$hostUrl/$Database"
        Write-Host ""
    } else {
        Write-Host "Database '$Database' already exists." -ForegroundColor Gray
    }
}

# Ensure standard system databases
Create-Database "_users"
Create-Database "_replicator"
Create-Database "_global_changes"

# Ensure vault database
Create-Database $dbName

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " CouchDB setup completed successfully!" -ForegroundColor Green
Write-Host " Vault Database: $hostUrl/$dbName" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Green
