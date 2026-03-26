# Конвенции кода и операций

_Стандарты кодирования и операционные конвенции для всех агентов._

---

## Shell Security

Все переменные в shell-командах должны быть в двойных кавычках.

```bash
# Правильно
rm -f "${file}"
ssh root@"${server}" "cat \"${path}\""

# Неправильно
rm -f $file
ssh root@${server} 'cat ${path}'
```

### Правила:

| Контекст | Формат | Пример |
|----------|--------|--------|
| Локальная команда | `"${var}"` | `cat "${file}"` |
| SSH команда | `ssh root@"${server}" "cmd \"${arg}\""` | `ssh root@"${ip}" "cat \"${path}\""` |
| Python open() | `sys.argv`, не f-string | `python3 -c "import sys; open(sys.argv[1])" "${file}"` |
| Имена переменных | Только `_`, без `-` | `pipeline_name` (не `pipeline-name`) |

**Почему:** `${pipeline-name}` в bash = `${pipeline:-name}` (parameter expansion с default). Одинарные кавычки не защищают от `'` внутри значения переменной.

---

## Artifact Delivery (воркеры)

Воркеры (sessions_spawn) записывают результат в файл, а не возвращают текстом.

### Стандарт:

```
Запиши результат в /tmp/worker-{label}.md
```

### Freshness Check (обязательно):

Перед спавном воркера:
```bash
rm -f "/tmp/worker-${label}.md"
```

После завершения воркера:
```bash
# Проверить что файл свежий (не старше 10 мин)
stat -c %Y "/tmp/worker-${label}.md"
```

### Параллельные pipeline'ы:

Если возможен параллельный запуск -- добавить timestamp суффикс:
```bash
label="gather-$(date +%s)"
```

---

## Timeout для воркеров

Если задача воркера включает `sleep N`, timeout должен быть:
```
timeout = sleep_time + work_time + buffer
```

Пример: safe-update VERIFY (sleep 300) → timeout = 660 (300 + 300 + 60).

---

## Git

- Коммиты на русском языке
- Workflow: ветки + PR, не пуш в main напрямую
- Git user: настроен на каждом сервере (Тралл, Иллидан, Сильвана)

### Scoped commit (рекомендация)

Для точечных задач не использовать `git add -A`.

Рекомендуемый порядок:
```bash
git add <конкретные_пути>
git diff --cached --name-only
```

Цель: не захватывать в коммит посторонние накопленные изменения.

---

## Язык и форматирование

- Код и комментарии: английский
- Коммиты, документация, отчёты: русский
- Тире: короткое `–` (не длинное `—`)
- Кавычки: русские `«»` (не `""`)

---

## Git Conventions

### Commit message format
```
<type>(<scope>): <описание на русском>

type: feat, fix, test, docs, refactor, chore
scope: thrall, illidan, sylvanas, shared, github, constitution
```

Примеры:
- `feat(thrall): добавить скилл code-review`
- `fix(shared): исправить canary-deploy.sh arg parsing`
- `docs(illidan): обновить AGENTS.md -- роль reviewer`

### Branch naming
```
feature/<server>/<описание>
fix/<server>/<описание>
test/<server>/<описание>
```

### PR size limit
Рекомендуемый максимум: **300 строк**. CI выдаёт warning при превышении. Если PR больше -- разбить на части.

### Merge strategy
Squash merge для чистой истории. Один PR = один коммит в main.

### Cross-review
- Автор PR не может approve свой PR
- Reviewer обязан написать содержательный review (не просто LGTM)
- L3 (конституция) -- merge только принцем через GitHub UI
- **Ограничение:** Тралл и Иллидан на одном GitHub-аккаунте (qwwiwi) -- GitHub не позволяет approve своего PR. Cross-review обеспечивается процессом: агент-автор НЕ мержит свой PR, передаёт другому агенту
- Конституция: агенты создают PR через fork, merge технически заблокирован

---

## PR-first Exceptions

Прямой пуш в `main` разрешён ТОЛЬКО для:
1. `obsidian-sync.sh` -- автоматическая синхронизация заметок принца.
2. Emergency hotfix -- по прямому указанию принца (записать причину в events/).
3. Emergency recovery -- по прямому указанию принца.

---

## Аналитические события

Формат записи аналитического события через orgbus:

```bash
DATE=$(date -u +%Y-%m-%d)
TS=$(date +%s)000

~/.local/bin/orgbus push "analytics/events/${DATE}" \
  "{\"agent\":\"sa-<agent>\",\"type\":\"<type>\",\"timestamp\":${TS},\"data\":{...}}"
```

### Обязательные поля

| Поле | Тип | Пример |
|------|-----|--------|
| `agent` | string | `sa-silvana` |
| `type` | string | `task.created` |
| `timestamp` | number (Unix ms) | `1711475400000` |
| `data` | object | `{"task_id": "-Oabc"}` |

### Дополнительные поля

- **Субагенты** (`subagent.*`): `parent_agent`, `worker_model`, `duration_ms`, `outcome`
- **Стоимость** (`cost.incurred`): `provider`, `model`, `cost_usd`, `tokens_in`, `tokens_out`
- **Ошибки** (`error`): `severity` (P0/P1/P2), `source`, `message`

### Допустимые типы

`task.created`, `task.completed`, `subagent.spawn`, `subagent.completed`, `cost.incurred`, `error`, `heartbeat.check`

### Правила

- Timestamps: Unix milliseconds (13 цифр), UTC
- Дата в пути: UTC (`date -u +%Y-%m-%d`)
- Один push на событие; не батчить
- Не записывать PII (персональные данные) в `data`
- Полная схема: `docs/analytics/event-schema.md`
