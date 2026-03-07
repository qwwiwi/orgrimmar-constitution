# Стандарт агента: Иллидан (DevOps)

_Полное описание архитектуры, конфигурации и регламента работы агента Иллидан._

---

## Общие сведения

| Параметр | Значение |
|----------|----------|
| **Имя** | Иллидан |
| **Роли** | devops, code-reviewer |
| **Сервер** | Illidan VPS |
| **Tailscale IP** | `<ILLIDAN_TS_IP>` |
| **Workspace** | `/home/openclaw/.openclaw/workspace/` |
| **Config** | `/home/openclaw/.openclaw/openclaw.json` |
| **Каналы** | Telegram (@Illidandevopsbot), Discord |

---

## Модельная конфигурация

| Параметр | Модель | Алиас | Обоснование |
|----------|--------|-------|-------------|
| **Primary** | Kimi (Moonshot) | `kimi` | Дешёвая, быстрая. Heartbeat, мониторинг, парсинг логов, cron-проверки (~70% задач) |
| **Fallback 1** | Grok (xAI) | `grok` | Запасная если Kimi недоступен |
| **Fallback 2** | Codex (OpenAI) | `codex` | Code review (OAuth $0) |
| **Heartbeat** | Kimi (Moonshot) | `kimi` | Всегда дешёвая модель, никогда Opus/Codex |
| **Subagents** | Grok (xAI) | `grok` | Воркеры для параллельных задач |
| **P0 incidents** | Opus (Anthropic) | `opus` | Только при: production down, необратимое действие, запрос принца (~5% задач) |
| **Сложный RCA** | Gemini (Google) | `gemini` | Контекст >50K, multi-server инциденты (~25% задач) |

**Fallback-цепочка:** Kimi → Grok → Codex

**Лимиты concurrency:**
- Агент: 4 параллельных сессии
- Субагенты: 8 параллельных

---

## Heartbeat

| Параметр | Значение |
|----------|----------|
| **Интервал** | Каждые 2 часа |
| **Модель** | `kimi` |
| **Активные часы** | 24/7 |
| **Вызовов/день** | ~12 |
| **Стоимость** | ~$0.01/день |

### Что проверяет (OODA loop)

Heartbeat выполняет проактивный чеклист по 4 точкам:

**1. Свой сервер (Illidan):**
```bash
systemctl is-active openclaw && free -h | grep Mem && df -h / | tail -1
```

**2. Sylvanas (`<ARTHAS_TS_IP>`):**
```bash
ssh -o ConnectTimeout=5 root@<ARTHAS_TS_IP> "systemctl is-active openclaw && free -h | grep Mem && df -h / | tail -1"
```

**3. Thrall (`<THRALL_TS_IP>`):**
```bash
ssh -o ConnectTimeout=5 root@<THRALL_TS_IP> "systemctl is-active openclaw && free -h | grep Mem && df -h / | tail -1"
```

**4. Codex JWT (Sylvanas):**
```bash
ssh -o ConnectTimeout=5 root@<ARTHAS_TS_IP> "bash /home/openclaw/.openclaw/scripts/check-codex-jwt.sh"
```

### Логика реакции

| Ситуация | Действие |
|----------|----------|
| Всё ок | HEARTBEAT_OK (молчит, не пишет принцу) |
| Диск 75-90% | Автофикс: `journalctl --vacuum-size=100M`. Молчит |
| Диск >90% | Автофикс + алерт принцу |
| Сервис упал | `systemctl restart openclaw` + алерт принцу |
| RAM >85% | Диагностика top-процессов + алерт принцу |
| SSH не отвечает | Повтор через 2 мин. Если снова -- алерт принцу |
| JWT ALERT | Переслать принцу |

**Принцип:** heartbeat = молчание если всё ок. Алерт только при проблеме.

---

## System Cron (crontab openclaw)

3 задачи, из них 2 защищённые (OPERATIONS.md инварианты).

### ILL-C1: constitution-sync (ЗАЩИЩЁННЫЙ)

| Параметр | Значение |
|----------|----------|
| **Расписание** | `0 */6 * * *` (каждые 6 часов) |
| **Скрипт** | `/home/openclaw/.openclaw/scripts/constitution-sync.sh` |
| **Что делает** | `git pull` репозитория `jasonqween/orgrimmar-constitution` |
| **Зачем** | Обновляет локальную копию конституции. Без него Иллидан работает по устаревшим правилам |
| **При удалении** | Иллидан работает по старой конституции -- НАРУШЕНИЕ инварианта |

### ILL-C2: memory-rotate (ЗАЩИЩЁННЫЙ)

| Параметр | Значение |
|----------|----------|
| **Расписание** | `0 21 * * *` (21:00 UTC = 00:00 MSK) |
| **Скрипт** | `/home/openclaw/.openclaw/workspace/scripts/memory-rotate.sh` |
| **Что делает** | Ротация файлов памяти: COLD/WARM/LEARNINGS >8KB → последние 50 строк остаются, старое в `archive/`. Дневники >3 дней → в `archive/` |
| **Зачем** | Без ротации файлы раздуваются >10KB → memoryFlush блокируется → агент не сохраняет контекст между сессиями |
| **При удалении** | Память перестаёт работать -- НАРУШЕНИЕ инварианта P0 |

### backup-daily

| Параметр | Значение |
|----------|----------|
| **Расписание** | `30 4 * * *` (04:30 UTC) |
| **Скрипт** | `/home/openclaw/.openclaw/scripts/backup-daily.sh` |
| **Что делает** | Restic бэкап данных Иллидана на Thrall + DigitalOcean Spaces |
| **Удержание** | 7 дней, 4 недели, 3 месяца |
| **Зачем** | Защита от потери данных. Позволяет откатить конфиг, память, скрипты |

### System cron (root)

| Расписание | Команда | Назначение |
|-----------|---------|------------|
| `*/30 * * * *` | `cd orgrimmar && git pull` | Синхронизация монорепо `qwwiwi/orgrimmar` |

---

## OpenClaw Cron

3 задачи (дополнительные, не в конституции, одобрены принцем 2026-03-02).

### Backup Verify

| Параметр | Значение |
|----------|----------|
| **Расписание** | `0 3 * * *` (03:00 UTC, раз в день) |
| **Модель** | default (`kimi`) |
| **Delivery** | announce |
| **Что делает** | Проверяет существование и свежесть restic-бэкапов (<25ч) на всех 3 серверах |
| **Зачем** | Страховка: backup-daily мог упасть молча, verify это ловит. По конституции бэкапы не старше 25ч -- этот cron это контролирует |

### OAuth Expiry Monitor

| Параметр | Значение |
|----------|----------|
| **Расписание** | `0 5 * * *` (05:00 UTC, раз в день) |
| **Модель** | default (`kimi`) |
| **Delivery** | announce |
| **Что делает** | Проверяет сроки OAuth-токенов (Anthropic, Codex) на Sylvanas |
| **Зачем** | Anthropic OAuth периодически даёт 401. Cron ловит умирающие токены до того, как агенты перестанут работать |

### OpenClaw Update Check

| Параметр | Значение |
|----------|----------|
| **Расписание** | `0 7 * * *` (07:00 UTC, раз в день) |
| **Модель** | default (`kimi`) |
| **Delivery** | announce |
| **Что делает** | Проверяет наличие новой версии OpenClaw в npm registry |
| **Зачем** | Информирует о доступных обновлениях. Не обновляет сам -- обновление идёт через канарейку (Illidan → Thrall → Sylvanas) по решению принца или Тралла |

---

## Память

Стандартная архитектура по OPERATIONS.md «Стандарт памяти».

### Файловая структура

```
workspace/
├── MEMORY.md                    COLD: архив инцидентов, решений (838 bytes)
├── SOUL.md                      Личность агента (3.3KB)
└── memory/
    ├── hot/
    │   └── HOT_MEMORY.md        Now / Next / Blockers (250 bytes)
    ├── warm/
    │   ├── WARM_MEMORY.md       Инфра, IP, конфиги, правила (1.5KB)
    │   ├── WATCHLIST.md         Личные наблюдения (416 bytes)
    │   └── LEARNINGS.md         Уроки из ошибок (803 bytes)
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

**Коллекции (index.yml, 5 штук):**

| Коллекция | Путь | Что индексирует |
|-----------|------|-----------------|
| `shared-main` | `agent-memory/shared/` | Общая память команды (CFG-4) |
| `memory-root-main` | `workspace/MEMORY.md` | COLD memory |
| `memory-alt-main` | `workspace/memory.md` | Альтернативный COLD |
| `memory-dir-main` | `workspace/memory/**/*.md` | HOT, WARM, дневники |
| `sessions-main` | `agents/main/qmd/sessions/` | Транскрипты сессий |

### Shared-память

Иллидан получает shared-контекст через `agent-memory/shared/` (10 файлов):
- USER.md, USER_COGNITIVE_PROFILE.md -- профиль принца
- ROSTER.md, AGENTS-ROSTER.md -- реестр агентов
- CONVENTIONS.md -- конвенции из конституции
- COSTS.md -- расходы
- CHATS.md, TELEGRAM-CHATS.md -- чаты
- LEARNINGS.md -- общие уроки
- IDEAS.md -- идеи

Синхронизация: `obsidian-sync.sh` на Thrall (THR-C1, каждый час) → GitHub → Иллидан через QMD.

---

## Скиллы

### Обязательные (по конституции)

| Скилл | Назначение | Статус |
|-------|-----------|--------|
| `task-system` | Работа с задачной системой | ✅ |
| `learnings` | Запись ошибок и уроков (SKL-2) | ✅ |
| `memory-tiering` | Управление памятью HOT/WARM/COLD | ✅ |
| `transcript` | Транскрипция YouTube | ✅ |
| `socialdata-twitter` | Чтение Twitter/X | ✅ |
| `memory-audit` | Самоаудит памяти (SKL-1) | ✅ |

### Ролевые (devops + code-reviewer)

| Скилл | Назначение | Статус |
|-------|-----------|--------|
| `agent-introspection` | Pre-task read, post-action update (обязателен для координаторов) | ✅ |
| `code-review` | Pipeline ревью PR (Change Levels, чеклисты) | ✅ |
| `github` | GitHub CLI операции | ✅ |
| `git-workflows` | Git ветки, rebase, cherry-pick | ✅ |
| `git-pushing` | Git push операции | ✅ |
| `agent-bugfix` | Pipeline починки агентов | ✅ |
| `safe-update` | Раскатка обновлений | ✅ |
| `debug-pro` | Диагностика и отладка | ✅ |
| `security-auditor` | Аудит безопасности | ✅ |
| `docker-essentials` | Docker операции | ✅ |

### Дополнительные (установлены, не обязательные)

`shared-memory`, `web-deploy-timeweb`, `frontend-design`, `skill-creator`, `api-design-reviewer`, `architecture-patterns`, `cicd-pipeline`, `perf-profiler`, `sql-toolkit`, `test-master`, `typescript-pro`, `webapp-testing`, `mcp-builder`, `twitter-reader`, `dev-pipeline`, `web-design-guidelines`, `ui-ux-pro-max`, `canvas-design`, `deploy-agent`, `superdesign`, `pipeline-builder`

> **Замечание:** У Иллидана 37 скиллов -- многие (frontend-design, canvas-design, ui-ux-pro-max и др.) не относятся к его ролям devops/code-reviewer. Рекомендуется ревью и чистка для экономии контекста при загрузке.

---

## Каналы связи

| Канал | Policy | AllowFrom |
|-------|--------|-----------|
| Telegram | DM allowlist | `<PRINCE_TG_ID>` (принц) |
| Discord | DM allowlist | `<PRINCE_DISCORD_ID>` (принц) |

Streaming: Telegram partial, Discord off.
groupPolicy: allowlist на обоих каналах.

---

## Зона ответственности

### Что делает

1. **Мониторинг 3 серверов** -- heartbeat каждые 2ч, автофикс мелочей, алерт при проблемах
2. **Incident response** -- перезапуск сервисов, откат конфигов, восстановление после падений
3. **Code review** -- ревью всех PR от Тралла, Change Levels L0-L3, merge L0-L2
4. **Бэкапы** -- daily backup + verify
5. **OAuth мониторинг** -- отслеживание протухающих токенов
6. **Обновления OpenClaw** -- проверка новых версий, участие в канарейке

### Чего не делает

- НЕ пишет код приложений (→ Тралл)
- НЕ устанавливает скиллы агентам (→ Тралл)
- НЕ координирует задачи агентов (→ Сильвана)
- НЕ мержит L3 (конституция) -- только принц
- НЕ мержит свои PR -- cross-review от Тралла

### Взаимная страховка

| Сценарий | Кто чинит |
|----------|-----------|
| Sylvanas упал | Иллидан (primary), Тралл (backup) |
| Thrall упал | Иллидан |
| Illidan упал | Тралл (единственный) |

---

## Конфигурация Gateway

| Параметр | Значение |
|----------|----------|
| `channelHealthCheckMinutes` | 30 (увеличено с дефолта 5, предотвращает ложные рестарты провайдеров) |
| `gateway.mode` | local |
| `gateway.auth` | token |
| `ackReactionScope` | group-mentions |

---

## Сводка: что должно быть на Illidan

### Обязательное (конституция)

| Компонент | Что | Статус |
|-----------|-----|--------|
| Heartbeat | 2ч, `kimi`, 24/7 | ✅ |
| ILL-C1 | constitution-sync */6h | ✅ |
| ILL-C2 | memory-rotate 21:00 | ✅ |
| CFG-1 | embedInterval: 30m | ✅ |
| CFG-2 | softThresholdTokens: 30000 | ✅ |
| CFG-3 | memoryFlush.enabled: true | ✅ |
| CFG-4 | shared-main в QMD index | ✅ |
| SKL-1 | memory-audit | ✅ |
| SKL-2 | learnings | ✅ |
| 6 базовых скиллов | task-system, learnings, memory-tiering, transcript, socialdata-twitter, memory-audit | ✅ |

### Одобренное принцем (не в конституции)

| Компонент | Что | Дата одобрения |
|-----------|-----|----------------|
| Backup Verify | cron 03:00 UTC daily | 2026-03-02 |
| OAuth Expiry Monitor | cron 05:00 UTC daily | 2026-03-02 |
| OpenClaw Update Check | cron 07:00 UTC daily | 2026-03-02 |
| backup-daily | system cron 04:30 UTC | (с момента создания) |
| orgrimmar git pull | root cron */30 | (с момента создания) |
