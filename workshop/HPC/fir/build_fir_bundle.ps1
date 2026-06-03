$ErrorActionPreference = "Stop"

$firRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$bundleRoot = Join-Path $firRoot "bundle"
$scriptsOut = Join-Path $bundleRoot "r-scripts"

$requiredRScripts = @(
  "Inspect_Extensions_Script.R",
  "Inspect_csv_Script.R",
  "Inspect_Images_Script.R",
  "Inspect_hdf5_Script.R",
  "Inspect_nc_Script.R",
  "Inspect_PDF_Script.R",
  "Inspect_sqlite_Script.R"
)

if (Test-Path $bundleRoot) {
  Remove-Item -Recurse -Force $bundleRoot
}

New-Item -ItemType Directory -Path $scriptsOut | Out-Null

@(
  "activate_fir_r_env.sh",
  "setup_fir_r_env.sh",
  "run_workshop_module.sh",
  "submit_workshop_module.sh",
  "README.md"
) | ForEach-Object {
  Copy-Item (Join-Path $firRoot $_) -Destination $bundleRoot
}

foreach ($scriptName in $requiredRScripts) {
  Copy-Item (Join-Path $repoRoot "Scripts/$scriptName") -Destination $scriptsOut
}

Write-Host "Minimal Fir bundle created at: $bundleRoot"
