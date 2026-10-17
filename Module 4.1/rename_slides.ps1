<#
.SYNOPSIS
Rename all *.png in the current directory that don't start with the prefix
(or any excluded prefix) to <prefix>_<N>.png, ordered by modification time
(oldest first). Numbering continues after the highest existing
<prefix>_<N>.png.

.EXAMPLE
./rename_slides.ps1 [prefix] [-DryRun] [-Exclude EXCLUDE]...
./rename_slides.ps1 [-DryRun] [prefix]

prefix defaults to "slide".
Excluded prefixes (repeatable, e.g. -Exclude fig,sketch) are never renamed.
"slide" is always excluded, so renaming to another prefix leaves
slide_*.png untouched.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Prefix = 'slide',

    [Alias('n', 'dry-run')]
    [switch]$DryRun,

    [Alias('e')]
    [string[]]$Exclude = @(),

    [Alias('h')]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$unbound = $MyInvocation.UnboundArguments
if ($Help -or ($PSBoundParameters.Count -eq 0 -and (-not $unbound -or $unbound.Count -eq 0))) {
    Get-Help $MyInvocation.MyCommand.Path -Full | Out-Host
    exit 0
}

if ([string]::IsNullOrEmpty($Prefix)) {
    Write-Error 'prefix cannot be empty.'
}

# The current prefix and "slide" are always excluded; user-supplied
# exclusions are appended.
$excludes = @('slide', $Prefix) + $Exclude

# --- 1. Find the highest existing <prefix>_<N>.png so we start at N+1 ---
$prefixPattern = '^{0}_(\d+)\.png$' -f [regex]::Escape($Prefix)
$maxN = 0
foreach ($f in (Get-ChildItem -File -Filter '*.png')) {
    if ($f.Name -match $prefixPattern) {
        $maxN = [Math]::Max($maxN, [int]$Matches[1])
    }
}

# --- 2. Collect candidate files (non-prefixed *.png), oldest mtime first ---
$candidates = Get-ChildItem -File -Filter '*.png' |
    Where-Object {
        $name = $_.Name
        -not ($excludes | Where-Object { $name -like "$_*" })
    } |
    Sort-Object LastWriteTime

if (-not $candidates) {
    Write-Host "No non-$Prefix *.png files found. Nothing to do."
    exit 0
}

# --- 3. Rename in ascending mtime order, starting at maxN + 1 ---
$n = $maxN
foreach ($file in $candidates) {
    $n++
    $target = '{0}_{1}.png' -f $Prefix, $n
    if (Test-Path -LiteralPath $target) {
        Write-Error "Refusing to overwrite existing file: $target"
    }
    if ($DryRun) {
        Write-Host "[dry-run] $($file.Name) -> $target"
    }
    else {
        Rename-Item -LiteralPath $file.FullName -NewName $target
        Write-Host "renamed: $($file.Name) -> $target"
    }
}

Write-Host ("Done. Started numbering at {0}_{1}.png (previous max: {0}_{2}.png)." -f $Prefix, ($maxN + 1), $maxN)
