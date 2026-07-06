# Hermes Agent — Русская локализация
# Установщик для Windows (PowerShell)
# Использование: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

Write-Host "`n🇷🇺 Hermes Agent — Русская локализация`n" -ForegroundColor Cyan

# 1. Найти установку Hermes
$hermesBin = Get-Command hermes -ErrorAction SilentlyContinue
if (-not $hermesBin) {
    $hermesDir = "$env:LOCALAPPDATA\hermes\hermes-agent"
} else {
    $hermesDir = Split-Path (Split-Path $hermesBin.Source)
}

$i18nDir = "$hermesDir\apps\desktop\src\i18n"
$settingsDir = "$hermesDir\apps\desktop\src\app\settings"

if (-not (Test-Path $i18nDir)) {
    Write-Host "❌ Hermes не найден в $hermesDir" -ForegroundColor Red
    Write-Host "Укажите путь вручную: .\install.ps1 -Path C:\path\to\hermes-agent"
    exit 1
}

Write-Host "✅ Hermes найден: $hermesDir" -ForegroundColor Green

# 2. Копируем файлы перевода
$scriptDir = Split-Path $MyInvocation.MyCommand.Path
Copy-Item "$scriptDir\ru.ts" "$i18nDir\ru.ts" -Force
Copy-Item "$scriptDir\ru-constants.ts" "$settingsDir\ru-constants.ts" -Force
Write-Host "✅ Файлы ru.ts и ru-constants.ts скопированы" -ForegroundColor Green

# 3. Патчим types.ts — добавляем 'ru' в Locale
$typesFile = "$i18nDir\types.ts"
$typesContent = Get-Content $typesFile -Raw
if ($typesContent -notmatch "'ru'") {
    $typesContent = $typesContent -replace "export type Locale = 'en' \| 'zh' \| 'zh-hant' \| 'ja'", "export type Locale = 'en' | 'zh' | 'zh-hant' | 'ja' | 'ru'"
    $typesContent | Set-Content $typesFile -NoNewline
    Write-Host "✅ types.ts пропатчен" -ForegroundColor Green
} else {
    Write-Host "⏭ types.ts уже содержит 'ru'" -ForegroundColor Yellow
}

# 4. Патчим languages.ts — добавляем ru в LOCALE_OPTIONS и алиасы
$langFile = "$i18nDir\languages.ts"
$langContent = Get-Content $langFile -Raw
if ($langContent -notmatch "id: 'ru'") {
    $langContent = $langContent -replace "(    id: 'ja',[\s\S]*?configValue: 'ja'\s+  })", "`$1,`n  {`n    id: 'ru',`n    name: 'Русский',`n    englishName: 'Russian',`n    configValue: 'ru'`n  }"
    $langContent | Set-Content $langFile -NoNewline
    Write-Host "✅ languages.ts — добавлен ru в LOCALE_OPTIONS" -ForegroundColor Green
}
if ($langContent -notmatch "'ru-ru'") {
    $langContent = $langContent -replace "(  ja_jp: 'ja'[\s\S]*?})", "`$1,`n  ru: 'ru',`n  'ru-ru': 'ru',`n  ru_ru: 'ru',`n  'русский': 'ru'`n}"
    $langContent | Set-Content $langFile -NoNewline
    Write-Host "✅ languages.ts — добавлены алиасы" -ForegroundColor Green
} else {
    Write-Host "⏭ languages.ts уже настроен" -ForegroundColor Yellow
}

# 5. Патчим catalog.ts — регистрируем ru
$catalogFile = "$i18nDir\catalog.ts"
$catalogContent = Get-Content $catalogFile -Raw
if ($catalogContent -notmatch "import { ru }") {
    $catalogContent = $catalogContent -replace "(import { zhHant } from '\./zh-hant')", "`$1`nimport { ru } from './ru'"
    $catalogContent = $catalogContent -replace "(  zh,)", "`$1`n  ru,"
    $catalogContent | Set-Content $catalogFile -NoNewline
    Write-Host "✅ catalog.ts пропатчен" -ForegroundColor Green
} else {
    Write-Host "⏭ catalog.ts уже содержит ru" -ForegroundColor Yellow
}

# 6. Собираем
Write-Host "`n🔨 Сборка десктопного приложения..." -ForegroundColor Cyan
Push-Location "$hermesDir\apps\desktop"
try {
    npm run build 2>&1 | Select-Object -Last 3
    Write-Host "✅ Сборка завершена" -ForegroundColor Green
} catch {
    Write-Host "⚠ Сборка через npm не удалась, но файлы перевода установлены" -ForegroundColor Yellow
    Write-Host "  Выполните вручную: cd $hermesDir\apps\desktop && npm run build"
} finally {
    Pop-Location
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "🇷🇺 Русская локализация установлена!" -ForegroundColor Green
Write-Host "Перезапустите Hermes Desktop и выберите:" -ForegroundColor White
Write-Host "  Settings → Appearance → Русский" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
