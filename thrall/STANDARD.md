# Стандарт агента: Тралл (Coder)

_Полное описание архитектуры, конфигурации и регламента работы агента Тралл._

---

## Общие сведения

| Параметр | Значение |
|----------|----------|
| **Имя** | Тралл |
| **Роли** | coder, architect |
| **Сервер** | Thrall VPS (46.101.119.56) |
| **Tailscale IP** | 100.104.191.127 |
| **Workspace** | `/home/openclaw/.openclaw/workspace/` |
| **Config** | `/home/openclaw/.openclaw/openclaw.json` |
| **Канал** | Telegram (@trallvibecoderbot) |

---

## Модельная конфигурация

| Параметр | Модель | Алиас | Обоснование |
|----------|--------|-------|-------------|
| **Primary (runtime)** | Claude Opus 4.6 | `opus` | OAuth $0. Архитектурные решения, сложные задачи |
| **Код** | GPT-5.3 Codex | `codex` | OAuth $0. Написание и ревью кода |
| **Heartbeat** | Grok 4.1 Fast | `grok` | Дешёвая, через OpenRouter. Рутинные проверки |
| **Воркеры** | Grok 4.1 Fast | `grok` | Параллельные задачи, сбор данных |
| **Cross-review** | Codex + Opus | | Оба OAuth $0. Двойная проверка PR |
| **Triple review (HIGH)** | Codex + Opus + Gemini | | Только P0/P1, security, финансовый код |

**Fallback-цепочка:** Opus → Codex → Grok

**Лимиты concurrency:**
- Агент: 5 параллельных сессий
- Субагенты (воркеры): макс 5 параллельных

---

## Heartbeat

| Параметр | Значение |
|----------|----------|
| **Интервал** | Каждые 3 часа |
| **Модель** | Grok 4.1 Fast |
| **Активные часы** | 06:00-23:00 MSK |
| **Вызовов/день** | ~6 |
| **Стоимость** | ~$0.006/день |

### Что проверяет (OODA loop)

1. **Свой сервер:** `systemctl is-active openclaw`, RAM, диск
2. **Pipeline state:** `/tmp/pipeline-state.json` -- не остался ли зависший pipeline
3. **Домен сканирования:** техдолг, инфра, безопасность, оптимизация (HEARTBEAT.md)

### Логика реакции

| Ситуация | Действие |
|----------|----------|
| Всё ок | HEARTBEAT_OK (молчит) |
| Найдена задача | SELF-TASK (low-risk: выполняет сам, med/high: в inbox) |
| Ничего не найдено | Проверяет каналы мониторинга |

**Принцип:** heartbeat = молчание если всё ок. Максимум 2 self-task за heartbeat.

---

## System Cron (crontab openclaw)

5 задач, из них 3 защищённые (OPERATIONS.md инварианты).

### THR-C1: obsidian-sync (ЗАЩИЩЁННЫЙ)

| Параметр | Значение |
|----------|----------|
| **ID** | THR-C1 |
| **Расписание** | `0 * * * *` (каждый час) |
| **Скрипт** | `obsidian-sync.sh` |
| **Что делает** | Синхронизирует `_shared/` + `LEARNINGS` + `CONVENTIONS` → `agent-memory/shared/` → GitHub |
| **Зачем** | Единственный источник shared-контекста для всех агентов через QMD. Без него Illidan и Sylvanas теряют доступ к общей памяти команды |
| **При удалении** | Все агенты теряют shared-контекст -- НАРУШЕНИЕ инварианта P0 |

### THR-C2: constitution-sync (ЗАЩИЩЁННЫЙ)

| Параметр | Значение |
|----------|----------|
| **ID** | THR-C2 |
| **Расписание** | `0 */6 * * *` (каждые 6 часов) |
| **Скрипт** | `constitution-sync.sh` |
| **Что делает** | `git pull` репозитория `jasonqween/orgrimmar-constitution` |
| **Зачем** | Обновляет локальную копию конституции. Без него Тралл работает по устаревшим правилам |
| **При удалении** | Тралл работает по старой конституции -- НАРУШЕНИЕ инварианта |

### THR-C3: memory-rotate (ЗАЩИЩЁННЫЙ)

| Параметр | Значение |
|----------|----------|
| **ID** | THR-C3 |
| **Расписание** | `0 21 * * *` (21:00 UTC = 00:00 MSK) |
| **Скрипт** | `memory-rotate.sh` |
| **Что делает** | Ротация файлов памяти: COLD/WARM/LEARNINGS >8KB → последние 50 строк остаются, старое в `archive/`. Дневники >3 дней → в `archive/` |
| **Зачем** | Без ротации файлы раздуваются >10KB → memoryFlush блокируется → агент не сохраняет контекст между сессиями |
| **При удалении** | Память перестаёт работать -- НАРУШЕНИЕ инварианта P0 |

### THR-C4: backup-daily

| Параметр | Значение |
|----------|----------|
| **ID** | THR-C4 |
| **Расписание** | `30 3 * * *` (03:30 UTC) |
| **Скрипт** | `backup-daily.sh` |
| **Что делает** | Restic бэкап данных Тралла на DigitalOcean Spaces |
| **Удержание** | 7 дней, 4 недели, 3 месяца |
| **Зачем** | Защита от потери данных. По конституции (раздел Backups): Thrall 03:30 UTC → DO Spaces |

### THR-C5: cleanup-tmp

| Параметр | Значение |
|----------|----------|
| **ID** | THR-C5 |
| **Расписание** | `0 4 * * *` (04:00 UTC) |
| **Скрипт** | `cleanup-tmp.sh` |
| **Что делает** | Чистит /tmp от логов и артефактов старше 7 дней |
| **Зачем** | Thrall на 2GB RAM -- диск критичен. Без чистки /tmp забивается за 2-3 недели (whisper, cron логи, worker артефакты, pipeline results) |

---

## OpenClaw Cron

1 задача.

### THR-OC1: Morning Briefing

| Параметр | Значение |
|----------|----------|
| **ID** | THR-OC1 |
| **Расписание** | `0 7 * * *` (07:00 UTC = 10:00 MSK, ежедневно) |
| **Модель** | Claude Opus 4.6 (исключение, документировано в конституции) |
| **Session** | isolated |
| **Delivery** | announce |
| **Timeout** | 240 сек |

**Пайплайн:**
1. **Сбор** (bash): `scripts/collect-ai-news.sh` парсит TG каналы + Twitter аккаунты за 24ч
   - Telegram: `curl t.me/s/{channel}`, извлечение `data-post` → прямые ссылки
   - Twitter: SocialData API (`$SOCIALDATA_API_KEY`), User-Agent обязателен
2. **Анализ + текст** (Opus): ТОП 3-5 событий AI, авторский стиль, причинно-следственные связи
3. **Отправка** (bash): `scripts/send-to-channel.sh` → Telegram Bot API, link preview отключён

**Источники:** конфиг `data/ai-news-sources.conf` (формат: `tg|channel` или `tw|handle`)

**Tone of Voice:** авторский аналитик, не RSS-лента. Тезис сразу, без вступлений. Макс 1500 символов. Русский.

**Fallback:** 0 элементов → пропуск дня. <10 элементов → «сокращённый выпуск». 3+ дня без данных → алерт вождю.

---

## Память

Стандартная архитектура по OPERATIONS.md «Стандарт памяти».

### Файловая структура

```
workspace/
├── MEMORY.md                    COLD: архив решений и итогов проектов
├── SOUL.md                      Личность агента
└── memory/
    ├── hot/
    │   └── HOT_MEMORY.md        Now / Next / Blockers
    ├── warm/
    │   ├── WARM_MEMORY.md       Серверы, IP, пути, инструменты
    │   ├── WATCHLIST.md         Личные наблюдения
    │   └── LEARNINGS.md         Уроки из ошибок
    ├── YYYY-MM-DD.md            Дневник сессии
    └── archive/                 Ротированные файлы
```

### Compaction

| Параметр | Значение |
|----------|----------|
| `memoryFlush.enabled` | true (CFG-3) |
| `softThresholdTokens` | 30000 (CFG-2) |
| `contextPruning.mode` | cache-ttl |
| `contextPruning.ttl` | 6h |
| `keepLastAssistants` | 3 |

### QMD (семантический поиск)

| Параметр | Значение |
|----------|----------|
| Backend | BM25 + Gemini embeddings (`gemini-embedding-001`) |
| Поиск | hybrid: vector 0.7 + BM25 0.3 |
| `embedInterval` | 30m (CFG-1) |
| `update.interval` | 5m |
| Max результатов | 6 чанков |
| Sessions retention | 30 дней |
| Коллекция `shared-main` | присутствует (CFG-4) |

### Shared-память (особая роль Тралла)

Тралл -- единственный сервер с `obsidian-sync.sh` (THR-C1). Он отвечает за синхронизацию shared-контекста для всей сети:

```
workspace/_shared/ (источник) → agent-memory/shared/ (зеркало) → GitHub → QMD всех агентов
```

Без THR-C1 цепочка рвётся → все агенты теряют общую память.

---

## Скиллы

### Обязательные (по конституции)

| Скилл | Назначение | Статус |
|-------|-----------|--------|
| `task-system` | Работа с задачной системой | ✅ |
| `learnings` | Запись ошибок и уроков (SKL-2) | ✅ |
| `memory-tiering` | Управление памятью HOT/WARM/COLD | ✅ |
| `transcript` | Транскрипция YouTube | ✅ |
| `twitter` | Чтение Twitter/X (FxTwitter + SocialData) | ✅ |
| `memory-audit` | Самоаудит памяти (SKL-1) | ✅ |

### Ролевые (coder + architect)

| Скилл | Назначение |
|-------|-----------|
| `server-ops` | SSH-операции на Sylvanas/Illidan |
| `cross-review` | Ревью PR: change levels, merge rules |
| `worker-orchestration` | Spawn воркеров: модели, уведомления |
| `openclaw-updater` | Обновление OpenClaw на всех серверах |
| `orgrimmar-introspection` | Pre-task read, post-action update |
| `dev-pipeline` | Pipeline разработки: SPEC → CODE → VERIFY → REVIEW |
| `agent-bugfix` | Pipeline починки агентов |
| `safe-update` | Раскатка обновлений на агентов |
| `pipeline-builder` | Создание новых pipeline'ов |
| `self-review` | Аудит системы |
| `brainstorm-pipeline` | Идеи и ресёрч |
| `constitution-pipeline` | Правки конституции |

---

## Зона ответственности

### Что делает

1. **Код, API, скрипты** -- написание и деплой
2. **Pipeline'ы** -- dev-pipeline, agent-bugfix, safe-update, brainstorm
3. **Cross-review** -- ревью PR от Иллидана
4. **Воркеры** -- spawn на Grok/Codex для параллельных задач
5. **Скиллы агентам** -- создание и раскатка через SSH
6. **Morning Briefing** -- ежедневный AI-дайджест
7. **Shared-память** -- obsidian-sync (THR-C1), единственный синхронизатор

### Чего не делает

- НЕ мониторит серверы (→ Иллидан)
- НЕ координирует задачи (→ Сильвана)
- НЕ мержит L3 (конституция) -- только принц
- НЕ мержит свои PR -- cross-review от Иллидана

### Взаимная страховка

| Сценарий | Кто чинит |
|----------|-----------|
| Sylvanas упал | Иллидан (primary), Тралл (backup) |
| Thrall упал | Иллидан |
| Illidan упал | Тралл (единственный) |

---

## Автономность

### Зелёная зона (сам, отчёт постфактум)
Код, скиллы, pipeline'ы, конфиги, деплой, фиксы, скрипты, git, рестарт, verify.

### Красная зона (ждёт одобрения)
Конституция, новый/удаление агента, >$50 разово, удаление данных/серверов.

### Правило 3 попыток
2 фикса сам, 3-й не сработал → СТОП, зову вождя. Таймаут: 30 мин на попытку.

---

## Сводка: что должно быть на Thrall

### Обязательное (конституция)

| Компонент | Что | Статус |
|-----------|-----|--------|
| Heartbeat | 3ч, Grok 4.1 Fast, 06:00-23:00 MSK | ✅ |
| THR-C1 | obsidian-sync */1h | ✅ |
| THR-C2 | constitution-sync */6h | ✅ |
| THR-C3 | memory-rotate 21:00 UTC | ✅ |
| THR-C4 | backup-daily 03:30 UTC | ✅ |
| THR-C5 | cleanup-tmp 04:00 UTC | ✅ |
| THR-OC1 | Morning Briefing 07:00 UTC (Opus) | ✅ |
| CFG-1 | embedInterval: 30m | ✅ |
| CFG-2 | softThresholdTokens: 30000 | ✅ |
| CFG-3 | memoryFlush.enabled: true | ✅ |
| CFG-4 | shared-main в QMD index | ✅ |
| SKL-1 | memory-audit | ✅ |
| SKL-2 | learnings | ✅ |
| 6 базовых скиллов | task-system, learnings, memory-tiering, transcript, twitter, memory-audit | ✅ |
