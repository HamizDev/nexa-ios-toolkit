# WCMigrate embedded components

Source: [WCMigrate](https://github.com/yangokok886/WCMigrate), pinned `55faba721fd44e04c65be481860c9d93e12f6f61` (GPL-3.0-or-later).
Copies:
- `OperationEstimate.swift`: exact upstream algorithm plus a provenance comment.
- `BackupProgress.swift`: exact upstream model struct extracted from `Core/Models.swift`.

These two files are compiled directly into the Nexa target and used to display progress/ETA for Nexa's **own local backup process**. They do **not** implement WCMigrate's WeChat migration, cross-app container access, staging, or recovery state machine. The complete unmodified upstream project remains linked under `ThirdParty/WCMigrate` as a Git submodule.

- `DatabaseInspector.swift` is adapted from the original `Core/DatabaseInspector.swift` and `DatabaseReport.swift` is an unchanged excerpt from original `Core/Models.swift`. The Nexa adapter first verifies the local backup's manifest, then copies database files and WAL/SHM sidecars into a disposable directory before running SQLite `quick_check(1)` with a bounded VM budget. Only user-imported data stored inside Nexa backups can be inspected. This provides **no access** to other app containers and is not a chat data recovery or migration engine.
