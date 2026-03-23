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
| Primary | `opus` (Claude Opus 4.6) | Anthropic (OAuth) |
| Fallback | нет (намеренно) | -- |
| Heartbeat | `kimi-k2.5` | OpenRouter |
| Субагенты (код) | `opus`, `codex` (GPT-5.4) | Anthropic (OAuth), OpenAI (OAuth) |
| Субагенты (ресерч/текст) | `opus`, `codex`, `grok` | Anthropic/OpenAI (OAuth), OpenRouter |

Запреты: Opus через OpenRouter (дорого). Grok к коду не допускается. Sonnet не используется. Max 5 concurrent субагентов.

## ACP (Agent Client Protocol)

Сильвана использует ACP для делегирования кодовых задач локальным CLI-harness'ам.

| Параметр | Значение |
|----------|----------|
| Backend | ACPX (OpenClaw plugin) |
| Max сессий | 4 параллельных |
| Idle timeout | 12 часов |
| Max age | 72 часа |
| Telegram группа | ACP agent (chat_id: `-1003548032826`) |

### Доступные harness'ы

| AgentId | CLI | Модель | Topic ID | Роль |
|---------|-----|--------|----------|------|
| `claude-code` | Claude Code CLI | Claude Opus 4.6 | topic:2 | Написание кода, фиксы, тесты |
| `codex` | Codex CLI | GPT-5.4 | topic:3 | Архитектура, планирование, code review |

### Пайплайн кодовых задач

1. **Codex** -- архитектура и план (sessions_spawn runtime=acp agentId=codex)
2. **Claude Code** -- написание кода (sessions_spawn runtime=acp agentId=claude-code)
3. **Codex** -- code review (параллельно с Opus)
4. **Claude Code** -- фиксы по результатам ревью
5. **Сильвана** -- финальная проверка и отчёт принцу

### Конфигурация

- ACPX config: `~/.acpx/config.json`
- Agent overrides: `claude-code` → `@zed-industries/claude-agent-acp@^0.22.0`
- Codex bridge: `~/.openclaw/scripts/codex-acp-bridge.mjs`
- Telegram bindings: type=acp в openclaw.json

### Два режима работы

1. **Программный**: Сильвана спавнит сессии через `sessions_spawn runtime=acp`
2. **Прямой**: принц пишет в Telegram-топики группы ACP agent

## Heartbeat

| Параметр | Значение |
|----------|----------|
| Интервал | 55 мин (OpenClaw) + cron */5 мин (Firebase) |
| Модель | `kimi-k2.5` (OpenRouter) |
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

Локальное read-only зеркало Firebase для retrieval и QMD находится в `firebase-mirror/`.

Это не источник истины. Источник истины -- Firebase RTDB через `orgbus`. `memory/firebase/` -- legacy path, не использовать.

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
| firebase-mirror/**/*.md | Локальное зеркало Firebase для retrieval/QMD |

### Принцип работы с памятью

1. При старте: HOT, WARM, SOUL, USER, AGENTS (автоматически через workspace context)
2. При фактических вопросах: `orgbus get` (Firebase > exec > память)
3. При записи: сначала Firebase, потом локальный файл
4. Daily memory: Firebase `/agents/sa-silvana/memory/daily/`

## Скиллы (смотри реестр в workspace, не фиксируй число в статике)

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
| SIL-SKL-25 | code-pipeline | 6-этапный пайплайн кодовых задач | -- |
| SIL-SKL-26 | code-review | Кросс-ревью кода субагентов | -- |

PROTECTED = удаление/замена требует PR + одобрение принца.

## Установленные CLI (Mac mini)

| CLI | Назначение |
|-----|------------|
| orgbus | Firebase RTDB |
| gog | Google Workspace (feature-rich) |
| gws | Google Workspace (official API) |
| claude | Claude Code CLI (v2.1.81) |
| codex | OpenAI Codex CLI |
| acpx | ACP multiplexer (bundled с OpenClaw) |
| duckduckgo-search | Web search (pip3) |
| yt-dlp | YouTube download (pip3) |
| gcloud | Google Cloud SDK |

## Зона ответственности

### Зелёная зона (без одобрения, отчёт постфактум)

- Triage inbox (каждые 2ч через heartbeat)
- Чтение Firebase, проверки системы
- Обновление своей памяти (HOT/WARM/COLD)
- Запись learnings
- Делегирование задач субагентам и ACP harness'ам
- Контент: черновики, идеи, разбор источников
- Ответы принцу в DM
- Спавн ACP сессий для кодовых задач

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
| Firebase→mirror sync | firebase-to-qmd-sync.sh / firebase-sse-listener-v3.sh | локальное зеркало в firebase-mirror/ для retrieval |
| Heartbeat | silvana-heartbeat.sh | cron */5 мин |
| Obsidian sync | firebase-to-obsidian.sh | cron */2 мин |

## Каналы связи

| Канал | Назначение |
|-------|------------|
| Telegram DM (см. openclaw.json `channels.telegram.allowFrom`) | Основной канал с принцем |
| Telegram ACP group (-1003548032826) | ACP harness топики (Claude Code, Codex) |
| Firebase inbox | Межагентная коммуникация |
| Claude Code (sa-claude) | Кодовые задачи на Mac mini |
| ACP sessions (sessions_spawn) | Программный спавн harness сессий |
