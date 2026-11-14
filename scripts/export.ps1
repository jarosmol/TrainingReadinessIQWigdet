<#
  Export widgetu do Connect IQ obchodu (subory .iq).

  Spustenie z priecinka projektu (terminal vo VS Code):
      powershell -ExecutionPolicy Bypass -File scripts\export.ps1              # verejna aj beta
      powershell -ExecutionPolicy Bypass -File scripts\export.ps1 -Only beta   # len beta
      powershell -ExecutionPolicy Bypass -File scripts\export.ps1 -Only public # len verejna

  Vystup:
      export\Readiness.iq       -> verejna aplikacia (ID 2de113d6...)
      export\Readiness-beta.iq  -> beta aplikacia    (ID fd723a7f..., nazov "... BETA")

  Developer key: -DeveloperKey <cesta>, inak cesta z nastaveni VS Code (Monkey C: Developer Key Path),
  inak Dokumenty\garmin\developer_key. Aktualizacie v obchode musia byt podpisane TYM ISTYM klucom.
#>
param(
    [ValidateSet("all", "public", "beta")]
    [string]$Only = "all",
    [string]$DeveloperKey = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$PublicId = "2de113d694ab4575bc0cadee4c950ea9"
$BetaId   = "fd723a7f78794bdaa61d618167a331e6"

# --- 1. API kluc nesmie byt v properties.xml (stal by sa predvolenou hodnotou v obchode)
$props = "resources\properties\properties.xml"
if (-not (Test-Path $props)) {
    Copy-Item "properties.example.xml" $props
    Write-Host "Vytvoril som $props zo vzoru."
}
$propsText = Get-Content $props -Raw
$m = [regex]::Match($propsText, '<property id="apiKey" type="string">([^<]*)</property>')
if (-not $m.Success) {
    throw "V $props chyba vlastnost apiKey."
}
$keyValue = $m.Groups[1].Value.Trim()
if ($keyValue -ne "" -and $keyValue -ne "SEM_VLOZTE_API_KLUC") {
    throw "V $props je API kluc! Pred exportom tam vratte SEM_VLOZTE_API_KLUC (kluc sa zadava v Garmin Connect)."
}

# --- 2. Connect IQ SDK a developer key
$ciq = Join-Path $env:APPDATA "Garmin\ConnectIQ"
$cfg = Join-Path $ciq "current-sdk.cfg"
$sdk = $null
if (Test-Path $cfg) {
    $sdk = (Get-Content $cfg -Raw).Trim()
}
if (-not $sdk -or -not (Test-Path $sdk)) {
    $sdk = (Get-ChildItem (Join-Path $ciq "Sdks") -Directory | Sort-Object Name | Select-Object -Last 1).FullName
}
$monkeyc = Join-Path $sdk "bin\monkeyc.bat"
if (-not (Test-Path $monkeyc)) {
    throw "Nenasiel som Connect IQ SDK ($monkeyc). Nastavte aktivne SDK v SDK Manageri."
}
if (-not $DeveloperKey) {
    # 1) nastavenie rozsirenia Monkey C vo VS Code (monkeyC.developerKeyPath)
    $vsSettings = Join-Path $env:APPDATA "Code\User\settings.json"
    if (Test-Path $vsSettings) {
        $mk = [regex]::Match((Get-Content $vsSettings -Raw), '"monkeyC\.developerKeyPath"\s*:\s*"([^"]+)"')
        if ($mk.Success) {
            $DeveloperKey = $mk.Groups[1].Value.Replace('\\', '\')
            Write-Host "Developer key z nastaveni VS Code: $DeveloperKey"
        }
    }
}
if (-not $DeveloperKey) {
    # 2) predvolene umiestnenie
    $DeveloperKey = Join-Path $env:USERPROFILE "Documents\garmin\developer_key"
}
if (-not (Test-Path $DeveloperKey)) {
    throw "Nenasiel som developer key: $DeveloperKey. Spustite s -DeveloperKey <cesta>. Pouzite ten isty kluc ako pri predoslej verzii v obchode."
}
Write-Host "SDK: $sdk"

New-Item -ItemType Directory -Force "export" | Out-Null

function Export-Iq([string]$jungle, [string]$out) {
    Write-Host ""
    Write-Host "=== Export $out ($jungle) ==="
    & $monkeyc -f $jungle -o $out -y $DeveloperKey -e -r -w
    if ($LASTEXITCODE -ne 0) {
        throw "Export $out zlyhal. Ak chyba hodinky, stiahnite ich v SDK Manageri (Devices)."
    }
}

# --- 3. Verejna verzia
if ($Only -ne "beta") {
    Export-Iq "monkey.jungle" "export\Readiness.iq"
}

# --- 4. Beta verzia: manifest z manifest.xml s inym ID a nazvom
if ($Only -ne "public") {
    $manifest = Get-Content "manifest.xml" -Raw
    if (-not $manifest.Contains("id=""$PublicId""")) {
        throw "V manifest.xml som nenasiel ID verejnej verzie $PublicId."
    }
    $manifest = $manifest.Replace("id=""$PublicId""", "id=""$BetaId""")
    $manifest = $manifest.Replace('name="@Strings.AppName"', 'name="@Strings.AppNameBeta"')
    # UTF-8 bez BOM (Java parser manifestu BOM neznasa)
    [System.IO.File]::WriteAllText((Join-Path $root "manifest-beta.xml"), $manifest)
    Export-Iq "beta.jungle" "export\Readiness-beta.iq"
}

Write-Host ""
Write-Host "Hotovo. Subory su v priecinku export\"
Get-ChildItem "export\*.iq" | ForEach-Object { Write-Host ("  " + $_.Name + "  (" + [math]::Round($_.Length / 1KB) + " kB)") }
