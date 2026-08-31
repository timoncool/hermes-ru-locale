# Hermes Agent — русская локализация рабочего стола (Desktop)
# Запуск:            powershell -ExecutionPolicy Bypass -File install.ps1
# Ручной путь:       powershell -ExecutionPolicy Bypass -File install.ps1 -Path "C:\путь\к\hermes-agent"
#
# Безопасно: идемпотентно (повторный запуск ничего не дублирует), устойчиво к любому
# набору уже установленных языков, перед изменением каждого файла делает <файл>.bak.

param([string]$Path)
$ErrorActionPreference = "Stop"

Write-Host "`n=== Hermes Desktop - русская локализация ===`n" -ForegroundColor Cyan

# --- 1. Найти десктопный i18n (папка с catalog.ts + define-locale.ts + en.ts) ---
function Find-DesktopI18n($root) {
  if (-not (Test-Path $root)) { return $null }
  Get-ChildItem -Path $root -Recurse -Filter "catalog.ts" -ErrorAction SilentlyContinue |
    Where-Object {
      $d = $_.DirectoryName
      ($d -match 'desktop') -and (Test-Path (Join-Path $d 'define-locale.ts')) -and (Test-Path (Join-Path $d 'en.ts'))
    } |
    Select-Object -First 1 -ExpandProperty DirectoryName
}

$roots = @()
if ($Path) { $roots += $Path }
$hc = Get-Command hermes -ErrorAction SilentlyContinue
if ($hc) { $roots += (Split-Path (Split-Path $hc.Source)) }
$roots += "$env:LOCALAPPDATA\hermes\hermes-agent"

$i18nDir = $null
foreach ($r in $roots) { $i18nDir = Find-DesktopI18n $r; if ($i18nDir) { break } }

if (-not $i18nDir) {
  Write-Host "[X] Не найден десктопный i18n Hermes (catalog.ts + define-locale.ts)." -ForegroundColor Red
  Write-Host "    Укажите путь вручную:  .\install.ps1 -Path `"C:\путь\к\hermes-agent`""
  exit 1
}
$srcDir      = Split-Path $i18nDir       # ...\src
$desktopDir  = Split-Path $srcDir        # ...\apps\desktop (или аналог)
$settingsDir = Join-Path $srcDir 'app\settings'
Write-Host "[OK] Найдено: $i18nDir" -ForegroundColor Green

$scriptDir = Split-Path $MyInvocation.MyCommand.Path
function Backup($f) { if ((Test-Path $f) -and -not (Test-Path "$f.bak")) { Copy-Item $f "$f.bak" } }
function WriteUtf8($f, $text) { [IO.File]::WriteAllText($f, $text, (New-Object System.Text.UTF8Encoding $false)) }
# ЕДИНСТВЕННАЯ замена (в PowerShell у [regex]::Replace 4-й аргумент — это RegexOptions, а не count!)
function ReplaceOnce($text, $pattern, [scriptblock]$fn) {
  $ev = [System.Text.RegularExpressions.MatchEvaluator]$fn
  return ([regex]::new($pattern)).Replace($text, $ev, 1)
}

# --- 2. Копируем файлы перевода ---
Copy-Item "$scriptDir\ru.ts" (Join-Path $i18nDir 'ru.ts') -Force
Write-Host "[OK] ru.ts скопирован" -ForegroundColor Green
if (Test-Path $settingsDir) {
  Copy-Item "$scriptDir\ru-constants.ts" (Join-Path $settingsDir 'ru-constants.ts') -Force
  Write-Host "[OK] ru-constants.ts скопирован" -ForegroundColor Green
} else {
  Write-Host "[!] Папка settings не найдена - лейблы настроек останутся английскими" -ForegroundColor Yellow
}

# --- 3. Идемпотентные патчи регистрации ---
function Patch($file, $skipPattern, [scriptblock]$fn) {
  $name = Split-Path $file -Leaf
  if (-not (Test-Path $file)) { Write-Host "[!] нет $name" -ForegroundColor Yellow; return }
  $c = Get-Content $file -Raw -Encoding UTF8
  if ($c -match $skipPattern) { Write-Host "[=] $name уже настроен" -ForegroundColor DarkGray; return }
  Backup $file
  $new = & $fn $c
  if ($new -and ($new -ne $c)) { WriteUtf8 $file $new; Write-Host "[OK] $name пропатчен" -ForegroundColor Green }
  else { Write-Host "[!] не удалось пропатчить $name (структура изменилась) - проверьте вручную" -ForegroundColor Yellow }
}

# types.ts: добавить 'ru' в объединение Locale (в конец строки, к любому набору языков)
Patch (Join-Path $i18nDir 'types.ts') "\|\s*'ru'" {
  param($c)
  ReplaceOnce $c "(export type Locale\s*=[^\r\n]*?)(\r?\n)" { param($m) $m.Groups[1].Value + " | 'ru'" + $m.Groups[2].Value }
}

# catalog.ts: импорт ru + запись ru в объект TRANSLATIONS
Patch (Join-Path $i18nDir 'catalog.ts') "import \{ ru \}" {
  param($c)
  $c = ReplaceOnce $c "(import [^\r\n]+ from '\./[^']+'\r?\n)" { param($m) $m.Value + "import { ru } from './ru'`n" }
  $c = ReplaceOnce $c "(TRANSLATIONS[^{]*\{[\s\S]*?)(\r?\n\})" { param($m) $m.Groups[1].Value + ",`n  ru" + $m.Groups[2].Value }
  $c
}

# languages.ts: запись в LOCALE_OPTIONS + алиасы в LOCALE_ALIASES
Patch (Join-Path $i18nDir 'languages.ts') "id:\s*'ru'" {
  param($c)
  $entry = "  {`n    id: 'ru',`n    name: 'Русский',`n    englishName: 'Russian',`n    configValue: 'ru'`n  }"
  $c = ReplaceOnce $c "(\r?\n)(\] as const)" { param($m) "," + $m.Groups[1].Value + $entry + $m.Groups[1].Value + $m.Groups[2].Value }
  $c = ReplaceOnce $c "(LOCALE_ALIASES[^{]*\{[\s\S]*?)(\r?\n\})" { param($m) $m.Groups[1].Value + ",`n  ru: 'ru',`n  'ru-ru': 'ru',`n  ru_ru: 'ru',`n  'русский': 'ru'" + $m.Groups[2].Value }
  $c
}

# --- 4. Сборка ---
Write-Host "`nСборка десктопа (может занять пару минут)..." -ForegroundColor Cyan
Push-Location $desktopDir
try {
  $log = & npm run build 2>&1
  if ($LASTEXITCODE -eq 0) { Write-Host "[OK] Сборка завершена" -ForegroundColor Green }
  else { $log | Select-Object -Last 6; throw "npm build вернул код $LASTEXITCODE" }
} catch {
  Write-Host "[!] Автосборка не удалась. Файлы уже установлены; соберите вручную:" -ForegroundColor Yellow
  Write-Host "    cd `"$desktopDir`"; npm install; npm run build"
} finally { Pop-Location }

Write-Host "`n=== Готово. Перезапустите Hermes -> Settings -> Appearance -> Русский ===`n" -ForegroundColor Cyan
