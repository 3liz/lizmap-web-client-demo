# Contributing

Each project must have the same structure.

## SQL

```bash
pg_dump service=SERVICE_DB -n demo_snapping --no-acl --no-owner > /home/etienne/dev/lizmap/lizmap-demo/snapping/sql/data.sql
psql service=SERVICE_DB -f snapping/sql/data.sql
```
