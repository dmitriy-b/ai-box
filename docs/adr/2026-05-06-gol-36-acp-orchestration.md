# ADR: GOL-36 — ACP-сумісність N8N і вибір оркестрації

- Статус: Accepted
- Дата: 2026-05-06
- Лінк на задачу: https://linear.app/goldbillka/issue/GOL-36/spike-acp-sumisnist-n8n-i-alternativi

## Контекст

Потрібно вибрати практичний стек для оркестрації агентів між різними VM з такими вимогами:
- retry/health
- декларативне додавання агентів (yaml/json)
- realtime-логи в orchestrator
- stateful sessions

## Результати spike

### 1) N8N і ACP

Станом на дату дослідження, у n8n немає нативних ACP nodes. Інтеграція можлива через HTTP/Webhook/custom node, але це додатковий адаптерний шар, а не пряма ACP-сумісність.

### 2) Готові ACP server/client варіанти

- `sample-acp-bridge` (вже інтегрований у `ai-box`) як ACP/REST gateway.
- `opencode` у ACP-режимі (`opencode acp`).
- `claude-agent-acp` як ACP-адаптер для Claude Code (використовується у дефолтному bridge config).

### 3) Розглянуті альтернативи

1. **N8N як orchestrator + ACP через custom інтеграцію**
   - Плюси: візуальні флоу.
   - Мінуси: немає нативного ACP, вища операційна складність.

2. **Власний orchestrator (Python/Go service) + MCP/custom transport**
   - Плюси: максимальна гнучкість.
   - Мінуси: найдовший time-to-market, треба з нуля будувати health/retry/session/logging контур.

3. **ACP Bridge + легкий launcher з керуючої машини (SSH)**
   - Плюси: вже присутній у репозиторії, декларативний YAML-конфіг агентів, швидкий POC.
   - Мінуси: для enterprise-потоків може знадобитися окремий control-plane сервіс.

## Рішення

Обираємо **ACP Bridge + SSH launcher** як базовий стек для старту.

### Чому це покриває критерії

- **Retry/health**: launcher виконує retry на виклик API та health-check bridge.
- **Декларативне додавання агентів**: `data/acp-bridge/<account>/config.yml` (`agents:`).
- **Realtime логи**: orchestrator читає job/event потік bridge API (або полінг job status).
- **Stateful sessions**: у bridge налаштовано `session_ttl_hours`, сесії керуються на стороні bridge.

## POC

Додано скрипт:

- `/home/runner/work/ai-box/ai-box/scripts/poc-remote-claude-via-acp-bridge.sh`

Сценарій POC:
1. З керуючої машини через SSH піднімає `acp-bridge` на віддаленій VM у Docker.
2. Чекає health endpoint bridge.
3. Створює job для `claude` через REST API bridge.

Це мінімальний наскрізний proof, що запуск Claude Code на віддаленій VM працює через вибраний механізм.
