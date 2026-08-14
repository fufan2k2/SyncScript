param(
    [string]$BatchPath = "D:\TACSyncPicture_ETC\EWSI_SyncImagev2\EWSI_SyncImagev2\EWSI_SyncImagev2\SyncSettings.ffs_batch",
    [string]$Now,
    [string]$BackupFolder,
    [string]$LogFolder,
    [switch]$NoBackup,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Now)) {
    $runTime = Get-Date
} else {
    $runTime = [datetime]::Parse($Now, [Globalization.CultureInfo]::InvariantCulture)
}

function Write-UpdateLog {
    param([string]$Message)

    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $line = "[$timestamp] $Message"
    Write-Host $line

    if ($script:LogFilePath) {
        Add-Content -LiteralPath $script:LogFilePath -Value $line -Encoding UTF8
    }
}

function Test-DateExcludeRule {
    param([string]$Value)
    if ($Value -notmatch '^\*\\(?<number>\d+)\*\\\*$') {
        return $false
    }

    $length = $Matches.number.Length
    return $length -ne 4 -and $length -ne 6
}

function Test-MonthExcludeRule {
    param([string]$Value)
    return $Value -match '^\*\\\d{6}\*\\\*$'
}

function Test-YearExcludeRule {
    param([string]$Value)
    return $Value -match '^\*\\\d{4}\*\\\*$'
}

function Test-GeneratedExcludeRule {
    param([string]$Value)
    return $Value -match '^\*\\\d+\*\\\*$'
}

function New-ExcludeRule {
    param([string]$DateText)
    return "*\$DateText*\*"
}

function New-DateExcludeRulesForCurrentMonth {
    param([datetime]$Now)

    $firstDayOfMonth = [datetime]::new($Now.Year, $Now.Month, 1)
    $lastCompletedDay = $Now.Date.AddDays(-1)
    $rules = @()

    for ($date = $firstDayOfMonth; $date -le $lastCompletedDay; $date = $date.AddDays(1)) {
        $rules += New-ExcludeRule ($date.ToString("yyyyMMdd"))
    }

    return $rules
}

if (-not (Test-Path -LiteralPath $BatchPath)) {
    throw "Batch file not found: $BatchPath"
}

if (-not $WhatIf) {
    if ([string]::IsNullOrWhiteSpace($LogFolder)) {
        $batchDirectory = Split-Path -Path $BatchPath -Parent
        $LogFolder = Join-Path -Path $batchDirectory -ChildPath "LogFiles\UpdateExclude"
    }

    if (-not (Test-Path -LiteralPath $LogFolder)) {
        New-Item -ItemType Directory -Path $LogFolder | Out-Null
    }

    $script:LogFilePath = Join-Path -Path $LogFolder -ChildPath "$($runTime.ToString('yyyy-MM-dd')).txt"
    Write-UpdateLog "Started exclude update. BatchPath=$BatchPath"
}

[xml]$xml = Get-Content -LiteralPath $BatchPath -Raw -Encoding UTF8
$excludeNode = $xml.FreeFileSync.Filter.Exclude
if ($null -eq $excludeNode) {
    throw "Cannot find FreeFileSync/Filter/Exclude in $BatchPath"
}

$existingRules = @($excludeNode.Item | ForEach-Object { [string]$_ })
$staticRules = @($existingRules | Where-Object {
    -not (Test-GeneratedExcludeRule $_)
})

$generatedRules = @($existingRules | Where-Object {
    Test-GeneratedExcludeRule $_
})

$previousDay = $runTime.Date.AddDays(-1)

if ($runTime.Month -eq 1 -and $runTime.Day -eq 1) {
    $newRule = New-ExcludeRule ($previousDay.ToString("yyyy"))
    $keptGeneratedRules = @($generatedRules | Where-Object { Test-YearExcludeRule $_ })
} elseif ($runTime.Day -eq 1) {
    $newRule = New-ExcludeRule ($previousDay.ToString("yyyyMM"))
    $keptGeneratedRules = @($generatedRules | Where-Object { -not (Test-DateExcludeRule $_) })
} else {
    $newRule = New-DateExcludeRulesForCurrentMonth $runTime
    $keptGeneratedRules = @($generatedRules)
}

$finalRules = @($staticRules + $keptGeneratedRules + $newRule) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Select-Object -Unique

if ($WhatIf) {
    $finalRules
    return
}

$currentRules = @($existingRules | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$hasChanges = ($currentRules.Count -ne $finalRules.Count)
if (-not $hasChanges) {
    for ($index = 0; $index -lt $currentRules.Count; $index++) {
        if ($currentRules[$index] -ne $finalRules[$index]) {
            $hasChanges = $true
            break
        }
    }
}

if (-not $hasChanges) {
    Write-UpdateLog "No changes needed. Exclude filter is already up to date."
    return
}

if (-not $NoBackup) {
    if ([string]::IsNullOrWhiteSpace($BackupFolder)) {
        $batchDirectory = Split-Path -Path $BatchPath -Parent
        $BackupFolder = Join-Path -Path $batchDirectory -ChildPath "BackupFiles"
    }

    if (-not (Test-Path -LiteralPath $BackupFolder)) {
        New-Item -ItemType Directory -Path $BackupFolder | Out-Null
    }

    $batchFileName = Split-Path -Path $BatchPath -Leaf
    $backupPath = Join-Path -Path $BackupFolder -ChildPath "$batchFileName.$($runTime.ToString('yyyyMMddHHmmss')).bak"
    Copy-Item -LiteralPath $BatchPath -Destination $backupPath -Force
    Write-UpdateLog "Backup created: $backupPath"
}

$excludeNode.RemoveAll()
foreach ($rule in $finalRules) {
    $item = $xml.CreateElement("Item")
    $item.InnerText = $rule
    [void]$excludeNode.AppendChild($item)
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$writerSettings = New-Object System.Xml.XmlWriterSettings
$writerSettings.Encoding = $utf8NoBom
$writerSettings.Indent = $true
$writerSettings.NewLineChars = "`r`n"

$writer = [System.Xml.XmlWriter]::Create($BatchPath, $writerSettings)
try {
    $xml.Save($writer)
} finally {
    $writer.Close()
}

Write-UpdateLog "Updated exclude filter in $BatchPath"
if ($NoBackup) {
    Write-UpdateLog "Backup skipped."
}
