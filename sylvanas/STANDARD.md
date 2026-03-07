# Стандарт агента: Сильвана (coordinator + creator)

## Общие сведения

| Параметр | Значение |
|----------|----------|
| ID | sa-silvana |
| Сервер | Mac mini (`orgbus get agents/sa-silvana/meta/ip`) |
| Runtime | OpenClaw |
| Telegram | @fridayhumanbot (канал: telegram, DM allowlist) |
| Роли | Координатор, контент-мейкер, брейншторм-партнёр, проектный ассистент |

## Модели

| Роль | Алиас | Провайдер |
|------|-------|-----------|
| Primary | `opus` | Anthropic (OAuth) |
| Fallback 1 | `codex` | OpenAI (OAuth) |
| Fallback 2 | `grok` | OpenRouter |
| Heartbeat | `grok` | OpenRouter |
| Субагенты (default) | `grok` | OpenRouter |

Запреты: opus и sonnet для субагентов. Max 5 concurrent субагентов.

Дополнительные модели (доступны для задач):
- `kimi` -- OpenRouter
- `gemini-flash` -- OpenRouter
- `gemini` -- OpenRouter, 1M контекст

## Heartbeat

| Параметр | Значение |
|----------|----------|
| Интервал | 55 мин (OpenClaw) + cron */5 мин (Firebase) |
| Модель | `grok` |
| Что проверяет (OpenClaw) | Inbox triage, задачи в Firebase, счётчики |
| Что делает (cron) | `orgbus patch agents/sa-silvana` -- обновляет lastHeartbeat |

Правило: если нечего делать -- HEARTBEAT_OK. Сообщение принцу ТОЛЬКО при action item.

## System Cron (crontab)

| ID | Расписание | Скрипт | Назначение |
|----|-----------|--------|------------|
| SIL-SC1 | */2 мин | firebase-to-obsidian.sh | Firebase → Obsidian sync |
| SIL-SC2 | */5 мин | silvana-heartbeat.sh | Firebase heartbeat |
| SIL-SC3 | */15 мин | sync-shared.sh | Shared memory sync |
| SIL-SC4 | 0 * | firebase-sse-listener.sh (watchdog) | SSE listener restart if dead |

## OpenClaw Cron

Нет активных OpenClaw cron jobs. Вся периодика через system cron + heartbeat.

## Взаимодействие с Firebase

Firebase RTDB -- единственный источник правды.

| Операция | Команда |
|----------|---------|
| Читать задачи | `orgbus get tasks` |
| Мои задачи | `orgbus get tasks` + фильтр assignee=sa-silvana |
| Создать задачу | `orgbus put tasks/TASK-ID '{...}'` |
| Обновить статус | `orgbus patch tasks/TASK-ID '{"status":"..."}'` |
| Мой inbox | `orgbus get messages/inbox/silvana` |
| Написать Claude Code | `orgbus push messages/inbox/claude '{...}'` |
| Записать урок | `orgbus push learnings '{...}'` |
| Обновить heartbeat | `orgbus patch agents/sa-silvana '{...}'` |
| Контент | `orgbus get content/telegram/{ideas\|sources\|drafts\|library\|stance\|tone\|workflow}` |
| Конституция | `orgbus get constitution/{charter\|operations\|principles}` |

### Зеркала (read-only кэш)

SSE listener поддерживает зеркала в `memory/firebase/`:
agents-status.md, tasks-mine.md, learnings.md, content-ideas.md, bulletin.md.

Обновляются в реальном времени. Используются для быстрого чтения, НЕ как источник фактов.

## Память (3 уровня)

| Уровень | Файл | Назначение |
|---------|------|------------|
| HOT | memory/hot/HOT_MEMORY.md | Активные задачи, текущий контекст |
| WARM | memory/warm/WARM_MEMORY.md | Серверы, агенты, скиллы, подписки |
| COLD | MEMORY.md | Архив, доверенные пользователи, ключевые решения |

### Дополнительная память

| Файл | Назначение |
|------|------------|
| memory/warm/WATCHLIST.md | Идеи и наблюдения |
| memory/stance/STANCE_CORE.md | Рыночные позиции принца |
| memory/tone/CONTENT_MODE.md | Контентный режим |
| memory/tone/TONE_OF_VOICE.md | Tone of Voice для постов |
| memory/channels/channel-*.md | Профили Telegram-каналов (4 шт) |
| memory/knowledge/STRATEGY_3-13M.md | Стратегия на 3-13 мес |
| memory/firebase/*.md | Зеркала Firebase (5 файлов) |

### Принцип работы с памятью

1. При старте: HOT, WARM, SOUL, USER, AGENTS (автоматически через workspace context)
2. При фактических вопросах: `orgbus get` (Firebase > exec > память)
3. При записи: сначала Firebase, потом локальный файл
4. Daily memory: Firebase `/agents/sa-silvana/memory/daily/`

## Скиллы (24)

| ID | Скилл | Назначение | Защита |
|----|-------|------------|--------|
| SIL-SKL-1 | firebase-ops | orgbus CLI, структура Firebase | PROTECTED |
| SIL-SKL-2 | shared-memory | Boot sequence при старте | PROTECTED |
| SIL-SKL-3 | memory-audit | Самоаудит памяти | PROTECTED |
| SIL-SKL-4 | learnings | Запись уроков в Firebase | PROTECTED |
| SIL-SKL-5 | task-triage | Inbox triage, SLA мониторинг | PROTECTED |
| SIL-SKL-6 | task-board | Задачи через Telegram-топики | -- |
| SIL-SKL-7 | task-system | Задачная система | -- |
| SIL-SKL-8 | content-engine | Контент-пайплайн | PROTECTED |
| SIL-SKL-9 | market-data | Рыночные данные, теханализ | -- |
| SIL-SKL-10 | twitter | Чтение Twitter/X | -- |
| SIL-SKL-11 | duckduckgo-search | Web-поиск | -- |
| SIL-SKL-12 | groq-voice | Транскрипция голосовых | PROTECTED |
| SIL-SKL-13 | transcript | Транскрипция видео | -- |
| SIL-SKL-14 | gws | Google Workspace CLI | -- |
| SIL-SKL-15 | whoop-health-analysis | WHOOP здоровье | -- |
| SIL-SKL-16 | whoop-cli | WHOOP CLI | -- |
| SIL-SKL-17 | quick-reminders | Напоминания (nohup) | -- |
| SIL-SKL-18 | topic-monitor | Мониторинг тем | -- |
| SIL-SKL-19 | brainstorm-pipeline | Брейншторм идей | -- |
| SIL-SKL-20 | skill-creative | Креативные задачи | -- |
| SIL-SKL-21 | agent-introspection | Самоаудит качества | -- |
| SIL-SKL-22 | agent-messaging | Межагентная коммуникация | -- |
| SIL-SKL-23 | openclaw-architecture | Аудит конфигурации | -- |
| SIL-SKL-24 | verification-before-completion | Проверка перед завершением | PROTECTED |

PROTECTED = удаление/замена требует PR + одобрение принца.

## Установленные CLI (Mac mini)

| CLI | Назначение |
|-----|------------|
| orgbus | Firebase RTDB |
| gog | Google Workspace (feature-rich) |
| gws | Google Workspace (official API) |
| claude | Claude Code CLI |
| duckduckgo-search | Web search (pip3) |
| yt-dlp | YouTube download (pip3) |
| gcloud | Google Cloud SDK |

## Зона ответственности

### Зелёная зона (без одобрения, отчёт постфактум)

- Triage inbox (каждые 2ч через heartbeat)
- Чтение Firebase, проверки системы
- Обновление своей памяти (HOT/WARM/COLD)
- Запись learnings
- Делегирование задач субагентам
- Контент: черновики, идеи, разбор источников
- Ответы принцу в DM

### Красная зона (требует одобрение принца)

- Публикация контента (посты, email)
- Изменение конфигурации OpenClaw
- Изменение cron
- Действия на других серверах (SSH)
- Изменение конституции (только через PR)
- Масштабные изменения инфраструктуры
- Финансовые действия

## Obsidian Sync

| Параметр | Значение |
|----------|----------|
| Vault | ~/Obsidian/Dashis Backoffice/ |
| Скрипт | ~/scripts/firebase-to-obsidian.sh |
| Cron | каждые 2 мин |
| Направление | Firebase → Obsidian (read-only) |

## Фоновые процессы

| Процесс | Скрипт | Описание |
|---------|--------|----------|
| SSE listener | firebase-sse-listener.sh | ~11 потоков, зеркала в memory/firebase/ |
| Heartbeat | silvana-heartbeat.sh | cron */5 мин |
| Obsidian sync | firebase-to-obsidian.sh | cron */2 мин |

## Каналы связи

| Канал | Назначение |
|-------|------------|
| Telegram DM (см. openclaw.json `channels.telegram.allowFrom`) | Основной канал с принцем |
| Firebase inbox | Межагентная коммуникация |
| Claude Code (sa-claude) | Кодовые задачи на Mac mini |
