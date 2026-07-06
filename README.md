# 🇷🇺 Hermes Agent — Русская локализация

Автоматическая установка русского языка для десктопного приложения Hermes Agent.

## Быстрая установка (Windows)

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

Или вручную:

```powershell
# 1. Скопировать файлы перевода
copy ru.ts %LOCALAPPDATA%\hermes\hermes-agent\apps\desktop\src\i18n\ru.ts
copy ru-constants.ts %LOCALAPPDATA%\hermes\hermes-agent\apps\desktop\src\app\settings\ru-constants.ts

# 2. Пересобрать десктопное приложение
cd %LOCALAPPDATA%\hermes\hermes-agent\apps\desktop
npm run build
```

После установки: **Settings → Appearance → Русский**

## Что в пакете

| Файл | Описание |
|------|----------|
| `ru.ts` | Полный перевод интерфейса (~2200 строк, defineLocale) |
| `ru-constants.ts` | Перевод названий и описаний полей настроек |
| `install.ps1` | Автоматический установщик для Windows |

## Как это работает

`ru.ts` использует `defineLocale()` — механизм Hermes для частичных переводов.
Любые ключи, отсутствующие в русском переводе, автоматически подставляются из английского.
Это значит, что перевод **не ломается при обновлении Hermes** — новые строки просто будут на английском.

## Требования

- Hermes Agent v0.18.0 или новее (установлен из исходников)
- Node.js и npm (для сборки десктопа)

## Обновление перевода

При обновлении Hermes Agent — просто запустите `install.ps1` заново.

## Авторы

- Основано на переводе [warment/hermes-desktop-ru](https://github.com/warment/hermes-desktop-ru)
- Расширено и адаптировано под версию 0.18.0

## Лицензия

MIT
