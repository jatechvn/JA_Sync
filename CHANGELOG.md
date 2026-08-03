# Changelog

All notable changes to JA Sync are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.2.0] - 2026-08-03

### Added
- **Sync Profiles**: apply built-in presets (Backup Mirror, Bi-Directional, Archive) when adding a pair, save your own pair settings as a reusable custom profile, and manage profiles from a new "Manage Profiles" dialog.
- **Dry-Run Preview**: a new "Preview Sync" action shows exactly what a sync would copy, delete, or create — without touching any file, manifest, or deletion record.

### Fixed
- Deletion propagation was silently broken for any pair on a `manual` or timed schedule (15m/1h/12h/24h): deleting a file only synced correctly when the pair's schedule was `realtime`, because only the realtime watcher ever confirmed a deletion. The watcher now runs (recording-only) for every schedule, so manual and scheduled pairs correctly propagate deletions on their next sync while keeping the existing safeguard against unconfirmed external data loss.
- A race condition where a deletion recorded mid-sync by the watcher could be silently lost, because the end-of-sync save used a stale in-memory snapshot instead of reloading from disk first.
- Atomic file copy now moves the existing destination file aside (instead of deleting it outright) before renaming the new file into place, so a failed rename can no longer leave the destination missing.
- A single malformed/hand-edited entry in `config.json` no longer wipes out every other configured sync pair — invalid entries are now skipped individually.
- A sync request that arrived while a pair was already busy is no longer silently dropped; it's queued and runs automatically once the current sync finishes.
- `removePair` now also cleans up the pair's orphaned `deletions_<id>.json` file.

### Changed
- Migrated to `file_picker` v11, `window_manager` v0.5.2, and `tray_manager` v0.5.3 (newer Material `RadioGroup` API, `withValues(alpha:)` instead of deprecated `withOpacity`).
- Bumped version to 1.2.0+3.

## [1.1.0] - 2026-07-30

### Added
- Initial tracked release: two-way and one-way mirror sync, real-time and scheduled sync (manual/15m/1h/12h/24h), conflict resolution strategies (Newer Wins, Source Wins, Target Wins).
- Glassmorphism UI with Windows 10/11 adaptive Acrylic/Aero effects, light/dark/auto themes.
- Multi-language support (English, Chinese, Vietnamese).
- System tray integration, structured JSON sync history, JSON config import/export, bandwidth speed limiting.
