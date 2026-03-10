# Стандарт агента: Артас (Monitor)

_Полное описание архитектуры, конфигурации и регламента работы агента Артас._

---

## Общие сведения

| Параметр | Значение |
|----------|----------|
| **Имя** | Артас |
| **Роли** | monitor |
| **Сервер** | Arthas VPS |
| **Workspace** | `/home/openclaw/.openclaw/workspaces/arthas/` |
| **Config** | `/home/openclaw/.openclaw/openclaw.json` |
| **Канал** | Telegram (@arthasmonitorbot) |

---

## Модельная конфигурация

| Параметр | Модель | Обоснование |
|----------|--------|-------------|
| **Primary** | `grok` (xAI) | Дешёвая, быстрая. Мониторинг не требует сложных рассуждений |
| **Fallback** | `kimi` (Moonshot) | Альтернатива при недоступности Grok |
| **Субагенты** | `grok` (xAI) | Max 5 параллельных |

**Fallback-цепочка:** `grok` -> `kimi`

**Heartbeat:** OFF (Артас работает реактивно -- реагирует на входящие сообщения)

---

## Роль и поведение

Секретарь рабочих чатов. Молчаливый наблюдатель.

### Правила поведения в чатах
- **МОЛЧИТ** по умолчанию
- Отвечает ТОЛЬКО на прямое обращение (@arthas, "Артас")
- Никогда не отправляет системные/технические сообщения в группы
- Обращение к принцу: "мой принц"
- WoW-стиль (ледяной дозорный) -- только в ответах принцу

### Режимы чатов (chat-registry.md)

| Тип | Поведение |
|-----|-----------|
| OWNER | Полный доступ, отвечает всегда (DM принца) |
| INTERNAL | Деловой режим, только @mention/reply |
| COMMUNITY | Голос эксперта, только @mention |
| Незарегистрированный | SILENT -- только логирует |

---

## Память (3 уровня)

### Структура файлов

```
workspaces/arthas/
├── MEMORY.md                       <- COLD: долгосрочный архив (вехи, решения)
├── memory/
│   ├── hot/HOT_MEMORY.md           <- HOT: текущие задачи сессии
│   ├── warm/WARM_MEMORY.md         <- WARM: стабильные факты (контакты, правила, скиллы)
│   ├── warm/LEARNINGS.md           <- уроки из ошибок
│   ├── warm/WATCHLIST.md           <- наблюдения
│   ├── YYYY-MM-DD.md              <- ежедневный дневник
│   ├── archive/INDEX.md           <- индекс архива
│   └── chats/                      <- per-chat история (см. ниже)
```

### Порядок чтения при старте сессии

COLD -> WARM -> HOT

### Размерные лимиты

| Файл | Лимит | Действие при превышении |
|------|-------|------------------------|
| HOT_MEMORY.md | нет | Перезаписывается каждую сессию |
| WARM_MEMORY.md | 8 KB | Архивация (last 50 lines остаются) |
| MEMORY.md (COLD) | 8 KB | Архивация (last 50 lines остаются) |
| LEARNINGS.md | 8 KB | Архивация |
| summary.md (per-chat) | 8 KB | Обрезка tail -c 8000 |

---

## Shared память

```
workspaces/arthas/_shared/          <- READ-ONLY
├── USER.md                         <- профиль принца
├── USER_COGNITIVE_PROFILE.md       <- стиль общения принца
├── ROSTER.md                       <- реестр всех агентов
├── CONVENTIONS.md                  <- код/git/shell-конвенции
├── COSTS.md                        <- бюджет
└── CHATS.md                        <- список чатов и ботов
```

- Синхронизация: Тралл пушит каждый час
- Артас только читает, никогда не пишет в `_shared/`

---

## Хранение чатов (4 слоя)

### Слой 1: Живые сессии

```
agents/arthas/sessions/{UUID}-topic-N.jsonl
```

Каждый Telegram-топик = отдельная сессия OpenClaw. Полная изоляция данных между чатами.

### Слой 2: QMD-саммари

```
agents/arthas/qmd/sessions/{UUID}.md
```

Генерируются автоматически OpenClaw gateway. Markdown-саммари содержимого сессии.

### Слой 3: Per-chat архив

```
workspaces/arthas/memory/chats/
├── topic-1/
│   ├── summary.md                  <- rolling саммари (max 8 KB)
│   └── archive/                    <- датированные QMD-бэкапы
├── topic-10862/
├── topic-113505/
├── topic-116748/
├── topic-123357/
├── topic-12959/
├── topic-30109/
├── topic-353/
├── topic-529/
└── dm-personal/
```

Заполняется при ротации сессий: QMD -> archive/, tail QMD -> summary.md.

### Слой 4: Структурированные логи

```
workspaces/arthas/data/jsonl/YYYY-MM-DD.jsonl
```

Формат: `{"ts":"ISO","chat_id":"...","chat_name":"...","type":"message","author":"...","text":"..."}`

Записывается chat-ops скиллом + chat_jsonl_collector.py.

---

## Ротация сессий

### Скрипт: `scripts/session-rotate.sh`

**Cron:** ежедневно 04:00 UTC

**Логика:**
1. Сканирует все `.jsonl` в `agents/arthas/sessions/`
2. Для каждой сессии > 500 KB:
   - Определяет topic из имени файла (`*-topic-N.jsonl` -> `topic-N`, иначе `dm-personal`)
   - Копирует QMD из `qmd/sessions/` в `memory/chats/{topic}/archive/YYYY-MM-DD-{id}.md`
   - Добавляет последние 50 строк QMD в `summary.md` (append)
   - Обрезает `summary.md` до 8 KB
   - Удаляет старую сессию -- OpenClaw создаёт новую автоматически
3. Dry-run по умолчанию, `--execute` для реального запуска

### Скрипт: `scripts/memory-rotate.sh`

**Cron:** ежедневно 21:00 UTC

**Логика:**
1. MEMORY.md, WARM_MEMORY.md, LEARNINGS.md > 8 KB -> архивация (last 50 lines остаются)
2. Дневники старше 3 дней -> `archive/`
3. Перегенерирует `archive/INDEX.md`

### Compaction (встроенный OpenClaw)

```
softThresholdTokens: 40000        <- ~20% от контекста, memoryFlush срабатывает
forceFlushTranscriptBytes: 1048576 <- принудительный flush при 1 MB транскрипта
reserveTokensFloor: 30000         <- минимальный резерв для ответа
```

При memoryFlush Артас сохраняет важное в `memory/YYYY-MM-DD.md`.

---

## Алерты

### Алерт 1: Упоминание принца

**Скилл:** `chat-alerts`

**Триггеры:**
- @mention принца (алиасы принца)
- Reply на сообщение принца
- Имя: «принц», «вождь»

**Формат:**
```
[ALERT] Упоминание в <название чата>
Кто: @username (имя)
Что: краткая суть (1-2 строки)
Ссылка: t.me/c/CHAT_ID/MESSAGE_ID
Время: ДД.ММ.ГГГГ ЧЧ:ММ MSK
```

**Ссылка обязательна.** `chat_id` берётся из inbound metadata (без -100), `message_id` из inbound metadata.

**Антиспам:**
- Нет дубликатов (один алерт на сообщение)
- Нет самоалертов (свои сообщения игнорируются)
- Тишина если принц писал в чат < 5 мин назад

### Алерт 2: Context overflow

**Скрипт:** `scripts/notify-overflow.sh`
**Cron:** каждые 5 мин

**Логика:**
1. Мониторит `journalctl -u openclaw` на `context overflow` / `prompt too large`
2. Шлёт DM принцу через Telegram Bot API
3. Токен из `/opt/openclaw.env` (`ARTHAS_BOT_TOKEN`)
4. Rate-limit: 1 раз в час (state file `/tmp/arthas-overflow-notified`)

### Алерт 3: Траты (cost-tracker)

После каждого алерта (chat-alerts) Артас автоматически добавляет строку с фактическими тратами OpenRouter:

```
Траты: $X.XX/час | $Y.YY/день
```

**Скрипт:** `scripts/arthas-spend.sh` -- обёртка над `or_manager.py`

```bash
bash scripts/arthas-spend.sh 1h   # траты за час
bash scripts/arthas-spend.sh 24h  # траты за день
bash scripts/arthas-spend.sh 7d   # траты за неделю
```

Возвращает JSON: `{"agent":"arthas","cost_usd":0.03,"assistant_messages":45,...}`

Данные берутся из session JSONL (`usage.cost` в каждом ответе модели) -- это фактические траты, не лимиты.

По запросу принца (`/cost`, «траты», «расходы») -- полный отчёт: за час / за день / за неделю.

### Абсолютное правило

Никогда не отправлять системные ошибки, context overflow, compaction failure, технические сообщения в групповые чаты. Только DM принцу.

---

## Скиллы (14)

### Базовые (8)

| Скилл | Назначение |
|-------|-----------|
| `shared-memory` | Общая память команды (читать при старте) |
| `task-system` | Работа с задачной системой |
| `learnings` | Запись ошибок и уроков |
| `memory-tiering` | Управление HOT/WARM/COLD |
| `transcript` | Транскрипция YouTube |
| `twitter` | Чтение Twitter/X (FxTwitter + SocialData fallback) |
| `gog` | Google Calendar, Gmail, Drive |
| `memory-audit` | Самоаудит памяти |

### Ролевые (3)

| Скилл | Назначение |
|-------|-----------|
| `chat-alerts` | Алерт принцу при @mention/reply с ссылкой |
| `chat-ops` | JSONL логирование, per-chat режимы, watchdog задач |
| `topic-monitor` | Мониторинг тем через веб-поиск |

### Дополнительные (3)

| Скилл | Назначение |
|-------|-----------|
| `cost-tracker` | Фактические траты OpenRouter (после каждого алерта + по запросу /cost) |
| `whoop-cli` | Здоровье (Whoop браслет) |
| `market-data` | Рыночные данные |

---

## Cron-расписание (user: openclaw)

| Время | Скрипт | Задача |
|-------|--------|--------|
| `*/5 * * * *` | `notify-overflow.sh` | Детекция overflow -> DM принцу |
| `0 4 * * *` | `session-rotate.sh --execute` | Ротация сессий > 500 KB |
| `0 21 * * *` | `memory-rotate.sh` | Ротация памяти > 8 KB, архив дневников |
| `0 */6 * * *` | `constitution-sync.sh` | Синк конституции |
| `0 */6 * * *` | `learnings-merge.py` | Мерж уроков в shared |

---

## Поток данных

```
Telegram сообщение
  |
  v
OpenClaw -> sessions/{UUID}-topic-N.jsonl
  |
  +-> QMD gateway -> qmd/sessions/{UUID}.md (авто-саммари)
  +-> chat_jsonl_collector.py -> data/jsonl/YYYY-MM-DD.jsonl
  |
  +-> Артас обрабатывает:
  |     +-> @mention принца? -> chat-alerts -> DM принцу
  |     +-> Важное? -> запись в data/jsonl/ (chat-ops)
  |     +-> Прямой запрос? -> ответ по chat-registry.md
  |
  +-> При ~70% контекста: memoryFlush -> memory/YYYY-MM-DD.md
  |
  +-> 04:00 UTC: session-rotate.sh
  |     sessions > 500 KB ->
  |       QMD -> memory/chats/{topic}/archive/
  |       tail QMD -> summary.md (max 8 KB)
  |       delete session -> OpenClaw creates new
  |
  +-> 21:00 UTC: memory-rotate.sh
        MEMORY/WARM/LEARNINGS > 8 KB -> archive/
        diary > 3 days -> archive/
```
