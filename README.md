# Мобильный мир

Проект четвёртого спринта. Масштабирование MongoDB и кеширование запросов приложения.

## Состав

- `mongo-sharding` — два шарда MongoDB.
- `mongo-sharding-repl` — два шарда, по три узла в каждом.
- `sharding-repl-cache` — шардирование, репликация и Redis. Этот вариант используется для проверки.
- `architecture.drawio` — пять этапов схемы. Итоговая схема находится на странице «5. CDN».

Исходное приложение находится в `api_app`. В стендах используется образ `kazhem/pymongo_api:1.0.0`.

## Запуск итогового стенда

Нужны Docker Compose, Bash (в Windows — Git Bash или WSL), минимум 2 CPU и 4 ГБ памяти для Docker, свободное место для образов и томов. Порт 8080 должен быть свободен.

```bash
cd sharding-repl-cache
docker compose up -d
bash scripts/mongo-init.sh
docker compose ps
```

Инициализация может занять несколько минут. Скрипт выводит общее количество документов, распределение по шардам и количество узлов. База — `somedb`, коллекция — `helloDoc`, исходных документов — 1000.

Откройте [приложение](http://localhost:8080), [количество документов](http://localhost:8080/helloDoc/count), [список пользователей](http://localhost:8080/helloDoc/users) и [Swagger](http://localhost:8080/docs).

В JSON приложения должны быть два шарда, по три адреса в каждом, 1000 документов, `mongo_topology_type: "Sharded"`, `mongo_is_mongos: true` и `cache_enabled: true`. Числа документов на отдельных шардах и состав наборов реплик проверяются командами из [инструкции стенда](sharding-repl-cache/README.md).

## Проверка Redis

Запросы выполняются подряд, пока не истекли 60 секунд TTL:

```bash
curl -s -D - -o /dev/null -w '\ntime=%{time_total}s\n' http://localhost:8080/helloDoc/users
curl -s -D - -o /dev/null -w '\ntime=%{time_total}s\n' http://localhost:8080/helloDoc/users
curl -s -D - -o /dev/null -w '\ntime=%{time_total}s\n' http://localhost:8080/helloDoc/users
```

Первый запрос заполняет кеш. Второй и последующие должны занимать менее 100 мс.

## Остальные этапы

Сначала остановите текущий стенд командой `docker compose down`. Затем перейдите в папку нужного этапа и выполните его [инструкцию](mongo-sharding/README.md) или [инструкцию репликации](mongo-sharding-repl/README.md). Все варианты используют порт 8080 и отдельные тома.

## Схема

Откройте `architecture.drawio` в draw.io. На итоговой странице показаны два экземпляра приложения, API Gateway с балансировкой, Consul, Redis, mongos, сервер конфигурации, два набора реплик MongoDB, CDN в двух регионах и источник статики. API Gateway, Consul и CDN добавлены на схему по заданиям 5 и 6.

## Остановка

Из папки запущенного стенда:

```bash
docker compose down
```

Данные MongoDB остаются в томах.
