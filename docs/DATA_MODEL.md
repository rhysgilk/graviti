# Graviti Implemented Data Model

**Version:** 1.0

**Status:** Local MVP

**Storage:** SwiftData domain record plus App Group image files

**Backup schema:** Version 3 JSON, with version 1 and version 2 restore compatibility

This document describes persisted and derived values in the current app. Future normalized server entities are listed separately.

## 1. Current entity graph

```text
Artifact (UUID)
├── original source
├── optional local image key
├── optional SavedPlace (MapKit identity)
├── optional ArtifactLinkMetadata
├── optional ArtifactEnrichment
├── optional ArtifactUserDetails
├── collection membership titles
└── independent processing states

Derived at runtime
├── canonical Place groups
├── geographic destination nodes
├── InterestProfile
├── DestinationRecommendation
└── FitGuide sections

App preferences
├── onboarding and selected modes
├── Explore filters
├── saved destination IDs
└── excluded destination IDs
```

Only `StoredArtifact` is a SwiftData `@Model`. Places, enrichment, link metadata, and corrections are Codable values embedded in that record.

## 2. Artifact

`Artifact` is the original unit of ownership and backup. It is never replaced by a derived Experience or Place.

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | UUID | Stable local and backup identity |
| `kind` | `url`, `manual`, `photo` | Current source kind; screenshots use `photo` |
| `sourceURL` | String? | Original or synthesized stable source link |
| `sourceCollectionTitle` | String? | First Apple, Google, or Fit Guide membership |
| `additionalSourceCollectionTitles` | [String]? | Later distinct memberships |
| `originalText` | String? | Shared title, imported place name, or manual note body |
| `userNote` | String? | User-authored reason or photo description |
| `mediaKey` | String? | Validated filename in App Group media storage |
| `extractedText` | String? | On-device OCR output |
| `extractedTextSource` | `appleVision`? | OCR provenance |
| `textExtractionState` | state | Independent OCR lifecycle |
| `linkMetadata` | value? | Cached public page metadata |
| `linkMetadataState` | state | Independent web metadata lifecycle |
| `place` | `SavedPlace`? | Accepted canonical place |
| `enrichment` | value? | Generated description/category/interests |
| `enrichmentState` | state | Independent enrichment lifecycle |
| `userDetails` | value? | Explicit correction overriding enrichment |
| `processingState` | state | Place-resolution lifecycle |
| `capturedAt` | Date | Original capture time |

Collection titles are trimmed, compared case and diacritic insensitively for deduplication, and returned in stable primary-then-additional order.

## 3. Artifact kinds and capture mapping

| Input | Stored kind |
| --- | --- |
| ordinary URL | `url` |
| Apple or Google Maps link | `url` |
| imported CSV/list place | `url` |
| Fit Guide place | `url` |
| manual note or shared plain text | `manual` |
| photo or screenshot | `photo` |

There are no separate persisted `video`, `socialPost`, `mapsLink`, or `importRecord` enum cases in the MVP. Those concepts are represented through URL/source fields.

## 4. Processing states

### Place resolution

`ArtifactProcessingState`:

- `saved`
- `processing`
- `processed`
- `needsReview`
- `failed`

A processed collection wrapper may have no place. A needs-review Artifact stays visible.

### OCR, link metadata, and enrichment

Each subsystem has:

- `pending`
- `processing`
- `processed`
- `unavailable`
- `failed`

The states are independent. A photo can be safely saved while OCR is processing and enrichment is pending. A URL can have processed link metadata and no place.

Older SwiftData records infer missing state fields from available data for migration compatibility.

## 5. SavedPlace

`SavedPlace` is a Codable value:

| Field | Type |
| --- | --- |
| `id` | String |
| `name` | String |
| `latitude` | Double |
| `longitude` | Double |
| `locality` | String? |
| `region` | String? |
| `country` | String? |

For MapKit results, `id` is the stable MapKit identifier. Place groups are derived by this ID. The subtitle removes repeated geography labels and joins locality, region, and country.

Multiple Artifacts can reference the same SavedPlace. Removing a Place from the Library clears the place on every connected Artifact and marks each one for review; it does not delete those Artifacts.

## 6. Link metadata

`ArtifactLinkMetadata` contains:

- title
- summary
- site name
- optional bounded preview image bytes
- resolved URL
- fetched date

This is cached evidence. It never replaces `sourceURL` or user-authored text.

## 7. Generated enrichment

`ArtifactEnrichment` contains:

- optional summary
- optional `ExperienceCategory`
- interest strings
- provenance source
- confidence from 0 through 1
- generation date
- optional per-interest evidence records

Each `ArtifactInterestEvidence` record contains:

- the inferred interest
- one exact `ArtifactEvidenceSource`
- source-specific confidence from 0 through 1

Evidence sources distinguish user note or photo description, original saved text, detected image text, source collection name, cached link metadata, and Apple Maps place category. The field is optional so records and backups created before semantic provenance was added continue to decode.

Provenance values distinguish:

- MapKit
- saved text
- MapKit plus saved text
- detected image text
- MapKit plus detected text
- link metadata
- MapKit plus link metadata

`ExperienceCategory` currently supports:

- `foodAndDrink`
- `sceneryAndNature`
- `artsAndCulture`
- `activities`
- `shopping`
- `landmarks`
- `stay`
- `other`

## 8. User corrections and effective values

`ArtifactUserDetails` contains an optional summary, optional category, and interest array.

Effective fields follow one rule:

```text
if userDetails exists:
    use every userDetails value
else:
    use generated enrichment
```

An intentionally empty user interest array therefore overrides generated interests. User notes remain independent and are preserved during enrichment refresh.

Changing a place clears generated enrichment when the place identity changes, then schedules regeneration. User details remain intact.

## 9. Source collection membership

Collection membership is stored as strings on the Artifact.

Examples:

- `Matcha`
- `Vanessa and Rhys`
- `New York City Fit Guide · Museums`

One Artifact can belong to several Apple/Google collections and Fit Guides. Adding a new membership clears generated enrichment and schedules a refresh because the collection title may explain why the item was saved.

Fit Guide membership is recognized by an exact guide title or its `guide · pattern` prefix.

## 10. SwiftData record

`StoredArtifact` stores scalar fields directly and encodes nested values to JSON `Data`:

- additional collection titles
- link metadata
- place
- enrichment
- user details

The model uses a unique UUID attribute. Repository mapping validates enum raw values and throws for unknown required values.

This single-record design keeps capture and restore simple for the local MVP. It does not prevent future normalization behind the repository boundary.

## 11. Image storage

Image bytes are stored outside SwiftData in the App Group:

```text
group.com.rhysgilk.graviti/
└── MediaAssets/
    └── <artifact UUID>.<extension>
```

Rules:

- filename only; no directory traversal
- JPEG, PNG, HEIC/HEIF, WebP, or GIF
- maximum 50 MB
- atomic writes
- cleanup on failed Artifact save
- cleanup after successful Artifact deletion
- embedded into backup on export

## 12. Derived canonical views

### Place groups

Unique `SavedPlace.id` values create the Places Library. Repeated artifacts remain separate evidence.

### Geography and OrbitNode

`OrbitNode` is computed from placed Artifacts and contains:

- deterministic UUID
- geographic name
- level: country, state/province, city, district, or neighborhood
- Gravity
- save count

No destination aggregate table is persisted.

### InterestProfile

Computed from effective Artifact details:

`InterestPattern` contains name, supporting Artifacts, distinct place count, and distinct area names.

`CategoryPattern` contains category and save count.

### Recommendation

`DestinationRecommendation` is computed and contains:

- destination name and country
- displayed Fit
- raw relevance
- confidence band and percentage
- reviewed destination-knowledge confidence and sources
- matched interests
- supporting Artifacts
- explicit preference matches
- reviewed traits supported by visited-and-liked feedback

Recommendations are not persisted as Library records.

### FitGuide

`FitGuide` contains a `SavedDestination` and up to four interests. Its live result sections are transient MapKit results. Saved guide membership persists through Artifact collection titles.

### DestinationKnowledgeCatalog

The bundled `destination-catalog-v1.json` resource has a schema version, catalog version, and review date. Every `DestinationKnowledge` record contains:

- destination name, country, region, and search span
- a destination-data confidence value capped at 0.95
- weighted interest strengths from 0 through 1
- one or more reviewed HTTPS sources with title and review date

Catalog data is read-only at runtime. The loader rejects unsupported schemas, duplicate destinations, invalid ranges, empty strengths, and missing or insecure provenance. `DestinationRecommendation` carries the candidate's knowledge confidence and sources for explanation in Explore.

## 13. Preference storage outside SwiftData

The following values use `UserDefaults` through `@AppStorage`:

| Key | Purpose |
| --- | --- |
| `onboarding.completed` | first-run completion |
| `library.mode` | last Library mode |
| `orbit.resolutionMode` | automatic/country/state/city grouping |
| `explore.region` | recommendation region |
| `explore.preferredInterests` | pipe-delimited interest IDs |
| `explore.avoidedInterests` | pipe-delimited interest IDs |
| `explore.savedDestinations` | saved recommendation IDs |
| `explore.excludedDestinations` | Not for me IDs |
| `explore.visitedLikedDestinations` | IDs marked visited and liked |
| `explore.visitedNotFitDestinations` | IDs marked visited and did not fit |
| `debug.dogfoodArtifactIDs` | Debug-only fixture cleanup |

The Explore region, preferred and avoided interests, saved destinations, Not for Me exclusions, and both visited-feedback sets are included in backup schema version 3. Version 2 contains the same preference snapshot without visited feedback. Display and debug preferences remain device-specific. Artifact-based Fit Guide memberships are stored on Artifacts and are also backed up.

## 14. Backup schema

`LibraryBackupArchive`:

```text
schemaVersion: Int = 3
exportedAt: Date
artifacts: [LibraryBackupEntry]
preferences: LibraryBackupPreferences?
```

`LibraryBackupEntry`:

```text
artifact: Artifact
mediaData: Data?
mediaFileExtension: String?
```

`LibraryBackupPreferences`:

```text
recommendationRegion: String
preferredInterests: [String]
avoidedInterests: [String]
savedDestinationIDs: [String]
excludedDestinationIDs: [String]
visitedLikedDestinationIDs: [String]
visitedNotFitDestinationIDs: [String]
```

Dates encode as seconds since 1970. JSON is pretty printed and sorted. Preference values are bounded, trimmed, deduplicated, and sorted during restore. Version 1 archives decode without preferences and leave current Explore settings unchanged. Version 2 preference snapshots decode with empty visited-feedback sets.

Restore identity is `Artifact.id`. Existing IDs are skipped; place identity alone does not suppress restoration of a separate source Artifact.

## 15. Deletion semantics

### Delete a save

- repository batch delete validates all IDs
- removes Artifact records
- removes local image files
- recomputes derived Places, destinations, Gravity, patterns, and Fit from the remaining in-memory Library

### Remove a place

- preserves every source Artifact
- clears matching `place` values
- marks them `needsReview`
- reruns eligible enrichment

### Remove repeated-place association

The same place-removal semantics apply across all selected canonical place IDs.

## 16. Identity and duplicate rules

- Artifact identity: UUID
- Place identity: MapKit identifier string
- Apple guide item identity: stable Apple place identifier
- Google list import identity: normalized stable Google source URL; transient coordinate hints are excluded where needed
- Collection membership identity: case-insensitive title on the existing Artifact
- Backup duplicate identity: Artifact UUID
- Search result saved-state identity: SavedPlace ID

Original Artifacts are retained even when they refer to one canonical Place.

## 17. Future normalized model

Possible post-MVP entities include User, Experience, PlaceAlias, GeoArea, Interest, ExperienceInterest, RecommendationFeedback, DestinationAggregate, Guide, and GuideItem.

They are intentionally absent today. Introducing them should happen only when a concrete feature needs independent lifecycle, querying, sync, or sharing.

Migration requirements:

- preserve every Artifact UUID and original source
- map MapKit place IDs into aliases rather than discarding them
- preserve user corrections and provenance
- preserve all collection and Fit Guide memberships
- keep local backup import available
- avoid treating recommendation exposure as explicit user interest
- make future account sync opt-in
