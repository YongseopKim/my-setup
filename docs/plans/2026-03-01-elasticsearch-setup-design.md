# Elasticsearch + Kibana Docker Setup

## Purpose
범용 Elasticsearch 환경 구축 (전문 검색 + 로그/모니터링). Kibana 포함.

## Architecture
- Single-node Elasticsearch 8.17.3
- Kibana 8.17.3
- 보안 비활성화 (xpack.security.enabled=false)
- localhost 바인딩

## Directory Structure
```
ubuntu/search/
├── docker-compose.yml
└── .env → ~/.env (symlink)
```

## Services

### Elasticsearch
- Image: `elasticsearch:8.17.3`
- Port: `9200:9200`
- Volume: `/loki1-sa510-2tb/elasticsearch-data` → `/usr/share/elasticsearch/data`
- Config: `discovery.type=single-node`, `xpack.security.enabled=false`
- JVM: `-Xms2g -Xmx2g`

### Kibana
- Image: `kibana:8.17.3`
- Port: `5601:5601`
- ES connection: `http://elasticsearch:9200` (internal network)

## Environment Variables (added to ~/.env)
```
ES_PORT=9200
ES_DATA_PATH=/loki1-sa510-2tb/elasticsearch-data
ES_JAVA_OPTS=-Xms2g -Xmx2g
KIBANA_PORT=5601
```

## Verification
1. ES health: `curl http://localhost:9200/_cluster/health`
2. Kibana UI: `http://localhost:5601`
