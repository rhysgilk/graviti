# Graviti Next Phase Plan

This plan turns the September 2026 product review into an implementation sequence. It preserves Graviti's local first model and keeps capture useful before background work finishes.

## Product rules

1. Save first. Identification, metadata, OCR, enrichment, indexing, and recommendations can finish later.
2. Keep the original source visible through every processing state.
3. Ask for user input only when automation cannot resolve uncertainty or when a personal preference would improve recommendations.
4. Explain generated results with evidence and confidence. Never overwrite a user correction.
5. Keep recommendation feedback local, inspectable, reversible, and separate from Gravity.
6. Every destructive single item action should offer Undo. Bulk deletion and backup replacement retain confirmation.

## Delivery sequence

### Phase A: Find, track, and recover

- [x] Add the place lifecycle: Saved, Curious, Shortlist, Visited, Loved, and Didn't fit.
- [x] Apply one lifecycle state to every Artifact attached to the canonical place.
- [x] Add Search scope chips for All, Places, Destinations, Interests, Guides, Notes, and Near me.
- [x] Add zero query Search content for recent searches, current destinations, strong interests, saved guides, and contextual suggestions.
- [x] Add a Library Import Inbox with processing, place found, needs help, retry, and completed views.
- [x] Persist import attempts independently so duplicates and failed attempts remain visible even when no Artifact is created.
- [x] Add real location authorization and distance ordering to Near me.

Acceptance: a shared item appears immediately; the user can leave the screen; its changing state is visible later; retries retain the original source; status changes survive relaunch and older records decode safely.

### Phase B: Library control

- [x] Add saved smart filters whose results update from Artifact data.
- [x] Ship starter filters: Unvisited scenery, Boston restaurants, National parks, Recently added, Needs description, Instagram imports, Places without notes, Visited and loved, and Matcha everywhere.
- [x] Add consistent sort menus to Places, Saves, Destinations, and Fit Guides. Only show sort choices supported by that surface.
- [x] Add a completeness score based on place match, description, category confidence, note, location consistency, and link preview.
- [x] Add a short Complete saves queue that prioritizes unresolved details while continuing automatic enrichment first.
- [x] Add Undo for single save deletion and place removal. Keep confirmation for bulk actions.

Acceptance: filters are derived rather than manually maintained; sort choice persists per surface; undo restores the complete Artifact and collection memberships; completeness never asks for data Graviti can fill itself.

### Phase C: Feedback and Fit learning

- [x] Define generic one tap questions from uncertain or high value evidence.
- [x] Always offer Yes, No, and Not sure; permit dismissal; rate limit prompts.
- [x] Record recommendation shown, opened, saved, dismissed, visited and loved, and visited and didn't fit events locally.
- [x] Add an inspectable feedback history and allow corrections.
- [ ] Use outcomes only after deterministic evaluation demonstrates better ranking and calibration. This is a deliberate post-MVP evaluation gate; current outcomes remain recorded locally and excluded from ranking.

Acceptance: feedback can be removed; Not sure has no negative meaning; prompts do not block navigation; Fit explanations identify which user evidence and destination knowledge changed the result.

### Phase D: Fit Guide as a planning object

- [x] Replace title encoded membership with durable guide and membership records.
- [x] Add rename, note, cover image, archive, duplicate, and share/export.
- [x] Add ordered memberships and removal from a guide without deleting the source Artifact.
- [x] Add a Shortlist section and category completion summary.
- [x] Migrate current `Destination Fit Guide · Interest` collection titles without losing membership.

Acceptance: source saves remain canonical; membership changes are reversible; duplicate creates a new guide identity; export contains a clean title, note, categories, shortlist, and map links.

### Phase E: Capture and onboarding

- [x] Replace the stock Share Extension presentation with a fast custom capture screen showing detected title/source, optional note, and immediate Save.
- [x] Add optional guide, priority, tag, and save without identification choices below the primary action.
- [x] Confirm with “Saved to Graviti” and “Finding the place and adding details…”.
- [x] Build interactive onboarding around one real first save.
- [x] Show the detected place and interests, then explain Gravity and Fit in context.
- [x] Add an optional sample library that can be removed as one unit.

Acceptance: the primary share path needs one tap after opening; optional choices never block saving; onboarding can be skipped; sample data is clearly labeled and removable.

### Phase F: Durable processing and scale

- [x] Persist jobs for metadata, OCR, place identification, enrichment, profile indexing, and thumbnails.
- [x] Store job version, attempt count, last error, next retry, dependencies, creation time, and completion time.
- [x] Add rebuildable indexes for place, destination, interest, guide, processing state, and search terms.
- [x] Version descriptions, categories, interests, place hints, and Fit evidence with producer and timestamp.
- [x] Formalize providers for place search, link metadata, social extraction, destination knowledge, recommendation ranking, and optional sync.
- [x] Prepare an optional CloudKit design with immutable IDs, user edit priority, membership merging, deletion tombstones, separate media transfer, and visible sync health.

Acceptance: force quitting cannot lose queued work; failed jobs use bounded backoff; indexes can be deleted and rebuilt; reprocessing never overwrites user authored fields; provider failures are testable without network access.

## Verification gates

- Unit tests for persistence compatibility, state classification, retry scheduling, filtering, sorting, guide migration, and feedback reversibility.
- Integration tests for Share Extension inbox delivery and background resumption.
- Oldest and newest supported simulator runs.
- Physical iPhone checks for Share Extension, MapKit, permissions, motion, Dynamic Type, VoiceOver, and relaunch recovery.
- Figma update after the implemented behavior is stable, followed by a code and design parity audit.

## Current implementation note

Phases A, B, D, E, and the local durability work in Phase F are implemented and physically verified. Phase C instrumentation is implemented; recommendation outcomes remain excluded from ranking until the post-MVP deterministic evaluation gate proves an improvement. Artifact processing jobs persist separately in the App Group container, interrupted work is recovered with bounded retry, and the Library index is disposable and rebuilt from canonical Artifact and Fit Guide membership data. See `OPTIONAL_CLOUDKIT_SYNC_DESIGN.md` for the future sync boundary and conflict policy.
