# mongo-sharding-repl

Два шарда MongoDB, в каждом по три узла. Ключ шардирования — хеш поля `name`.

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

В корневом JSON ожидаются `mongo_topology_type: "Sharded"`, `mongo_is_mongos: true`, `helloDoc.documents_count: 1000`, два шарда в `shards` и `cache_enabled: false`. В адресах каждого шарда три узла. Сумма документов на шардах равна общему количеству; числа на шардах могут немного различаться.

```bash
docker compose exec -T mongos_router mongosh --port 27020 --quiet --eval 'sh.status()'
docker compose exec -T shard1-1 mongosh 'mongodb://shard1-1:27018,shard1-2:27018,shard1-3:27018/somedb?replicaSet=shard1' --quiet --eval 'print(db.helloDoc.countDocuments({})); printjson(rs.status().members.map(m => ({name: m.name, state: m.stateStr})))'
docker compose exec -T shard2-1 mongosh 'mongodb://shard2-1:27019,shard2-2:27019,shard2-3:27019/somedb?replicaSet=shard2' --quiet --eval 'print(db.helloDoc.countDocuments({})); printjson(rs.status().members.map(m => ({name: m.name, state: m.stateStr})))'
```

## Остановка

```bash
docker compose down
```

Тома MongoDB сохраняются. Для следующего запуска повторите команды из раздела «Запуск».
