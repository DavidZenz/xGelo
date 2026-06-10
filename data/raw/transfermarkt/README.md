# Transfermarkt Snapshot Cache

Place the optional `dcaribou/transfermarkt-datasets` DuckDB snapshot here as:

```text
data/raw/transfermarkt/transfermarkt-datasets.duckdb
```

The snapshot is intentionally ignored by git. Commit only metadata and code.
All squad-strength features must be computed with source rows strictly before
the forecast or benchmark cutoff date.

Historical benchmarks should use dated `player_valuations` and avoid current
profile fields such as current club, current national team, current market
value, current caps, and current goals unless those fields are reconstructed
from dated records.
