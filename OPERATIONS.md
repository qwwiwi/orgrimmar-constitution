# Операционная модель Orgrimmar

_КАК работает система. Связующий слой между конституцией и pipeline._

---

## Роли

| Роль | Зона | Может | Не может |
|------|------|-------|----------|
| coordinator | Оркестрация | Распределять задачи, ревьюить планы | Править архитектуру coder'а |
| coder | Код, архитектура | Писать код, PR, деплой | Менять чужие AGENTS.md |
| devops | Инфра, мониторинг | Рестартовать, чинить | Менять бизнес-логику |
| monitor | Внешние данные | Алертить, собирать данные | Мониторить серверы |
| creator | Контент | Создавать, публиковать | Менять инфру |

---

## Задачная система

### Классификация сообщений

| Тип | Критерий | Маршрут |
|-----|----------|---------|
| ЗАДАЧА | Есть последствие невыполнения | inbox -> triage -> active -> done |
| ИДЕЯ | Ценная мысль, нет дедлайна | ideas/ |
| ЗАПРОС | Нужен ответ сейчас | Ответить |
| ОТВЕТ | Реакция на вопрос агента | Обновить задачу |

### Статусы задач

| Статус | Значение |
|--------|----------|
| new | Создана, ждёт assignee |
| in progress | Взята в работу |
| pipeline | Запущен автоматический pipeline |
| blocked | Заблокирована (причина обязательна) |
| review | Сделано, ждёт проверки принца |
| done | Завершена и подтверждена |

Жизненный цикл: new -> in progress -> [pipeline] -> review -> done

**Правила:**
- Задача без обновления >24ч -- Артас пингует
- >48ч -- алерт принцу
- Inbox >4ч без triage -- алерт координатору
- Удалять из inbox запрещено -- только triage или архивация

### Хранение
Firebase RTDB (`/tasks/`). Инструмент: orgbus.

---

## Маршрутизация задач

| Теги | Роль | Pipeline |
|------|------|----------|
| код, фича, баг, PR | coder | dev-pipeline |
| сервер, диск, RAM, деплой | devops | -- |
| агент тупит, ложный алерт | coder | agent-bugfix |
| контент, пост, видео | creator | content-pipeline |
| бюджет, расходы | finance | -- |
| напоминание, расписание | worker | -- |
| обновление агентов | coder | safe-update |
| идея, стратегия | coordinator + coder | brainstorm |
| неизвестно | coordinator -> принц | -- |

---

## Model routing (pipeline-воркеры)

| Задача | Модель | Обоснование |
|--------|--------|-------------|
| SPEC / PLANNING | opus | Архитектура |
| GATHER / RESEARCH | grok | Быстро, дёшево |
| GATHER (>50KB) | gemini | 2M контекст |
| Код / FIX | codex | OAuth $0 |
| VERIFY | codex | OAuth $0 |
| REVIEW (обычный) | codex + opus | OAuth $0 |
| REVIEW (HIGH risk) | codex + opus + gemini | Triple review |

---

## Git Workflow

- **Монорепо:** PR-first. Прямой push в main запрещён.
- **Cross-review:** PR от coder -> ревьюит devops, и наоборот. Автор ≠ reviewer.
- **Change levels:** L0 (косметика), L1 (рабочие файлы), L2 (инфра), L3 (конституция -- только принц мержит).
- **Deploy order:** Illidan -> Thrall -> Arthas -> Mac mini. Fail = стоп + rollback.
- **Branch naming:** feature/<server>/<описание>, fix/<server>/<описание>.

---

## Heartbeats

| Агент | Частота | Модель |
|-------|---------|--------|
| Тралл | 3ч | Grok |
| Сильвана | 2ч | Grok |
| Артас | OFF | -- |
| Иллидан | 2ч | Kimi |

Принцип: heartbeat = молчание если всё ок. Алерт только при проблеме.

---

## Эскалация

| Триггер | Действие |
|---------|----------|
| Задача вне роли | Передай координатору |
| 3 попытки фикса не помогли | Стоп, доклад принцу |
| Сервер/агент недоступен | devops чинит; devops упал -> coder |
| Перерасход >$20 | Стоп, одобрение принца |
| Конфликт между агентами | Эскалация принцу |
| Принц недоступен 1-3ч | L3 low-risk only |
| Принц недоступен >24ч | Все read-only |

---

## Обязательные скиллы

### Базовые (все агенты)

| Скилл | Назначение |
|-------|------------|
| memory-audit | Самодиагностика памяти |
| learnings | Запись ошибок и уроков |
| shared-memory | Чтение shared-контекста при старте |
| task-system | Работа с задачной системой |
| transcript | Транскрипция видео |
| twitter | Чтение Twitter/X |

### Ролевые

| Агент | Скиллы |
|-------|--------|
| Тралл | server-ops, cross-review, worker-orchestration, dev-pipeline |
| Сильвана | task-triage, groq-voice, content-engine |
| Артас | chat-alerts, chat-ops, topic-monitor |
| Иллидан | server-rescue, cross-review |

Отсутствие базового скилла = VIOLATION.

---

## Данные и инфраструктура

Persistent state: Firebase RTDB. Инструмент доступа: orgbus CLI. Бэкапы: ежедневно, перекрёстно.

> Детали Firebase (структура, SA, безопасность) -- runbook «firebase-ops» (Firebase).
> Backup policy -- runbook «backup» (Firebase).
> Инварианты памяти (protected configs/crons/skills) -- runbook «invariants» (Firebase).
> Стандарт openclaw.json -- runbook «config-standard» (Firebase).
