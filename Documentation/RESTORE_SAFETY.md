# Nexa 0.0.1 — Local backup/restore safety

**Scope:** Documents/Imports in the Nexa app container. This is not WCMigrate cross-app migration or an iOS sandbox exploit.

## Workflow

1. User selects one of Nexa's own backup folders and approves a destructive-action confirmation.
2. Validate that the selected backup is an immediate child of Nexa's backup root and is not a symlink.
3. Verify the original SHA-256 manifest and payload before any modification.
4. Copy the payload into a new RestoreStaging transaction folder and independently re-verify all file hashes.
5. Write an atomic restore journal in private Application Support.
6. Rename current Imports into a unique RestoreSafety snapshot and move the validated staging payload into Imports.
7. Re-verify the committed Imports tree and remove the journal; **retain the snapshot** of the prior files.

Source files: `Nexa/Sources/BackupManager.swift`, `Nexa/Sources/NexaBackupRestore.swift`, `Nexa/Sources/BackupView.swift`. Backups and snapshots are stored only in the user's own Nexa app container.

## Interrupted restore

- **Before journal creation:** no Imports change; staging data may remain and can be safely cleaned.
- **Journal exists, Imports still exists, no snapshot yet:** original remains intact; discard staging and journal.
- **Journal exists, snapshot exists, Imports missing:** move snapshot back to Imports.
- **Journal exists, snapshot and Imports exist:** verify Imports against the source backup. If it fails verification, retain the rejected tree separately and restore the previous snapshot.
- **Snapshot and Imports both missing:** report a recovery error, never pretend that empty files are valid.

Recovery runs when the Files or Backups screen initializes. If recovery fails, the app surfaces a file/backup error rather than silently declaring success. Normal completed restores retain older versions under `Application Support/Nexa/RestoreSafety`.

## Required tests before release

- [ ] Create a backup with nested directories and binary files; restore them; compare all SHA-256 hashes.
- [ ] Reject an altered payload or duplicate manifest path without crashing.
- [ ] Interrupt before moving Imports; restart and confirm no data loss.
- [ ] Interrupt after Imports moves into RestoreSafety but before the staged payload moves; restart and confirm rollback.
- [ ] Interrupt after moving the staged payload but before deleting the journal; restart and confirm integrity.
- [ ] Simulate disk-full and file-protection errors; confirm the recovery journal and original snapshot remain available.
- [ ] Verify the share sheet can export retained safety snapshots on a signed device.
- [ ] Check failures do not access any external app/private container.

**Not yet validated:** device kill/crash, concurrent tab edits, low-storage operations, and storage durability under all iOS protection classes. The implementation does not guarantee preservation against hardware failure or total filesystem corruption. It should be treated as a development feature until tests pass.
