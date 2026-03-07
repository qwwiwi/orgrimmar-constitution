# Стандарт агента: Иллидан (DevOps)

_Полное описание архитектуры, конфигурации и регламента работы агента Иллидан._

---

## Общие сведения

| Параметр | Значение |
|----------|----------|
| **Имя** | Иллидан |
| **Роли** | devops, code-reviewer |
| **Сервер** | Illidan VPS |
| **Tailscale IP** | `100.115.122.16` |
| **Workspace** | `/home/openclaw/.openclaw/workspace/` |
| **Config** | `/home/openclaw/.openclaw/openclaw.json` |
| **OpenClaw** | `2026.3.2` |
| **Каналы** | Telegram (@Illidandevopsbot), Discord |

---

## Модельная конфигурация

| Параметр | Модель | Алиас |
|----------|--------|-------|
| **Primary** | Kimi K2.5 (Moonshot) | `kimi` |
| **Fallback 1** | Grok 4.1 Fast (xAI) | `grok` |
| **Fallback 2** | GPT-5.3 Codex (OpenAI) | `codex` |
| **Subagents** | Kimi K2.5 → Codex fallback | `kimi` |
| **P0 incidents** | Claude Opus 4.6 (Anthropic) | `opus` |

**Fallback-цепочка:** Kimi -> Grok -> Codex

**Providers:** anthropic, openai-codex, openrouter

**Subagents:** max 4 параллельных

---

## Firebase -- единственный источник правды

| Параметр | Значение |
|----------|----------|
| **Firebase RTDB** | orgrimmar-brain (europe-west1) |
| **CLI** | `~/.local/bin/orgbus` |
| **SA ключ** | `~/.secrets/firebase/sa-illidan.json` |
| **SSE Listener** | `~/.openclaw/scripts/firebase-sse-listener.sh` |
| **Firebase mirrors** | `memory/firebase/*.md` (5 файлов) |

### Boot sequence

```bash
orgbus get messages/inbox/illidan   # 1. Входящие сообщения
orgbus get tasks                     # 2. Текущие задачи
orgbus get agents                    # 3. Статус агентов
```

### Коммуникация

```bash
# Читать inbox
orgbus get messages/inbox/illidan

# Писать агентам
orgbus push messages/inbox/{agent} '{"from":"sa-illidan","body":"...","timestamp":UNIX_MS}'

# Обновить статус
orgbus patch agents/sa-illidan '{"status":"online","heartbeat":"ISO_DATE"}'
```

---

## Heartbeat

| Параметр | Значение |
|----------|----------|
| **Интервал** | Каждые 5 минут (cron) |
| **Скрипт** | `illidan-heartbeat.sh` |
| **Что делает** | `orgbus patch agents/sa-illidan` с heartbeat timestamp |

### Мониторинг серверов (heartbeat сессия)

| Сервер | Как проверяет |
|--------|---------------|
| Illidan (localhost) | `systemctl is-active openclaw && free -h && df -h /` |
| Arthas (`100.107.104.91`) | SSH health check |
| Thrall (`100.104.191.127`) | SSH health check |
| Mac mini (`100.97.43.49`) | SSH health check |

### Логика реакции

| Ситуация | Действие |
|----------|----------|
| Всё ок | Молчит |
| Диск 75-90% | Автофикс (`journalctl --vacuum-size=100M`) |
| Диск >90% | Автофикс + алерт принцу |
| Сервис упал | `systemctl restart openclaw` + алерт |
| SSH не отвечает | Повтор через 2 мин, если снова -- алерт |

---

## System Cron (crontab openclaw)

| ID | Расписание | Скрипт | Назначение |
|----|-----------|--------|------------|
| **ILL-C1** | `0 */6 * * *` | `constitution-sync.sh` | Синхронизация конституции из Firebase (orgbus get) |
| **ILL-C2** | `0 21 * * *` | `memory-rotate.sh` | Ротация памяти (HOT/WARM/COLD, archive) |
| **ILL-C3** | `*/5 * * * *` | `illidan-heartbeat.sh` | Heartbeat в Firebase |
| **ILL-C4** | `*/5 * * * *` | `firebase-sse-listener.sh` | SSE listener auto-restart (pgrep + nohup) |

### Что защищено (удаление = VIOLATION)

- **ILL-C2** (memory-rotate) -- без него память раздувается, flush блокируется
- **ILL-C3** (heartbeat) -- без него Артас считает агента мёртвым
- **ILL-C4** (SSE listener) -- без него Firebase mirrors не обновляются

---

## Память

### Файловая структура

```
workspace/
├── MEMORY.md                     COLD: архив инцидентов, решений
├── SOUL.md                       Личность агента
├── USER.md                       Профиль принца
├── AGENTS.md                     Firebase, boot sequence, серверы
├── HEARTBEAT.md                  Чеклист мониторинга
├── _shared/                      Roster, conventions, user profile
│   ├── ROSTER.md
│   ├── CONVENTIONS.md
│   ├── USER.md
│   └── ...
└── memory/
    ├── hot/
    │   └── HOT_MEMORY.md         Now / Next / Blockers (<2KB)
    ├── warm/
    │   ├── WARM_MEMORY.md        Инфра, IP, конфиги, правила
    │   ├── WATCHLIST.md          Личные наблюдения
    │   └── LEARNINGS.md          Уроки из ошибок
    ├── firebase/                 SSE listener mirrors (realtime)
    │   ├── tasks-mine.md
    │   ├── bulletin.md
    │   ├── learnings.md
    │   ├── content-ideas.md
    │   └── agents-status.md
    ├── YYYY-MM-DD.md             Дневник сессии
    └── archive/                  Ротированные файлы
```

### Compaction

| Параметр | Значение |
|----------|----------|
| `compaction.mode` | `safeguard` (CFG-2a) |
| `memoryFlush.enabled` | `true` (CFG-3) |
| `softThresholdTokens` | `4000` (CFG-2) |
| `memoryFlush.prompt` | Firebase-aware: orgbus push learnings, HOT_MEMORY.md, проверка wc -c |

### QMD (семантический поиск)

| Параметр | Значение |
|----------|----------|
| Backend | BM25 + Gemini embeddings (`gemini-embedding-001`) |
| `embedInterval` | `30m` (CFG-1) |
| Max результатов | 6 чанков |
| Sessions retention | 30 дней |

**Коллекции (index.yml, 6 штук):**

| Коллекция | Путь | Что индексирует |
|-----------|------|-----------------|
| `firebase` | `memory/firebase/` | Firebase mirrors (SSE) |
| `shared-main` | `agent-memory/shared/` | Общая память команды (CFG-4) |
| `memory-root-main` | `workspace/MEMORY.md` | COLD memory |
| `memory-alt-main` | `workspace/memory.md` | Альтернативный COLD |
| `memory-dir-main` | `workspace/memory/**/*.md` | HOT, WARM, дневники |
| `sessions-main` | `agents/main/qmd/sessions/` | Транскрипты сессий |

---

## Skills by Tiers

### Tier 1 -- PROTECTED (удаление = VIOLATION)

| # | Скилл | Назначение |
|---|-------|------------|
| 1 | `firebase-ops` | Работа с Firebase через orgbus |
| 2 | `agent-messaging` | Межагентная коммуникация через Firebase inbox |
| 3 | `task-system` | Управление задачами |
| 4 | `learnings` | Запись уроков из ошибок |
| 5 | `memory-audit` | Самоаудит памяти |
| 6 | `memory-tiering` | Управление HOT/WARM/COLD |
| 7 | `code-review` | Ревью PR (Change Levels, чеклисты) |
| 8 | `docker-essentials` | Docker операции |
| 9 | `agent-introspection` | Pre-task read, post-action update |

### Tier 2 -- Role-specific (удаление через PR)

| # | Скилл | Назначение |
|---|-------|------------|
| 10 | `task-triage` | Сортировка и приоритизация задач |
| 11 | `openclaw-architecture` | Аудит конфигурации агентов |
| 12 | `agent-bugfix` | Pipeline починки агентов |
| 13 | `safe-update` | Раскатка обновлений с канарейкой |
| 14 | `security-auditor` | Аудит безопасности |
| 15 | `debug-pro` | Диагностика и отладка |
| 16 | `git-workflows` | Git ветки, rebase, cherry-pick |
| 17 | `git-pushing` | Git push операции |
| 18 | `github` | GitHub CLI операции |
| 19 | `transcript` | Транскрипция YouTube |
| 20 | `twitter` | Чтение Twitter/X |
| 21 | `skill-creator` | Создание скиллов для агентов |

### Tier 3 -- Auxiliary (можно удалить без PR)

| # | Скилл | Назначение | Примечание |
|---|-------|------------|------------|
| 22 | `dev-pipeline` | Pipeline разработки | Больше для Тралла |
| 23 | `deploy-agent` | Деплой агентов | |
| 24 | `cicd-pipeline` | CI/CD пайплайны | |
| 25 | `pipeline-builder` | Построение пайплайнов | |
| 26 | `vinculum` | Clawdbot P2P sync | Сомнительная нужность |

### Не нужны DevOps-агенту (рекомендуется удалить)

`frontend-design`, `canvas-design`, `ui-ux-pro-max`, `superdesign`, `web-design-guidelines`, `webapp-testing`, `web-deploy-timeweb`, `api-design-reviewer`, `architecture-patterns`, `sql-toolkit`, `test-master`, `typescript-pro`, `mcp-builder`, `perf-profiler`

> **14 скиллов** из 39 не относятся к ролям devops/code-reviewer. Удаление сэкономит контекст при загрузке.

---

## Карта серверов

| Сервер | Агент | Tailscale IP | SSH |
|--------|-------|-------------|-----|
| **Mac mini** | Сильвана | `100.97.43.49` | `jasonqwwen@100.97.43.49` |
| **Arthas VPS** | Артас | `100.107.104.91` | `root@100.107.104.91` |
| **Thrall VPS** | Тралл | `100.104.191.127` | `root@100.104.191.127` |
| **Illidan VPS** | Иллидан | `100.115.122.16` | localhost |

---

## Зона ответственности

### Что делает

1. **Мониторинг серверов** -- heartbeat, автофикс, алерт при проблемах
2. **Incident response** -- перезапуск сервисов, откат конфигов
3. **Code review** -- ревью PR от Тралла (Change Levels L0-L3, merge L0-L2)
4. **Обновления OpenClaw** -- проверка новых версий, канарейка

### Чего не делает

- НЕ пишет код приложений (-> Тралл)
- НЕ координирует задачи агентов (-> Сильвана)
- НЕ мержит L3 (конституция) -- только принц
- НЕ мержит свои PR -- cross-review от Тралла

### Взаимная страховка

| Сценарий | Кто чинит |
|----------|-----------|
| Mac mini упал | Иллидан (primary), Тралл (backup) |
| Thrall упал | Иллидан |
| Illidan упал | Тралл |

---

## Автономность

| Действие | Без одобрения принца | С одобрением |
|----------|---------------------|-------------|
| Перезапуск сервисов | Да | -- |
| Очистка диска (<100MB) | Да | -- |
| Создание PR | Да | -- |
| Merge PR L0-L2 | Да (после cross-review) | -- |
| Merge PR L3 (конституция) | -- | Да |
| Обновление OpenClaw | -- | Да |
| Удаление данных >100MB | -- | Да |

---

## DEPRECATED -- НЕ ИСПОЛЬЗОВАТЬ

| Что | Замена |
|-----|--------|
| `shared-memory` скилл | Firebase boot + QMD |
| `orgrimmar-introspection` скилл | `agent-introspection` |
| `gog` скилл | `gws` (только Mac mini) |
| `task-orchestrator` скилл | `task-system` + `task-triage` |
| `obsidian-sync.sh` | Firebase SSE listener |
| `backup-daily.sh` | Бэкапы отключены |
| `softThresholdTokens: 30000` | Исправлено на `4000` |
| `shared/tasks/` файлы | Firebase tasks |
| `task-inbox.sh`, `task-update.sh`, `task-complete.sh` | orgbus CLI |
| `sylvanas-health-check.sh` | Heartbeat через Firebase |
| root cron `git pull` | Удалён |
