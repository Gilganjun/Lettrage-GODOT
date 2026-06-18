# Opens the main level backdrop layers in GIMP.
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$bg1 = Join-Path $repoRoot "assets\environment\out_18.jpg"
$bg2 = Join-Path $repoRoot "assets\environment\out_18_3.png"

$candidates = @(
	"$env:LocalAppData\Programs\GIMP 3\bin\gimp-3.0.exe",
	"$env:ProgramFiles\GIMP 3\bin\gimp-3.0.exe",
	"$env:LocalAppData\Programs\GIMP 2\bin\gimp-2.10.exe",
	"$env:ProgramFiles\GIMP 2\bin\gimp-2.10.exe"
)

$gimp = $null
foreach ($path in $candidates) {
	if (Test-Path $path) {
		$gimp = $path
		break
	}
}

if (-not $gimp) {
	Write-Error "GIMP not found. Install GIMP or edit tools/open_background_in_gimp.ps1 with your gimp.exe path."
	exit 1
}

foreach ($image in @($bg1, $bg2)) {
	if (-not (Test-Path $image)) {
		Write-Error "Missing background file: $image"
		exit 1
	}
}

Start-Process -FilePath $gimp -ArgumentList @($bg1, $bg2)
