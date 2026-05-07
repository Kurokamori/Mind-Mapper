$RootDir = $PSScriptRoot
$presetsFile = "export_presets.cfg"

if (-not (Test-Path $presetsFile)) {
    Write-Error "Could not find $presetsFile. Please run this script from the root of your Godot project."
    exit 1
}

$presets = @()
$currentPreset = $null

# Parse the export_presets.cfg file to map out preset names and export paths
foreach ($line in Get-Content $presetsFile) {
    if ($line -match '^\[preset\.(\d+)\]$') {
        if ($currentPreset) { $presets += $currentPreset }
        $currentPreset = [PSCustomObject]@{ Name = ""; Path = "" }
    }
    elseif ($line -match '^name="(.*)"$') {
        if ($currentPreset) { $currentPreset.Name = $matches[1] }
    }
    elseif ($line -match '^export_path="(.*)"$') {
        if ($currentPreset) { $currentPreset.Path = $matches[1] }
    }
}
if ($currentPreset) { $presets += $currentPreset } # Catch the last item

# Determine Godot executable
$godotCmd = "godot"
if (Test-Path "./godot.exe") {
    $godotCmd = "./godot.exe"
} elseif (Test-Path "./godot") {
    $godotCmd = "./godot"
}

# Compile the exports
foreach ($preset in $presets) {
    if (-not $preset.Name) { continue }

    $name = $preset.Name
    $path = $preset.Path

    if (-not $path) {
        Write-Warning "Skipping '$name' because no Export File path is defined."
        continue
    }

    # Godot CLI output relies on standard directory paths rather than res:// paths
    if ($path.StartsWith("res://")) {
        $path = $path.Replace("res://", "./")
    }

    # Ensure the target directory for the export exists
    $outputDir = Split-Path $path
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    }

    if ($name.StartsWith("[PCK]")) {
        # Ensure the path ends with .pck or .zip for pack exports
        if (-not $path.EndsWith(".pck") -and -not $path.EndsWith(".zip")) {
            $path = $path -replace '\.[^./\\]+$', ''
            if (-not $path.EndsWith(".pck")) {
                $path += ".pck"
            }
        }

        Write-Host "Compiling PCK for Room: $name -> $path" -ForegroundColor Cyan
        $argList = @("--headless", "--export-pack", "`"$name`"", "`"$path`"")
    }
    else {
        Write-Host "Compiling Full Project Export: $name -> $path" -ForegroundColor Yellow
        $argList = @("--headless", "--export-release", "`"$name`"", "`"$path`"")
    }

    $process = Start-Process -FilePath $godotCmd -ArgumentList $argList -Wait -NoNewWindow -PassThru

    if ($process.ExitCode -ne 0) {
        Write-Error "Failed to compile '$name'. Exit code: $($process.ExitCode)"
    }
    else {
        Write-Host "Successfully compiled '$name'." -ForegroundColor Green
    }
}