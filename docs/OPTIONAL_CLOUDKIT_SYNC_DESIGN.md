# Optional CloudKit Sync Design

Graviti remains fully useful as a local first app. This document defines a future, opt in CloudKit adapter without making CloudKit a prerequisite for the MVP.

## Product contract

- Local SwiftData remains the source used by the interface and processing pipeline.
- Sync is optional and can be disabled without losing local data.
- Original media and derived thumbnails transfer separately from small records.
- A visible sync health surface reports Local only, Syncing, Last synced, Paused, and Needs attention.
- Sign out, quota exhaustion, partial transfer, and provider outages never hide local saves.

## Record identities

Every synchronized object uses its existing immutable application ID as its CloudKit record name:

| Record | Identity | Merge behavior |
| --- | --- | --- |
| Artifact | `Artifact.id` | Field merge with user authored values taking priority |
| SavedPlace snapshot | stable provider ID or Graviti UUID | Latest reviewed snapshot; user correction wins |
| FitGuide | `FitGuideRecord.id` | Field merge |
| FitGuide membership | `guideID + artifactID` | Set union unless a newer tombstone exists |
| User preference | stable preference key | Latest explicit user edit |
| Original media | Artifact ID plus media revision | Asset transfer, independent of Artifact fields |
| Thumbnail | Artifact ID plus generator version | Rebuildable; lowest transfer priority |
| Tombstone | record type plus immutable ID | Retained until every known device acknowledges it |

Generated processing jobs and the derived Library index are local cache records. They are rebuilt or rescheduled after remote Artifact changes rather than synced.

## Conflict rules

1. A user authored summary, category, interest, note, tag, lifecycle state, priority, or place correction wins over generated content regardless of timestamp.
2. Two user edits use field level last writer wins with a device ID and modification timestamp. The losing value is retained in a short local conflict history until the next successful sync.
3. Collection and Fit Guide memberships merge as sets. Removing a membership writes a tombstone rather than replacing the remote membership array.
4. Artifact deletion writes a tombstone. A late device cannot resurrect the Artifact by uploading an older copy.
5. Generated fields compare producer and version first, then generation time. A lower version never replaces a higher version.
6. Original media transfers before derived thumbnails are considered complete. Missing thumbnails are regenerated locally.

## Incremental flow

1. Write the local SwiftData transaction.
2. Append an outbox mutation containing the immutable record ID and changed fields.
3. Let the interface continue immediately.
4. The sync adapter uploads small records in bounded batches.
5. Upload original media through a separate asset queue with resumable state.
6. Fetch server changes using a persisted change token.
7. Merge into SwiftData using the conflict rules above.
8. Reconcile the durable processing queue and rebuild the derived Library index.
9. Advance the change token only after the local transaction succeeds.

## Deletion retention

- Tombstones include record type, immutable ID, deletion time, originating device, and logical revision.
- Retain tombstones for at least 90 days and until all devices seen during that window have advanced beyond the deletion revision.
- A user initiated permanent account deletion uses CloudKit zone deletion only after local export and a destructive confirmation.

## Media policy

- Original images are encrypted CloudKit assets associated with the user's private database.
- Link preview images and generated thumbnails are caches and can be omitted when quota or bandwidth is constrained.
- Upload on Wi-Fi by default for large media; expose a cellular transfer preference.
- Verify size and checksum before replacing a local media reference.

## Health model

`LibrarySyncProviding` is the application boundary. Its health state supports:

- `localOnly`
- `idle(lastSuccessfulSync:)`
- `syncing`
- `needsAttention(message:)`

The future Data & Privacy screen should show the state, pending record and media counts, last successful sync, account availability, retry, and a link to export a backup. Raw CloudKit errors should be translated into an action the user can take.

## Rollout gates

1. Prove repeatable local backup and restore first.
2. Add a fake sync provider and deterministic conflict tests.
3. Test two device edits, offline edits, deletion races, membership races, quota failures, token expiration, and partial media transfer.
4. Run an opt in internal migration that uploads copies while leaving local records authoritative.
5. Compare record counts and checksums before enabling bidirectional deletion.
6. Provide a one tap return to Local only that does not delete local data.
