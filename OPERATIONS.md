# Операционная модель Orgrimmar

_Связующий слой между конституцией и pipeline'ами. Описывает КАК работает система._

---

## Роли

Система описывает роли, не агентов. Один агент = одна или несколько ролей.

| Роль | Зона | Может | Не может |
|------|------|-------|----------|
| **coordinator** | Оркестрация, маршрутизация | Распределять задачи агентам, ревьюить планы, мониторить все серверы. Тралл/Иллидан -- только через задачную систему (shared/tasks/) или принца | Править архитектурные решения coder'а. Командовать devops по инфраструктуре |
| **coder** | Код, архитектура, скиллы | Писать код, создавать PR, деплоить | Менять чужие AGENTS.md без одобрения |
| **devops** | Инфра, мониторинг, recovery | Рестартовать сервисы, чинить серверы | Менять бизнес-логику агентов |
| **monitor** | Отслеживание внешних данных | Алертить, собирать данные | Мониторить серверы (это devops) |
| **creator** | Контент, дизайн | Создавать контент, публиковать | Менять инфраструктуру |
| **finance** | Бюджет, расходы | Отслеживать траты, алертить о лимитах | Управлять подписками (только принц) |
| **worker** | Рутина, автоматизация | Выполнять простые задачи | Брать задачи вне своей роли |

---

## Задачная система

Все входящие от принца проходят классификацию перед обработкой.

### Классификация сообщений

| Тип | Критерий | Маршрут |
|-----|----------|---------|
| **ЗАДАЧА** | Есть последствие невыполнения | inbox → triage → active → done |
| **ИДЕЯ** | Ценная мысль, нет дедлайна | ideas/ (отдельный трек) |
| **ЗАПРОС** | Нужен ответ сейчас | ответить, не записывать |
| **ОТВЕТ** | Реакция на вопрос агента | обновить существующую задачу |

**Правило классификации:** «Если не сделать -- что-то сломается или потеряется?»
- Да → ЗАДАЧА
- Нет, но ценно → ИДЕЯ
- Нет → ЗАПРОС/ОТВЕТ

**Приоритеты задач:** P0 (срочно) → P1 (надо) → P2 (попробуй) → P3 (бэклог).

### Статусы задач (регламент)

| Статус | Значение | Кто ставит | Цвет |
|--------|----------|-----------|------|
| **inbox** | Создана, ждёт assignee | Система / агент | синий |
| **progress** | Взята в работу | Агент-исполнитель | жёлтый |
| **pipeline** | Запущен автоматический pipeline | Агент-исполнитель | оранжевый |
| **blocked** | Заблокирована (причина в blocked_reason) | Агент-исполнитель | красный |
| **review** | Сделано, ждёт проверки принца | Агент-исполнитель | фиолетовый |
| **done** | Завершена и подтверждена | task-complete.sh | зелёный |

**Жизненный цикл:**
```
inbox -> progress -> [pipeline] -> review -> done
          |                                    ^
          +-> blocked -> progress ------------+
```

**Обязательные поля задачи:**

| Поле | Описание | Обязательно |
|------|----------|-------------|
| `id` | Уникальный ID (генерирует скрипт) | да |
| `from` | Кто создал (prince/silvana/thrall/arthas/illidan) | да |
| `assignee` | Кто выполняет | да (после triage) |
| `status` | Один из 6 статусов | да |
| `stage` | Текущий этап (RESEARCH, CODING, TESTING и др.) | да |
| `created` | Дата создания | да |
| `updated` | Дата последнего обновления | да |
| `needs_chief` | yes/no -- ждёт решения принца | да |
| `blocked_reason` | Причина блокировки | да (если blocked) |

**Правила исполнителя:**
1. Взял задачу -- сразу поставь `progress`
2. Запустил pipeline -- поставь `pipeline`
3. Заблокирован -- поставь `blocked` + заполни `blocked_reason`
4. Готово -- поставь `review`
5. Обновляй `updated` при каждом изменении статуса
6. Задача без обновления >24ч -- Артас пингует исполнителя
7. Задача без обновления >48ч -- алерт принцу

**Правила Артаса (watchdog):**
1. Каждые 3 часа сканировать inbox/, active/, ideas/
2. Выдавать счётчики: сколько в inbox, active, blocked, review, ideas, done
3. >24ч без обновления в active -- пинг исполнителю
4. >48ч -- алерт принцу
5. `needs_chief: yes` >4ч -- напоминание принцу
6. Inbox >4ч без triage -- алерт координатору

### Базовые скиллы (обязательны для ВСЕХ агентов)

| # | Скилл | Назначение | Исключение |
|---|-------|-----------|------------|
| 1 | `task-system` | Работа с задачной системой | кроме Кель'таса (свой регламент) |
| 2 | `learnings` | Запись ошибок и уроков | -- |
| 3 | `memory-tiering` | Управление памятью (HOT/WARM/COLD) | -- |
| 4 | `transcript` | Транскрипция YouTube | -- |
| 5 | `twitter` | Чтение Twitter/X и статей (FxTwitter + SocialData fallback) | -- |
| 6 | `gog` | Google Workspace | только Mac mini (Сильвана) + Arthas VPS (Артас) |
| 7 | Groq Whisper | Транскрипция голосовых. Требует `tools.alsoAllow: ["exec", "read"]` при профиле `messaging` | -- |
| 8 | `memory-audit` | Самоаудит памяти по регламенту конституции | -- |
| 9 | `shared-memory` | Чтение shared-слоя памяти при старте сессии | все агенты |

**Правило OAuth-скиллов:** скиллы с OAuth-авторизацией (`gog` и подобные) ставятся только на ОДИН сервер. GOG = Mac mini (Сильвана).

**Дополнительно:** `orgrimmar-introspection` обязателен для координаторов (Сильвана, Тралл, Иллидан); отсутствие = **VIOLATION**.

**Правило clean-up скиллов:** удаление скилла выполняется через перенос в `skills/_archive/`. Полное удаление из репозитория — только с явным одобрением принца.

**Ролевые скиллы:**
| Агент | Скилл | Назначение |
|-------|-------|------------|
| Тралл | `server-ops` | SSH-операции на Arthas VPS/Illidan/Mac mini: maintenance, конфиги, рестарты |
| Тралл | `cross-review` | Ревью PR: change levels, merge rules, раскатка |
| Тралл | `worker-orchestration` | Spawn воркеров: модели, уведомления, коммуникация |
| Тралл | `openclaw-updater` | Обновление OpenClaw на всех серверах |
| Сильвана | `task-triage` | Inbox triage + SLA мониторинг задач |
| Сильвана | `groq-voice` | Транскрипция голосовых из Telegram через Groq Whisper API (whisper-large-v3-turbo) |
| Артас | `chat-alerts` | Алерт принцу при @mention/reply с ссылкой t.me/c/CHAT_ID/MESSAGE_ID |
| Артас | `chat-ops` | JSONL логирование, per-chat режимы, watchdog задач |
| Артас | `topic-monitor` | Мониторинг тем через веб-поиск |
| Кель'тас | `content-engine` | Классификация входящих + pipeline поста |
| Иллидан | `server-rescue` | Incident response: диагностика, откат, восстановление |
| Иллидан | `cross-review` | Ревью PR: change levels, merge rules, раскатка |
Нарушение (отсутствие базового скилла) = VIOLATION. Иллидан проверяет при еженедельном аудите.

**Обязательность:**
- Регламент задач ОБЯЗАТЕЛЕН для ВСЕХ агентов: Сильвана, Артас, Батрак, Джайна, Тралл, Иллидан
- Нарушение регламента = VIOLATION категории «задачная система»

**Прочие правила:**
- `blocked` -- обязательно заполнять `blocked_reason` и `needs_chief` если ждёт принца
- `review` -- агент считает задачу готовой, принц ещё не подтвердил
- `pipeline` -- автоматическая обработка (dev-pipeline, brainstorm, agent-bugfix и др.)
- Только принц или task-complete.sh переводит в `done`
- Статус `parked` и `in_progress` (с подчёркиванием) -- DEPRECATED, не использовать

### Хранение задач (Firebase)

Задачи живут в Firebase RTDB (`/tasks/`). Формат задачи остаётся тем же (id, from, assignee, status, stage и т.д.), но хранение -- Firebase вместо файловой системы. Основные команды:
- `orgbus push tasks '<json>'` -- создать задачу
- `orgbus put tasks/<task-id> '<json>'` -- обновить задачу
- `orgbus get tasks` -- получить все задачи

Статусы задач в Firebase: `inbox | progress | pipeline | blocked | review | done`.

Файловая система на Mac mini (`shared/tasks/`) -- **deprecated**. Все задачи -- только в Firebase.

### Роли в задачной системе

| Роль | Что делает |
|------|------------|
| **triage** (coordinator) | Классифицирует inbox, назначает исполнителя |
| **executor** (все агенты) | Выполняют назначенные задачи, обновляют статус |
| **watchdog** (monitor) | Следит за зависшими задачами, пингует исполнителей |
| **enforcer** (monitor) | Проверяет качество, подгоняет без снижения стандартов |

### Автоматизация task lifecycle (обязательно)

| Роль | Cron | Частота | Что проверяет |
|------|------|---------|---------------|
| **triage** (Сильвана) | Inbox Triage | 2h | Новые задачи в inbox/ -- классифицировать, назначить исполнителя, переместить в active/ |
| **watchdog** (Артас) | Active Watchdog | 2h | Задачи в active/ без обновления >24ч -- пинг исполнителю. >48ч -- алерт принцу |

**Правило:** ни одна задача не должна лежать в inbox >4ч без triage. Ни одна задача не должна висеть в active >48ч без обновления статуса.
**Нарушение:** если Иллидан обнаружит на ежедневном аудите задачу в inbox >4ч или в active >48ч без обновления -- это VIOLATION категории "задачная система".

### Неприкосновенность inbox

- Удалять из inbox **ЗАПРЕЩЕНО** -- любому агенту, включая coordinator
- Допустимые действия: triage (перемещение в active) или архивация (в done с причиной)
- Inbox = лог намерений принца. Потеря записи = нарушение конституции

### Shadow logging

- Все сообщения принца сохраняются, даже ЗАПРОСЫ и ОТВЕТЫ
- Ни одно сообщение принца не должно потеряться
- Идеи, упомянутые повторно, кристаллизуются в задачу (из ideas/ → inbox)

### Жизненный цикл идей

| Событие | Действие | Кто |
|---------|----------|-----|
| Принц говорит «сделай задачу из идеи» | `task-triage.sh` из ideas/ → active/ | coordinator |
| Принц повторно упоминает идею | Предложить принцу создать задачу | coordinator |
| Принц явно отклоняет идею | Перенести в done/ с `result: rejected` | coordinator |
| Идея >90 дней без упоминания | Перенести в done/ с `result: stale` | coordinator |

**Правило:** coordinator НЕ удаляет и НЕ архивирует идеи самостоятельно. Только по команде принца или по правилу 90 дней.

---

## Маршрутизация задач

Switch-case по тегам. Неизвестная задача -> coordinator -> принц.

| Теги задачи | Роль | Pipeline | Домен жизни |
|-------------|------|----------|-------------|
| задача, поручение | coordinator | task-system (triage) | -- |
| код, фича, баг, PR | coder | dev-pipeline | Бизнес |
| сервер, диск, RAM, деплой | devops | -- | Бизнес |
| агент тупит, ложный алерт | coder | agent-bugfix | Бизнес |
| крипто, инвестиции | finance | -- | Финансы |
| контент, пост, видео | creator | content-pipeline | Бизнес |
| бюджет, расходы, подписки | finance | -- | Финансы |
| напоминание, рутина, расписание | worker | -- | Продуктивность |
| здоровье, сон, тренировка | monitor | -- | Здоровье, Сон |
| семья, дети, отношения, даты | worker | -- | Семья |
| обновление агентов | coder | safe-update |
| новый pipeline | coder | pipeline-builder |
| идея, стратегия | coordinator + coder | brainstorm-pipeline |
| аудит системы | coder | self-review |
| неизвестно | coordinator | -- (эскалация принцу) |

---

## Слой данных -- Firebase RTDB

Firebase Realtime Database (проект `orgrimmar-brain`, регион `europe-west1`) -- единый persistent state для всей сети Orgrimmar. Заменяет файловую синхронизацию (rsync, sshpass, JSON-файлы) как источник правды.

### Параметры

| Параметр | Значение |
|----------|----------|
| Проект | `orgrimmar-brain` |
| Регион | `europe-west1` |
| URL | `orgrimmar-brain-default-rtdb.europe-west1.firebasedatabase.app` |
| План | Spark (бесплатный) |
| Лимит хранения | 1 GB |
| Лимит bandwidth | 10 GB/мес |

### Три уровня данных

| Уровень | Описание | Примеры нод |
|---------|----------|-------------|
| **L1 -- System** | Системные данные, общие для всей сети | `agents/`, `tasks/`, `events/`, `learnings/`, `messages/`, `constitution/` |
| **L2 -- Projects** | Проектные данные с изоляцией | `projects/{project-id}/` |
| **L3 -- Personal Vault** | Личные зашифрованные данные вождя | `vault/documents/`, `vault/health/`, `vault/finance/` |

### Структура Firebase RTDB (V2)

> **FROZEN STRUCTURE:** Корневые ноды зафиксированы. Добавлять/удалять/переименовывать
> корневые ноды ЗАПРЕЩЕНО. Изменения только ВНУТРИ существующих нод.
> Структурные изменения требуют PR + одобрение вождя.

```
/
├── agents/            # Agent registry, nested meta/ structure
│   └── {agent-id}/
│       ├── meta/      # name, role, model, server, ip
│       ├── status     # online | offline | busy
│       ├── heartbeat  # ISO timestamp
│       ├── memory/    # Agent-specific memory
│       └── soul       # Agent identity (optional)
├── constitution/      # GitHub mirror (read-only, synced via GitHub Action)
├── content/           # Content by platform
│   ├── telegram/      # Telegram channels content (ideas, sources, drafts, library, stance, tone)
│   ├── youtube/       # YouTube pipeline (idea -> published, per-video workspace)
│   ├── instagram/     # Instagram content (placeholder)
│   └── ideas/         # Cross-platform ideas (legacy compat)
├── events/            # Append-only event log
├── finance/           # API usage, budgets, subscriptions, alerts
├── learnings/         # Shared lessons (lesson, author, date)
├── messages/          # Per-agent inbox
│   └── inbox/
│       ├── claude/    # Inbox for Claude Code
│       ├── silvana/   # Inbox for Silvana
│       ├── thrall/    # Inbox for Thrall
│       ├── illidan/   # Inbox for Illidan
│       └── arthas/    # Inbox for Arthas
├── meta/              # System metadata, backups, access control, architecture
├── projects/          # Isolated project workspaces
│   └── {project-id}/
│       ├── meta       # name, status, created, curator
│       ├── stages/    # Project stages
│       ├── budget/    # Project budget
│       ├── finance/   # Project expenses/revenue
│       ├── team/      # Team members
│       ├── files/     # Documents, assets
│       ├── credentials/ # Encrypted project credentials
│       └── history/   # Append-only change log
├── ref/               # Reference data (user, cron, heartbeat, chats, errands)
├── tasks/             # Unified task board (6 statuses)
└── vault/             # Personal Vault L3 (encrypted)
    ├── documents/     # Passports, visas, IDs
    ├── health/        # Whoop, prescriptions, vaccinations
    └── finance/       # Bank accounts, subscriptions
```

### Инструмент доступа -- orgbus.sh

`orgbus.sh` -- bash CLI обёртка над Firebase REST API. Основные команды:

| Команда | Описание |
|---------|----------|
| `orgbus get <path>` | Чтение ноды |
| `orgbus put <path> <json>` | Перезапись ноды |
| `orgbus push <path> <json>` | Append (генерирует ID) |
| `orgbus patch <path> <json>` | Частичное обновление |
| `orgbus del <path>` | Удаление ноды |

Все данные передаются через `jq` -- НИКОГДА не подставлять переменные напрямую в JSON строки (предотвращение shell injection).

### Безопасность

- Каждый агент имеет персональный Service Account (SA) с минимальными правами (path-level isolation)
- `databaseAuthVariableOverride` **ОБЯЗАТЕЛЬНА** при инициализации Admin SDK -- без неё SA получает god mode (обход всех Security Rules)
- `database.rules.json` -- единственный source of truth для правил доступа
- `.read: false, .write: false` на корне -- root никогда не открыт
- SA зашифрованы через sops/age, хранятся в `~/.secrets/firebase/` (chmod 600). НИКОГДА в Git

### Синхронизация конституции (GitHub --> Firebase)

GitHub Action (`sa-github-action`) зеркалит конституцию в Firebase (`/constitution/`) при каждом push в `main`.
Агенты читают конституцию из Firebase: `orgbus get constitution/charter`, `orgbus get constitution/operations` и т.д.
Локальный cron `constitution-sync.sh` -- **DEPRECATED**, заменён Firebase.

### Obsidian Sync (Firebase --> Obsidian)

Firebase --> Obsidian -- read-only зеркало через cron каждые 2 минуты (`firebase-to-obsidian.sh` на Mac mini). Obsidian используется для визуализации, Firebase -- source of truth.

Vault path: `~/Obsidian/Dashis Backoffice/`

Три уровня надёжности:
1. **Schema contract** (`firebase-schema.json`) -- валидация структуры Firebase
2. **Resilient sync** -- валидация fetch, abort при >6 ошибках, проверка диска
3. **Healthcheck** (`firebase-obsidian-healthcheck.sh`) -- 12 проверок после каждого sync, Telegram-алерты при ошибках

### Межагентная коммуникация (Messages)

Сообщения организованы как per-agent inbox: `/messages/inbox/{agent}/$msgId`.

- Каждый агент читает ТОЛЬКО свой inbox (`auth.uid == $agentId`)
- Сильвана читает все inboxes (координатор)
- Append-only: сообщения нельзя редактировать или удалять
- Формат: `from` (автор), `body` (текст, до 5000), `timestamp` (unix ms)

---

## Service Accounts (Firebase)

### Таблица SA

| SA | Сервер | Доступ |
|----|--------|--------|
| `sa-silvana` | Mac mini | `agents/silvana`, `tasks`, `content`, `events`, `learnings`, `messages` (all inboxes), `ref`, `finance`, `projects`, `meta` |
| `sa-claude` | Mac mini | `agents/claude`, `tasks`, `content/ideas`, `events`, `learnings`, `messages/inbox/claude`, `finance` (read) |
| `sa-thrall` | Thrall VPS | `agents/thrall`, `tasks`, `content`, `events`, `learnings` |
| `sa-arthas` | Arthas VPS | `agents/arthas` (+ write all via watchdog), `events`, `finance/alerts` |
| `sa-illidan` | Illidan VPS | `agents/illidan`, `events` |
| `sa-youtube-bot` | Arthas VPS | `content/youtube` (read/write), `content/youtube/*/published/stats` (write) |
| `sa-langfuse-sync` | Arthas VPS | `finance/api_usage` (write) |
| `sa-github-action` | CI | `constitution` (write) |
| `sa-backup` | Arthas VPS | Полный read (Admin SDK БЕЗ override -- единственное исключение, SA зашифрован sops/age) |
| `sa-vault-bot` | Mac mini | `vault/` (read/write) |
| `sa-whoop-sync` | Mac mini | `vault/health/whoop/` (write) |
| `sa-expiry-check` | Mac mini | `vault/documents`, `vault/health/prescriptions`, `vault/health/vaccinations`, `vault/finance/subscriptions` (read) |
| `sa-cost-rollup` | Arthas VPS | `projects/*/finance` (read), `finance/budget` (write) |
| `sa-project-bot-{id}` | Arthas VPS | Per-project SA: ONLY own `/projects/{id}/` |

### Правила SA

- Каждый SA видит ТОЛЬКО свои данные (path-level isolation)
- SA зашифрованы через sops/age (chmod 600)
- Новый SA создаётся через `orgbus agent-setup`
- `databaseAuthVariableOverride` **ОБЯЗАТЕЛЬНА** при любом использовании Admin SDK
- SA хранятся в `~/.secrets/firebase/` на каждом сервере. НИКОГДА в Git

### Распределение SA по серверам

```
Mac mini:    sa-silvana, sa-claude, sa-vault-bot, sa-whoop-sync, sa-expiry-check
Arthas VPS:  sa-arthas, sa-youtube-bot, sa-langfuse-sync, sa-cost-rollup, sa-backup, sa-project-bot-*
Thrall VPS:  sa-thrall
Illidan VPS: sa-illidan
```

---

## Проектная система (Firebase)

- Projects живут в `/projects/{project-id}/` с полной изоляцией
- Каждый сложный проект получает Curator Agent (dedicated)
- Простые проекты ведёт один General Curator
- Per-project SA: `sa-project-bot-{project-id}`
- Curator видит ТОЛЬКО свой проект
- История изменений -- append-only (`/projects/{project-id}/history/`)
- Credentials проекта доступны только `sa-silvana`

---

## Контентная система (Firebase, V2: Platform-First)

Контентная система живёт в `/content/` на Firebase RTDB. Организована по платформам, 8-фазный pipeline.

### Платформы

| Платформа | Firebase path | Каналы | Контент |
|-----------|--------------|--------|---------|
| Telegram | `/content/telegram/` | @dashi_eshiev, DCA, AI-enthusiast | Крипто, макро, AI, DCA |
| YouTube | `/content/youtube/` | Dashi Eshiev | Видео: крипта, AI, бренд |
| Instagram | `/content/instagram/` | (placeholder) | Visual content |

### Pipeline (8 фаз)

```
1. SOURCE      → /content/telegram/sources/   Принц присылает ссылку/аудио/скрин
2. ANALYSIS    → source.key_thesis            Синтез тезисов из sources
3. STANCE      → /content/telegram/stance/    Сверка с позицией вождя
4. DRAFT       → /content/telegram/drafts/    Написать черновик (version 1)
5. FACT-CHECK  → draft.fact_check             Проверка фактов через API
6. REVIEW      → idea.status=review           Показать вождю
7. PUBLISH     → /content/telegram/library/   После одобрения → финальный текст
8. LEARN       → library.learnings/           Записать уроки из правок → tone/
```

### Структура данных по платформам

**telegram/** -- полный контент-pipeline:
- `channels/` -- каналы (dashi-eshiev, dca, ai-enthusiast) с tone_of_voice
- `ideas/` -- идеи постов. Статусы: `idea → approved → drafting → fact-check → review → published | rejected`
- `sources/` -- входящие материалы. Типы: article, video, voice, tweet, podcast, screenshot, forward
- `drafts/` -- черновики с версионированием и fact-check
- `library/` -- опубликованные посты (референсы стиля, learnings из правок)
- `stance/` -- позиции вождя (`core` + append-only `history/`)
- `tone/` -- tone of voice: `voice` (общий), `bans/`, `patterns/`
- `workflow/` -- pipeline config

**youtube/** -- per-video workspace:
- `{videoId}/meta/` -- title, status (8 статусов: idea → published), priority, tags
- `{videoId}/idea/` -- concept, hook, angle
- `{videoId}/script/` -- outline, full_text, version
- `{videoId}/recording_package/` -- shot_list, assets, checklist
- `{videoId}/published/` -- youtube_url, stats (views, likes, CTR)

**instagram/** -- placeholder для будущего контента

**ideas/** -- cross-platform ideas (legacy backward compat)

### Доступ

- `sa-silvana`, `sa-claude` -- пишут в telegram/, instagram/, ideas/
- `sa-youtube-bot` -- пишет в youtube/ (+ `published/stats`)
- Stance и tone пишет только `sa-silvana`

---

## Профиль вождя (Firebase)

Профиль вождя хранится в `/ref/user/` на Firebase RTDB. Содержит:

| Поле | Описание |
|------|----------|
| `name` | Имя |
| `telegram` | Telegram username |
| `telegram_id` | ID в Telegram |
| `timezone` | Часовой пояс |
| `location` | Город |
| `email` | Почта |
| `channels` | Список каналов с типом и URL |
| `goals` | Текущие цели |

Конкретные значения -- в Firebase, НЕ в конституции (приватные данные).

Доступ: читают все агенты, пишет только `sa-silvana` (по команде вождя).

---

## Распределение моделей по задачам (model routing)

> Полный модельный регламент, каталог моделей, fallback-цепочки и процедура смены модели -- в **CHARTER.md**, секция «Модельный регламент».

Стандарт для pipeline-воркеров:

| Задача | Модель | Обоснование |
|--------|--------|-------------|
| SPEC / PLANNING | `opus` | Архитектурные решения |
| GATHER / RESEARCH | `grok` | Быстро, дёшево |
| GATHER (>50KB) | `gemini` | 2M контекст, глубокий анализ |
| Написание кода / FIX | `codex` | OAuth $0 |
| VERIFY | `codex` | OAuth $0 |
| REVIEW (обычный) | `codex` + `opus` | OAuth $0 + OAuth $0 |
| REVIEW (HIGH risk) | `codex` + `opus` + `gemini` | Triple review |
| DIVERGE (brainstorm) | `codex` + `gemini` + `grok` | Разнообразие моделей |

**Принцип:** Обычный review = `codex` + `opus` (оба OAuth $0). Triple review (+ `gemini`) -- только для HIGH risk (P0/P1 баги, security, multi-server деплой, финансовый код).

---

## Git Workflow и Change Management

### Репозиторий
- Монорепо: `qwwiwi/orgrimmar` (GitHub, private)
- Структура: `thrall/`, `sylvanas/`, `illidan/`, `shared/`, `.github/`
- Branch protection на `main`: require 1 approving review, no force push

### PR-first правило
Все изменения в монорепо идут через Pull Request. Прямой push в main запрещён.

### SSH-операции на серверах (обязательно)

При редактировании файлов на Arthas VPS/Illidan через SSH агент заходит как **root**, а OpenClaw работает как пользователь **openclaw**. Файлы, созданные или изменённые root'ом, недоступны для OpenClaw на запись (ошибка EACCES).

**Правило:** после ЛЮБОЙ правки файлов через SSH -- обязательно вернуть ownership:

```bash
chown -R openclaw:openclaw /home/openclaw/.openclaw/agents/
chown openclaw:openclaw /home/openclaw/.openclaw/openclaw.json
```

**Что ломается без chown:**
- QMD index не обновляется (memory search перестаёт работать)
- Embedding sync падает с EACCES на каждом запросе
- Все агенты на сервере получают задержки и ошибки
- auth-profiles.json не сохраняется (настройки теряются при рестарте)

**Инцидент:** пропущенный chown = **P2** (немедленное устранение при обнаружении).

---

### Change Levels (классификация изменений)

| Level | Описание | Примеры | Review | Merge |
|-------|----------|---------|--------|-------|
| **L0** | Косметика | Typo, комментарии, README | Любой reviewer | Reviewer |
| **L1** | Рабочие файлы | Скрипты, конфиги, AGENTS.md, скиллы | Cross-reviewer | Reviewer |
| **L2** | Инфраструктура | Deploy scripts, auth, CI, multi-server | Cross-reviewer + CI green | Reviewer |
| **L3** | Критическое | Конституция, новый/удаление агента | Cross-reviewer + принц | Принц |

Полная матрица: `shared/playbook/CHANGE-CLASSIFICATION.md`.

### Cross-review правило
- PR от coder (Тралл) -> ревьюит devops (Иллидан)
- PR от devops (Иллидан) -> ревьюит coder (Тралл)
- Автор PR НЕ МОЖЕТ быть единственным reviewer
- Запрещено: выполнять review от имени другого агента (нарушение = P1 инцидент)
- Cross-review -- процессное ограничение (оба агента на одном GitHub-аккаунте qwwiwi)

### GitHub-доступы
| Ресурс | Тралл | Иллидан | Принц |
|--------|-------|---------|-------|
| Монорепо (`qwwiwi/orgrimmar`) | full (qwwiwi) | full (qwwiwi, fine-grained token) | owner |
| Конституция (`jasonqween/orgrimmar-constitution`) | fork+PR, merge ЗАПРЕЩЁН | read only | owner (jasonqween), единственный кто мержит |

- Конституцию мержит ТОЛЬКО принц через GitHub UI
- Агенты НЕ МОГУТ мержить PR в конституции (технически заблокировано)
- Иллидан: fine-grained token с доступом только к монорепо

### Review формат (обязательный)
Каждый review содержит:
- Change Level (L0/L1/L2/L3)
- Чеклист: логика, безопасность, стиль, тесты, breaking changes
- Конкретные замечания с файлом и строкой
- Вердикт: APPROVE / REQUEST_CHANGES / COMMENT

Просто «LGTM» без анализа = невалидный review.

### Branch naming
```
feature/<server>/<описание>   -- новый функционал
fix/<server>/<описание>       -- исправление
test/<server>/<описание>      -- тестовые изменения
```

### Deploy order (канарейка)
Illidan -> Thrall -> Arthas VPS -> Mac mini. При fail на любом этапе -- стоп + rollback.

### CI (автоматические проверки)
5 checks на каждый PR: lint JSON/YAML, shellcheck, no-secrets, PR size, merge conflicts.

### Incident Severity

| Severity | Описание | SLA | Пример |
|----------|----------|-----|--------|
| **P0** | Прод упал, данные под угрозой | Немедленно | Все серверы down, утечка секретов |
| **P1** | Критический сервис деградирован | 1 час | Один сервер down, агент неуправляем |
| **P2** | Некритичная проблема | 24 часа | Ложные алерты, CI broken |
| **P3** | Улучшение, техдолг | Бэклог | Рефакторинг, оптимизация |

Полные playbook: `shared/playbook/INCIDENT-RESPONSE.md`, `shared/playbook/HOTFIX-PROTOCOL.md`.

---

## Эскалация

| Триггер | Уровень | Действие |
|---------|---------|----------|
| Задача вне роли | L1 | Передай coordinator'у |
| 3 попытки фикса провалились | L2 | Стоп, доклад принцу |
| Сервер/агент недоступен | L2 | devops чинит; если devops недоступен -> coder |
| Перерасход API > $20/сутки | L3 | Стоп, одобрение принца |
| Конфликт между агентами | L3 | Эскалация принцу |
| Critical security issue | L3 | Немедленно принцу |

---

## Health (OODA loop)

Каждый агент с heartbeat выполняет цикл:

```
Observe:  проверь свою зону (метрики, логи, статусы)
Orient:   сравни с ожидаемым состоянием
Decide:   отклонение > порог? -> алерт. Всё ок? -> молчи.
Act:      алерт принцу / автофикс (если в рамках роли) / эскалация
```

**Правило:** heartbeat = молчание если всё ок. Алерт только при проблеме.

---

## Связи pipeline'ов

```
self-review  ──обнаружил баг──>  agent-bugfix
self-review  ──нужен апдейт──>  safe-update
agent-bugfix ──нужен код──>     dev-pipeline
dev-pipeline ──готов деплой──>  safe-update
brainstorm   ──решение принято──> dev-pipeline
rd-engine    ──нашёл идею──>    brainstorm / dev-pipeline
rd-engine    ──нашёл модель──>  model-scout (measure -> migrate)
```

---

## Добавление нового агента

**Только по прямому приказу принца.** Ни один агент не может создать другого агента по собственной инициативе.

### Фаза 1: Firebase (5 мин)

1. Создать Service Account в Firebase Console: `sa-{agent}`
2. Скачать JSON ключ, скопировать на сервер: `~/.secrets/firebase/sa-{agent}.json` (chmod 600)
3. Скопировать orgbus: `scp ~/.local/bin/orgbus user@server:~/.local/bin/`
4. Проверить: `orgbus health` -- OK

### Фаза 2: Регистрация агента в Firebase (2 мин)

```bash
orgbus patch agents/sa-{agent} '{"meta":{"name":"...","role":"...","model":"...","server":"...","ip":"..."},"status":"online"}'
```

### Фаза 3: QMD -- семантический поиск (5 мин)

1. Установить qmd: `npm install -g @tobilu/qmd`
2. Установить ollama + модель: `ollama pull nomic-embed-text`
3. Создать `~/.openclaw/agents/{agent_id}/qmd/xdg-config/qmd/index.yml`:

```yaml
collections:
  firebase:
    path: ~/.openclaw/workspace/memory/firebase
    pattern: "**/*.md"
  memory-dir:
    path: ~/.openclaw/workspace/memory
    pattern: "**/*.md"
  soul:
    path: ~/.openclaw/workspace
    pattern: SOUL.md
  sessions:
    path: ~/.openclaw/agents/{agent_id}/qmd/sessions
    pattern: "**/*.md"
```

4. Добавить `memory` секцию в openclaw.json:

```json
{
  "memory": {
    "backend": "qmd",
    "citations": "auto",
    "qmd": {
      "searchMode": "search",
      "includeDefaultMemory": true,
      "sessions": { "enabled": true, "retentionDays": 30 },
      "update": { "interval": "5m", "debounceMs": 15000, "embedInterval": "30m" },
      "limits": { "maxResults": 6, "timeoutMs": 4000 }
    }
  }
}
```

### Фаза 4: SSE Listener -- realtime Firebase зеркала (5 мин)

1. Скопировать `firebase-sse-listener.sh` на сервер (`~/scripts/`)
2. Создать `~/.openclaw/workspace/memory/firebase/`
3. Запустить: `nohup ~/scripts/firebase-sse-listener.sh &`
4. Добавить в cron: `@reboot nohup ~/scripts/firebase-sse-listener.sh &`
5. Проверить: `ls ~/.openclaw/workspace/memory/firebase/` -- 5 .md файлов

### Фаза 5: Обязательные скиллы (5 мин)

Скопировать с Mac mini (100.97.43.49):

| Скилл | Зачем |
|-------|-------|
| task-system | Работа с задачами через Firebase |
| learnings | Запись уроков в Firebase |
| agent-messaging | Межагентная коммуникация через Firebase inbox |
| firebase-ops | Операции с Firebase |
| agent-introspection | Самоанализ через Firebase |
| memory-audit | Аудит памяти (Firebase-aware) |
| task-triage | Триаж входящих задач |

```bash
for skill in task-system learnings agent-messaging firebase-ops agent-introspection memory-audit task-triage; do
  scp -r ~/.openclaw/workspace/skills/$skill/ user@server:~/.openclaw/workspace/skills/
done
```

### Фаза 6: SOUL.md (10 мин)

Создать SOUL.md с обязательными секциями:
- Идентичность, характер, правила
- Firebase секция (boot sequence, коммуникация, иерархия данных)
- «Проверяй, а не вспоминай» -- orgbus get перед ответом на факты
- Непрерывность -- каждая сессия с нуля, Firebase = постоянная база
- Синхронизация результатов -- результат ОБЯЗАН быть в Firebase
- DEPRECATED секция (shared-dark-lady, файловые задачи)

### Фаза 7: Cron jobs (3 мин)

| Расписание | Команда | Зачем |
|-----------|---------|-------|
| `*/5 * * * *` | `orgbus patch agents/sa-{agent} '{"lastSeen":"...","status":"online"}'` | Heartbeat |
| `0 */6 * * *` | `constitution-sync.sh` | Синк конституции из Firebase |
| `@reboot` | `nohup firebase-sse-listener.sh &` | SSE daemon |

### Фаза 8: Конфиг openclaw.json (5 мин)

Рекомендуемые настройки agents:

```json
{
  "agents": {
    "defaults": {
      "compaction": { "mode": "safeguard" },
      "contextPruning": { "mode": "cache-ttl", "ttl": "1h" },
      "heartbeat": { "every": "55m" },
      "memorySearch": { "provider": "ollama" },
      "models": {
        "anthropic/claude-opus-4-6": {
          "alias": "opus",
          "params": { "cacheRetention": "long" }
        }
      }
    }
  }
}
```

### Фаза 9: Проверка (5 мин)

- [ ] `orgbus health` -- OK
- [ ] `orgbus get agents/sa-{agent}` -- данные есть
- [ ] `orgbus get messages/inbox/{agent}` -- inbox читается
- [ ] `ls ~/.openclaw/workspace/memory/firebase/` -- 5 зеркал
- [ ] `ls ~/.openclaw/agents/{id}/qmd/xdg-cache/qmd/index.sqlite` -- QMD индекс есть
- [ ] Написать агенту в Telegram -- ответ приходит, скиллы грузятся

**Общее время: ~40 минут.**

Удаление: обратный порядок (9→1), убери SA из Firebase, агента из `/agents/`.

---

## Резервное копирование (Backups)

| Тип | Сервер | Хранилище | Время | Удержание |
|-----|--------|-----------|-------|-----------|
| **Daily** | Arthas VPS | Thrall + DO Spaces | 03:00 UTC | 7 days, 4 weeks, 3 months |
| **Daily** | Thrall | DO Spaces | 03:30 UTC | 7 days, 4 weeks, 3 months |
| **Daily** | Illidan | Thrall + DO Spaces | 04:00 UTC | 7 days, 4 weeks, 3 months |

**Правило:** секреты бэкапа (пароли restic) запрещено хранить в коде скриптов. Только в `/home/openclaw/.openclaw/.secrets/*.env` (chmod 600).


---

## Обновление OpenClaw

Ответственный: devops (Иллидан). Cron: ежедневно 10:00 MSK.
Порядок канарейки: Illidan → Thrall → Arthas VPS → Mac mini.
Полная процедура: `scripts/update-openclaw-all.sh` и `skills/safe-update/`.

---

## Heartbeats

| Агент | Частота | Модель | Активные часы | Вызовов/день |
|-------|---------|--------|---------------|-------------|
| Тралл | 3h | `grok` | 06:00-23:00 MSK | ~6 |
| Сильвана | 2h | `grok` | 24/7 | ~12 |
| Артас | OFF | -- | -- | 0 |
| Иллидан | 2h | `kimi` | 24/7 | ~12 |

**Итого:** ~30 вызовов/день, ~$0.25/день.

**Принцип:** heartbeat -- дешёвая модель (`grok` через OpenRouter). Не использовать `opus`/`codex`/`gemini` для heartbeat.
Артас отключён (нет активных задач). Включается по необходимости.

---

## Инварианты памяти (НЕЛЬЗЯ НАРУШАТЬ)

> **Это не рекомендации. Нарушение любого пункта = память перестаёт работать.**
> Категория: **P0**. Иллидан проверяет при каждом аудите. Нарушение → немедленный алерт принцу.

### Защищённые кроны (PROTECTED CRONS)

Следующие кроны **запрещено удалять** без замены на эквивалент. Перед любым изменением crontab — убедись, что ни один из них не затронут.

#### Arthas VPS (crontab openclaw)

| ID | Расписание | Скрипт | Что сломается при удалении |
|----|-----------|--------|---------------------------|
| **ART-C1** | `0 21 * * *` | `memory-rotate.sh` (Артас) | Файлы памяти вырастут >10KB → flush заблокирован → Артас не сохраняет контекст |
| ~~**ART-C2**~~ | ~~`0 */6 * * *`~~ | ~~`constitution-sync.sh`~~ | **DEPRECATED** — заменён Firebase sync (GitHub Action `sa-github-action`) |
| **ART-C3** | `0 */6 * * *` | `learnings-merge.py` | `shared/LEARNINGS.md` не обновляется → уроки не попадают в общую память |
| **ART-C4** | `0 4 * * *` | `backup-daily.sh` | Нет бэкапов → потеря данных при сбое |
| **ART-C5** | `0 4 * * *` | `session-rotate.sh` | Сессии не чистятся → диск переполняется |
| **ART-C6** | `*/5 * * * *` | `notify-overflow.sh` | Нет мониторинга переполнения |

#### Thrall (crontab openclaw)

| ID | Расписание | Скрипт | Что сломается при удалении |
|----|-----------|--------|---------------------------|
| **THR-C1** | `0 * * * *` | `obsidian-sync.sh` | `agent-memory/shared/` устаревает → все агенты теряют shared-контекст через QMD |
| ~~**THR-C2**~~ | ~~`0 */6 * * *`~~ | ~~`constitution-sync.sh`~~ | **DEPRECATED** — заменён Firebase sync (GitHub Action `sa-github-action`) |
| **THR-C3** | `0 21 * * *` | `memory-rotate.sh` | Тралл не ротирует память → flush заблокирован |
| **THR-C4** | `30 3 * * *` | `backup-daily.sh` | Нет бэкапов → потеря данных при сбое |
| **THR-C5** | `0 4 * * *` | `cleanup-tmp.sh` | /tmp забивается → диск переполняется |

#### Illidan (crontab openclaw)

| ID | Расписание | Скрипт | Что сломается при удалении |
|----|-----------|--------|---------------------------|
| ~~**ILL-C1**~~ | ~~`0 */6 * * *`~~ | ~~`constitution-sync.sh`~~ | **DEPRECATED** — заменён Firebase sync (GitHub Action `sa-github-action`) |
| **ILL-C2** | `0 21 * * *` | `memory-rotate.sh` | Иллидан не ротирует память → flush заблокирован |

### Защищённые конфиги (PROTECTED CONFIG)

Следующие параметры в `openclaw.json` **запрещено изменять** без понимания последствий:

| ID | Параметр | Обязательное значение | Что сломается при нарушении |
|----|---------|----------------------|----------------------------|
| **CFG-1** | `memory.qmd.update.embedInterval` | `"30m"` (не `"0"`, не пусто) | QMD не строит эмбеддинги → семантический поиск мёртв |
| **CFG-2** | `agents.defaults.compaction.memoryFlush.softThresholdTokens` | `4000` (дефолт OpenClaw) | Flush не запускается вовремя → память не сбрасывается перед compaction |
| **CFG-2a** | `agents.defaults.compaction.mode` | `"safeguard"` | Compaction не срабатывает автоматически |
| **CFG-3** | `agents.defaults.compaction.memoryFlush.enabled` | `true` | Flush отключён → агент не сохраняет ничего между сессиями |
| **CFG-4** | Коллекция `shared-main` в `agents/<id>/qmd/index.yml` | присутствует на всех агентах | Агент не видит shared-память через QMD |

### Защищённые скиллы (PROTECTED SKILLS)

| ID | Скилл | Где установлен | Что сломается при удалении |
|----|-------|---------------|---------------------------|
| **SKL-1** | `memory-audit` | все серверы, все агенты | Нет самодиагностики → нарушения памяти не обнаруживаются |
| **SKL-2** | `learnings` | все серверы, все агенты | Агент не пишет уроки в LEARNINGS.md |
| **SKL-3** | `shared-memory` | все серверы, все агенты | Агент не читает контекст принца и команды при старте |

### Protected baseline — Сильвана (минимум для работы)

Этот блок фиксирует минимальный набор, который нельзя удалять при оптимизации системы.

#### 1) Обязательные файлы личной памяти (Silvana)

| ID | Путь | Назначение | Статус |
|----|------|------------|--------|
| **S-MEM-1** | `workspace/SOUL.md` | Идентичность и стиль поведения | PROTECTED |
| **S-MEM-2** | `workspace/MEMORY.md` | COLD-архив решений | PROTECTED |
| **S-MEM-3** | `workspace/memory/hot/HOT_MEMORY.md` | Активный контекст (Now/Next/Blockers) | PROTECTED |
| **S-MEM-4** | `workspace/memory/warm/WARM_MEMORY.md` | Операционная база | PROTECTED |
| **S-MEM-5** | `workspace/memory/warm/LEARNINGS.md` | Уроки и правила из ошибок | PROTECTED |
| **S-MEM-6** | `workspace/memory/YYYY-MM-DD.md` | Краткий дневник сессий | PROTECTED |

#### 2) Обязательные shared-слои

| ID | Путь | Назначение | Статус |
|----|------|------------|--------|
| **S-SH-1** | `workspace/_shared/*` | Source of truth по принцу, roster, conventions | PROTECTED |
| **S-SH-2** | `shared/tasks/inbox|active|done|ideas` | Контур задач и SLA | PROTECTED |
| **S-SH-3** | `shared/LEARNINGS.md` | Общий merge уроков | PROTECTED |

#### 3) Обязательные кроны поддержки памяти и задач (Mac mini + Arthas VPS)

| ID | Cron | Назначение | Статус |
|----|------|------------|--------|
| **S-CRON-1** | ~~`constitution-sync.sh`~~ | ~~Актуализирует конституцию/конвенции~~ | DEPRECATED — заменён Firebase sync (GitHub Action `sa-github-action`) |
| **S-CRON-2** | `memory-rotate.sh` (daily) | Сдерживает рост memory-файлов, сохраняет flush-работоспособность | PROTECTED |
| **S-CRON-3** | `learnings-merge.py` (каждые 6ч) | Синхронизирует общий слой уроков | PROTECTED |
| **S-CRON-4** | `notify-chief-channel.sh` (каждые 30м) | Сигнализирует про blocked/needs_chief по задачам | REMOVED (2026-03-06) |

#### 4) Обязательные параметры памяти/QMD

| ID | Параметр | Значение | Статус |
|----|----------|----------|--------|
| **S-CFG-1** | `memory.qmd.update.embedInterval` | `30m` | PROTECTED |
| **S-CFG-2** | `agents.defaults.compaction.memoryFlush.enabled` | `true` | PROTECTED |
| **S-CFG-3** | `agents.defaults.compaction.memoryFlush.softThresholdTokens` | `4000` | PROTECTED |
| **S-CFG-3a** | `agents.defaults.compaction.mode` | `"safeguard"` | PROTECTED |
| **S-CFG-4** | `agents/<id>/qmd/index.yml` содержит `shared-main` | обязательно для каждого агента | PROTECTED |

#### 5) Границы, что НЕ является protected

- Отдельные отчётные cron (например утренний дайджест) могут включаться/выключаться по решению принца.
- SQL-layer (sqlite) может быть в freeze/legacy режиме, если QMD + markdown memory функционируют штатно.

#### Ролевые скиллы Тралла (coder)

| ID | Скилл | Что сломается при удалении |
|----|-------|---------------------------|
| **THR-SKL-7** | `server-ops` | Не может управлять Arthas VPS/Illidan/Mac mini через SSH |
| **THR-SKL-8** | `cross-review` | PR от Иллидана остаются без review |
| **THR-SKL-9** | `worker-orchestration` | Не может делегировать задачи воркерам |
| **THR-SKL-10** | `openclaw-updater` | Обновления без процедуры канарейки |
| **THR-SKL-11** | `orgrimmar-introspection` | Потеря контекста при cross-server задачах |
| **THR-SKL-12** | `dev-pipeline` | Нет структурированного процесса разработки |
| **THR-SKL-13** | `agent-bugfix` | Агенты чинятся без процедуры |
| **THR-SKL-14** | `safe-update` | Раскатка на агентов без проверки |
| **THR-SKL-21** | `skill-creator` | Не может создавать скиллы для агентов |

Полный реестр: `thrall/STANDARD.md`, секция «Защищённые скиллы».

### Протокол перед изменением crontab

**Обязателен при любом редактировании `crontab -e` или `crontab -u openclaw -l`:**

```bash
# 1. Сохрани текущий crontab перед изменением
crontab -u openclaw -l > /tmp/crontab.backup.$(date +%Y%m%d_%H%M%S)

# 2. После изменения — верифицируй, что защищённые кроны на месте
crontab -u openclaw -l | grep -E "memory-rotate|learnings-merge|obsidian-sync"

# 3. Если кто-то из них пропал — СТОП, восстанови из бэкапа:
# crontab -u openclaw /tmp/crontab.backup.<timestamp>
```

**Нарушение:** если Иллидан при аудите обнаружит отсутствие хотя бы одного защищённого крона — это **P0**, немедленный алерт принцу.

### Быстрая верификация инвариантов

Запусти на любом сервере для проверки своих инвариантов:

```bash
#!/bin/bash
# Запусти или скажи агенту "memory-audit" для полного отчёта
echo "=== Инварианты памяти ==="
CRON=$(crontab -u openclaw -l 2>/dev/null)
SERVER=$(hostname)

# Кроны
check() { echo "$CRON" | grep -q "$2" && echo "✅ $1" || echo "❌ НАРУШЕН: $1 ($2)"; }
check "memory-rotate"     "memory-rotate"
[ "$(echo $SERVER | grep -i thrall)" ] && check "obsidian-sync" "obsidian-sync"
[ "$(echo $SERVER | grep -i sylvanas)" ] && check "learnings-merge" "learnings-merge"

# Config
python3 -c "
import json
d = json.load(open('/home/openclaw/.openclaw/openclaw.json'))
ei = d.get('memory',{}).get('qmd',{}).get('update',{}).get('embedInterval','')
ok = ei not in ['0','0s','']
print('✅ embedInterval: ' + ei if ok else '❌ НАРУШЕН: embedInterval=' + ei)
thr = d.get('agents',{}).get('defaults',{}).get('compaction',{}).get('memoryFlush',{}).get('softThresholdTokens',0)
print('✅ softThresholdTokens: ' + str(thr) if thr==4000 else '❌ НАРУШЕН: softThresholdTokens=' + str(thr))
mode = d.get('agents',{}).get('defaults',{}).get('compaction',{}).get('mode','')
print('✅ compaction.mode: ' + mode if mode=='safeguard' else '❌ НАРУШЕН: compaction.mode=' + mode)
"
```

---

## Cron jobs (реестр)

Полный реестр cron jobs: `shared/cron-registry.md` (не дублируется в конституции).

| Сервер | OpenClaw cron | System cron | Heartbeat |
|--------|--------------|-------------|-----------|
| Thrall | 1 | 5 | 3h `grok` |
| Mac mini | 0 | 8 | 2h `grok` (Silvana) |
| Arthas VPS | 0 | 1 | 2h `grok` (Артас) |
| Illidan | 0 | 3 | 2h `kimi` |

### Firebase cron jobs

| Cron | Сервер | Скрипт | Назначение |
|------|--------|--------|-----------|
| `*/2 * * * *` | Mac mini | `firebase-to-obsidian.sh` | Firebase --> Obsidian sync + healthcheck |
| `*/5 * * * *` | Все серверы | `agent-heartbeat.sh` | Heartbeat в `/agents/{id}/heartbeat` |
| `0 4 * * *` | Arthas VPS | `firebase-backup.sh` | Firebase backup --> DO Spaces (restic) |
| `*/15 * * * *` | Arthas VPS | `langfuse-sync.sh` | Langfuse --> Firebase `/finance/api_usage` |
| `0 */1 * * *` | Arthas VPS | `project-cost-rollup.sh` | Расходы по проектам --> `/finance/budget` |

### Правила cron

- Все agentTurn cron = `grok` (стандарт)
- 0 `sonnet` в cron'ах. `opus`/`codex` -- только как spawned workers внутри задач
- **Исключения** (документированные): Morning Briefing (`opus` -- качество авторского текста). Новые исключения -- только через PR
- systemEvent cron'ы = $0 (не тратят модель)
- Правило молчания: если всё ОК -- не алертить принца
- Алерт только при нарушении/аномалии

---

## Аудит конституции (по запросу)

Аудит соответствия системы конституции выполняется по запросу вождя (Тралл запускает cross-review с `grok`-воркерами).

### 8 категорий аудита

1. **Модели** -- правильные модели на всех серверах, Flash отсутствует
2. **Безопасность** -- UFW active, .secrets 700, ownership openclaw
3. **Git Workflow** -- branch protection, CODEOWNERS enforced
4. **Бэкапы** -- restic snapshots не старше 25ч на всех серверах
5. **Конституция** -- одинаковый commit hash на 3 серверах
6. **Heartbeats** -- активные агенты без ошибок
7. **groupPolicy** -- allowlist на всех серверах
8. **Задачная система** -- нет задач в active >48ч без обновления

### При обнаружении нарушения

- P0/P1: немедленный алерт принцу
- P2: записать в inbox

---

## Стандарт памяти (Memory Standard)

Единый регламент для ВСЕХ агентов. Три слоя: личная память агента, общая память команды, семантический поиск (QMD). Исключения для доменных ролей описаны ниже.

---

### Слой 1 — Личная память агента (приватная)

Каждый агент хранит свою память в workspace. Структура одинакова на всех серверах.

#### Структура файлов

```
workspace/<agent>/
├── MEMORY.md                    COLD: архив решений и итогов проектов
├── SOUL.md                      идентичность агента, не меняется
└── memory/
    ├── hot/
    │   └── HOT_MEMORY.md        Now / Next / Blockers. Только активное.
    ├── warm/
    │   ├── WARM_MEMORY.md       Операционная база: серверы, пути, инструменты
    │   └── WATCHLIST.md         Личные наблюдения агента во время работы
    ├── YYYY-MM-DD.md            Дневник сессии, 3-5 строк за flush
    └── archive/                 Ротированные файлы
```

#### Правила по уровням

**HOT -- только активное состояние:**
- Формат: `Now` (что делаю) / `Next` (что дальше) / `Blockers` (что мешает)
- Перезаписывать полностью при каждом flush -- только то, что актуально СЕЙЧАС
- «Сделано» -- НЕ сюда, только в дневник
- Backlog -- НЕ сюда, только в WARM

**WARM -- только операционное:**
- Серверы, IP, пути, скрипты, инструменты, контакты, процедуры
- Идеи и наблюдения -- НЕ сюда, только в WATCHLIST
- Архитектурные решения -- НЕ сюда, только в COLD

**WATCHLIST -- личные наблюдения агента:**
- Что агент заметил во время работы: гипотезы, ресёрч, паттерны
- Формат: название / тезис / статус (наблюдаем / отложено / адаптировано / отклонено)
- Если наблюдение стало проектной идеей -- перенести в `shared/tasks/ideas/` + удалить из WATCHLIST

**LEARNINGS -- уроки из ошибок (Firebase):**
- Записывать через `orgbus push learnings '{...}'` -- напрямую в Firebase
- Listener skill зеркалирует в `agent-memory/firebase/learnings.md` для QMD
- Записывать ТОЛЬКО когда: вождь поправил, ошибка дорогая, паттерн повторяется
- Качество > количество. Не дублировать.
- **Формат урока (3 обязательных поля):**

| Поле | Описание | Обязательно |
|------|----------|-------------|
| `lesson` | Текст урока (до 2000 символов) | да |
| `author` | SA кто записал (автоматически = auth.uid) | да |
| `date` | Дата записи (ISO string) | да |

**COLD -- архив решений:**
- Только уникальные решения и итоги, которых НЕТ в AGENTS.md
- НЕ дублировать: архитектуру, модели, автономность (это в AGENTS.md)

**Дневник -- хронология:**
- Структура: `## Сессия HH:MM-HH:MM UTC`
- 3-5 строк за flush, не повторять предыдущие записи

#### Лимиты

| Параметр | Значение |
|----------|----------|
| Порог memory flush | contextWindow − reserveTokensFloor − softThresholdTokens (`opus`: ~176k) |
| Порог auto-compaction | contextWindow − reserveTokensFloor (`opus`: ~180k) |
| Макс. размер файла для flush | 10 KB |
| Порог ротации | 8 KB |
| Хранение дневников | 3 дня, затем → archive/ |
| AGENTS.md | макс. 20 000 символов |

#### Compaction (автоматическое сжатие)

Формула порогов (из исходников OpenClaw):
```
Memory flush = contextWindow - reserveTokensFloor - softThresholdTokens
Auto-compaction = contextWindow - reserveTokensFloor

opus (200k): flush при ~176k, compaction при ~180k
codex (200k): flush при ~176k, compaction при ~180k
grok (131k): flush при ~107k, compaction при ~111k
```

При достижении порога flush OpenClaw вызывает memoryFlush:

1. Агент проверяет размер каждого файла (`wc -c`) ПЕРЕД записью
2. Если файл >10KB -- пропустить, НЕ писать
3. HOT -- перезаписать полностью (только активные задачи)
4. COLD -- дописать ТОЛЬКО если есть новое архитектурное решение
5. Дневник -- 3-5 строк summary, не повторять прошлые записи
6. **НЕ трогать** `agent-memory/firebase/*.md` -- listener skill обновляет сам
7. Learnings -- писать в Firebase через `orgbus push learnings`, НЕ в локальный файл
8. Если нечего сохранять -- ответить `NO_FLUSH`

#### Boot (старт сессии)

При старте сессии в контекст загружаются **только 3 файла (~8 KB)**:

| Файл | Размер | Содержание |
|------|--------|-----------|
| SOUL.md | ~3.5 KB | Идентичность агента (неизменна) |
| HOT_MEMORY.md | ~1 KB | Активное состояние (NOW / NEXT / BLOCKERS) |
| WARM_MEMORY.md | ~3.5 KB | Операционная база (серверы, пути, инструменты) |

Всё остальное (LEARNINGS, CONVENTIONS, ROSTER, USER, stance, tone, Firebase данные) -- **QMD подмешивает автоматически** при релевантном запросе. Не грузить при boot.

#### Защита от перегрузки контекста

- `contextPruning: cache-ttl, ttl: 6h` -- сообщения старше 6ч автоматически удаляются
- `keepLastAssistants: 3` -- всегда видит 3 последних своих ответа
- QMD при каждом запросе подмешивает max 6 релевантных чанков (не весь файл целиком)
- Boot = 8 KB. Остальное -- on-demand через QMD

#### Ротация (автоматическая, ежедневно)

Скрипт: `scripts/memory-rotate.sh` на каждом сервере.

1. COLD / WARM >8KB → последние 50 строк остаются, старое в `archive/`
2. Дневники старше 3 дней → целиком в `archive/`
3. Cron: `0 21 * * *` (00:00 MSK)

---

### Слой 2 — Общая память команды (shared)

#### Источник правды на Mac mini

```
workspace/_shared/               Эталон. Читается всеми агентами.
├── USER.md                      Профиль вождя (вручную)
├── USER_COGNITIVE_PROFILE.md    Когнитивный профиль вождя (вручную)
├── ROSTER.md                    Реестр агентов (вручную)
├── AGENTS-ROSTER.md             Авто: roster-sync.sh из openclaw.json
├── CONVENTIONS.md               Авто: копия из constitution/ каждые 6ч
├── COSTS.md                     Расходы (вручную)
├── CHATS.md                     Telegram чаты агентов (вручную)
└── TELEGRAM-CHATS.md            Процедуры подключения ботов (вручную)

shared/
├── LEARNINGS.md                 Авто: merge из LEARNINGS всех агентов (каждые 6ч)
└── tasks/
    ├── inbox/                   Входящие задачи
    ├── active/                  Задачи в работе
    ├── done/                    Завершённые задачи
    └── ideas/                   Проектные идеи (idea-capture.sh)
```

#### Obsidian-зеркало (agent-memory/shared/)

Только для чтения. Синхронизируется с GitHub каждый час (obsidian-sync.sh на Thrall).

```
agent-memory/shared/
├── все файлы из workspace/_shared/    rsync каждый час
├── LEARNINGS.md                       из shared/LEARNINGS.md каждый час
├── CONVENTIONS.md                     из constitution/ каждый час (актуальная версия)
└── IDEAS.md                           агрегация из tasks/ideas/ (плоский список)
```

#### Firebase как source of truth

Firebase RTDB = единственный source of truth для shared данных:
- **tasks** -- `/tasks/` (замена `shared/tasks/`)
- **events** -- `/events/` (append-only лог)
- **learnings** -- `/learnings/` (замена `shared/LEARNINGS.md` и `memory/warm/LEARNINGS.md`)
- **agents status** -- `/agents/` (статусы, heartbeat)
- **content** -- `/content/` (по платформам: telegram/, youtube/, instagram/)
- **messages** -- `/messages/inbox/{agent}/` (per-agent inbox)

Файловый `shared/` на Mac mini -- **deprecated**. Новые данные пишутся только в Firebase через `orgbus push/patch`.

#### Realtime sync: Firebase --> .md --> QMD (Listener Skill)

Данные из Firebase зеркалируются в локальные .md файлы через **SSE (Server-Sent Events)** -- realtime push без cron/polling. Listener skill на каждом сервере:

1. Держит SSE-подключения к Firebase
2. При изменении -- обновляет .md файл
3. Вызывает `qmd update` (BM25 переиндексация, ~1s)
4. Каждые 5 мин / 5 events -- `qmd embed` (vector, ~5-10s)

```
Firebase RTDB --> SSE --> Listener skill --> agent-memory/firebase/*.md --> QMD
```

| SSE Stream | Firebase path | .md файл | Формат |
|-----------|---------------|----------|--------|
| 1 | `/tasks/` | `tasks-mine.md` | Компактный (title + status + assignee) |
| 2 | `/messages/inbox/{agent}/` | `messages.md` | Per-agent inbox |
| 3 | `/learnings/` | `learnings.md` | Полный (последние 20, lesson + author + date) |
| 4 | `/content/telegram/ideas/` | `content-ideas.md` | Средний (title + concept + status) |
| 5 | `/agents/` | `agents-status.md` | Компактный (имя + статус + last seen) |

**Результат:** QMD ищет по ВСЕМ данным (личная память + Firebase зеркала) через единый поисковый слой. Задержка от записи в Firebase до видимости в QMD -- **2-3 секунды**.

**При потере SSE-соединения:** reconnect с exponential backoff. .md файлы остаются (stale но рабочие). Агент работает на cached данных.

#### Learnings -- единый путь

```
Агент -> orgbus push learnings '{...}' -> Firebase /learnings/
    -> SSE -> Listener -> learnings.md -> QMD
```

**Deprecated:** `learnings-merge.py`, `shared/LEARNINGS.md`, локальный `memory/warm/LEARNINGS.md`. Одна копия -- Firebase. Одно зеркало -- .md для QMD.

#### Правила shared памяти

- `workspace/_shared/` -- источник правды для ручных файлов (USER.md, ROSTER.md и др.)
- Агенты НЕ пишут напрямую в `_shared/` -- только через скрипты или вождь вручную
- `agent-memory/firebase/` -- read-only, обновляется listener skill'ом
- Запись shared данных -- ТОЛЬКО через `orgbus push/patch` в Firebase

---

### Слой 3 — QMD (семантический поиск)

#### Что такое QMD

QMD -- локальный векторный индекс на каждом сервере. При каждом запросе к агенту OpenClaw ищет релевантные фрагменты памяти и автоматически добавляет их в контекст.

#### Где должен быть

| Сервер | Агенты | QMD |
|--------|--------|-----|
| Thrall | Тралл | ✅ обязателен |
| Mac mini | Сильвана | ✅ обязателен |
| Arthas VPS | Артас | ✅ обязателен |
| Illidan | Иллидан | ✅ обязателен |

#### Что индексирует (index.yml на каждом сервере)

```yaml
collections:
  memory-root:       workspace/<agent>/MEMORY.md
  memory-dir:        workspace/<agent>/memory/**/*.md
  shared:            agent-memory/shared/**/*.md
  firebase:          agent-memory/firebase/**/*.md
  sessions:          agents/<id>/qmd/sessions/**/*.md
```

**Обязательно:** коллекции `shared` и `firebase` должны быть на всех серверах -- QMD = единый поисковый слой по личной памяти, shared файлам и Firebase зеркалам.

#### Параметры

| Параметр | Значение |
|----------|----------|
| Backend | BM25 + Vector + LLM reranking (локальные GGUF модели) |
| Модели | gemma-300M (embeddings), qwen3-reranker-0.6B, qmd-query-expansion-1.7B |
| Поиск | hybrid: Reciprocal Rank Fusion (BM25 + vector + reranking) |
| Chunking | 900 токенов, 15% overlap |
| Обновление FTS | listener skill вызывает `qmd update` при каждом SSE event (~1s) |
| Обновление embeddings | listener skill вызывает `qmd embed` каждые 5 мин / 5 events (~5-10s) |
| Max результатов при запросе | 6 чанков |
| Session memory | 30 дней |

---

### Маршрутизация идей

| Источник | Куда | Инструмент |
|----------|------|-----------|
| Идея от вождя (проектная) | `shared/tasks/ideas/` | `idea-capture.sh` |
| Агент заметил сам во время работы | `memory/warm/WATCHLIST.md` | flush / вручную |
| WATCHLIST → стала проектной (повторное упоминание, вождь сказал «делай») | `shared/tasks/ideas/` + удалить из WATCHLIST | `idea-capture.sh` |
| Задача выполнена | `shared/tasks/done/` | `task-complete.sh` |

**Правило одного вопроса:** «Если не сделать -- что-то сломается или потеряется?»
- Да → ЗАДАЧА → `inbox/`
- Нет, но ценно → ИДЕЯ → `ideas/` или `WATCHLIST`
- Нет → ЗАПРОС → ответить, не записывать

---

### Кроны памяти (обязательные)

#### Arthas VPS + Mac mini

| Расписание | Скрипт | Что делает |
|-----------|--------|-----------|
| `0 21 * * *` | `memory-rotate.sh` ×3 | ротация Сильваны, Артаса |
| ~~`0 */6 * * *`~~ | ~~`constitution-sync.sh`~~ | **DEPRECATED** — заменён Firebase sync (GitHub Action `sa-github-action`) |
| `0 */6 * * *` | ~~`learnings-merge.py`~~ | **DEPRECATED**: заменён Firebase + Listener skill |

#### Thrall

| Расписание | Скрипт | Что делает |
|-----------|--------|-----------|
| `0 21 * * *` | `memory-rotate.sh` | ротация памяти Тралла |
| `0 * * * *` | `obsidian-sync.sh` | sync `_shared/` + `LEARNINGS` + `CONVENTIONS` → `agent-memory/shared/` → GitHub |

#### Illidan

| Расписание | Скрипт | Что делает |
|-----------|--------|-----------|
| `0 21 * * *` | `memory-rotate.sh` | ротация памяти Иллидана |
| ~~`0 */6 * * *`~~ | ~~`constitution-sync.sh`~~ | **DEPRECATED** — заменён Firebase sync (GitHub Action `sa-github-action`) |

**Итого: 5 активных кронов памяти** на 3 сервера (3× `constitution-sync.sh` DEPRECATED — заменены Firebase sync).

---

### Shared Memory (shared-memory)

**Скилл:** `shared-memory` (файл: `skills/shared-memory/SKILL.md`)

Обязателен для всех агентов. При старте загружает только boot-файлы (SOUL + HOT + WARM = 8 KB). Shared данные (USER.md, ROSTER.md, CONVENTIONS.md, LEARNINGS и др.) подгружаются автоматически через QMD при релевантном запросе.

| Триггер | Что происходит |
|---------|---------------|
| Старт сессии | Boot: SOUL + HOT + WARM (~8 KB) |
| Любой запрос | QMD подмешивает релевантные чанки из всех collections (личное + shared + firebase) |
| Нужны детали по ID | `orgbus get {path}/{id}` -- точечный запрос в Firebase |

### Firebase Listener (firebase-listener)

**Скилл:** `firebase-listener` (файл: `skills/firebase-listener/SKILL.md`)

Обязателен для всех серверов. SSE-подключение к Firebase RTDB, realtime sync в .md файлы.

| Что делает | Как |
|-----------|-----|
| Слушает Firebase через SSE | `curl -N -H "Accept: text/event-stream"` |
| Обновляет .md при изменении | Инкрементальная запись в `agent-memory/firebase/` |
| Обновляет QMD индекс | `qmd update` на каждый event, `qmd embed` каждые 5 мин |
| Reconnect при обрыве | Exponential backoff, cached .md остаются |

### Самоаудит памяти (memory-audit)

**Скилл:** `memory-audit` (файл: `skills/memory-audit/SKILL.md`)

Каждый агент обязан периодически проводить самоаудит памяти по регламенту конституции.

#### Когда запускать

| Триггер | Кто | Как |
|---------|-----|-----|
| Команда принца: «аудит памяти», «memory-audit», «проверь память» | любой агент | немедленно |
| Еженедельно (воскресенье) | любой агент | по крону или вручную |
| После крупных изменений конфигурации | агент, вносивший изменения | после изменения |

#### Что проверяется (7 разделов)

| Раздел | Содержание |
|--------|-----------|
| А. Личная память | Наличие 6 файлов (HOT/WARM/WATCHLIST/LEARNINGS/MEMORY/SOUL), размеры |
| Б. Compaction | Промпт flush содержит все 6 элементов, `softThresholdTokens: 4000`, `compaction.mode: safeguard` |
| В. Shared память | `_shared/` — 8 файлов (Mac mini, master), `agent-memory/shared/` — 10 файлов (все серверы) |
| Г. QMD | index.yml: 5 коллекций включая `shared`, `embedInterval: 30m` |
| Д. Obsidian sync | Покрытие 5 агентов, последний успешный запуск (только Тралл) |
| Е. Cron | Обязательные кроны по серверу присутствуют |
| Ж. Маршрутизация | idea-capture.sh обновляет IDEAS.md и пушит в GitHub |

#### Выходной формат

```markdown
# Memory Audit — <agent> — <YYYY-MM-DD>
| Раздел | Статус | Детали |
...
Общий балл: X/7 ✅
```

**Правило:** если найдены ❌ CRITICAL — немедленно сообщить принцу. Если только ⚠️ — занести в HOT_MEMORY.md (Blockers) и предложить план.

---

### Запрещено

- Записывать API ключи, токены, пароли в любые memory файлы
- Дублировать данные из AGENTS.md в COLD
- Писать «сделано» в HOT (только в дневник)
- Писать идеи/наблюдения в WARM (только в WATCHLIST)
- Игнорировать проверку размера перед записью (flush)
- Писать в `agent-memory/shared/` напрямую (только через obsidian-sync)
- Писать в `shared/LEARNINGS.md` напрямую (только через learnings-merge.py)
- **Удалять защищённые кроны** (ART-C1,C3..C6, THR-C1,C3..C5, ILL-C2) без замены — см. раздел «Инварианты памяти». ART-C2, THR-C2, ILL-C1 (`constitution-sync.sh`) DEPRECATED — заменены Firebase sync.
- **Менять `embedInterval` на `"0"`** — QMD перестаёт строить эмбеддинги
- **Удалять коллекцию `shared-main`** из QMD index.yml любого агента

### Кельтас (АРХИВИРОВАН 2026-03-05)

> Роль creator объединена с Сильваной. Контентные задачи (память, pipeline, sources) перенесены в workspace Сильваны.
> Доменные файлы Кельтаса теперь в content/ и memory/ Сильваны.

## Система уведомлений (AI alerts)

### Канал

| Параметр | Значение |
|----------|----------|
| Канал | AI alerts (ID в конфиге агента) |
| Платформа | Telegram |
| Боты-админы | Артас, Сильвана, Тралл |
| Язык | Русский |
| Макс постов/день | 5 (целевой -- 3) |

### Потоки

| Поток | Расписание | Сервер | Модель | Владелец |
|-------|-----------|--------|--------|----------|
| Morning Briefing | 07:00 UTC daily | Thrall | `opus` (fallback `codex`) | Тралл |
| Blocked Tasks | */15 cron bash | Mac mini | -- (без AI) | Сильвана |
| Ideas Digest | 09:00 UTC (12:00 MSK) Вт,Пт | Thrall | `grok` | Тралл |
| Health Alert | по событию | Arthas VPS | Артас heartbeat | Артас |
| Personal Reminders | по запросу вождя | Arthas VPS | Артас | Артас (DM) |

### Morning Briefing

#### Источники

Конфиг: `data/ai-news-sources.conf` (Thrall workspace).
Формат: `tg|channel_name` или `tw|twitter_handle`, одна строка на источник.
Управление: вождь говорит Траллу «добавь канал @X» / «убери твиттер @Y».
Конкретные источники в конституции НЕ перечисляются -- source of truth в конфиге.

#### Пайплайн

1. **Сбор** (bash): `scripts/collect-ai-news.sh` парсит все источники за последние 24ч
   - Telegram: `curl t.me/s/{channel}`, `data-post` ID -> прямые ссылки `t.me/channel/post_id`
   - Twitter: SocialData API (`$SOCIALDATA_API_KEY`), User-Agent обязателен
2. **Анализ + текст** (`opus`): ТОП 3-5 новостей AI + саммари каналов, авторский пост
3. **Отправка** (bash): `scripts/send-to-channel.sh` -- Telegram Bot API, `link_preview_options.is_disabled: true`

#### Fallback при сбое сбора

- Если 0 элементов собрано (API down / парсинг сломался) -- пропустить день, не отправлять пустой пост.
- Если собрано <10 элементов -- отправить с пометкой «сокращённый выпуск».
- При 3+ днях подряд без данных -- алерт вождю.

#### Tone of Voice

- Авторский стиль, не RSS-лента. Уверенный аналитик со своим мнением.
- Сразу тезис. Без вступлений.
- Логика и причинно-следственные связи между новостями.
- Короткие абзацы: 2-4 предложения. 1 абзац = 1 мысль. Пустая строка между абзацами.
- Конкретика: числа, суммы, проценты. Без «примерно».
- Комментарии допустимы: «по факту...», «это уже в цене», «главное здесь не X, а Y».
- Ссылка в конце абзаца: `([->](URL))`.
- Кавычки русские: «». Тире короткое: –.
- Эмодзи: 0-1 на пост. НЕ нумерованный список -- абзацами.
- Запрещено: «Что это значит на практике:», «Почему это важно:», шаблонные вступления.
- Макс 1500 символов.

#### Правило ссылок

URL берутся ТОЛЬКО из данных парсера (теги `[https://...]` в raw-файле). Ссылки на профили/каналы запрещены -- только на конкретные посты и твиты.

### Blocked Tasks Scanner

- Скрипт: `scripts/notify-chief-channel.sh` + `scripts/check-needs-chief.sh` (Mac mini)
- Проверяет задачи с `needs_chief=yes`
- Дедупликация: ключ `task_id`, TTL 24ч, state в `/tmp/notified-tasks.json`
- Формат: `НУЖНА ПОМОЩЬ` + кто, что, причина, task ID
- Если заблокированных нет -- молчит
- При >5 blocked одновременно -- группирует в один пост

### Ideas Digest

- Расписание: 09:00 UTC (12:00 MSK) Вт, Пт
- Собирает: `WATCHLIST.md` (Thrall) + `shared/tasks/ideas/` (Mac mini)
- Формат: ТОП-3 идеи с Effort (S/M/L), ROI, первый шаг
- Если идей нет -- не отправляет

### Health Alert

- Триггер: WHOOP recovery <33% или sleep <6h
- Источник: Артас heartbeat (WHOOP API)
- Канал: AI alerts. Формат: `ЗДОРОВЬЕ` + метрики + рекомендация
- Token refresh: `scripts/whoop-token-refresh.sh` каждые 12ч (Arthas VPS system cron)

### Personal Reminders

- Триггер: запрос вождя (через любого агента)
- Доставка: DM вождю через Артаса (не в канал)
- Формат: свободный, с указанием контекста напоминания

### Anti-noise правила

1. Макс 5 постов/день в канал. Целевой -- 3. Критические алерты (ЗДОРОВЬЕ, НУЖНА ПОМОЩЬ) не лимитируются.
2. Каждый пост начинается с bold CAPS-заголовка: **BRIEFING** / **НУЖНА ПОМОЩЬ** / **ИДЕИ** / **ЗДОРОВЬЕ**.
3. Запрещено в канале: heartbeat-логи, DCA-отчёты, технические дампы, мемы.
4. Дедупликация: одна новость/задача не публикуется дважды за 24ч.
5. Если нечего сообщать -- молчание. Пустые дайджесты не отправляются.

### Пауза / возобновление

Для временной паузы потока (отпуск, техработы):
- Morning Briefing: `cron(action=update, jobId=..., patch={enabled: false})`
- Blocked Tasks: закомментировать строку в `crontab -u openclaw`
- Возобновление: обратное действие. Вождь или Тралл.

### Скрипты

| Скрипт | Сервер | Назначение |
|--------|--------|------------|
| `scripts/collect-ai-news.sh` | Thrall | Сбор постов TG + Twitter за 24ч |
| `scripts/send-to-channel.sh` | Thrall | Отправка в канал без link preview |
| `data/ai-news-sources.conf` | Thrall | Конфиг источников |
| `scripts/notify-chief-channel.sh` | Mac mini | Blocked tasks scanner |
| `scripts/check-needs-chief.sh` | Mac mini | Проверка needs_chief задач |
| ~~`scripts/whoop-token-refresh.sh`~~ | ~~Arthas VPS~~ | REMOVED (2026-03-06) |

Cron ID потоков -- в `shared/cron-registry.md` (source of truth для расписаний).
## Task Dashboard (task.orgrimmar.xyz)

### Общее

| Параметр | Значение |
|----------|----------|
| URL | `task.orgrimmar.xyz` |
| Хостинг | Timeweb VPS (отдельный сервер, только frontend + API) |
| Источник данных | Mac mini (`/home/openclaw/.openclaw/shared/tasks/`) |
| Обновление board.json | каждые 15 мин (root cron, `sync-dashboard.sh`) |
| Обработка действий | каждую 1 секунду (systemd `dashboard-queue.service`) |
| Mobile-first | Оптимизирован под Telegram WebView (iPhone) |

### Миграция на Firebase Hosting (Firebase)

Dashboard мигрирует с Timeweb VPS на Firebase Hosting (`orgrimmar-brain.web.app`). Ключевые изменения:
- Realtime подписка на Firebase RTDB вместо polling `board.json` каждые 15 мин
- Нет промежуточного сервера (Timeweb) -- прямое подключение к Firebase
- Авторизация через Firebase Auth (замена SHA-256 пароля)
- Latency: realtime (вместо 15 мин polling + 1 сек queue)

### Авторизация

Два метода параллельно:
1. **Пароль** -- SHA-256 hash в клиентском JS. Значение пароля хранится в `shared/secrets/dashboard-password.txt` (не в конституции).
2. **Google Sign-In** -- admin email в конфиге. Полный доступ = admin. Остальные email = пустая доска.

### Дизайн

Shuttle-style тёмный минимализм.

**Цветовая палитра:**

| Токен | Значение | Назначение |
|-------|----------|------------|
| `--bg` | `#000000` | Фон |
| `--bg-elev-1` | `#0A0A0A` | Карточки |
| `--bg-elev-2` | `#111111` | Hover-состояния |
| `--surface-hover` | `#171717` | Hover карточек |
| `--border-subtle` | `#232323` | Границы |
| `--text-primary` | `#FFFFFF` | Заголовки |
| `--text-secondary` | `#B3B3B3` | Описания |
| `--text-tertiary` | `#7A7A7A` | Мета-данные |
| `--accent` | `#2F6BFF` | Кнопки, активные ссылки |
| `--error` | `#EF4444` | Ошибки, blocked |
| `--success` | `#16A34A` | Done |
| `--warning` | `#F59E0B` | In progress, pipeline |

**Типографика:**

- Основной шрифт: Inter (500/700/800)
- Моноширинный: JetBrains Mono (ID задач)
- H1: 32px, weight 800, letter-spacing -0.02em
- H2: 20px, weight 700
- Мета: 12px, weight 500

**Компоненты:**

- Радиус карточек: 16px (`--r-lg`)
- Радиус бейджей: 22px (`--r-md`)
- Радиус кнопок: 10px (`--r-sm`)
- Анимации: 140ms/200ms/280ms, cubic-bezier(0.2, 0.8, 0.2, 1)
- Карточки -- аккордеон (expand/collapse)
- Sticky header + tabs
- URL в title/description -- автолинкификация (кликабельные, цвет `#5b9aff`)
- ID задачи -- tap-to-copy (клик копирует в буфер, текст зеленеет на 0.8с как подтверждение)

### Вкладки

4 вкладки, фиксированная ширина, равные:

| Вкладка | Содержимое | Кнопки |
|---------|-----------|--------|
| Ideas | Идеи из `ideas/` | Archive, Activate |
| Inbox | Новые задачи из `inbox/` | Archive, Activate |
| Active | Задачи в работе из `active/` (включая pipeline, review, blocked) | Archive, Done |
| Done | Завершённые из `done/` | Archive, Activate |

### Статусы задач (бейджи)

| Статус | Цвет бейджа | Описание |
|--------|------------|----------|
| new | `#3b82f6` (синий) | Новая задача |
| progress | `#f59e0b` (жёлтый) | В работе |
| pipeline | `#f59e0b` (жёлтый) | Выполняется pipeline |
| blocked | `#ef4444` (красный) | Заблокирована (+ CHIEF бейдж если needs_chief) |
| review | `#a855f7` (фиолетовый) | На ревью |
| done | `#22c55e` (зелёный) | Завершена |

### Карточка задачи

Каждая карточка содержит:
- **Бейдж статуса** -- цвет по таблице выше
- **From** -- кто создал (prince/silvana/thrall/etc)
- **Title** -- заголовок (URL автолинкификация)
- **Created** -- дата создания
- **CHIEF бейдж** -- красный, если `needs_chief=yes`
- **Expand:** ID, From, Assignee, Status, Stage, Created, Updated
- **Description** -- полный текст (URL автолинкификация)
- **Кнопки действий** -- Archive / Done / Activate

### API

Endpoints (см. приватную документацию):

| Endpoint | Метод | Auth | Описание |
|----------|-------|------|----------|
| `/api/health` | GET | нет | `{"ok": true, "pending": N}` |
| `/api/archive` | POST | Bearer token | `{"id": "TASK-..."}` -- перемещает в done |
| `/api/activate` | POST | Bearer token | `{"id": "TASK-..."}` -- перемещает в active |
| `/board.json` | GET | нет | Полный board: inbox/active/done/ideas |

Bearer token = SHA-256 от пароля. Хранится в клиентском JS.

### Очередь действий (queue/)

Директория `/var/www/task-dashboard/queue/` на Timeweb — асинхронная очередь команд принца:

| Поле | Описание |
|------|----------|
| `action` | `activate` / `archive` |
| `id` | ID задачи (например `TASK-20260301...`) |
| `ts` | Unix timestamp создания |
| `by` | Кто инициировал |

**Обработчик:** `process-dashboard-queue.sh` запущен как `dashboard-queue.service` (systemd, автостарт).
Читает queue через SSH, применяет `mv` локально на Mac mini, удаляет обработанные файлы, синхронизирует board.json.
**Latency:** ≤1 секунда от нажатия до отражения в файловой системе.

### Файловая структура задач (Mac mini)

```
/home/openclaw/.openclaw/shared/tasks/
  inbox/          -- новые задачи (task-inbox.sh)
  active/         -- задачи в работе
  done/           -- завершённые
  ideas/          -- идеи (idea-capture.sh)
  board.json      -- сгенерированный board
```

### Формат файла задачи

```
id: TASK-YYYYMMDDHHMMSS-RANDOM
from: prince|silvana|thrall|arthas|illidan|self
assignee: имя_агента
status: inbox|progress|pipeline|blocked|review|done
stage: текст текущего этапа
priority: P0|P1|P2|P3
needs_chief: yes|no
blocked_reason: текст (если needs_chief=yes)
created: YYYY-MM-DD HH:MM UTC
updated: YYYY-MM-DD HH:MM UTC
---
Заголовок задачи

Описание и лог обновлений.
```

### Скрипты (Mac mini + Arthas VPS)

| Скрипт | Расположение | Назначение |
|--------|-------------|------------|
| `task-inbox.sh "описание" assignee` | `shared/tasks/` | Создать задачу в inbox |
| `task-update.sh TASK-ID field value` | `shared/tasks/` | Обновить поле задачи |
| `task-complete.sh TASK-ID "результат"` | `shared/tasks/` | Завершить задачу (→ done/) |
| `task-board.py` | `shared/tasks/` | Генерация board.json из файлов |
| `idea-capture.sh "описание"` | `shared/tasks/` | Создать идею + обновить shared/IDEAS.md |
| `sync-dashboard.sh` | `shared/tasks/` | Генерация board.json + SCP на Timeweb (cron */15) |
| `process-dashboard-queue.sh` | `scripts/` | Обработка очереди действий с дашборда (systemd, каждые 1 сек) |

### Pipeline обновления

**Данные → дашборд (каждые 15 мин):**


**Действие принца → файловая система (каждые 1 сек):**


**Источник правды:** всегда Mac mini (). Timeweb — только зеркало для отображения и очередь действий.
