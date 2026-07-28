param(
    [int]$Minimum = 4000,
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
$files = Get-ChildItem -LiteralPath $resolvedRoot -File -Filter '*.mbt' |
    Where-Object {
        $_.Name -notmatch '(_test|_wbtest)\.mbt$'
    } |
    Sort-Object Name

if ($files.Count -eq 0) {
    throw "No production MoonBit files found in $resolvedRoot"
}

$rows = foreach ($file in $files) {
    $lines = @(Get-Content -LiteralPath $file.FullName -Encoding UTF8)
    $nonBlank = @($lines | Where-Object { $_.Trim().Length -gt 0 }).Count
    [pscustomobject]@{
        File = $file.Name
        NonBlankLines = $nonBlank
    }
}

$rows | Format-Table -AutoSize
$total = ($rows | Measure-Object -Property NonBlankLines -Sum).Sum
Write-Host "Production MoonBit non-blank lines: $total"
Write-Host "Required minimum: $Minimum"

if ($total -lt $Minimum) {
    throw "Production workload is below the required minimum ($total < $Minimum)"
}
