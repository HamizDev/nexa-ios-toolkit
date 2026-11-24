# Nexa's WCMigrate TransferCore compatibility package

Upstream: yangokok886/WCMigrate at 55faba721fd44e04c65be481860c9d93e12f6f61 (GPL-3.0-or-later). The pinned submodule is untouched. This package preserves all original Core/CSupport files and selected original test suites; see LICENSE. Its manifest sets iOS 17 (the original app deployment target) alongside macOS 13 and links sqlite3. Nexa continues to target iOS 26.

One explicit source delta: DirectMigrationService.createParents compares standardized canonical path strings rather than URL equality, so directory-flag/trailing-slash variants of the same root do not trigger a false invalidPath. The same strict descendant boundary remains. This is a candidate compatibility correction, not a proven fix until CI passes. Scripts/check_transfercore.py verifies this single exact delta and byte equality for all other source files, original tests, and license.

Original baseline run 45298981054 reported four DataStagingTests invalidPath errors and a Debug deep-tree RecoveryTests process crash (signal 10). The new CI executes original suites independently, including the deep-tree case as a required separate step. It must not be skipped or counted as passing. No migration execution or resume UI is enabled. The production Nexa adapter calls only the original preview on local imported folders and applies a temporary 32-level bound while the deep-tree failure is investigated. Additional Nexa host fixtures exercise original migration of disposable copies in Replace/Merge with both original inputs retained.

