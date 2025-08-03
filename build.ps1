# === CONFIG ===
$scriptName     = "t7es3sma.ahk"
$baseExeName    = "t7es3sma"
$ahk2exePath    = "ahk\Compiler\Ahk2Exe.exe"
$upxPath        = "upx/upx.exe"
$iconPath       = "t7es3_media\t7es3-default.ico"
$versionDat     = "version.dat"
$versionTxt     = "version.txt"
$versionTpl     = "version_template.txt"
$extraAssets    = @("README.txt", "t7es3.ini", "LICENSE", $versionTxt, $versionDat)


# === GET ENVIRONMENT INFO ===
$localTag = "LocalBuild_" + (Get-Date -Format "yyyyMMdd_HHmmss")
$finalExe = "${baseExeName}${localTag}.exe"
$zipName  = "${baseExeName}${localTag}.zip"


$timestamp    = Get-Date -Format "yyyyMMdd_HH"
# ^ Only define $timestamp if you need it for logging, not for naming output files


# === VERSIONING ===
Copy-Item $versionTpl $versionTxt -Force
(Get-Content $versionTxt) -replace "%%DATETIME%%", $timestamp | Set-Content $versionTxt
$timestamp | Set-Content $versionDat


# === CLEANUP OLD FILES ===
Remove-Item "$baseExeName.exe","$finalExe","build.log","$zipName" -ErrorAction SilentlyContinue


# === COMPILE SCRIPT ===
Write-Host "Compiling AHK..."

# Show current working directory
Write-Host "_ Current directory: $(Get-Location)"

# Verify all paths
Write-Host "Path verification:" -ForegroundColor Yellow
Write-Host "- Script: $scriptName (exists: $(Test-Path $scriptName))"
Write-Host "- Ahk2Exe: $ahk2exePath (exists: $(Test-Path $ahk2exePath))"
Write-Host "- Icon: $iconPath (exists: $(Test-Path $iconPath))"
Write-Host "- UPX: $upxPath (exists: $(Test-Path $upxPath))"
Write-Host "- Output will be: $baseExeName.exe"

# Build the argument list with proper quoting
$arguments = @(
    "/in", $scriptName,
    "/out", "$baseExeName.exe",
    "/icon", $iconPath
)

Write-Host "Full command:" -ForegroundColor Cyan
Write-Host "`"$ahk2exePath`" $($arguments -join ' ')"

# Execute with detailed error capture
Write-Host "_ Executing..." -ForegroundColor Green
$process = Start-Process -FilePath $ahk2exePath -ArgumentList $arguments -Wait -PassThru -NoNewWindow

Write-Host "_ Process exit code: $($process.ExitCode)"

# Check if output file was created
if (Test-Path "$baseExeName.exe") {
    Write-Host "_ Compilation successful!" -ForegroundColor Green
    Copy-Item "$baseExeName.exe" "$finalExe" -Force
    Write-Host "_ Copied $baseExeName.exe to $finalExe (timestamped build EXE)"
} else {
    Write-Host "_ Output file not created!" -ForegroundColor Red
    Write-Error "Compilation failed."
    Exit 1
}


# === COMPRESS EXE ===
Write-Host "_ Pre-UPX size:" (Get-Item $finalExe).Length
$upxResult = & $upxPath --best --lzma $finalExe
$upxResult | ForEach-Object { Write-Host $_ }
Write-Host "_ Post-UPX size:" (Get-Item $finalExe).Length
Write-Host "_ UPX compression finished."

# === ZIP CONTENTS ===
Write-Host "_ Creating ZIP: $zipName"

# Build file list
$allFiles = @()

# Add final executable
if (Test-Path $finalExe) {
    $allFiles += $finalExe
    Write-Host "_ Added: $finalExe"
} else {
    Write-Host "Warning: $finalExe not found!" -ForegroundColor Yellow
}

# Add extra assets
foreach ($asset in $extraAssets) {
    if (Test-Path $asset) {
        $allFiles += $asset
        Write-Host "Added: $asset"
    } else {
        Write-Host "Warning: $asset not found!" -ForegroundColor Yellow
    }
}

# Remove any missing paths
$allFiles = $allFiles | Where-Object { Test-Path $_ }

Write-Host "_ Total files to zip: $($allFiles.Count)"

# Create build staging folder
$stagingFolder = "build_temp"
Remove-Item $stagingFolder -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stagingFolder | Out-Null

# Copy all files into staging while preserving folder structure
foreach ($file in $allFiles) {
    $relativePath = Resolve-Path -Relative $file
    $destination = Join-Path $stagingFolder $relativePath
    $destinationDir = Split-Path $destination
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    Copy-Item $file -Destination $destination -Force
}

# Create ZIP from staging
try {
    Compress-Archive -Path "$stagingFolder\*" -DestinationPath $zipName -Force
    Write-Host "_ ZIP created successfully: $zipName" -ForegroundColor Green
} catch {
    Write-Host "_ ZIP creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Cleanup
Remove-Item $stagingFolder -R
Write-Host "_ Fallback EXE created!" -ForegroundColor Yellow
Write-Host "`n===== BUILD COMPLETE =====" -ForegroundColor Cyan
Write-Host "Output EXE: $finalExe"
Write-Host "ZIP Archive: $zipName"
Write-Host "Timestamp: $timestamp"


# === COPY OUTPUT TO NEW_BUILDS FOLDER ===
try {
    $buildFolder = "C:\repos\t7es3-screen-manager-advanced\new_builds"
    $outputFiles = @(
        $finalExe,
        $zipName,
        "$baseExeName.exe"
    )

    # Ensure $buildFolder is a proper directory
    if (Test-Path $buildFolder) {
        $item = Get-Item $buildFolder
        if (-not $item.PSIsContainer) {
            Write-Host "_ Removing file named 'new_builds' so we can create a folder instead..."
            Remove-Item $buildFolder -Force
        }
    }

    if (-not (Test-Path $buildFolder)) {
        Write-Host "_ Creating build folder: $buildFolder"
        New-Item -ItemType Directory -Path $buildFolder | Out-Null
    }

    # Copy files to build folder
    foreach ($file in $outputFiles) {
        if (Test-Path $file) {
            Write-Host "_ Copying $file to $buildFolder"
            Copy-Item $file -Destination $buildFolder -Force
        } else {
            Write-Warning "File not found, skipping: $file"
        }
    }

    Write-Host "_ All available files copied to: $buildFolder"
}
catch {
    Write-Error "Error copying build files: $_"
}


# === LOG SUCCESS ===
"[$timestamp] Built $finalExe with embedded WAVs" | Add-Content "changelog.txt"
Write-Host "_ Done: $finalExe + $zipName"

Write-Host "Script completed!" -ForegroundColor Yellow

# Open folder
Invoke-Item (Get-Item $finalExe).DirectoryName
