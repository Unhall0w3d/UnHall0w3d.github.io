# CUCM SQL inputs and example results

All rows below are synthetic illustrations of the output shapes. Names, extensions, profile names, and CSS memberships are fictional. The calling examples reuse the pattern/partition text from the published article to show the exact substitutions. Use your own configured values.

## Speed Dial and BLF references

For the published incident example, set each of the three `<EXTENSION>` occurrences to `3012`. The regular Speed Dial row has an empty partition field. A DN-backed BLF can show its linked partition, and a direct BLF without a linked DN can return a null partition.

| entrytype | name | description | buttonindex | label | destination | partitionname |
| --- | --- | --- | --- | --- | --- | --- |
| BLF | SEP000000000001 | Example desk | 2 | Old label | 3012 | Internal-PT |
| BLF | SEP000000000002 | Example room | 5 | Support | 3012 | NULL |
| SD | SEP000000000002 | Example room | 7 | Support | 3012 | |

AXL returned the regular speed-dial type as `SD ` (one trailing space) in the CUCM 15 lab. Trim trailing spaces from that column when comparing its value in code.

Both BLF predicates matter. One checks the direct destination and the other checks the linked DN. The reported destination prefers a populated direct value, and the partition always comes from the linked DN. If a row displays a different destination from the input, inspect the configured button and associated DN. Search matches can span partitions. After an authorized label change through CUCM Administration, the same query can verify the saved label. Use the device to confirm what the user sees.

## Configured phone lines and Voice Mail Profiles

There are no input substitutions. A shared extension can appear under several devices. A missing partition or Voice Mail Profile name can be returned as null.

| devicename | devicedescription | extension | partition | voicemailprofile |
| --- | --- | --- | --- | --- |
| SEP000000000001 | Example desk | 3001 | Internal-PT | Staff-VM |
| SEP000000000002 | Example room | 3001 | Internal-PT | Staff-VM |
| SEP000000000002 | Example room | 3002 | Internal-PT | NULL |

“Active” in the source means configured on a phone-class device. Use separate evidence for registration, current ownership, and whether voicemail is operational. A null Voice Mail Profile means the left join returned no matching profile name.

## Calling access by exact route pattern and partition

Replace both placeholders for each desired audit. Match the full configured pattern string in the specified partition, including brackets, dots, and `X` characters.

| Published scenario | `<ROUTE_PATTERN>` | `<ROUTE_PARTITION>` | Published example authorization level |
| --- | --- | --- | --- |
| Long distance with FAC | `8.1[2-9]XXXXXXXXX` | `LD-FAC-PT` | 100 |
| Long distance without FAC | `8.1[2-9]XXXXXXXXX` | `LongDistance-PT` | 0 |
| Local | `8.[2-9]XXXXXX` | `Local-PT` | 0 |

Primary-line output for the first pair:

| device | description | extension | devicecss | linecss | routepattern | routepatternpt | authorizationlevel |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SEP000000000001 | Example desk | 3001 | Example-Device-CSS | Example-Staff-CSS | `8.1[2-9]XXXXXXXXX` | LD-FAC-PT | 100 |

All-line output for the same pair:

| device | description | lineindex | extension | devicecss | linecss | routepattern | routepatternpt | authorizationlevel |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SEP000000000001 | Example desk | 1 | 3001 | Example-Device-CSS | Example-Staff-CSS | `8.1[2-9]XXXXXXXXX` | LD-FAC-PT | 100 |
| SEP000000000001 | Example desk | 2 | 3003 | Example-Device-CSS | Example-Secondary-CSS | `8.1[2-9]XXXXXXXXX` | LD-FAC-PT | 100 |

Each row means at least one of the two configured CSSs includes the target partition. A missed match can reflect an absent pattern/partition pair, a line outside the selected scope, or missing CSS membership. The returned authorization level is the requirement on the target pattern. An authorized FAC still has to meet the configured threshold where applicable. The pack does not collect FAC codes.

Compare equivalent device-line scopes across target pairs. An overlap is a configuration finding. Dialed Number Analyzer or a controlled call test can assess the call path, including partition order, competing patterns, transformations, time schedules, and the actual digits dialed.
