# Tuning Fork installer for Windows.
#   irm https://raw.githubusercontent.com/Mitalee/tuning-fork/main/install.ps1 | iex
# Adds the tuningfork MCP server to GitHub Copilot CLI and/or Claude Code (whichever is installed)
# and lets them use Tuning Fork's tools without asking each time. Safe to run more than once.

$ErrorActionPreference = "Continue"
$url = "https://ziwygmfxsynuccngnehe.supabase.co/functions/v1/tuningfork"
$marker = "# Tuning Fork: let Copilot CLI use the tuningfork MCP tools without asking each time."
$found = $false

function Say($msg) { Write-Host "  $msg" }
Write-Host ""
Write-Host "Installing Tuning Fork..."

if (Get-Command copilot -CommandType Application -ErrorAction SilentlyContinue) {
    $found = $true
    $null = & copilot mcp get tuningfork 2>&1
    if ($LASTEXITCODE -eq 0) { Say "Copilot CLI: tuningfork server already added" }
    else { $null = & copilot mcp add --transport http tuningfork $url 2>&1; Say "Copilot CLI: added tuningfork server" }

    $fn = "`r`n$marker`r`n" + @'
function copilot {
    $exe = (Get-Command copilot -CommandType Application | Select-Object -First 1).Source
    if ($args.Count -eq 0 -or "$($args[0])".StartsWith('-')) { & $exe --allow-tool "tuningfork" @args }
    else { & $exe @args }
}
'@
    $docs = [Environment]::GetFolderPath("MyDocuments")
    foreach ($p in "$docs\PowerShell\Microsoft.PowerShell_profile.ps1", "$docs\WindowsPowerShell\Microsoft.PowerShell_profile.ps1") {
        New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null
        if ((Test-Path $p) -and ((Get-Content -Raw $p) -like "*$marker*")) { continue }
        Add-Content -Path $p -Value $fn -Encoding UTF8
    }
    Say "Copilot CLI: Tuning Fork tools won't ask for approval (PowerShell)"
}

if (Get-Command claude -ErrorAction SilentlyContinue) {
    $found = $true
    $null = & claude mcp get tuningfork 2>&1
    if ($LASTEXITCODE -eq 0) { Say "Claude Code: tuningfork server already added" }
    else { $null = & claude mcp add --transport http --scope user tuningfork $url 2>&1; Say "Claude Code: added tuningfork server" }

    $settings = Join-Path $HOME ".claude\settings.json"
    New-Item -ItemType Directory -Force (Split-Path $settings) | Out-Null
    $json = if (Test-Path $settings) { Get-Content -Raw $settings | ConvertFrom-Json } else { $null }
    if (-not $json) { $json = New-Object PSObject }
    if (-not $json.PSObject.Properties["permissions"]) { $json | Add-Member permissions (New-Object PSObject) }
    if (-not $json.permissions.PSObject.Properties["allow"]) { $json.permissions | Add-Member allow @() }
    if (@($json.permissions.allow) -notcontains "mcp__tuningfork") {
        $json.permissions.allow = @($json.permissions.allow) + "mcp__tuningfork"
        [IO.File]::WriteAllText($settings, ($json | ConvertTo-Json -Depth 50))
    }
    Say "Claude Code: Tuning Fork tools won't ask for approval"
}

Write-Host ""
if ($found) {
    Write-Host "Done. Open a new PowerShell window and start Copilot CLI or Claude Code."
    Write-Host "Using Claude desktop or claude.ai? See https://github.com/Mitalee/tuning-fork"
} else {
    Write-Host "Didn't find Copilot CLI or Claude Code on this computer."
    Write-Host "Install one first, or follow https://github.com/Mitalee/tuning-fork"
}
