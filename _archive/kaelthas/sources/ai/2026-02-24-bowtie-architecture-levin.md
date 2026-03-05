# source-2026-02-24-bowtie-architecture-levin.md

type: article
url: https://www.instagram.com/matskevich/
tags: [ai, agents, memory, architecture, bowtie]
---

Источник: Michael Levin (Tufts University), пересказ/разбор через @matskevich (Instagram).

## Суть
Биологические когнитивные агенты устроены как «бабочка» (bowtie):
- Encoder (прошлое) → Bottleneck (сжатое NOW) → Decoder (будущее)
- Selflets: агент не имеет прямого доступа к прошлому, реконструирует себя каждый момент
- Bottleneck – не удаление, а сжатие с потенциалом декомпрессии

## Применимость к AI-агентам
- Каждая сессия AI-агента = selflet (stateless, реконструирует себя из памяти)
- HOT/WARM/COLD память = bowtie-архитектура
- Structured compression: логи → события → паттерны → принципы
- Cognitive Glue = общие протоколы между агентами (конституция, конвенции)

## Контент-идея
Тема для поста/статьи: «Как биологическая архитектура памяти объясняет дизайн AI-агентов». Levin + наш опыт с 8 агентами.

## Ресёрч
- research/selflets-levin-analysis.md (на Thrall)
- research/bowtie_memory_research.md (на Thrall)
- Статья Levin 2024: «Self-Improvising Memory» (Entropy)
