# Graviti Implemented Architecture

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
│   │   │   └── MapKitPlaceSearchProvider
│   │   ├── VisionTextRecognizer
│   │   ├── LinkMetadataFetcher
│   │   └── ArtifactEnricher
│   ├── ArtifactImportCoordinator
│   │   ├── AppleMapsGuideParser
│   │   ├── GoogleMapsListImporter
│   │   └── GoogleSavedCSVParser
│   └── LibraryBackupService
├── DestinationOrbitBuilder and OrbitLayoutEngine
├── InterestProfileBuilder and DestinationFitEngine
├── FitGuideSearchEngine
└── App Group
    ├── SharedArtifactInbox JSON envelopes
    └── MediaAssets image files

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

Cancellation returns an active job to `pending`. A transient failure can retry on the next foreground pass. Existing successful enrichment is retained if a later refresh fails.

`unavailable` means the inputs were insufficient; it is different from a processing error.

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

- it has at least six saves
- at least two child clusters have at least two saves
- those meaningful children cover at least 65% of the country's saves
- the expansion fits the ten-label budget

Several cities in one useful region can group at state/province level. Unknown geography falls back without crashing.

Gravity is deterministic and based on explicit saved artifacts. Nodes rank by Gravity, then save count, then localized name, then stable ID.

`OrbitLayoutEngine` produces deterministic bounded positions with collision checks. Visual drift is a view modifier and is disabled by Reduce Motion.

`HomeInsightBuilder` derives a small ordered set of explanations from the visible destination nodes and their supporting Artifacts. It uses capture timestamps, canonical place IDs, geographic membership, and effective interests to detect recent momentum, meaningful child-area splits, recurring cross-destination interests, and quiet destinations. Thresholds require multiple saves or places before stronger language appears. If no rule has enough evidence, it returns a conservative field-leader summary.

Insights do not change Gravity or Fit. `HomeView` presents up to four in a carousel, focuses the associated destination, and links to the destination's saved evidence.

`DestinationReadinessBuilder` evaluates the Artifacts belonging to one geographic node. It counts canonical places once, measures category and interest breadth, recognizes subarea spread for countries and states/provinces, and includes recent distinct places as a small supporting signal. Gated thresholds prevent raw save volume or one category from producing a strong band. The builder returns an understandable readiness band, its evidence counts, and guidance for the next band.

Readiness is computed on demand for the selected destination and remains independent from Gravity and Fit.

## 12. Search

`LibrarySearchEngine` is pure and synchronous. It searches cached local fields and builds grouped results.

`SearchView` runs local matching immediately and debounces live MapKit search. Saving a result goes through `ArtifactLibrary`.

## 13. Fit recommendation architecture

`InterestProfileBuilder` reads each Artifact's effective interests and category. It records distinct places and geographic areas to distinguish independent evidence from duplicates.

`DestinationFitEngine` loads `Resources/Recommendation/destination-catalog-v1.json`, a reviewed, schema-versioned catalog with weighted destination strengths, a conservative data-confidence value, review date, and HTTPS provenance for every destination. The loader rejects unsupported schemas, duplicate destinations, invalid weights or confidence, and missing or insecure sources. It filters valid candidates by saved geography, region, exclusions, and avoided interests.

The engine calculates:

- weighted semantic affinity
- destination specificity
- match breadth
- explicit preference boost
- raw relevance
- evidence confidence from artifact, place, area, source-kind, and rich-text counts
- source-quality weighting that favors a user note or photo description over collection names and link metadata
- a modest discount when several signals come from one imported collection
- candidate knowledge confidence that caps combined confidence
- confidence-shrunk displayed Fit

The recommendation retains supporting Artifacts and destination sources so the detail screen can explain personal evidence and link to the reviewed knowledge provenance. Explore state does not mutate the explicit Library or Gravity.

## 14. Fit Guide architecture

`FitGuideSearchEngine` maps interests to specific and fallback MapKit terms.

`MapKitPlaceSearchProvider` first resolves and caches the destination region. Scoped requests:

- require the region
- request points of interest and physical features
- use destination-specific spans for broad regions
- retry server failure or throttling twice
- return an empty result for placemark-not-found

The engine deduplicates places between pattern sections and limits each section to six suggestions.

Guide persistence uses source collection titles on Artifacts rather than a separate guide table. This supports multiple guide memberships on one canonical place and automatically includes membership in backup/restore.

## 15. Backup architecture

`LibraryBackupService` serializes a schema-versioned archive with full Artifacts, optional image bytes, and a snapshot of Explore recommendation preferences. Schema version 2 adds region, preferred and avoided interests, saved destinations, and Not for Me exclusions while retaining version 1 decode compatibility.

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

## 18. Tests and packaging

The `gravitiTests` target contains deterministic unit and integration tests for domain services, repositories, import parsers, backup behavior, OCR, link safety, search, place resolution, Fit, catalog validation, motif generalization, Fit Guides, and layout.

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
