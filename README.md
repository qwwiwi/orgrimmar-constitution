# Конституция Orgrimmar

**Версия: 4.0.0** (2026-03-10)

Свод правил для агентского роя.

## Что это

Read-only правила, обязательные для всех агентов. Конституция выше любых локальных файлов (AGENTS.md, SOUL.md). Выше конституции -- только прямой приказ принца. P1 (безопасность) непереопределяем.

## Структура

| Файл | Назначение | Обновляется |
|------|-----------|-------------|
| PRINCIPLES.md | Ядро: приоритеты, принципы, иерархия | Редко |
| CHARTER.md | Устав: роли, границы, безопасность, модели | По необходимости |
| OPERATIONS.md | Операции: задачи, маршрутизация, git, heartbeats | По необходимости |
| MISSION.md | Миссия: 6 доменов, adversarial review | Редко |
| CONVENTIONS.md | Конвенции кода и операций | По необходимости |

## Иерархия документов

```
0. P1 Безопасность (непереопределяем)
1. Приказ принца
2. PRINCIPLES.md
3. CHARTER.md
4. OPERATIONS.md
5. CONVENTIONS.md
6. AGENTS.md
7. SOUL.md
```

## Runbooks

Детальные процедуры вынесены в Firebase (`events/guides/runbooks/`):
- **model-change** -- процедура смены модели
- **backup** -- политика резервного копирования
- **incidents** -- incident playbooks
- **firebase-ops** -- Firebase структура и SA
- **config-standard** -- стандарт openclaw.json
- **invariants** -- защищённые ресурсы
- **agent-onboarding** -- добавление нового агента
- **failure-protocol** -- Firebase down, task collision, принц недоступен
- **adversarial-review** -- процедура self-review задач
- **secrets-lifecycle** -- ротация, компрометация, inventory секретов

Доступ: `orgbus get events/guides/runbooks/{name}`

## Memory Architecture

Четырёхслойная система памяти агентов: in-context → hot inject → on-demand → cold storage.

| Слой | Загрузка | Пример |
|------|----------|--------|
| In-context | Автоматически | CLAUDE.md, rules, handoff.md |
| Hot inject | `inject-hot-context.sh` | Последние 10 событий из recent.md |
| On-demand | Read tool | AGENTS.md, TOOLS.md, полный recent.md |
| Cold storage | orgbus CLI | Firebase: tasks, learnings, runbooks |

Подробнее: [docs/memory-architecture.md](docs/memory-architecture.md)

## Как предложить изменение

1. Создай ветку от main
2. Внеси изменения
3. Открой Pull Request
4. Принц ревьюит и мержит

## Single Source of Truth

| Тема | Авторитетный файл | STANDARD содержит |
|------|--------------------|-------------------|
| Приоритеты P1-P4 | PRINCIPLES.md | Только ссылку |
| Роли, границы | CHARTER.md | Только delta для своей роли |
| Модели, алиасы | CHARTER.md | Только свою модельную карту |
| Задачная система | OPERATIONS.md | Только ссылку |
| Git workflow | OPERATIONS.md | Только ссылку |
| Heartbeats | OPERATIONS.md | Свои параметры (частота, скрипт) |
| Скиллы (базовые) | OPERATIONS.md | Свои ролевые скиллы |
| Процедуры | Firebase runbooks | Только ссылку |
| Конвенции кода | CONVENTIONS.md | Только ссылку |

**Правило:** STANDARD агента содержит только delta (что уникально для агента) + ссылки на ядро. Дубликаты запрещены. При расхождении -- ядро побеждает.
