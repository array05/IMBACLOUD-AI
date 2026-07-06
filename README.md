# IMBACLOUD AI — Worker

**Imbai Worker** — агент, который устанавливается на **ваш сервер** и подключается к облаку [IMBACLOUD AI](https://github.com/array05/IMBACLOUD-AI).

Этот репозиторий содержит **только клиентскую часть** (worker).  
Gateway, LLM и биллинг живут на стороне IMBACLOUD — вам не нужен к ним root-доступ.

---

## Зачем это нужно

IMBACLOUD AI — платформа AI-агента, который может:

- выполнять команды на **вашем** сервере (`bash`, `git`, `docker`, `systemctl`…)
- читать и писать файлы в указанной директории
- решать задачи в несколько шагов (agent loop)
- отвечать через LLM (Qwen и др.)

Worker — это «руки» агента на вашей машине.  
Gateway — «мозг» и API, через который вы (или ваше приложение) отправляете задачи.

```
┌─────────────┐     HTTPS API      ┌──────────────────┐     tools     ┌─────────────────┐
│  Ваш сайт   │ ────────────────▶  │  IMBACLOUD       │ ────────────▶ │  Worker         │
│  PHP / app  │   /v1/agent/run    │  Gateway         │   HTTP :9090  │  (этот репо)    │
└─────────────┘                    │  31.129.101.206  │               │  ВАШ сервер     │
                                   └────────┬─────────┘               └─────────────────┘
                                            │
                                            ▼ LLM inference
                                   ┌──────────────────┐
                                   │  GPU / vLLM      │
                                   └──────────────────┘
```

---

## Быстрая установка

### 1. Получите от администратора IMBACLOUD

| Параметр | Пример |
|----------|--------|
| `worker-id` | `client-prod` |
| `registration-token` | одноразовый token |
| `gateway` | `http://31.129.101.206:8080` |

> Token **одноразовый**. Root-пароль gateway **не нужен**.

### 2. Одна команда на вашем сервере

```bash
curl -fsSL https://raw.githubusercontent.com/array05/IMBACLOUD-AI/main/install.sh | bash -s -- \
  --worker-id client-prod \
  --workspace /var/www/myapp \
  --registration-token ВАШ_TOKEN \
  --gateway http://31.129.101.206:8080
```

Замените:
- `/var/www/myapp` — корень вашего проекта (или `/root`, `/home/user/app`)
- `ВАШ_TOKEN` — token от администратора

### 3. Проверка

После установки worker автоматически:
- запускается на порту **9090**
- регистрируется на gateway
- шлёт heartbeat каждые 30 секунд

---

## Установка без root

Если есть Python 3 и пользователь с доступом к проекту:

```bash
curl -fsSL https://raw.githubusercontent.com/array05/IMBACLOUD-AI/main/install.sh | bash -s -- \
  --worker-id client-prod \
  --workspace /home/deploy/myapp \
  --registration-token ВАШ_TOKEN \
  --user deploy
```

---

## Использование после установки

Worker сам по себе **не имеет UI**. Вы работаете через **Gateway API**:

```bash
curl -X POST http://31.129.101.206:8080/v1/agent/run \
  -H "Authorization: Bearer ВАШ_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "task": "проверь nginx и покажи статус",
    "worker_id": "client-prod",
    "stream": true
  }'
```

| Endpoint | Описание |
|----------|----------|
| `POST /v1/agent/run` | Agent с tools на вашем сервере |
| `POST /v1/chat/completions` | Chat с LLM (без tools) |
| `GET /v1/workers` | Список worker'ов (online/offline) |

API key выдаёт администратор IMBACLOUD (отдельно от install token).

---

## Требования

| Компонент | Минимум |
|-----------|---------|
| ОС | Linux (Ubuntu 22.04+, Debian 12+) |
| Python | 3.10+ (для native install) |
| Docker | опционально (`--docker`) |
| Сеть | исходящий HTTPS + входящий **9090** с IP gateway |
| Права | root **или** user с доступом к workspace |

---

## Firewall

Откройте порт **9090** **только** для IP gateway:

```
31.129.101.206  →  ваш_сервер:9090
```

Не открывайте 9090 в интернет — worker принимает команды только от gateway.

---

## Безопасность

- **Registration token** — одноразовый, только для установки
- **Worker token** — генерируется локально, хранится в `.env.worker`
- **API key** — для запросов к gateway (ваше приложение / PHP)
- Файловые tools ограничены `workspace`
- Shell — blocklist на опасные команды (`rm -rf /`, `mkfs`, …)

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

## Обновление worker

```bash
cd /opt/imbai   # или каталог установки
curl -fsSL https://raw.githubusercontent.com/array05/IMBACLOUD-AI/main/install.sh | bash -s -- \
  --worker-id client-prod \
  --workspace /var/www/myapp \
  --registration-token НОВЫЙ_TOKEN
```

Нужен новый registration token от администратора.

---

## Troubleshooting

| Проблема | Решение |
|----------|---------|
| `Invalid registration token` | Token одноразовый / истёк — запросите новый |
| Worker offline на gateway | `systemctl status imbai-worker` или `docker logs imbai-worker` |
| Gateway не достучится | firewall :9090, проверьте `WORKER_PUBLIC_URL` |
| Команды в Docker, не на хосте | переустановите **без** `--docker` (native mode) |

Логи native:
```bash
journalctl -u imbai-worker -f
```

---

## Поддержка

- Gateway: `http://31.129.101.206:8080/health`
- Worker health: `http://localhost:9090/health`
- Swagger: `http://31.129.101.206:8080/docs`

---

## License

Proprietary — IMBACLOUD AI Platform.  
Worker install package for registered clients.
