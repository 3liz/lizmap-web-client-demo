# Contributing

Each project must have the same structure.

* Edit the `mapping.csv` in which repository the project must land

## SQL

### Remove some lines

The name of the service is `PG_SERVICE`.

Please edit `projects/lzm_demo.py`, the variable `SCHEMAS` at the top of the file with the name of your schema used for the project.

To be removed from the SQL file :

```sql
SELECT pg_catalog.set_config('search_path', '', false);
SET default_table_access_method = heap;
```

### Manage

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
