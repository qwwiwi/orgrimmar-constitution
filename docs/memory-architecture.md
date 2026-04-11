# Memory Architecture

Четырёхслойная архитектура памяти агентов Orgrimmar.

## Слои

| # | Слой | Что хранит | Где живёт | Загрузка |
|---|------|-----------|-----------|----------|
| 1 | **In-context (harness)** | CLAUDE.md + @include файлы | Локальный диск агента | Автоматически при старте сессии |
| 2 | **Hot context (inject)** | Последние 10 записей из recent.md | `@core/hot/handoff.md` | `inject-hot-context.sh` перед сессией |
| 3 | **On-demand** | Справочники (AGENTS.md, TOOLS.md, полный recent.md) | Локальный диск | Read tool по необходимости |
| 4 | **Cold storage** | Задачи, события, learnings, runbooks | Firebase RTDB | orgbus CLI по необходимости |

## Принцип

**In-context = минимум для старта.** Всё остальное -- on-demand.

Цель: уложить in-context слой в **≤400 строк** на агента (было ~1200+).

## inject-hot-context.sh

Скрипт выполняется перед стартом сессии (через `session-bootstrap.sh`).

**Что делает:**
1. Читает `@core/hot/recent.md` (полный лог событий)
2. Берёт последние 10 записей
3. Записывает их в `@core/hot/handoff.md`
4. `handoff.md` подключается через `@include` в CLAUDE.md

**Результат:** агент видит свежий контекст без загрузки сотен строк истории.

```
recent.md (385+ строк, on-demand)
        │
        ▼ inject-hot-context.sh (tail 10)
        │
handoff.md (≤50 строк, in-context)
```

## Что убрано из in-context → on-demand

| Файл | Строк | Причина |
|------|-------|---------|
| `@core/AGENTS.md` | ~137 | Справочник, нужен редко |
| `@tools/TOOLS.md` | ~228 | Справочник, нужен редко |
| `@core/hot/recent.md` | ~385 | Заменён на handoff.md (10 записей) |
| Дублирующие секции rules.md | ~112 | Объединены и сокращены |

## Доступ к on-demand справочникам

В CLAUDE.md каждого агента есть секция:
```
## On-demand справочники (Read tool)
- Агенты: @core/AGENTS.md
- Инструменты: @tools/TOOLS.md
- Полная история: @core/hot/recent.md
```
