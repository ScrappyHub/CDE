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
$ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ")
$bak=($RunnerPath + ".bak_" + $ts)
Copy-Item -LiteralPath $RunnerPath -Destination $bak -Force
Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow

$lines = [System.IO.File]::ReadAllLines($RunnerPath,[System.Text.Encoding]::UTF8)
$out = New-Object System.Collections.Generic.List[string]
$changes = 0

function NextNonBlank([string[]]$arr,[int]$start){
  for($k=$start; $k -lt $arr.Length; $k++){
    if(-not [string]::IsNullOrWhiteSpace($arr[$k])){ return $k }
  }
  return -1
}

for($i=0; $i -lt $lines.Length; $i++){
  $ln = $lines[$i]
  $isQuotedWithComma = [System.Text.RegularExpressions.Regex]::IsMatch($ln, '^\s*''.*''\s*,\s*$')
  $isBraceWithComma  = [System.Text.RegularExpressions.Regex]::IsMatch($ln, '^\s*\}\s*,\s*$')
  if($isQuotedWithComma -or $isBraceWithComma){
    $j = NextNonBlank $lines ($i + 1)
    if($j -ge 0 -and [System.Text.RegularExpressions.Regex]::IsMatch($lines[$j], '^\s*\)\s*$')){
      $ln2 = [System.Text.RegularExpressions.Regex]::Replace($ln, ',\s*$', '')
      if($ln2 -ne $ln){ $ln = $ln2; $changes++ }
    }
  }
  [void]$out.Add($ln)
}

$newText = (@($out.ToArray()) -join "`n") + "`n"
Write-Utf8NoBomLf $RunnerPath $newText
Write-Host ("PATCH_OK: removed trailing commas before close-paren. changes=" + $changes) -ForegroundColor Green
