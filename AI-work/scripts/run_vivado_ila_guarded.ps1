param(
    [Parameter(Mandatory = $true)]
    [string]$Tcl,

    [string]$OutDir = "AI-work/features/DL5_laser_sync/DL5_UNIT_005/out/hw_debug",

    [string]$RunName = "",

    [string]$Vivado = "D:\Xilinx\Vivado\2021.1\bin\vivado.bat",

    [string[]]$TclArgs = @()
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir "..\..")).Path

function Resolve-ProjectPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return (Resolve-Path -LiteralPath $Path).Path
    }
    return (Resolve-Path -LiteralPath (Join-Path $projectRoot $Path)).Path
}

function Get-DrootHwIlaDirs {
    @(Get-ChildItem -Path "D:\" -Directory -Force -Filter "hw_ila_data_*" -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName)
}

$tclPath = Resolve-ProjectPath $Tcl
if (-not (Test-Path -LiteralPath $Vivado)) {
    throw "Vivado launcher not found: $Vivado"
}

if ([System.IO.Path]::IsPathRooted($OutDir)) {
    $outFull = $OutDir
} else {
    $outFull = Join-Path $projectRoot $OutDir
}
$outFull = [System.IO.Path]::GetFullPath($outFull)
New-Item -ItemType Directory -Force -Path $outFull | Out-Null

if ([string]::IsNullOrWhiteSpace($RunName)) {
    $RunName = [System.IO.Path]::GetFileNameWithoutExtension($tclPath)
}
$safeName = $RunName -replace "[^A-Za-z0-9_.-]", "_"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"

$workRoot = Join-Path $outFull "vivado_batch_work"
$workDir = Join-Path $workRoot "${safeName}_${stamp}"
$spillRoot = Join-Path $outFull "droot_spill"
$spillDir = Join-Path $spillRoot "${safeName}_${stamp}"
$logFile = Join-Path $outFull "${safeName}_${stamp}.log"
$journalFile = Join-Path $outFull "${safeName}_${stamp}.jou"
$manifestFile = Join-Path $outFull "${safeName}_${stamp}.spill_manifest.txt"

New-Item -ItemType Directory -Force -Path $workDir | Out-Null

$before = Get-DrootHwIlaDirs
$beforeSet = @{}
foreach ($path in $before) {
    $beforeSet[$path.ToLowerInvariant()] = $true
}

$vivadoArgs = @(
    "-mode", "batch",
    "-log", $logFile,
    "-journal", $journalFile,
    "-source", $tclPath
)
if ($TclArgs.Count -gt 0) {
    $vivadoArgs += "-tclargs"
    $vivadoArgs += $TclArgs
}

$exitCode = 0
try {
    Push-Location -LiteralPath $workDir
    & $Vivado @vivadoArgs
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}

$after = Get-DrootHwIlaDirs
$newDirs = @()
foreach ($path in $after) {
    if (-not $beforeSet.ContainsKey($path.ToLowerInvariant())) {
        $newDirs += $path
    }
}

$moved = @()
if ($newDirs.Count -gt 0) {
    New-Item -ItemType Directory -Force -Path $spillDir | Out-Null
    foreach ($path in $newDirs) {
        $resolved = (Resolve-Path -LiteralPath $path).Path
        if ($resolved -notmatch '^D:\\hw_ila_data_[^\\]+$') {
            throw "Refusing to move unexpected D-root path: $resolved"
        }

        $dest = Join-Path $spillDir (Split-Path -Leaf $resolved)
        $n = 1
        while (Test-Path -LiteralPath $dest) {
            $dest = Join-Path $spillDir ("{0}_{1}" -f (Split-Path -Leaf $resolved), $n)
            $n += 1
        }
        Move-Item -LiteralPath $resolved -Destination $dest
        $moved += "$resolved -> $dest"
    }
}

$manifest = @(
    "timestamp=$stamp",
    "project_root=$projectRoot",
    "tcl=$tclPath",
    "vivado=$Vivado",
    "work_dir=$workDir",
    "log=$logFile",
    "journal=$journalFile",
    "droot_before_count=$($before.Count)",
    "droot_after_count=$($after.Count)",
    "new_droot_spill_count=$($newDirs.Count)",
    "vivado_exit_code=$exitCode"
)
if ($moved.Count -gt 0) {
    $manifest += "moved:"
    $manifest += $moved
}
$manifest | Set-Content -LiteralPath $manifestFile -Encoding ASCII

Write-Host "VIVADO_EXIT_CODE=$exitCode"
Write-Host "LOG=$logFile"
Write-Host "JOURNAL=$journalFile"
Write-Host "SPILL_MANIFEST=$manifestFile"
Write-Host "NEW_DROOT_SPILL_COUNT=$($newDirs.Count)"
if ($moved.Count -gt 0) {
    foreach ($line in $moved) {
        Write-Host "ARCHIVED_DROOT_ILA_SPILL=$line"
    }
}

exit $exitCode
