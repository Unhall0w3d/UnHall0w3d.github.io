# CUCM SQL query pack · 2026-11-20

| Statement | Use it to review | Inputs |
| --- | --- | --- |
| [speed-dial-references.sql](speed-dial-references.sql) | Regular and BLF Speed Dial button records that reference one extension | Replace `<EXTENSION>` in all three places with the same extension string. |
| [configured-phone-lines.sql](configured-phone-lines.sql) | Mapped phone-class directory numbers, partitions, and Voice Mail Profiles | None. This inventories the matching assignments across the database. |
| [css-primary-line.sql](css-primary-line.sql) | Device or Line Calling Search Space (CSS) membership for the target route pattern's partition, limited to the first line appearance | Replace `<ROUTE_PATTERN>` and `<ROUTE_PARTITION>` with the exact configured pair. |
| [css-all-lines.sql](css-all-lines.sql) | The same membership check across all line appearances, including the configured line index | Replace `<ROUTE_PATTERN>` and `<ROUTE_PARTITION>` with the exact configured pair. |

## Run a query

Work on a copy of the SQL file. Keep extensions as strings, including leading zeros. For a route pattern, copy the configured punctuation and partition exactly. Replace every placeholder inside its existing single quotes. Double any apostrophe inside a value. An overlooked placeholder can produce a convincing empty report.

**Publisher CLI.** Put the completed SELECT on one line, prefix it with `run sql `, and paste it at the CUCM administrator prompt.

**AXL.** Use an AXL account with SQL query access. Send the completed SELECT as the text of the `sql` element in an `executeSQLQuery` request to the publisher. Let the SOAP client or XML serializer escape the text. Omit the CLI prefix. For example, in a client bound to the Cisco AXL WSDL:

```python
from pathlib import Path

statement = Path("configured-phone-lines.sql").read_text(encoding="utf-8")
response = service.executeSQLQuery(sql=statement)
```

## What the CUCM 15 test covered

All four statements ran via AXL 15.0 on CUCM 15.0.1.15900(150). Inventory returned four configured line appearances. The button query found one regular speed dial and one DN-backed BLF for the same extension. For a blocked test route pattern, the primary-line CSS query returned Line 1. The all-lines query returned Lines 1 and 2. Both lines matched through their line CSS.

A CSS match tells you that a device or line CSS includes the pattern’s partition. A blocked pattern can match that test. Use Dialed Number Analyzer or an authorized call test to investigate actual dialing behavior. The pack reports the configured authorization level and excludes FAC codes. Treat real results as private inventory.

See [EXAMPLES.md](EXAMPLES.md) for sample substitutions, result columns, and interpretation. From the extracted directory on Linux, run `sha256sum -c SHA256SUMS.txt` to verify the four templates and both documents before editing a working copy.
