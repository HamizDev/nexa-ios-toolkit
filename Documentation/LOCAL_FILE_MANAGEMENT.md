# Nexa imported-file operations — 0.0.1 development

The file manager only operates on copies **explicitly imported into Nexa's own Documents/Imports**. It does not enumerate, copy, delete, or rewrite files from another app's protected container.

## Implemented operations

- Create a folder, rename an existing item, duplicate a regular file or directory, and move an item between existing imported folders (now available in root and nested folder context menus).
- Root and nested folder UIs offer scoped search and file sharing.
- Delete moves to `Application Support/Nexa/FileTrash/<UUID>/Payload` with a JSON metadata record describing the original relative path.
- Recently Deleted lists recoverable items. Restore refuses to overwrite existing items, and checks the original imported path before re-creating intermediate folders.
- A separate, explicitly confirmed permanent-delete action removes a specific Trash item.

## Validation and failure handling

1. Existing and destination paths must stay inside Nexa's canonical Imports path; lexical path traversal and invalid component names are rejected.
2. Symbolic links (including links nested within a directory being duplicated, moved, renamed, or deleted) are rejected.
3. Target names must be nonempty, nonhidden, and no longer than 240 UTF-8 bytes. Names with slash, backslash, NUL, or colon are not accepted.
4. Duplicate names receive an unused "copy" suffix; rename/move/restore never silently overwrite a conflicting path.
5. Moving a directory into itself or its descendant is refused.
6. Trash items retain their original relative path. A malformed record or absent payload cannot be restored as a valid file.

**Limitations:** The initial implementation does not use coordinated file presenters, does not provide arbitrary external-provider editing, and does not guarantee behavior if the app is terminated during the brief interval between writing Trash metadata and moving the payload. In that crash state the original should remain in Imports; orphan metadata may remain. During large duplication operations the UI shows a busy state, but system storage exhaustion and file-protection errors need real-device tests. Recoverability is limited to the continued installation and storage health of Nexa.

## Acceptance tests

- [x] Disposable host tests created for nested paths, duplicate/rename collisions, sandbox traversal, nested symlinks, moves into descendants, trash, restore and permanent delete.
- [ ] These new tests pass in GitHub Actions on macOS.
- [ ] Build and launch on an iOS 26+ simulator.
- [ ] Confirm file-provider imports and local trash recovery on a provisioned iPhone.
- [ ] Verify low-storage and interruption behavior with large folder trees.

Upstream WQFiles ZIP compression, WCMigrate diagnostics and GestaltX offline plist editing remain separate features with their own documented limitations.

## Move picker and import hardening

Moving a file invokes `availableMoveFolders(for:limit:)` and presents existing folders inside Imports only. The original parent and a source directory's descendants are excluded, and the picker limits enumeration to 200 folders. The actual move API rechecks scope, source and destination before mutating anything. Newly imported content is inspected for symlinks, including inside a selected directory, before copying from a user-granted file-provider URL. This validation does not permit opening protected private app containers.
