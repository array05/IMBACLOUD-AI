# IMBACLOUD AI — Worker

[![ImbaCloud](https://img.shields.io/badge/ImbaCloud-imbacloud.ru-2563eb?style=for-the-badge)](https://imbacloud.ru/)
[![GitHub](https://img.shields.io/badge/GitHub-IMBACLOUD--AI-181717?style=for-the-badge&logo=github)](https://github.com/array05/IMBACLOUD-AI)

**Imbai Worker** — агент, который устанавливается на **ваш сервер** и подключается к платформе **[ImbaCloud AI](https://imbacloud.ru/)**.

> 🌐 Сайт: **[imbacloud.ru](https://imbacloud.ru/)** · VPS, Dedicated и GPU от 637 ₽/мес  
> 📚 Документация: [imbacloud.ru — раздел «Документация»](https://imbacloud.ru/)  
> 💬 Поддержка: [@imbacloud_bot](https://t.me/imbacloud_bot) · support@imbacloud.ru

Этот репозиторий содержит **только клиентскую часть** (worker).  
Gateway, LLM и биллинг — на стороне ImbaCloud. Root-доступ к нашим серверам **не нужен**.

---

## Зачем это нужно

**[ImbaCloud](https://imbacloud.ru/)** — облачный хостинг для разработчиков и бизнеса.  
**IMBACLOUD AI** — AI-агент поверх инфраструктуры ImbaCloud:

- выполняет команды на **вашем** сервере (`bash`, `git`, `docker`, `systemctl`…)
- читает и пишет файлы в указанной директории
- решает задачи в несколько шагов (agent loop)
- отвечает через LLM (Qwen и др.)

Worker — «руки» агента на вашей машине.  
Gateway — «мозг» и API, через который вы отправляете задачи.

```
┌─────────────┐     HTTPS API      ┌──────────────────┐     tools     ┌─────────────────┐
│  Ваш сайт   │ ────────────────▶  │  IMBACLOUD AI    │ ────────────▶ │  Worker         │
│  PHP / app  │   /v1/agent/run    │  Gateway         │   HTTP :9090  │  (этот репо)    │
└─────────────┘                    │  imbacloud.ru    │               │  ВАШ VPS        │
                                   └────────┬─────────┘               └─────────────────┘
                                            │
                                            ▼ LLM inference
                                   ┌──────────────────┐
                                   │  GPU-сервер      │
                                   │  ImbaCloud       │
                                   └──────────────────┘
```

> Нет своего VPS? Закажите на **[imbacloud.ru](https://imbacloud.ru/)** — от 637 ₽/мес, 13 локаций.

---

## Скоро: установка в один клик

Для клиентов **[ImbaCloud](https://imbacloud.ru/)** мы готовим автоматическую установку AI-агента **при заказе сервера** — прямо из личного кабинета, без ручных команд и registration token.

**Чат в карточке сервера** — задачи агенту прямо в панели ImbaCloud: открыл VPS → написал «проверь nginx» → получил ответ. Без SSH, без терминала, без лишней суеты.

| Сейчас | Скоро |
|--------|-------|
| `curl \| bash` + token от поддержки | **One-click** при создании VPS |
| API / curl для задач агенту | **Чат в карточке сервера** в личном кабинете |
| Ручная настройка firewall | Автоматически в панели ImbaCloud |
| Отдельный install token | Worker привязывается к серверу сам |

```
Личный кабинет ImbaCloud
  └── Серверы → VPS #12345
        ├── Статус · IP · Ребут
        └── 💬 IMBACLOUD AI Chat    ← задачи агенту здесь
              "обнови пакеты и проверь docker"
              "создай backup в /root"
```

> Уже есть VPS на ImbaCloud? Пока используйте [ручную установку](#быстрая-установка) и [API](#использование-после-установки).  
> Новым клиентам скоро будет доступен переключатель **«IMBACLOUD AI Agent»** при заказе + встроенный чат на каждой карточке сервера.

---

## Быстрая установка

### 1. Получите от [ImbaCloud](https://imbacloud.ru/)

| Параметр | Пример | Откуда |
|----------|--------|--------|
| `worker-id` | `server-srv_abc123` | **Уникальный ID этого VPS** — из [кабинета ImbaCloud](https://imbacloud.ru/) или от поддержки |
| `registration-token` | одноразовый token | ImbaCloud (один раз на установку) |
| `gateway` | URL API | ImbaCloud |

> **Важно:** один `worker-id` = один сервер. На 3 VPS — три разных id. Не копируйте один и тот же id на несколько машин.

### 2. Одна команда на вашем сервере

```bash
curl -fsSL "https://raw.githubusercontent.com/array05/IMBACLOUD-AI/main/install.sh?v=20260707" | bash -s -- \
  --worker-id server-srv_abc123 \
  --registration-token ВАШ_TOKEN \
  --gateway http://31.129.101.206:8080
```

По умолчанию workspace = **`/root`** (весь root home на сервере).

Другой путь — явно:
```bash
  --workspace /var/www/myapp
```

Замените:
- `server-srv_abc123` — **ваш** `worker-id` (из панели — не придумывайте сами)
- `ВАШ_TOKEN` — token от ImbaCloud
- `--gateway` — URL API (актуальный — у поддержки или в [кабинете](https://imbacloud.ru/))

> Token **одноразовый**. Пароль root gateway **не нужен**.  
> Запросить token: [Telegram @imbacloud_bot](https://t.me/imbacloud_bot) или support@imbacloud.ru

### 3. Проверка

После установки worker автоматически:
- запускается на порту **9090**
- регистрируется на gateway
- шлёт heartbeat каждые 30 секунд

---

## worker_id — что это

**`worker_id`** — уникальное имя агента на конкретном VPS. Gateway по нему понимает, **на какой сервер** отправить задачу.

```
Пользователь (1 API key)
    │
    ├── worker_id: server-vps1  →  VPS в Москве
    ├── worker_id: server-vps2  →  VPS в Амстердаме
    └── worker_id: server-vps3  →  VPS в Финляндии
```

| | API key | worker_id |
|--|---------|-----------|
| Что это | доступ к gateway | конкретный сервер |
| Сколько | один на пользователя (или несколько) | **один на каждый VPS** |
| Где указать | `Authorization: Bearer ...` | `--worker-id` при установке и `"worker_id"` в API |

**Из панели ImbaCloud** — id уже в команде установки (`server-{id}`). **Не меняйте** его вручную.

**Ручная установка** — каждый сервер получает свой id от поддержки. Пример: `server-srv_abc123`, `server-srv_def456`.

При смене VPS (миграция) — **остановите worker на старом сервере**, затем установите на новом с **новым** registration token. Тот же `worker_id` на двух машинах одновременно — конфликт в реестре gateway.

---

## Установка без root

```bash
curl -fsSL "https://raw.githubusercontent.com/array05/IMBACLOUD-AI/main/install.sh?v=20260707" | bash -s -- \
  --worker-id server-srv_abc123 \
  --workspace /home/deploy/myapp \
  --registration-token ВАШ_TOKEN \
  --user deploy
```

---

## Использование после установки

```bash
curl -X POST http://31.129.101.206:8080/v1/agent/run \
  -H "Authorization: Bearer ВАШ_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "task": "проверь nginx и покажи статус",
    "worker_id": "server-srv_abc123",
    "stream": true
  }'
```

| Endpoint | Описание |
|----------|----------|
| `POST /v1/agent/run` | Agent с tools на вашем сервере |
| `POST /v1/chat/completions` | Chat с LLM (без tools) |
| `GET /v1/workers` | Список worker'ов (online/offline) |

API key выдаёт [ImbaCloud](https://imbacloud.ru/) (отдельно от install token). **Один API key работает на все ваши серверы** — в запросе указываете нужный `worker_id`.

---

## Требования

| Компонент | Минимум |
|-----------|---------|
| ОС | Linux (Ubuntu 22.04+, Debian 12+) |
| Python | 3.10+ |
| VPS | свой сервер или [ImbaCloud VPS](https://imbacloud.ru/) от 637 ₽/мес |
| Сеть | исходящий HTTPS + входящий **9090** с IP gateway |
| Права | root **или** user с доступом к workspace |

---

## Firewall

Откройте порт **9090** **только** для IP gateway ImbaCloud (уточните у поддержки).

Не открывайте 9090 в интернет.

---

## Безопасность

- **Registration token** — одноразовый, только для установки
- **Worker token** — генерируется локально (`.env.worker`)
- **API key** — для запросов к gateway
- Файловые tools ограничены `workspace`
- Shell — blocklist на опасные команды

---

## Структура репозитория

```
├── install.sh              # точка входа (curl | bash)
├── scripts/
│   └── install-worker.sh   # установщик
├── worker/                 # FastAPI worker daemon
├── shared/                 # общая логика tools
└── docker-compose.worker.yml
```

---

## Обновление

```bash
curl -fsSL "https://raw.githubusercontent.com/array05/IMBACLOUD-AI/main/install.sh?v=20260707" | bash -s -- \
  --worker-id server-srv_abc123 \
  --registration-token НОВЫЙ_TOKEN \
  --gateway http://31.129.101.206:8080
```

---

## Troubleshooting

| Проблема | Решение |
|----------|---------|
| `Invalid registration token` | Запросите новый token у [поддержки](https://imbacloud.ru/) |
| Два VPS с одним `worker-id` | Остановите worker на старом сервере, зарегистрируйте новый |
| Worker offline | `journalctl -u imbai-worker -f` |
| Gateway недоступен | Проверьте firewall, напишите в [@imbacloud_bot](https://t.me/imbacloud_bot) |
| Команды в Docker, не на хосте | Переустановите без `--docker` |

---

## Поддержка

| Канал | Ссылка |
|-------|--------|
| 🌐 Сайт | [imbacloud.ru](https://imbacloud.ru/) |
| 💬 Telegram | [@imbacloud_bot](https://t.me/imbacloud_bot) |
| ✉️ Email | support@imbacloud.ru |
| 📦 GitHub | [array05/IMBACLOUD-AI](https://github.com/array05/IMBACLOUD-AI) |

---

## License

© [ImbaCloud](https://imbacloud.ru/). Worker install package for registered clients.
