# cc-win-statusline installer (Windows / PowerShell)
# Installs statusline.sh and merges statusLine config into ~/.claude/settings.json

$ErrorActionPreference = "Stop"

$repoRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path
$claudeDir  = Join-Path $env:USERPROFILE ".claude"
$scriptDest = Join-Path $claudeDir "statusline.sh"
$settingsPath = Join-Path $claudeDir "settings.json"

# Convert C:\Users\foo to /c/Users/foo (Git Bash style)
function ConvertTo-UnixPath {
    param([string]$winPath)
    $p = $winPath -replace '\\', '/'
    if ($p -match '^([A-Za-z]):(.*)$') {
        return "/$($Matches[1].ToLower())$($Matches[2])"
    }
    return $p
}

# 1. Ensure ~/.claude exists
if (-not (Test-Path $claudeDir)) {
    New-Item -ItemType Directory -Path $claudeDir | Out-Null
    Write-Host "Created $claudeDir"
}

# 2. Copy statusline.sh
Copy-Item -Path (Join-Path $repoRoot "template\statusline.sh") -Destination $scriptDest -Force
Write-Host "Installed: $scriptDest"

# 3. Verify dependencies on PATH
$missing = @()
foreach ($cmd in @("bash", "jq", "git")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { $missing += $cmd }
}
if ($missing.Count -gt 0) {
    Write-Warning "Not found on PATH: $($missing -join ', '). Install Git for Windows and jq before using."
}

# 4. Build statusLine config
$homeUnix = ConvertTo-UnixPath $env:USERPROFILE
$cmdLine  = "bash $homeUnix/.claude/statusline.sh"
$statusLineCfg = [ordered]@{
    type            = "command"
    command         = $cmdLine
    refreshInterval = 5000
}

# 5. Merge into existing settings.json (or create new)
if (Test-Path $settingsPath) {
    $backup = "$settingsPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $settingsPath $backup
    Write-Host "Backed up existing settings.json to $backup"
    $existing = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $existing | Add-Member -NotePropertyName "statusLine" -NotePropertyValue $statusLineCfg -Force
    $merged = $existing
} else {
    $merged = [ordered]@{ statusLine = $statusLineCfg }
}

$merged | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8
Write-Host "Updated: $settingsPath"
Write-Host ""
Write-Host "statusLine command: $cmdLine"
Write-Host "Done. Restart Claude Code to see the status line."
