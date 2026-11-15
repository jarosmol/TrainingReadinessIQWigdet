<#
  Najde pravdepodobne duplicitne aktivity v intervals.icu (napr. ta ista jazda raz
  z Garmin Connect a raz zo Stravy alebo z rucneho uploadu).

  Pouzitie:
    powershell -ExecutionPolicy Bypass -File scripts\find-duplicates.ps1 [-Days 180]

  API kluc sa zada pri spusteni (nikam sa neuklada). Skript iba cita - nic nemaze.
  Za duplikat povazuje dve aktivity, ktore zacinaju do 15 minut od seba a (ak su udaje
  k dispozicii) maju podobne trvanie a zataz. Aktivity zo Stravy vracia API intervals.icu
  bez detailov (obmedzenie Stravy), tie sa porovnavaju iba podla casu zaciatku.
#>
param(
    [int]$Days = 180,
    [int]$WindowMinutes = 15
)
$ErrorActionPreference = "Stop"

$sec = Read-Host "intervals.icu API kluc" -AsSecureString
$key = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
$token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("API_KEY:$key"))
$headers = @{ Authorization = "Basic $token" }

$newest = (Get-Date).ToString("yyyy-MM-dd")
$oldest = (Get-Date).AddDays(-$Days).ToString("yyyy-MM-dd")
$url = "https://intervals.icu/api/v1/athlete/0/activities?oldest=$oldest&newest=$newest"
$acts = Invoke-RestMethod -Uri $url -Headers $headers

function Src($a) {
    if ($a.source) { return $a.source } else { return "?" }
}
function Dur($a) {
    if ($a.elapsed_time) { return [int]$a.elapsed_time }
    if ($a.moving_time) { return [int]$a.moving_time }
    return $null
}
function Near($x, $y, $tol) {
    if ($null -eq $x -or $null -eq $y -or $x -eq 0 -or $y -eq 0) { return $true }
    return [math]::Abs($x - $y) / [math]::Max($x, $y) -le $tol
}

$list = $acts | Where-Object { $_.start_date_local } |
    ForEach-Object {
        [pscustomobject]@{
            Id = $_.id
            Start = [datetime]$_.start_date_local
            Name = $_.name
            Source = Src $_
            Dur = Dur $_
            Load = $_.icu_training_load
        }
    } | Sort-Object Start

$found = 0
for ($i = 0; $i -lt $list.Count; $i++) {
    for ($j = $i + 1; $j -lt $list.Count; $j++) {
        $a = $list[$i]; $b = $list[$j]
        if (($b.Start - $a.Start).TotalMinutes -gt $WindowMinutes) { break }
        if (-not (Near $a.Dur $b.Dur 0.10)) { continue }
        if (-not (Near $a.Load $b.Load 0.15)) { continue }
        $found++
        Write-Host ""
        Write-Host ("{0:ddd dd.MM.yyyy HH:mm}" -f $a.Start) -ForegroundColor Yellow
        foreach ($x in @($a, $b)) {
            $d = if ($x.Dur) { [TimeSpan]::FromSeconds($x.Dur).ToString("h\:mm") } else { "-" }
            $l = if ($null -ne $x.Load) { $x.Load } else { "-" }
            Write-Host ("  {0,-16} {1,6}  load {2,4}  {3}" -f $x.Source, $d, $l, $x.Name)
            Write-Host ("  https://intervals.icu/activities/{0}" -f $x.Id) -ForegroundColor DarkGray
        }
    }
}
Write-Host ""
if ($found -eq 0) {
    Write-Host "Ziadne duplikaty za poslednych $Days dni."
} else {
    Write-Host "Najdenych dvojic: $found. Odporucanie: nechajte verziu z GARMIN_CONNECT (povodny FIT subor)," -ForegroundColor Cyan
    Write-Host "druhu v intervals.icu vymazte (ikona kosa v detaile aktivity)." -ForegroundColor Cyan
}
