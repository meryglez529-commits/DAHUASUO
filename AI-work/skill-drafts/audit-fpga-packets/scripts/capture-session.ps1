[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$FpgaIp,

    [int[]]$Ports = @(32000),

    [string]$Interface,

    [ValidateRange(1, 86400)]
    [int]$DurationSeconds = 30,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [ValidateSet('auto', 'tshark', 'pktmon')]
    [string]$Backend = 'auto',

    [switch]$ReplaceExistingPktmonFilters,

    [switch]$ListInterfaces
)

$ErrorActionPreference = 'Stop'

function Resolve-Backend {
    param([string]$Requested)
    if ($Requested -ne 'auto') { return $Requested }
    if (Get-Command tshark -ErrorAction SilentlyContinue) { return 'tshark' }
    if (Get-Command pktmon -ErrorAction SilentlyContinue) { return 'pktmon' }
    throw 'No supported capture backend found. Install TShark/Npcap or use Windows pktmon.'
}

$selected = Resolve-Backend $Backend
if ($ListInterfaces) {
    if ($selected -eq 'tshark') {
        & tshark -D
    }
    else {
        & pktmon list
    }
    exit $LASTEXITCODE
}

if ([string]::IsNullOrWhiteSpace($FpgaIp)) {
    throw 'Capture requires -FpgaIp.'
}

$target = [System.IO.Path]::GetFullPath($OutputPath)
$targetDirectory = [System.IO.Path]::GetDirectoryName($target)
if (-not [string]::IsNullOrWhiteSpace($targetDirectory)) {
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
}

Write-Host "backend=$selected"
Write-Host "fpga_ip=$FpgaIp"
Write-Host "ports=$($Ports -join ',')"
$interfaceDisplay = if ([string]::IsNullOrWhiteSpace($Interface)) { 'auto' } else { $Interface }
Write-Host "interface=$interfaceDisplay"
Write-Host "duration_seconds=$DurationSeconds"
Write-Host "output=$target"

if ($selected -eq 'tshark') {
    if ([string]::IsNullOrWhiteSpace($Interface)) {
        throw 'TShark capture requires -Interface. Run with -ListInterfaces first.'
    }
    $portFilter = ($Ports | ForEach-Object { "port $_" }) -join ' or '
    $captureFilter = "host $FpgaIp and udp and ($portFilter)"
    $arguments = @('-i', $Interface, '-f', $captureFilter, '-a', "duration:$DurationSeconds", '-w', $target)
    Write-Host "filter=$captureFilter"
    if ($PSCmdlet.ShouldProcess($target, "Capture with tshark: tshark $($arguments -join ' ')")) {
        & tshark @arguments
        if ($LASTEXITCODE -ne 0) { throw "tshark failed with exit code $LASTEXITCODE" }
    }
    exit 0
}

$existingFilters = (& pktmon filter list 2>&1 | Out-String).Trim()
$filterLines = @($existingFilters -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
# Localized pktmon output contains one heading plus one localized "none" line
# when no filters exist. Active filters add detail lines, independent of locale.
$hasExistingFilters = $filterLines.Count -gt 2
if ($hasExistingFilters -and -not $ReplaceExistingPktmonFilters) {
    throw "pktmon already has active filters. Refusing to broaden or replace capture scope. Re-run with -ReplaceExistingPktmonFilters only after reviewing: $existingFilters"
}

$etlPath = [System.IO.Path]::ChangeExtension($target, '.etl')
$pktmonComponent = if ([string]::IsNullOrWhiteSpace($Interface)) { 'nics' } else { $Interface }
$statusLines = @((& pktmon status 2>&1 | Out-String).Trim() -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($statusLines.Count -gt 1) {
    throw "pktmon appears to be running already. Refusing to stop or replace another capture: $($statusLines -join ' | ')"
}
$captureStarted = $false
$filtersChanged = $false
try {
    if ($PSCmdlet.ShouldProcess('pktmon filters', 'Replace with FPGA-only UDP filters')) {
        & pktmon filter remove | Out-Null
        $filtersChanged = $true
        foreach ($port in $Ports) {
            & pktmon filter add "FPGA_$port" -i $FpgaIp -t UDP -p $port | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "pktmon filter add failed for port $port" }
        }
    }
    if ($PSCmdlet.ShouldProcess($etlPath, 'Start pktmon capture')) {
        & pktmon start --capture --comp $pktmonComponent --pkt-size 0 --file-name $etlPath --log-mode circular | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "pktmon start failed with exit code $LASTEXITCODE" }
        $captureStarted = $true
        Start-Sleep -Seconds $DurationSeconds
        & pktmon stop | Out-Null
        $captureStarted = $false
        & pktmon etl2pcap $etlPath --out $target | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "pktmon etl2pcap failed with exit code $LASTEXITCODE" }
    }
}
finally {
    if ($captureStarted) {
        & pktmon stop 2>$null | Out-Null
    }
    if ($filtersChanged) {
        & pktmon filter remove 2>$null | Out-Null
    }
}

Write-Host "capture=$target"
