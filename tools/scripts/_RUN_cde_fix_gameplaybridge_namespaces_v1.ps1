param([Parameter(Mandatory=$true)][string]$RepoRoot)
$ErrorActionPreference="Stop"
Set-StrictMode -Version Latest
function Die([string]$m){ throw $m }
function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ Die "Ensure-Dir: empty" }
  if(-not (Test-Path -LiteralPath $p -PathType Container)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}
function Write-Utf8NoBomLf([string]$path,[string]$text){
  $dir = Split-Path -Parent $path
  if(-not [string]::IsNullOrWhiteSpace($dir)){ Ensure-Dir $dir }
  $u = New-Object System.Text.UTF8Encoding($false)
  $bytes = $u.GetBytes($text.Replace("`r`n","`n"))
  [System.IO.File]::WriteAllBytes($path,$bytes)
}
function Backup-IfExists([string]$p){
  if(Test-Path -LiteralPath $p -PathType Leaf){
    $ts=[DateTime]::UtcNow.ToString("yyyyMMdd_HHmmssZ")
    $bak=($p + ".bak_" + $ts)
    Copy-Item -LiteralPath $p -Destination $bak -Force
    Write-Host ("BACKUP: " + $bak) -ForegroundColor Yellow
  }
}
function ReadAllTextUtf8([string]$p){ return [System.IO.File]::ReadAllText($p,[System.Text.Encoding]::UTF8) }

$RepoRootAbs = (Resolve-Path -LiteralPath $RepoRoot).Path
$GameProj = Join-Path $RepoRootAbs "src\CDE.Game\CDE.Game.csproj"
$GameplayDir = Join-Path $RepoRootAbs "src\CDE.Gameplay"
if(-not (Test-Path -LiteralPath $GameProj -PathType Leaf)){ Die ("MISSING_GAME_PROJECT: " + $GameProj) }
if(-not (Test-Path -LiteralPath $GameplayDir -PathType Container)){ Die ("MISSING_GAMEPLAY_DIR: " + $GameplayDir) }

# Ensure ProjectReference exists (fix if missing)
$csproj = ReadAllTextUtf8 $GameProj
if($csproj -notmatch "CDE\.Gameplay\.csproj"){
  Backup-IfExists $GameProj
  $ins = @("  <ItemGroup>","    <ProjectReference Include=""..\CDE.Gameplay\CDE.Gameplay.csproj"" />","  </ItemGroup>") -join "`n"
  $new = [System.Text.RegularExpressions.Regex]::Replace($csproj,"</Project>\s*$",($ins + "`n</Project>`n"))
  Write-Utf8NoBomLf $GameProj $new
  Write-Host ("PATCH_OK: added ProjectReference to CDE.Gameplay: " + $GameProj) -ForegroundColor Green
} else {
  Write-Host ("OK: Game already references Gameplay: " + $GameProj) -ForegroundColor Green
}

function Find-TypeNamespace([string]$RootDir,[string]$TypeName){
  $files = Get-ChildItem -LiteralPath $RootDir -Recurse -Filter *.cs -File
  foreach($f in $files){
    $t = ReadAllTextUtf8 $f.FullName
    if($t -match ("(\bclass\b|\brecord\b|\bstruct\b)\s+" + [System.Text.RegularExpressions.Regex]::Escape($TypeName) + "\b")){
      $ns = $null
      $m1 = [System.Text.RegularExpressions.Regex]::Match($t,"namespace\s+([A-Za-z0-9_\.]+)\s*;")
      if($m1.Success){ $ns = $m1.Groups[1].Value }
      else {
        $m2 = [System.Text.RegularExpressions.Regex]::Match($t,"namespace\s+([A-Za-z0-9_\.]+)\s*\{")
        if($m2.Success){ $ns = $m2.Groups[1].Value }
      }
      if([string]::IsNullOrWhiteSpace($ns)){
        Die ("FOUND_TYPE_NO_NAMESPACE: type=" + $TypeName + " file=" + $f.FullName)
      }
      return @{ Namespace=$ns; File=$f.FullName }
    }
  }
  return $null
}

$flag = Find-TypeNamespace $GameplayDir "FlagStore"
$warp = Find-TypeNamespace $GameplayDir "WarpKernel"
$world = Find-TypeNamespace $GameplayDir "KernelWorld"
if($flag -eq $null){ Die "MISSING_TYPE_IN_GAMEPLAY: FlagStore" }
if($warp -eq $null){ Die "MISSING_TYPE_IN_GAMEPLAY: WarpKernel" }
if($world -eq $null){ Die "MISSING_TYPE_IN_GAMEPLAY: KernelWorld" }
Write-Host ("FOUND: FlagStore ns=" + $flag.Namespace + " file=" + $flag.File) -ForegroundColor Yellow
Write-Host ("FOUND: WarpKernel ns=" + $warp.Namespace + " file=" + $warp.File) -ForegroundColor Yellow
Write-Host ("FOUND: KernelWorld ns=" + $world.Namespace + " file=" + $world.Namespace + " file=" + $world.File) -ForegroundColor Yellow

$BridgePath = Join-Path $RepoRootAbs "src\CDE.Game\GameplayBridge.cs"
Backup-IfExists $BridgePath

# Write GameplayBridge.cs using fully-qualified gameplay types (no guessed using directives)
$nsFlag = $flag.Namespace
$nsWarp = $warp.Namespace
$nsWorld = $world.Namespace
$bridgeLines = New-Object System.Collections.Generic.List[string]
[void]$bridgeLines.Add("using System.IO;")
[void]$bridgeLines.Add("using System.Text;")
[void]$bridgeLines.Add("")
[void]$bridgeLines.Add("namespace CDE.Game;")
[void]$bridgeLines.Add("")
[void]$bridgeLines.Add("internal sealed class GameplayBridge")
[void]$bridgeLines.Add("{")
[void]$bridgeLines.Add("    public enum Mode { Yume, Mario }")
[void]$bridgeLines.Add("    public Mode ActiveMode { get; private set; } = Mode.Yume;")
[void]$bridgeLines.Add("")
[void]$bridgeLines.Add("    public string SceneId { get; private set; } = ""StartRoom"";")
[void]$bridgeLines.Add("    public float X { get; private set; } = 1f;")
[void]$bridgeLines.Add("    public float Y { get; private set; } = 1f;")
[void]$bridgeLines.Add("")
[void]$bridgeLines.Add(("    public readonly " + $nsFlag + ".FlagStore Flags = new();"))
[void]$bridgeLines.Add(("    private " + $nsWarp + ".WarpKernel? _warp;"))
[void]$bridgeLines.Add(("    private " + $nsWorld + ".KernelWorld? _mario;"))
[void]$bridgeLines.Add("    public string Last { get; private set; } = """";")
[void]$bridgeLines.Add("")
[void]$bridgeLines.Add("    public void SetMode(Mode m)")
[void]$bridgeLines.Add("    {")
[void]$bridgeLines.Add("        ActiveMode = m;")
[void]$bridgeLines.Add("        if (m == Mode.Yume) { SceneId = ""StartRoom""; X = 1f; Y = 1f; }")
[void]$bridgeLines.Add("        else { SceneId = ""MarioRoom""; X = 0f; Y = 0f; }")
[void]$bridgeLines.Add("        Last = """";")
[void]$bridgeLines.Add("    }")
[void]$bridgeLines.Add("")
[void]$bridgeLines.Add("    public void LoadFromRepoRoot(string repoRoot)")
[void]$bridgeLines.Add("    {")
[void]$bridgeLines.Add("        var yumePath = Path.Combine(repoRoot, ""assets_src"", ""gameplay"", ""warp_graph.v1.json"");")
[void]$bridgeLines.Add("        var marioPath = Path.Combine(repoRoot, ""assets_src"", ""gameplay"", ""mario_graph.v1.json"");")
[void]$bridgeLines.Add("")
[void]$bridgeLines.Add("        if (File.Exists(yumePath))")
[void]$bridgeLines.Add("        {")
[void]$bridgeLines.Add("            var json = File.ReadAllText(yumePath, new UTF8Encoding(false));")
[void]$bridgeLines.Add(("            var g = " + $nsWarp + ".WarpKernel.LoadWarpGraphJson(json);"))
[void]$bridgeLines.Add(("            _warp = new " + $nsWarp + ".WarpKernel(g, Flags);"))
[void]$bridgeLines.Add("        }")
[void]$bridgeLines.Add("")
[void]$bridgeLines.Add("        if (File.Exists(marioPath))")
[void]$bridgeLines.Add("        {")
[void]$bridgeLines.Add("            var json = File.ReadAllText(marioPath, new UTF8Encoding(false));")
[void]$bridgeLines.Add(("            _mario = " + $nsWorld + ".KernelWorld.LoadMarioJson(json);"))
[void]$bridgeLines.Add("        }")
[void]$bridgeLines.Add("    }")
[void]$bridgeLines.Add("")
[void]$bridgeLines.Add("    public int GetCoins() => _mario?.Inventory.GetCount(""coin"") ?? 0;")
[void]$bridgeLines.Add("    public int GetCoinTarget() => _mario?.Objectives.CoinTarget ?? 0;")
[void]$bridgeLines.Add("")
[void]$bridgeLines.Add("    public void Move(float dx, float dy){ X += dx; Y += dy; }")
[void]$bridgeLines.Add("")
[void]$bridgeLines.Add("    public void Tick()")
[void]$bridgeLines.Add("    {")
[void]$bridgeLines.Add("        if (ActiveMode == Mode.Yume)")
[void]$bridgeLines.Add("        {")
[void]$bridgeLines.Add("            if (_warp == null) { Last = """"; return; }")
[void]$bridgeLines.Add(("            var r = _warp.TryWarp(new " + $nsWarp + ".WarpKernel.WarpRequest(SceneId, X, Y));"))
[void]$bridgeLines.Add("            if (r.Warped)")
[void]$bridgeLines.Add("            {")
[void]$bridgeLines.Add("                SceneId = r.NewSceneId; X = r.SpawnX; Y = r.SpawnY;")
[void]$bridgeLines.Add("                Last = r.MatchedWarpId;")
[void]$bridgeLines.Add("                return;")
[void]$bridgeLines.Add("            }")
[void]$bridgeLines.Add("            Last = """";")
[void]$bridgeLines.Add("        }")
[void]$bridgeLines.Add("        else")
[void]$bridgeLines.Add("        {")
[void]$bridgeLines.Add("            if (_mario == null) { Last = """"; return; }")
[void]$bridgeLines.Add(("            var p = new " + $nsWorld + ".KernelWorld.PlayerState(SceneId, X, Y);"))
[void]$bridgeLines.Add("            var r = _mario.Tick(p);")
[void]$bridgeLines.Add("            SceneId = r.Player.SceneId; X = r.Player.X; Y = r.Player.Y;")
[void]$bridgeLines.Add("            Last = r.MatchedTriggerId ?? """";")
[void]$bridgeLines.Add("        }")
[void]$bridgeLines.Add("    }")
[void]$bridgeLines.Add("}")

$bridgeText = (@($bridgeLines.ToArray()) -join "`n") + "`n"
Write-Utf8NoBomLf $BridgePath $bridgeText
Write-Host ("WROTE: " + $BridgePath) -ForegroundColor Green

Write-Host "NOW_BUILD: dotnet build .\CDE.sln -c Debug" -ForegroundColor Yellow
