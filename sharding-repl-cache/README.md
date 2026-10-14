# sharding-repl-cache

Два шарда MongoDB, в каждом по три узла. Для кеширования используется Redis. Ключ шардирования — хеш поля `name`.

## Запуск

Команды выполняются из этой папки. Нужны Docker Compose и Bash (в Windows — Git Bash или WSL). Порт 8080 должен быть свободен. Одновременно запускайте один вариант стенда.

```bash
docker compose up -d
bash scripts/mongo-init.sh
docker compose ps
```

Скрипт создаёт наборы реплик, добавляет шарды в mongos, включает шардирование коллекции `somedb.helloDoc` и записывает 1000 документов. В конце он выводит общее количество, количество документов на каждом шарде и число узлов. Повторный запуск не дублирует исходные записи.

## Проверка

- [Состояние MongoDB и кеша](http://localhost:8080)
- [Количество документов](http://localhost:8080/helloDoc/count)
- [Пользователи](http://localhost:8080/helloDoc/users)
- [Swagger](http://localhost:8080/docs)

В корневом JSON ожидаются `mongo_topology_type: "Sharded"`, `mongo_is_mongos: true`, `helloDoc.documents_count: 1000`, два шарда в `shards` и `cache_enabled: true`. В адресах каждого шарда три узла. Сумма документов на шардах равна общему количеству; числа на шардах могут немного различаться.

```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet --eval 'sh.status()'
docker compose exec -T shard1-1 mongosh 'mongodb://shard1-1:27018,shard1-2:27018,shard1-3:27018/somedb?replicaSet=shard1' --quiet --eval 'print(db.helloDoc.countDocuments({})); printjson(rs.status().members.map(m => ({name: m.name, state: m.stateStr})))'
docker compose exec -T shard2-1 mongosh 'mongodb://shard2-1:27019,shard2-2:27019,shard2-3:27019/somedb?replicaSet=shard2' --quiet --eval 'print(db.helloDoc.countDocuments({})); printjson(rs.status().members.map(m => ({name: m.name, state: m.stateStr})))'
```

## Проверка кеша

Выполните команды подряд в пределах минуты:

```bash
curl -s -D - -o /dev/null -w '\ntime=%{time_total}s\n' http://localhost:8080/helloDoc/users
curl -s -D - -o /dev/null -w '\ntime=%{time_total}s\n' http://localhost:8080/helloDoc/users
curl -s -D - -o /dev/null -w '\ntime=%{time_total}s\n' http://localhost:8080/helloDoc/users
docker compose exec -T redis redis-cli DBSIZE
```

Первый запрос заполняет кеш; второй и третий должны занимать менее 0,1 секунды. TTL в предоставленном приложении — 60 секунд. После истечения TTL следующий запрос снова читает MongoDB. Для измерения первого запроса используйте новый стенд либо дождитесь истечения TTL. Команда `DBSIZE` подтверждает наличие записей в Redis.

## Остановка

```bash
docker compose down
```

Тома MongoDB сохраняются. Для следующего запуска повторите команды из раздела «Запуск».
