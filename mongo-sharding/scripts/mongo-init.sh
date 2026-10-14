#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Ожидание запуска MongoDB.
wait_mongo() {
  for attempt in $(seq 1 60); do
    if docker compose exec -T "$1" mongosh --port "$2" --quiet --eval 'db.adminCommand({ping: 1})' >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "Не удалось дождаться $1" >&2
  return 1
}

wait_mongo configSrv 27017
wait_mongo shard1-1 27018
wait_mongo shard2-1 27019

# Каждый шард имеет свой набор реплик.
docker compose exec -T configSrv mongosh --port 27017 --quiet --file /dev/stdin <<'EOF'
try {
  rs.status();
} catch (error) {
  if (error.code !== 94) throw error;
  rs.initiate({_id: "config_server", configsvr: true, members: [{_id: 0, host: "configSrv:27017"}]});
}
EOF

docker compose exec -T shard1-1 mongosh --port 27018 --quiet --file /dev/stdin <<'EOF'
try {
  rs.status();
} catch (error) {
  if (error.code !== 94) throw error;
  rs.initiate({_id: "shard1", members: [
      {_id: 0, host: "shard1-1:27018"}
  ]});
}
EOF

docker compose exec -T shard2-1 mongosh --port 27019 --quiet --file /dev/stdin <<'EOF'
try {
  rs.status();
} catch (error) {
  if (error.code !== 94) throw error;
  rs.initiate({_id: "shard2", members: [
      {_id: 0, host: "shard2-1:27019"}
  ]});
}
EOF

# Подключение к primary после выборов.
docker compose exec -T configSrv mongosh 'mongodb://configSrv:27017/?replicaSet=config_server&serverSelectionTimeoutMS=120000' --quiet --eval 'db.adminCommand({ping: 1})'
docker compose exec -T shard1-1 mongosh 'mongodb://shard1-1:27018/?replicaSet=shard1&serverSelectionTimeoutMS=120000' --quiet --eval 'db.adminCommand({ping: 1})'
docker compose exec -T shard2-1 mongosh 'mongodb://shard2-1:27019/?replicaSet=shard2&serverSelectionTimeoutMS=120000' --quiet --eval 'db.adminCommand({ping: 1})'

wait_mongo mongos_router 27020

# Шардирование настраивается до наполнения коллекции.
docker compose exec -T mongos_router mongosh --port 27020 --quiet --file /dev/stdin <<'EOF'
const config = db.getSiblingDB("config");
if (!config.shards.findOne({_id: "shard1"})) sh.addShard("shard1/shard1-1:27018");
if (!config.shards.findOne({_id: "shard2"})) sh.addShard("shard2/shard2-1:27019");
sh.enableSharding("somedb");
if (!config.collections.findOne({_id: "somedb.helloDoc", dropped: {$ne: true}})) {
  db.adminCommand({shardCollection: "somedb.helloDoc", key: {name: "hashed"}, numInitialChunks: 4});
}
const data = db.getSiblingDB("somedb");
for (let i = 0; i < 1000; i++) {
  data.helloDoc.updateOne({_id: i, name: "ly" + i}, {$set: {age: i}}, {upsert: true});
}
print("Всего документов: " + data.helloDoc.countDocuments({}));
sh.status();
EOF

docker compose exec -T shard1-1 mongosh 'mongodb://shard1-1:27018/somedb?replicaSet=shard1' --quiet --eval 'print("shard1: " + db.helloDoc.countDocuments({})); print("Узлов в shard1: " + rs.status().members.length)'

docker compose exec -T shard2-1 mongosh 'mongodb://shard2-1:27019/somedb?replicaSet=shard2' --quiet --eval 'print("shard2: " + db.helloDoc.countDocuments({})); print("Узлов в shard2: " + rs.status().members.length)'
