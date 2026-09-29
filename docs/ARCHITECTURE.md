# Graviti Implemented Architecture

## Current architecture expansion

Search remains a combined local and MapKit surface, with view-level scopes over indexed `LibrarySearchEngine` results, real distance ordering, and persisted zero-query suggestions. The Import Inbox combines live Artifact states with independent ImportAttempt records, so duplicate and failed collection attempts remain inspectable even when they create no Artifact. Place lifecycle writes use the repository's atomic `updateMany` operation across every Artifact sharing a canonical place ID.

Artifacts remain authoritative. Background work is represented by independent persisted jobs; the search/grouping index is disposable; Fit Guide identity and membership are durable local records; and recommendation questions and outcomes remain inspectable local event histories. Provider protocols separate MapKit, metadata, social extraction, destination knowledge, ranking, and optional sync behavior from feature views.

See [Next Phase Plan](NEXT_PHASE_PLAN.md) for the completed delivery sequence and [Optional CloudKit Sync Design](OPTIONAL_CLOUDKIT_SYNC_DESIGN.md) for the future cross-device boundary.

**Version:** 1.0

**Status:** Local MVP implementation

**Platform:** Native iOS, SwiftUI, SwiftData

**Minimum OS:** iOS 18.0

This document describes the code that exists today. Future server and social directions are separated at the end.

## 1. Design rules

1. Persist the user's source before optional interpretation.
2. Keep the Library usable offline.
3. Put persistence and provider behavior behind interfaces.
4. Preserve original text, URL, image, and collection context.
5. Make place resolution and enrichment resumable and correctable.
6. Keep explicit Gravity evidence separate from recommendation state.
7. Treat accessibility, localization, privacy, and data recovery as core behavior.
8. Prefer deterministic, inspectable local algorithms for the MVP.

## 2. Runtime system

```text
SwiftUI App
├── ContentView and five feature tabs
├── ArtifactLibrary (@MainActor ObservableObject)
│   ├── ArtifactRepository
│   │   └── SwiftDataArtifactRepository
│   ├── ArtifactProcessingCoordinator
│   │   ├── MapPlaceResolver
│   │   │   ├── PlaceSearchProviding → MapKitPlaceSearchProvider
│   │   │   ├── MapLinkExpanding → URLSessionMapLinkExpander
│   │   │   └── SocialPlaceHintProviding
│   │   ├── VisionTextRecognizer
│   │   ├── LinkMetadataProviding → LinkMetadataFetcher
│   │   └── ArtifactEnricher
│   ├── ProcessingJobStore
│   │   └── App Group GravitiProcessing/jobs.json
│   ├── LibraryDerivedIndexStore
│   │   └── disposable cache GravitiDerived/library-index.json
│   ├── ArtifactImportCoordinator
│   │   ├── AppleMapsGuideParser
│   │   ├── GoogleMapsListImporter
│   │   └── GoogleSavedCSVParser
│   └── LibraryBackupService (schema v4)
├── DestinationOrbitBuilder and OrbitLayoutEngine
├── InterestProfileBuilder and DestinationFitEngine
├── DestinationKnowledgeProviding and RecommendationRankingProviding
├── FitGuideSearchEngine and durable FitGuideLibraryState
├── RecommendationFeedbackStore and RecommendationOutcomeStore
├── LibrarySyncProviding → LocalOnlyLibrarySyncProvider
├── AppDiagnosticsReport
└── App Group
    ├── SharedArtifactInbox JSON envelopes
    ├── MediaAssets image files
    └── durable processing state

Share Extension
└── validates one URL, text item, or image
    └── writes envelope/media into the App Group
```

There is no account, sync engine, remote database, Graviti API, telemetry service, or server job system in the local MVP.

## 3. Repository layout

```text
graviti/graviti/
├── App/
│   ├── GravitiApp.swift
│   ├── ContentView.swift
│   └── ArtifactLibrary.swift
├── Data/
│   ├── Local/StoredArtifact.swift
│   └── Repositories/
│       ├── SwiftDataArtifactRepository.swift
│       └── PreviewArtifactRepository.swift
├── DesignSystem/
├── Domain/
│   ├── Models/
│   ├── Repositories/ArtifactRepository.swift
│   └── Services/
├── Features/
│   ├── Onboarding/
│   ├── Home/
│   ├── Explore/
│   ├── Capture/
│   ├── Library/
│   └── Search/
├── Integrations/
│   ├── MapKit/
│   └── ShareExtensionSupport/
└── Resources/

graviti/GravitiShareExtension/
graviti/gravitiTests/
```

## 4. Composition and state

`GravitiApp` configures Sora appearance and opens a `ModelContainer` for `StoredArtifact`. Failure produces a visible Library unavailable screen.

`ContentView` owns one `ArtifactLibrary` and injects it into all tabs. It also manages onboarding, tab selection, shared-inbox import notices, and lifecycle resumption.

On initial task and every return to the active scene, the app:

1. loads queued Share Extension items
2. retries pending or interrupted Maps resolution
3. schedules pending OCR
4. schedules pending link metadata
5. resumes enrichment

Small UI preferences use `@AppStorage`:

- onboarding completion
- last Library mode
- Gravity resolution mode
- Explore region
- preferred and avoided interests
- saved destination IDs
- excluded destination IDs
- Debug fixture IDs

## 5. ArtifactLibrary facade

`ArtifactLibrary` is the single observable application facade. It owns the in-memory ordered Artifact array and coordinates repository writes.

Responsibilities include:

- load and save
- update generated and user-edited fields
- assign and remove place matches
- atomic bulk save deletion
- bulk place-association removal
- image storage cleanup
- backup and restore
- Share Extension inbox ingestion
- CSV, `.webloc`, Apple guide, and Google list import
- collection-title backfill and refresh
- background processing state transitions

The UI does not manipulate SwiftData directly.

## 6. Persistence

`ArtifactRepository` defines load, save, batch save, update, batch update, delete, and batch delete behavior.

`SwiftDataArtifactRepository` maps the domain `Artifact` to `StoredArtifact`. Structured nested values are encoded as JSON blobs so the domain remains Codable and backup-compatible.

Batch update and delete operations validate all requested IDs before mutating and save once. This provides atomic behavior for bulk actions.

Image bytes live in the App Group's `MediaAssets` directory. Artifacts store only a validated filename key. Writes are atomic; deletion removes the corresponding file after the repository delete succeeds.

Legacy records with no later processing-state fields are covered by a focused compatibility test for the fallback rules in `StoredArtifact.asArtifact()`. Backup schema compatibility is tested separately for versions 1 through 4. No persisted `StoredArtifact` fields have changed since the `v1.0-local-mvp` baseline; if they do, a disk-backed schema fixture must be added with that change.

## 7. Capture and processing state machine

Capture persists synchronously from the user's perspective. Optional work begins afterward.

### Place resolution

```text
saved or failed
  → processing
  → processed(place)
  → processed(collection)
  → needsReview
  → failed
```

Map links are eligible. Collection links are recognized separately so they are not misclassified as a single place.

### OCR, link metadata, and enrichment

Each uses:

```text
pending → processing → processed
                     → unavailable
                     → failed
```

Cancellation returns an active job to `pending`. Map place work runs through one paced queue so large imports do not launch simultaneous provider requests. Transient failures are retained in a coalesced in-memory retry set and retried with increasing delays, in addition to the next foreground pass. If an enrichment result becomes stale because its place, text, OCR, or link metadata changed while it was running, the coordinator resets that artifact to `pending` and immediately schedules a fresh pass. Existing successful enrichment is retained if a later refresh fails.

`unavailable` means the inputs were insufficient; it is different from a processing error.

`ProcessingJobStore` persists the durable execution ledger separately from SwiftData. Every eligible Artifact is reconciled against six job specifications: link metadata, text extraction, place identification, enrichment, profile indexing, and thumbnail availability. Jobs retain version, status, attempt count, last error, next retry, dependencies, creation/start/completion/update times, and optional output provenance. Relaunch converts orphaned `running` jobs to `waitingForRetry`; bounded exponential delays stop after six attempts. Explicit retry resets the attempt budget. The store is a value type owned by `ArtifactLibrary`, avoiding actor-isolated reference destruction on the iOS 18 runtime.

The persisted ledger coordinates recovery and visibility. Artifacts remain the result authority, so deleting the ledger cannot delete a save and reconciliation can recreate every required job.

The UI mirrors these states without hiding persisted content. Saved Item detail exposes place and link-metadata retry actions, collection imports retain their wrapper Artifact and report partial counts, and Fit Guide loading leaves persisted guide membership visible. `ArtifactLibrary.retryLinkMetadata` resets only the metadata state before running the bounded fetch again.

## 8. Place resolution

`MapPlaceResolver` expands supported short links with a bounded HEAD request. It extracts name, query, and coordinate hints, then asks `PlaceSearchProviding` for candidates.

Automatic acceptance requires:

- one unique exact normalized name match; or
- compatible token overlap plus a coordinate match within 250 meters
- enough distance separation from the next candidate

Anything ambiguous becomes `needsReview`.

`MapItemPlaceAdapter` converts MapKit results into provider-stable `SavedPlace` values. The MapKit identifier is the canonical local place ID for this MVP.

## 9. Import architecture

`ArtifactImportCoordinator` creates side-effect-free plans against existing Artifacts. `ArtifactLibrary` applies the plan through batch repository calls.

### CSV

The parser handles RFC-style quoting and creates map-link artifacts. Stable source URL identity prevents repeat imports.

### Apple Maps guides

The importer retrieves the public guide payload, decodes its protobuf-like wire representation, extracts a title and place IDs, requests each MapKit item, and builds placed Artifacts.

### Google Maps lists

The importer retrieves a public shared-list page, finds a same-provider HTTPS data endpoint with an exact allowed path, parses the bounded JSON payload, and retains names, notes, addresses, coordinates, and feature identifiers.

Collection import planning can:

- insert new records
- count duplicates and skipped records
- backfill collection membership
- refresh unresolved older Google records with better hints
- preserve user-matched places
- avoid duplicate collection wrapper artifacts

## 10. OCR, web metadata, and enrichment

`VisionTextRecognizer` performs on-device recognition against the stored image file.

`LinkMetadataFetcher` uses an ephemeral URL session and follows safe public HTTP(S) redirects. It blocks private, loopback, link-local, and otherwise unsafe targets and bounds response and image sizes.

`ArtifactEnricher` is deterministic. It evaluates each semantic input separately, with user notes and photo descriptions weighted above original text, OCR, collection names, link metadata, and provider metadata. It generates a summary, broad category, fine-grained interest tags, provenance, confidence, and timestamp. Per-interest evidence retains its exact source and confidence. User details remain in a separate value and override generated values.

The vocabulary keeps broad tags used by the recommendation catalog while adding compatible finer motifs, including forest or desert hiking, rocky coast, historic or modern architecture, and specific dishes. This lets existing Fit behavior continue while preserving more meaning for later recommendation expansion.

## 11. Geography and Gravity

`DestinationOrbitBuilder` derives nodes directly from placed Artifacts. It can group by country, state/province, or city.

Automatic resolution starts broad and expands a country only when:

- four or more saves already span at least two useful child areas, or
- it has at least six saves, at least two child clusters have two saves each, and those meaningful children cover at least 65% of the country's saves
- the expansion fits the ten-label budget

Several cities in one useful region can group at state/province level. Unknown geography falls back without crashing.

MapKit geography is normalized at the adapter boundary. On iOS 26, `regionName` represents the country, so Graviti derives the state or province from `cityWithContext` and expands US and Canadian abbreviations to full names. On launch, a paced background repair re-resolves older places that have a city and country but no state/province, then persists the repaired place across every matching save.

Gravity is deterministic and based on explicit saved artifacts. Nodes rank by Gravity, then save count, then localized name, then stable ID.

`OrbitLayoutEngine` produces deterministic bounded positions with collision checks. Visual drift is a view modifier and is disabled by Reduce Motion.

`HomeInsightBuilder` derives a small ordered set of explanations from the visible destination nodes and their supporting Artifacts. It uses capture timestamps, canonical place IDs, geographic membership, and effective interests to detect recent momentum, meaningful child-area splits, recurring cross-destination interests, and quiet destinations. Thresholds require multiple saves or places before stronger language appears. If no rule has enough evidence, it returns a conservative field-leader summary.

Insights do not change Gravity or Fit. `HomeView` presents up to four in a carousel, focuses the associated destination, and links to the destination's saved evidence.

`DestinationReadinessBuilder` evaluates the Artifacts belonging to one geographic node. It counts canonical places once, measures category and interest breadth, recognizes subarea spread for countries and states/provinces, and includes recent distinct places as a small supporting signal. Gated thresholds prevent raw save volume or one category from producing a strong band. The builder returns an understandable readiness band, its evidence counts, and guidance for the next band.

Readiness is computed on demand for the selected destination and remains independent from Gravity and Fit.

### About and diagnostics

`HomeView` presents `AboutGravitiView` from its gear button. The sheet contains the product purpose, local-data and backup promises, network boundaries, app version, the public support route, and the privacy-policy link.

`AppDiagnosticsReport` is a pure value builder. It accepts the in-memory Artifact collection plus app and device metadata and emits aggregate counts for support. It never serializes Artifact names, text, URLs, media, coordinates, or identifiers. Clipboard access occurs only in `AboutGravitiView` after the user taps **Copy diagnostics**; no diagnostics transport or telemetry service exists.

## 12. Search

`LibrarySearchEngine` is pure and synchronous. It searches cached local fields and builds grouped results. `LibraryDerivedIndex` maintains rebuildable mappings for place → Artifacts, destination → places, interest → Artifacts, guide → Artifacts, processing state → Artifacts, and normalized search tokens → Artifact IDs. A deterministic source fingerprint identifies the canonical inputs used to build it.

`LibraryDerivedIndexStore` writes the index to the caches container. Decode failure, schema mismatch, or deletion falls back to an empty index and a rebuild from Artifacts plus durable Fit Guide memberships. Search uses index candidates when available and retains its full matching rules as the final check.

`SearchView` runs local matching immediately and debounces live MapKit search. Scope chips filter local groups; Near me uses `SearchLocationManager` and `CLLocation` distance rather than text approximation. Saving a result goes through `ArtifactLibrary`.

## 12.1 Provider boundaries

The following protocols isolate replaceable or failure-prone dependencies:

- `PlaceSearchProviding`
- `LinkMetadataProviding`
- `SocialPlaceHintProviding`
- `DestinationKnowledgeProviding`
- `RecommendationRankingProviding`
- `LibrarySyncProviding`

The local MVP uses MapKit, the bounded URL metadata fetcher, deterministic social-caption extraction, the reviewed bundled destination catalog, deterministic ranking engines, and `LocalOnlyLibrarySyncProvider`. Feature views consume the provider interfaces and can receive controlled test doubles without network access. The sync provider currently reports local-only health; it performs no cloud transfer.

## 13. Fit recommendation architecture

`InterestProfileBuilder` reads each Artifact's effective interests and category. It records distinct places and geographic areas to distinguish independent evidence from duplicates.

`DestinationFitEngine` loads `Resources/Recommendation/destination-catalog-v1.json`, a reviewed, schema-versioned catalog with weighted destination strengths, a conservative data-confidence value, review date, and HTTPS provenance for every destination. The loader rejects unsupported schemas, duplicate destinations, invalid weights or confidence, and missing or insecure sources. It filters valid candidates by saved geography, region, exclusions, and avoided interests.

The engine calculates:

- weighted semantic affinity
- destination specificity
- match breadth
- explicit preference boost
- conservative reviewed-strength signals from destinations marked visited and liked
- exclusion of every destination marked visited, regardless of outcome
- raw relevance
- evidence confidence from artifact, place, area, source-kind, and rich-text counts
- source-quality weighting that favors a user note or photo description over collection names and link metadata
- a modest discount when several signals come from one imported collection
- candidate knowledge confidence that caps combined confidence
- confidence-shrunk displayed Fit

The recommendation retains supporting Artifacts, visited-liked matches, and destination sources so the detail screen can explain personal evidence and link to the reviewed knowledge provenance. Visited feedback is stored in dedicated Explore preference sets. It does not create Artifacts, alter Gravity, or rewrite explicit interests. A not-fit visit contributes no positive interest signal; a liked visit contributes a capped secondary signal and a modest confidence contribution.

`RecommendationFeedbackStore` retains one-tap Yes, No, and Not sure responses and supports correction or deletion. `RecommendationPromptStore` rate limits a question for seven days and records permanent dismissal. `RecommendationOutcomeStore` records shown, opened, destination saved, suggested place saved, dismissed, visited-loved, and visited-did-not-fit events. Daily impression deduplication bounds noise, histories have fixed maximum sizes, and Fit evidence events carry producer/version provenance. These events remain local and inspectable. They are deliberately excluded from ranking until the deterministic evaluation gate demonstrates better relevance and calibration.

## 14. Fit Guide architecture

`FitGuideSearchEngine` maps interests to specific and fallback MapKit terms.

`MapKitPlaceSearchProvider` first resolves and caches the destination region. Scoped requests:

- require the region
- request points of interest and physical features
- use destination-specific spans for broad regions
- retry server failure or throttling twice
- return an empty result for placemark-not-found

The engine deduplicates places between pattern sections and limits each section to six suggestions.

`FitGuideLibraryState` is a versioned local aggregate of `FitGuideRecord` and `FitGuideMembership`. A membership points from a stable guide ID to an Artifact ID and optional interest section. Legacy title-encoded memberships migrate without deleting their source context. Separate `FitGuideMetadata` stores the user title, note, archive state, cover Artifact, shortlist place IDs, ordered Artifact IDs, and update time.

This design supports multiple guide memberships on one canonical Artifact, removal from one guide without deleting the save, independent duplicated guides, and retrieval after a destination leaves the recommendation ranking. `FitGuideLibraryView` filters locally across guide metadata, destination, country, interests, and saved place names.

## 15. Backup architecture

`LibraryBackupService` serializes a schema-versioned archive with full Artifacts, optional image bytes, and a snapshot of durable local app state. Schema version 2 added region, preferred and avoided interests, saved destinations, and Not for Me exclusions. Schema version 3 added visited-and-liked and visited-and-did-not-fit destination IDs. Schema version 4 adds Fit Guide records and metadata, recommendation feedback/outcomes/prompt history, ImportAttempt records, and saved Library filters. Versions 1 through 3 remain decode compatible.

Decode validates total size, schema, count, unique IDs, media consistency, preference bounds, and the recommendation region before returning a normalized archive. Restore skips existing Artifact IDs, applies preferences only when the archive contains them, and cleans up newly written media if repository insertion fails.

## 16. Accessibility, localization, and resources

Customer-facing text uses String Catalogs. Spanish coverage exists in the app and Share Extension. Sora Regular and SemiBold are registered in the product; other font source files and Debug CSV fixtures are excluded from Release packaging.

The Gravity Field exposes a logical accessibility order, combined labels, persisted resolution control, Reduce Motion behavior, and conventional Library/Search access.

## 17. Security and privacy boundaries

- no Graviti backend or account
- no analytics, ads, or crash SDK
- local SwiftData and App Group files are authoritative
- privacy manifests declare no collected data and no tracking
- UserDefaults required-reason API declaration is present for the app
- public-link fetches use scheme, host, redirect, response, and size validation
- file imports use security-scoped access
- media keys reject path traversal
- backups are user-initiated exports
- diagnostics are aggregate-only, remain local, and reach the clipboard only after an explicit action

## 18. Tests and packaging

The `gravitiTests` target contains deterministic unit and integration tests for domain services, repositories, import parsers, backup behavior, aggregate-only diagnostics, OCR, link safety, search, place resolution, Fit, catalog validation, motif generalization, Fit Guides, and layout.

Release scripts:

- `scripts/verify-release-archive.sh` validates identifiers, versions, minimum OS, privacy manifests, encryption declaration, fonts, Debug fixture exclusion, signatures, and App Group entitlements.
- `scripts/export-testflight.sh` prepares an App Store Connect export only when valid distribution signing is available. It does not upload.

## 19. Future architecture direction

Potential post-MVP work includes opt-in account sync, a larger reviewed destination knowledge service, server-assisted or on-device semantic enrichment, social recommendation signals, collaboration, and cross-device recovery.

Any future sync design must:

- migrate the existing local Library safely
- remain opt-in
- preserve original sources and user corrections
- keep explicit Gravity separate from recommendation exposure
- provide deletion and export controls
- document new collection, telemetry, and network behavior before release

Microservices, event streaming, generalized agent chat, and premature multi-platform abstractions remain unnecessary until product requirements justify them.
