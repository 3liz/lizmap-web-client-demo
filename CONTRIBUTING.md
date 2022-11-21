# Contributing

Each project must have the same structure.

## SQL

* To extract data from a service for the whole schema

```bash
pg_dump service=lizmapdb -n demo_snapping --no-acl --no-owner > /home/etienne/dev/lizmap/lizmap-demo/snapping/sql/data.sql
```

* To extract data from a service for a subset of tables

```bash
pg_dump service=lizmapdb -t tests_projects.XXX -t tests_projects.YYY --no-acl --no-owner > /home/etienne/dev/lizmap/lizmap-demo/snapping/sql/data.sql
```

* To import data
```bash
psql service=lizmapdb -f snapping/sql/data.sql
```
