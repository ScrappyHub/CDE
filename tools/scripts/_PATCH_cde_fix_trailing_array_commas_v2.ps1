param([Parameter(Mandatory=$true)][string]$RunnerPath)

$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest

function Die([string]$m){ throw $m }
function Write-Utf8NoBomLf([string]$path,[string]$text){
  $u = New-Object System.Text.UTF8Encoding($false)
  $bytes = $u.GetBytes($text.Replace("`r`n","`n"))
  [System.IO.File]::WriteAllBytes($path,$bytes)
}

if(-not (Test-Path -LiteralPath $RunnerPath -PathType Leaf)){ Die ("MISSING_RUNNER: " + $RunnerPath) }
$ts = [DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ")
$bak = ($RunnerPath + ".bak_" + $ts)
Copy-Item -LiteralPath $RunnerPath -Destination $bak -Force
Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow

$lines = [System.IO.File]::ReadAllLines($RunnerPath,[System.Text.Encoding]::UTF8)
$out = New-Object System.Collections.Generic.List[string]
$changes = 0

for($i=0; $i -lt $lines.Length; $i++){
  $ln = $lines[$i]
  $trim = $ln.Trim()
  if($trim -eq "'}',"){
    $j = $i + 1
    while($j -lt $lines.Length -and [string]::IsNullOrWhiteSpace($lines[$j])){ $j++ }
    if($j -lt $lines.Length){
      $nextTrim = $lines[$j].Trim()
      if($nextTrim -eq ")"){
        $indentLen = $ln.Length - $ln.TrimStart().Length
        $indent = ""
        if($indentLen -gt 0){ $indent = $ln.Substring(0,$indentLen) }
        $ln = ($indent + "'}'")
        $changes++
      }
    }
  }
  [void]$out.Add($ln)
}

$newText = (@($out.ToArray()) -join "`n") + "`n"
Write-Utf8NoBomLf $RunnerPath $newText
Write-Host ("PATCH_OK: removed trailing array commas before close-paren. changes=" + $changes) -ForegroundColor Green
