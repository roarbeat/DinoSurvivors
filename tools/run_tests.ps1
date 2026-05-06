# Headless GUT-Test-Runner für DinoRogue (Windows / PowerShell).
#
# Nutzung:
#   .\tools\run_tests.ps1                              # alle Unit-Tests
#   .\tools\run_tests.ps1 tests/unit/test_event_bus.gd # einzelner Test
#
# Voraussetzungen:
#   - godot.exe oder godot4.exe im PATH (4.3+ empfohlen)
#   - oder Umgebungsvariable $env:GODOT mit Pfad zum Binary
#   - GUT-Addon unter addons/gut/ (im Repo)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

# Godot-Binary suchen
$GodotBin = $null
if ($env:GODOT) {
    $GodotBin = $env:GODOT
} elseif (Get-Command "godot4" -ErrorAction SilentlyContinue) {
    $GodotBin = "godot4"
} elseif (Get-Command "godot" -ErrorAction SilentlyContinue) {
    $GodotBin = "godot"
} else {
    Write-Error "Weder 'godot' noch 'godot4' gefunden. Setze `$env:GODOT oder installiere Godot 4.3+."
    exit 127
}

Write-Host "Godot: $(& $GodotBin --version 2>&1 | Select-Object -First 1)"
Write-Host "Projekt: $ProjectRoot"
Write-Host ""

# Target-Argument
$Target = if ($args.Count -gt 0) { $args[0] } else { "res://tests/unit" }
if (-not $Target.StartsWith("res://")) {
    $Target = "res://" + $Target.TrimStart('.').TrimStart('/')
}

if ($Target.EndsWith(".gd")) {
    $GutArg = "-gtest=$Target"
} else {
    $GutArg = "-gdir=$Target"
}

Write-Host "GUT-Arg: $GutArg"
Write-Host ""

& $GodotBin --headless --path . `
    -s addons/gut/gut_cmdln.gd `
    $GutArg `
    -gexit `
    -glog=2

$ExitCode = $LASTEXITCODE
Write-Host ""
Write-Host "GUT exit code: $ExitCode"
exit $ExitCode
