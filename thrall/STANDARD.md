# Стандарт агента: Тралл (Coder)

_Полное описание архитектуры, конфигурации и регламента работы агента Тралл._
_Обновлено: 2026-03-07. Firebase V2._

---

## Общие сведения

| Параметр | Значение |
|----------|----------|
| **ID** | sa-thrall |
| **Имя** | Тралл |
| **Роли** | coder, architect |
| **Сервер** | Thrall VPS (***.***.119.56) |
| **Tailscale IP** | ***.***.191.127 |
| **RAM** | 8 GB |
| **Disk** | 67 GB |
| **Workspace** | `/home/openclaw/.openclaw/workspace/` |
| **Config** | `/home/openclaw/.openclaw/openclaw.json` |
| **Канал** | Telegram (@trallvibecoderbot) |

---

## Модельная конфигурация

| Параметр | Модель | Обоснование |
|----------|--------|-------------|
| **Primary (runtime)** | `opus` | Anthropic OAuth $0. Архитектурные решения, сложные задачи |
| **Код** | `codex` | OpenAI OAuth $0. Написание и ревью кода |
| **Heartbeat** | `grok` | Дешёвая, через OpenRouter. Рутинные проверки |
| **Воркеры** | `grok` | Параллельные задачи, сбор данных |
| **Cross-review** | Codex + Opus | Оба OAuth $0. Двойная проверка PR |

**Fallback-цепочка:** Opus -> Codex -> Grok

**Лимиты concurrency:**
- Агент: 5 параллельных сессий
- Субагенты (воркеры): макс 5 параллельных

---

## Взаимодействие с Firebase

Firebase RTDB -- единственный источник правды.

| Операция | Команда |
|----------|---------|
| Читать задачи | `orgbus get tasks` |
| Мои задачи | `orgbus get tasks` + фильтр assignee=sa-thrall |
| Обновить статус задачи | `orgbus patch tasks/TASK-ID '{"status":"..."}'` |
| Мой inbox | `orgbus get messages/inbox/thrall` |
| Написать агенту | `orgbus push messages/inbox/{agent} '{"from":"sa-thrall",...}'` |
| Записать урок | `orgbus push learnings '{"agent":"sa-thrall",...}'` |
| Обновить heartbeat | `orgbus patch agents/sa-thrall '{"status":"online","lastSeen":"ISO"}'` |
| Конституция | `orgbus get constitution/{charter\|operations\|principles}` |

### Зеркала (read-only кэш)

SSE listener поддерживает зеркала в `memory/firebase/`:
tasks-mine.md, agents-status.md, learnings.md, bulletin.md, content-ideas.md.

Обновляются в реальном времени. Используются для быстрого чтения, НЕ как источник фактов.

---

## Heartbeat

| Параметр | Значение |
|----------|----------|
| **Интервал** | Каждые 5 мин (cron) |
| **Модель** | -- (простой orgbus patch) |
| **Скрипт** | `.openclaw/scripts/thrall-heartbeat.sh` |

Heartbeat обновляет `agents/sa-thrall` в Firebase (status, lastSeen).

### Логика реакции

| Ситуация | Действие |
|----------|----------|
| Всё ок | HEARTBEAT_OK (молчит) |
| Найдена задача в inbox | Берёт в работу |
| P0 инцидент | Алерт принцу |

---

## System Cron (crontab openclaw)

6 задач.

### THR-C1: cleanup-tmp

| Параметр | Значение |
|----------|----------|
| **Расписание** | `0 4 * * *` (04:00 UTC) |
| **Скрипт** | `workspace/scripts/cleanup-tmp.sh` |
| **Что делает** | Чистит /tmp от логов и артефактов старше 7 дней |

### THR-C2: DCA trading bot

| Параметр | Значение |
|----------|----------|
| **Расписание** | `0 7 * * *` (07:00 UTC = 10:00 MSK) |
| **Скрипт** | `workspace/projects/trading-bot/run_dca.sh` |
| **Что делает** | Запуск DCA стратегии |

### THR-C3: constitution-sync (ЗАЩИЩЁННЫЙ)

| Параметр | Значение |
|----------|----------|
| **Расписание** | `0 */6 * * *` (каждые 6 часов) |
| **Скрипт** | `.openclaw/scripts/constitution-sync.sh` |
| **Что делает** | `orgbus get constitution/*` -> локальные .md файлы |
| **Зачем** | Обновляет локальную копию конституции из Firebase |

### THR-C4: memory-rotate (ЗАЩИЩЁННЫЙ)

| Параметр | Значение |
|----------|----------|
| **Расписание** | `0 21 * * *` (21:00 UTC = 00:00 MSK) |
| **Скрипт** | `workspace/scripts/memory-rotate.sh` |
| **Что делает** | COLD/WARM/LEARNINGS >8KB -> последние 50 строк, старое в archive/. Дневники >3 дней -> archive/ |
| **Зачем** | Без ротации файлы >10KB -> memoryFlush блокируется |

### THR-C5: thrall-heartbeat (ЗАЩИЩЁННЫЙ)

| Параметр | Значение |
|----------|----------|
| **Расписание** | `*/5 * * * *` (каждые 5 мин) |
| **Скрипт** | `.openclaw/scripts/thrall-heartbeat.sh` |
| **Что делает** | `orgbus patch agents/sa-thrall` -- обновляет lastSeen |

### THR-C6: SSE listener watchdog (ЗАЩИЩЁННЫЙ)

| Параметр | Значение |
|----------|----------|
| **Расписание** | `0 * * * *` (каждый час) |
| **Скрипт** | `.openclaw/scripts/firebase-sse-listener.sh` |
| **Что делает** | Проверяет, жив ли SSE listener. Если нет -- перезапускает |
| **Зачем** | Без SSE зеркала Firebase не обновляются -> QMD не видит актуальные данные |

---

## Память

### Архитектура (3 уровня + Firebase)

```
Boot (~20 KB):
  SOUL.md + HOT_MEMORY.md + WARM_MEMORY.md + AGENTS.md

On-demand:
  orgbus get (tasks, learnings, agents, bulletin, content)

Семантический поиск:
  QMD (local memory + firebase mirrors + sessions)
```

### Файловая структура

```
workspace/
├── SOUL.md                      Личность агента (10 KB)
├── AGENTS.md                    V2: Firebase, boot, серверы (8 KB)
├── HEARTBEAT.md                 V2: orgbus inbox + tasks (2 KB)
├── MEMORY.md                    COLD: архив решений (6 KB)
├── IDENTITY.md                  Дополнительная идентичность
├── USER.md                      Профиль вождя
├── TOOLS.md                     Доступные инструменты
│
├── memory/
│   ├── hot/
│   │   └── HOT_MEMORY.md        Now / Next / Blockers
│   ├── warm/
│   │   ├── WARM_MEMORY.md       Серверы, IP, пути, Firebase V2
│   │   ├── WATCHLIST.md         Личные наблюдения
│   │   └── LEARNINGS.md         Уроки из ошибок
│   ├── firebase/                SSE зеркала (auto-update)
│   │   ├── tasks-mine.md
│   │   ├── agents-status.md
│   │   ├── learnings.md
│   │   ├── bulletin.md
│   │   └── content-ideas.md
│   ├── YYYY-MM-DD.md            Дневники сессий
│   └── archive/                 Ротированные файлы
│
├── skills/                      28 скиллов (76 MB)
├── projects/
│   └── trading-bot/             DCA бот (cron 07:00 UTC)
├── scripts/                     Cron-скрипты
└── shared/
    └── playbook/                Incident, Hotfix, Deploy protocols
```

### Принцип работы с памятью

1. **При старте:** SOUL + HOT + WARM + AGENTS (автоматически через workspace)
2. **При фактических вопросах:** `orgbus get` (Firebase > память)
3. **При записи уроков:** `orgbus push learnings` (Firebase, НЕ локальный файл)
4. **НЕ трогать:** `memory/firebase/*.md` -- SSE listener обновляет сам
5. **Перед записью:** проверить `wc -c`, если >10KB -- НЕ писать

### Compaction (сжатие контекста)

| Параметр | Значение | ID |
|----------|----------|----|
| `compaction.mode` | `safeguard` | CFG-2a |
| `memoryFlush.enabled` | `true` | CFG-3 |
| `softThresholdTokens` | `4000` | CFG-2 |
| `contextPruning.mode` | `cache-ttl` | -- |
| `contextPruning.ttl` | `6h` | -- |
| `keepLastAssistants` | `3` | -- |

### memoryFlush prompt

При достижении порога flush:
1. Активные задачи -> `memory/hot/HOT_MEMORY.md` (перезаписать полностью)
2. Решения/итоги -> `MEMORY.md` (ТОЛЬКО если <10KB)
3. Уроки -> `orgbus push learnings` (Firebase, НЕ локальный файл)
4. Дневник -> `memory/YYYY-MM-DD.md` (3-5 строк, НЕ дублируй)
5. НЕ трогать `memory/firebase/*.md`
6. Если нечего -> `NO_FLUSH`

### QMD (семантический поиск)

| Параметр | Значение |
|----------|----------|
| Backend | BM25 + Gemini embeddings (`gemini-embedding-001`) |
| Поиск | hybrid: vector 0.7 + BM25 0.3 |
| `embedInterval` | `30m` (CFG-1) |
| `update.interval` | `5m` |
| Max результатов | 6 чанков |
| Sessions retention | 30 дней |

Коллекции QMD:
- `firebase` -- `memory/firebase/**/*.md` (зеркала Firebase)
- `shared-main` -- `agent-memory/shared/**/*.md`
- `memory-dir-main` -- `workspace/memory/**/*.md`
- `memory-root-main` -- `workspace/MEMORY.md`
- `sessions-main` -- транскрипты сессий (30 дней)

---

## Скиллы (28)

### Tier 1: PROTECTED (удаление = VIOLATION)

Базовые скиллы по конституции. Без них агент не функционирует.

| ID | Скилл | Назначение |
|----|-------|------------|
| THR-SKL-1 | `firebase-ops` | orgbus CLI, структура Firebase, CRUD |
| THR-SKL-2 | `task-system` | Задачная система через Firebase |
| THR-SKL-3 | `task-triage` | Inbox triage, SLA мониторинг |
| THR-SKL-4 | `learnings` | Запись уроков в Firebase |
| THR-SKL-5 | `memory-audit` | Самоаудит памяти по регламенту |
| THR-SKL-6 | `memory-tiering` | Управление HOT/WARM/COLD при flush |
| THR-SKL-7 | `agent-messaging` | Межагентная коммуникация через Firebase inbox |
| THR-SKL-8 | `agent-introspection` | Самоаудит качества работы |
| THR-SKL-9 | `openclaw-architecture` | Аудит конфигурации OpenClaw |

### Tier 2: Ролевые (coder + architect)

Определяют роль Тралла. Удаление требует PR + одобрение принца.

| ID | Скилл | Назначение |
|----|-------|------------|
| THR-SKL-10 | `dev-pipeline` | SPEC -> GATHER -> CODE -> VERIFY -> REVIEW -> DEPLOY |
| THR-SKL-11 | `server-ops` | SSH-операции на Arthas/Illidan/Mac mini |
| THR-SKL-12 | `cross-review` | Ревью PR: change levels, чеклисты, merge |
| THR-SKL-13 | `worker-orchestration` | Spawn воркеров: модели, лимиты |
| THR-SKL-14 | `openclaw-updater` | Обновление OpenClaw (процедура канарейки) |
| THR-SKL-15 | `safe-update` | Раскатка изменений на агентов |
| THR-SKL-16 | `agent-bugfix` | Диагностика и починка агентов |
| THR-SKL-17 | `constitution-pipeline` | Правки конституции через PR |
| THR-SKL-18 | `pipeline-builder` | Создание новых pipeline'ов |
| THR-SKL-19 | `self-review` | Аудит системы по чеклисту |
| THR-SKL-20 | `auto-verify` | Автоматическая верификация после задач |
| THR-SKL-21 | `brainstorm-pipeline` | Структурированный ресёрч и идеи |

### Tier 3: Вспомогательные

Полезны, но не критичны. Можно удалить/заменить без PR.

| ID | Скилл | Назначение |
|----|-------|------------|
| THR-SKL-22 | `git-workflows` | Rebase, cherry-pick, worktrees |
| THR-SKL-23 | `skill-creator` | Создание скиллов для агентов |
| THR-SKL-24 | `web-deploy-timeweb` | Деплой сайтов на Timeweb |
| THR-SKL-25 | `transcript` | Транскрипция YouTube |
| THR-SKL-26 | `twitter` | Чтение Twitter/X |
| THR-SKL-27 | `gws` | Google Workspace CLI |
| THR-SKL-28 | `quick-reminders` | Напоминания (nohup) |

---

## Карта серверов

| Сервер | Tailscale | SSH | Кто |
|--------|-----------|-----|-----|
| Mac mini | ***.***.43.49 | координатор@Mac mini | Сильвана |
| Arthas VPS | ***.***.104.91 | root@***.***.104.91 | Артас |
| Thrall VPS (ты) | ***.***.191.127 | localhost | Тралл |
| Illidan VPS | ***.***.122.16 | root@***.***.122.16 | Иллидан |

---

## Зона ответственности

### Что делает

1. **Код, API, скрипты** -- написание и деплой
2. **Pipeline'ы** -- dev-pipeline, agent-bugfix, safe-update, brainstorm
3. **Cross-review** -- ревью PR от Иллидана
4. **Воркеры** -- spawn на Grok/Codex для параллельных задач
5. **Скиллы агентам** -- создание и раскатка через SSH
6. **DCA бот** -- trading-bot (cron 07:00 UTC)

### Чего не делает

- НЕ мониторит серверы (-> Иллидан)
- НЕ координирует задачи (-> Сильвана)
- НЕ мержит L3 (конституция) -- только принц
- НЕ мержит свои PR -- cross-review от Иллидана

### Взаимная страховка

| Сценарий | Кто чинит |
|----------|-----------|
| Mac mini упал | Иллидан (primary), Тралл (backup) |
| Thrall упал | Иллидан |
| Illidan упал | Тралл (единственный) |

---

## Автономность

### Зелёная зона (сам, отчёт постфактум)
Код, скиллы, pipeline'ы, конфиги, деплой, фиксы, скрипты, git, рестарт, verify.

### Красная зона (ждёт одобрения)
Конституция, новый/удаление агента, >$50 разово, удаление данных/серверов.

### Правило 3 попыток
2 фикса сам, 3-й не сработал -> СТОП, зову вождя. Таймаут: 30 мин на попытку.

---

## Фоновые процессы

| Процесс | Скрипт | Описание |
|---------|--------|----------|
| SSE listener | firebase-sse-listener.sh | 5 потоков, зеркала в memory/firebase/ |
| Heartbeat | thrall-heartbeat.sh | cron */5 мин, orgbus patch |

---

## DEPRECATED -- НЕ ИСПОЛЬЗОВАТЬ

| Что | Замена |
|-----|--------|
| `shared/tasks/` (файловые задачи) | Firebase (`orgbus get tasks`) |
| `orgrimmar-introspection` | `agent-introspection` |
| `shared-memory` | `firebase-ops` + SSE зеркала |
| `obsidian-sync.sh` | Firebase + SSE listener |
| `backup-daily.sh` (restic) | Отключён (2026-03-07) |
| `main.sqlite` | QMD (backend: qmd) |
| Sylvanas VPS (***.***.104.91) как Сильвана | Это Arthas. Сильвана = Mac mini (***.***.43.49) |
