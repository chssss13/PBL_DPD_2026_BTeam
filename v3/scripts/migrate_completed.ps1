$ErrorActionPreference = 'Stop'
$taskWorkspace = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Wait-Process -Id 23664 -ErrorAction SilentlyContinue
$taskSource = Join-Path $taskWorkspace 'v2\results\v2.5'
$taskStatePath = Join-Path $taskSource 'state.json'
$taskState = Get-Content -LiteralPath $taskStatePath -Raw | ConvertFrom-Json
if ($taskState.completed -notcontains 'impl') { throw 'Implementation is not complete; no files moved.' }
if (-not (Test-Path -LiteralPath (Join-Path $taskWorkspace 'v2\results\HIDDEN_METRICS.md'))) { throw 'Summary is missing; no files moved.' }
$taskPairs = @(
    @('v2\results\v2.5', 'v3\results\v3.1'),
    @('v2\prj_step_v2_5', 'v3\prj_v3_1_original'),
    @('v2\results\HIDDEN_METRICS.md', 'v3\results\COMPARISON.md'),
    @('v2\results\hidden_metrics.json', 'v3\results\metrics.json')
)
foreach ($taskPair in $taskPairs) {
    foreach ($taskRelative in $taskPair) {
        $taskAbsolute = [System.IO.Path]::GetFullPath((Join-Path $taskWorkspace $taskRelative))
        if (-not $taskAbsolute.StartsWith($taskWorkspace + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw "Outside workspace: $taskAbsolute" }
    }
    if (Test-Path -LiteralPath (Join-Path $taskWorkspace $taskPair[1])) { throw "Destination exists: $($taskPair[1])" }
    if (-not (Test-Path -LiteralPath (Join-Path $taskWorkspace $taskPair[0]))) { throw "Source missing: $($taskPair[0])" }
}
foreach ($taskPair in $taskPairs) {
    Move-Item -LiteralPath (Join-Path $taskWorkspace $taskPair[0]) -Destination (Join-Path $taskWorkspace $taskPair[1])
    Write-Output "Moved $($taskPair[0]) -> $($taskPair[1])"
}
$taskPython = 'C:\Project\venv_dpd\Scripts\python.exe'
& $taskPython (Join-Path $PSScriptRoot 'finish_migration.py')
if ($LASTEXITCODE -ne 0) { throw 'Final metadata verification failed.' }
