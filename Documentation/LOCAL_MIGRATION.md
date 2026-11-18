# Nexa 0.0.1 — imported-folder migration and recovery

## Boundary

This feature migrates **copies already present inside Nexa Documents/Imports**. It does not open, migrate, decrypt, merge or overwrite live WeChat / third-party private containers. It is separate from WCMigrate's original `DirectMigrationService`.

The original WCMigrate source and pinned commit are maintained under `ThirdParty/WCMigrate`. Its `OperationEstimate`, `BackupProgress`, `WeChatIdentityResolver` and adapted SQLite quick-check are used elsewhere in Nexa; this staging subsystem is Nexa-specific.

## Transaction

1. Choose an existing imported source directory and a separate imported destination directory.
2. Inventory the source recursively, rejecting symbolic links, special files and more than 100,000 entries.
3. Stream SHA-256 hashes of every regular file; show count/bytes for confirmation.
4. Repeat the preview immediately before executing; reject a changed source.
5. Copy to a UUID temporary folder in private Documents/ImportMigrationStaging.
6. Verify staged files against the original manifest and independently rescan the source.
7. Persist a JSON receipt in private Application Support with state `staging`.
8. Move the staged copy to a **new uniquely named** folder in the selected destination. Existing files are never overwritten.
9. Re-verify destination hashes; mark `complete`. **Never delete the source.**

## Recovery

On reopening the migration page, each `staging` receipt is evaluated. If the destination exists and its hashes agree with the manifest, it can be marked complete. Otherwise it is marked failed for manual review. Recovery never overwrites existing files or deletes the source. An interrupted operation may leave staging-only remnants in `Documents/ImportMigrationStaging` until cleanup.

## Tests and limits

- [ ] Preview count/bytes and folder discovery
- [ ] Changed source, symlink, nested target and out-of-scope rejection
- [ ] Verified staged copy, complete receipt and preservation of the original
- [ ] Recover a verified post-commit interruption
- [ ] Mark missing results failed without modifying original data
- [ ] On-device large-tree, storage-full, app termination and file-protection tests

This is a development feature until CI and device acceptance pass. It does not implement WCMigrate's live-app transaction, database merging, background service or bidirectional exchange.

## Additional recovery hardening

Migration receipt files are **not treated as file-access authority**. Each pending receipt is revalidated before it can be marked complete: the destination must be a Nexa Imports directory, the generated name must exactly match its transaction UUID, every manifest path/hash must be well formed, the destination must not be a symbolic link, and the SHA-256 inventory must match. Corrupted paths and missing folders are marked failed without opening external data or replacing source files. Symlinked `.json` journal files are ignored. Host tests cover path traversal in the destination/output, a symlinked output, a missing destination, and linked metadata.

## Imported folder file-level Merge / Replace (Nexa-native)

`NexaImportCombine.swift` and `NexaImportCombineView.swift` extend the Nexa-only staging workspace with two **non-destructive output** modes. For `merge`, the result uses the source file for each matching relative path and otherwise retains target files. For `replace`, the result includes source files alone and excludes target-only files. Both create an independent `NexaMerged-<UUID>` or `NexaReplaced-<UUID>` under Nexa Imports; neither mutates or removes the source or target. Empty directories are not preserved, and source/target folders must be separate and non-nested.

The engine computes SHA-256 inventories before approval, rejects symlinks and special files, validates relative paths, denies file/directory conflicts, streams copies through an app-private staging directory, verifies each copied byte stream against the manifest, rechecks the originals, and moves the staged folder to an unused result path. A private journal records the exact expected hashes, and reopening confirms a pending commit only when the resulting directory exactly matches. Modified inputs cause a fail-closed refusal.

This is **Nexa-native snapshot transformation**, not the original WCMigrate `DirectMigrationService`, nor a WeChat database row merge, nor a live cross-app Replace/Convert/Merge. Cross-app authorization and device acceptance remain open release gates.
