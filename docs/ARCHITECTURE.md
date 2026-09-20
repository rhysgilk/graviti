# Graviti — Architecture

**Version:** 0.1  
**Status:** Proposed MVP architecture  
**Primary client:** Native iOS / SwiftUI

---

## 1. Architecture Principles

1. Capture must be fast; network/model work never blocks saving.
2. The user's own library is offline-first.
3. UI does not talk directly to persistence or HTTP clients.
4. External providers live behind adapters.
5. Original source data is preserved.
6. Machine inference is asynchronous, confidence-aware, and correctable.
7. Accessibility and localization are architecture concerns, not polish.
8. Recommendation-derived data is separated from explicit user intent.
9. Start simple; add distributed complexity only when actual load requires it.
10. The MVP should remain debuggable by one developer.

Artifact capture and enrichment have separate persisted lifecycles. Capturing the original source completes first. Description, category, interests, and other derived details then move through `pending`, `processing`, `processed`, `unavailable`, or `failed` without hiding or invalidating the saved Artifact. The app resumes interrupted and failed enrichment when it next becomes active. This contract stays the same when the local enricher is replaced or supplemented by backend jobs.

## 2. High-Level System

```text
iOS App
 ├── SwiftUI Presentation
 ├── Feature / Domain Layer
 ├── Repository Interfaces
 ├── SwiftData Local Store
 ├── Sync Engine
 ├── Share Extension
 ├── Map / Place Provider Adapter
 └── Ingestion Client
          │
          ▼
Backend API / Supabase
 ├── Auth
 ├── PostgreSQL
 ├── Object Storage
 ├── Ingestion Jobs
 ├── Place Resolution
 ├── Classification / Interest Extraction
 ├── Gravity Aggregation
 └── Recommendation Queries
```

## 3. Recommended iOS Project Structure

```text
Graviti/
├── App/
│   ├── GravitiApp.swift
│   ├── AppEnvironment.swift
│   ├── AppRouter.swift
│   └── DependencyContainer.swift
│
├── DesignSystem/
│   ├── ColorTokens.swift
│   ├── Typography.swift
│   ├── Spacing.swift
│   ├── Radius.swift
│   ├── Motion.swift
│   ├── Components/
│   └── Accessibility/
│
├── Domain/
│   ├── Models/
│   ├── Repositories/
│   ├── Services/
│   └── UseCases/
│
├── Data/
│   ├── Local/
│   │   ├── SwiftData/
│   │   └── Mappers/
│   ├── Remote/
│   │   ├── API/
│   │   ├── DTOs/
│   │   └── Auth/
│   ├── Repositories/
│   └── Sync/
│
├── Features/
│   ├── Authentication/
│   ├── Onboarding/
│   ├── GravityField/
│   ├── Capture/
│   ├── Library/
│   ├── Search/
│   ├── Destination/
│   ├── SavedItem/
│   ├── Review/
│   └── Explore/
│
├── Integrations/
│   ├── MapKit/
│   ├── Photos/
│   ├── Vision/
│   └── ShareExtensionSupport/
│
├── Resources/
│   ├── Localization/
│   ├── Assets.xcassets
│   └── PreviewData/
│
└── Tests/
    ├── Unit/
    ├── Integration/
    ├── Accessibility/
    └── Snapshot/
```

Separate target:

```text
GravitiShareExtension/
```

## 4. Layer Responsibilities

### Presentation

SwiftUI views and presentation models handle rendering, interaction, navigation state, accessibility, animation, and loading/error presentation.

They do not own SQL, HTTP, provider details, scoring logic, or social-link parsing.

### Domain

Pure application concepts and policies:

- Artifact
- Experience
- Place
- GeoArea
- GravityScore
- OrbitResolution
- Recommendation
- use cases such as CaptureArtifact and ResolveOrbit

### Data

Implements repositories and handles:

- SwiftData persistence
- backend API
- sync
- DTO mapping
- conflict handling
- caching

### Integrations

Provider-specific adapters such as MapKit, Vision, Photos, and Share Extension inbox handling.

## 5. Repository Interfaces

Illustrative contracts:

```swift
protocol ArtifactRepository {
    func save(_ artifact: Artifact) async throws
    func artifact(id: Artifact.ID) async throws -> Artifact?
    func artifacts(filter: ArtifactFilter) async throws -> [Artifact]
}

protocol PlaceRepository {
    func place(id: Place.ID) async throws -> Place?
    func search(query: String) async throws -> [Place]
    func resolve(alias: PlaceAlias) async throws -> Place?
}

protocol GeoAreaRepository {
    func ancestors(of areaID: GeoArea.ID) async throws -> [GeoArea]
    func children(of areaID: GeoArea.ID) async throws -> [GeoArea]
}

protocol DestinationRepository {
    func aggregates() async throws -> [DestinationAggregate]
}

protocol RecommendationRepository {
    func recommendations(for request: ExploreRequest) async throws -> [DestinationRecommendation]
}
```

Views should not know whether data comes from SwiftData, network, or both.

## 6. Local-First Repository Pattern

```text
SwiftUI
  ↓
Repository
  ↓
Local SwiftData store  ← immediate read/write
  ↓
Sync Queue
  ↓
Backend
```

Capture writes locally first. The user sees success before server processing.

## 7. Capture Flow

```text
User selects photo/link/place
        ↓
Create local Artifact UUID
        ↓
Persist immediately
        ↓
UI confirms "Saved"
        ↓
Queue sync
        ↓
Upload source/media if required
        ↓
Start backend processing
        ↓
Receive processing result
        ↓
Update local Experience / Place / Interests
        ↓
Update affected Destination aggregates
```

## 8. Share Extension Flow

The Share Extension is intentionally small.

It should:

1. accept supported content types
2. capture source URL/media/optional note
3. write a lightweight payload into an App Group container
4. confirm save immediately
5. exit

Avoid expensive model calls, full synchronization, complex place resolution, or blocking uploads inside the extension.

Conceptual payload:

```text
SharedArtifactEnvelope
- local_id
- content_type
- source_url
- app_group_media_url
- note
- captured_at
```

## 9. Ingestion Pipeline

```text
Artifact saved
      ↓
Source normalization
      ↓
Text / metadata extraction
      ↓
Experience candidate extraction
      ↓
Place candidate extraction
      ↓
Place resolution
      ↓
Category classification
      ↓
Interest extraction
      ↓
Duplicate detection
      ↓
Confidence evaluation
      ↓
Destination aggregate update
```

Every stage should be retryable/idempotent where practical.

## 10. Confidence Handling

Suggested initial policy:

```text
high confidence:
    apply automatically

medium confidence:
    apply provisionally and expose easy correction

low confidence:
    mark Needs Review
    do not allow uncertain geography to materially affect Gravity
```

Tune thresholds with real dogfood data.

## 11. Provider Abstractions

Domain code must not depend directly on MapKit IDs.

```swift
protocol PlaceSearchProvider {
    func search(_ query: PlaceSearchQuery) async throws -> [PlaceCandidate]
}

protocol GeocodingProvider {
    func resolve(_ input: GeocodingInput) async throws -> GeoCandidate
}
```

Initial implementation may use MapKit.

## 12. SwiftData Strategy

SwiftData acts as:

- local source for responsive UI
- offline library
- pending mutation store
- cache of server-derived results

It should not dictate the backend schema.

Use explicit mappers if domain models and persistence models need to diverge.

## 13. Backend Direction

The MVP beta is local only. SwiftData and the versioned Library backup are authoritative for user-owned data. No account or backend is required for capture, organization, recommendation, or restore.

If post-MVP sync is added, a Supabase-style backend remains a reasonable option:

- PostgreSQL
- authentication
- object storage
- row-level security
- server functions/jobs where needed

The backend becomes authoritative only for users who explicitly enable a future synchronized account, after their local library migrates successfully.

## 14. Backend Modules

Conceptual modules:

```text
auth
artifacts
media
experiences
places
geo
interests
processing
gravity
recommendations
imports
```

Keep this a modular monolith/serverless-function set for MVP rather than separate microservices.

## 15. Object Storage

Example paths:

```text
users/{user_id}/artifacts/{artifact_id}/original
users/{user_id}/artifacts/{artifact_id}/thumbnail
```

Consider privacy, lifecycle rules, thumbnails, duplicate hashing, and deletion.

## 16. Geography Service

Responsibilities:

- canonical GeoArea lookup
- parent/child traversal
- localized names
- place-to-area mapping
- aggregate propagation

A Place references its most specific useful known GeoArea. Gravity aggregates propagate upward to ancestors.

## 17. Adaptive Orbit Resolution Service

Input:

```text
DestinationAggregate tree
user resolution preference
screen label budget
current navigation context
```

Output:

```text
[OrbitNode]
```

Example:

```text
[
  Tokyo(city),
  Kyoto(city),
  Uji(city),
  California(state),
  Montreal(city),
  Portugal(country)
]
```

Potential approach:

1. start from broad high-level nodes
2. score whether splitting a node increases information value
3. split highest-value nodes while label count ≤ 10 and minimum legibility is maintained
4. return stable ordering/layout seeds

The algorithm should be deterministic for identical inputs.

## 18. Gravity Field Layout Engine

Requirements:

- deterministic initial layout seed
- maximum ~10 labeled nodes
- optional background unlabeled nodes
- collision avoidance
- gentle drift
- bounded motion
- no node escaping tappable space
- stable selected-node transitions
- Reduce Motion fallback

Potential implementation:

- custom SwiftUI layout + lightweight physics
- Canvas where useful for background visuals
- TimelineView only if performance/battery testing justifies it

Avoid constant high-frequency animation.

## 19. Planet Size Mapping

Do not map Gravity linearly to diameter.

Initial bounds:

```text
minimum labeled diameter ≈ 58pt
maximum labeled diameter ≈ 170–180pt
```

A square-root-like mapping is a reasonable starting point.

## 20. Navigation

MVP primary tabs:

```text
Home
Explore
Save (+)
Library
Search
```

Profile/settings live behind a secondary affordance.

Map is a Library mode, not a primary tab.

## 21. Brand Motion

Use the custom `graviti` dot animation only on brand-focused screens.

Implementation should respect:

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion
```

If motion is allowed:

- alternate dot scale values
- ~1.8 seconds
- easeInOut
- repeatForever(autoreverses: true)

If Reduce Motion is enabled, keep static asymmetric dots.

## 22. Media UI

Home remains abstract.

Media-heavy screens include:

- Destination saved-media view
- Saved Artifact detail
- Saves Library tab

Support:

- photo
- screenshot
- link preview
- Reel/video thumbnail
- guide/source card

Artifact remains first-class even after place extraction.

## 23. Search

Search should query:

1. local user library immediately
2. external/world places as network results arrive
3. destinations/GeoAreas
4. Interests where useful

Results distinguish already-saved content from external results.

## 24. Recommendation Architecture

Start deterministic.

Inputs:

```text
UserInterestProfile
ExploreRequest hard constraints
ExploreRequest preferences
negative preferences
destination interest/category aggregates
```

Do not start with a generalized AI travel chat system.

AI may assist with messy Artifact understanding without owning the recommendation stack.

## 25. Internationalization

Use localization infrastructure from day one:

- String Catalogs / localized strings
- no hardcoded customer-facing strings
- leading/trailing semantics
- locale-aware formatting
- localized/native GeoArea names
- script-appropriate font fallback
- no assumption of city/state/country hierarchy

Test English, German expansion, Chinese/Japanese, and an RTL language.

## 26. Accessibility

Support:

- Dynamic Type
- VoiceOver
- Reduce Motion
- Increase Contrast
- Differentiation Without Color
- practical 44×44pt interactive targets

Gravity Field VoiceOver should expose logical Gravity order rather than arbitrary visual coordinate order.

Example:

```text
"Tokyo. Gravity 86. City. 27 saved experiences."
```

## 27. Observability

Track non-sensitive operational events such as:

- capture succeeded/failed
- processing-stage timing
- resolution confidence
- review correction rate
- duplicate merge accuracy
- orbit-resolution output size
- recommendation save/dismiss actions

Avoid logging private source content by default.

## 28. Testing Strategy

### Unit

- Gravity calculation
- Orbit resolution
- duplicate matching rules
- category mapping
- sync state machine

### Integration

- Share Extension inbox → app import
- local save → remote sync
- ingestion result → local update
- provider alias resolution

### UI

- primary capture loop
- low-confidence review
- Gravity Field selection/zoom
- Library modes

### Accessibility

- VoiceOver labels/order
- Dynamic Type
- Reduce Motion
- contrast

### Localization

Snapshot/stress tests for long strings, CJK, and RTL.

## 29. Initial Technical Spikes

Before full UI implementation, prove these risks:

### Spike A — Share Extension
Can a user share a URL/photo from another app, close immediately, and reliably find it in Graviti later?

### Spike B — Place Resolution
Can MapKit/provider search reliably turn messy extracted names into canonical Places?

### Spike C — Artifact Extraction
Can screenshots/URLs yield useful Experience + Place candidates without unacceptable failure rates?

### Spike D — Gravity Field
Can 10 labeled planets move smoothly, remain stable, support accessibility, and avoid excessive battery use?

## 30. First Vertical Slice

The first meaningful milestone:

> **Share an artifact from another app → save instantly → process asynchronously → resolve Experience/Place → organize into GeoArea → update Gravity → see result in Library and Gravity Field.**

Build this before a sophisticated recommendation engine.

## 31. Suggested Build Order

1. Project scaffolding + design tokens
2. Domain models / repository interfaces
3. SwiftData local persistence
4. Authentication shell
5. Share Extension spike
6. In-app Capture
7. Artifact processing-state UI
8. Place search/resolution
9. Library
10. Destination aggregates
11. Gravity v1
12. Adaptive orbit resolution
13. Gravity Field
14. Review/correction flow
15. Search
16. Saved media/detail
17. Explore + Fit
18. Import workflow
19. Accessibility/localization hardening
20. TestFlight dogfood

## 32. Architecture Non-goals

For MVP, do not introduce:

- microservices
- Kafka/event streaming
- distributed caches
- custom ML infrastructure
- overly generic plugin frameworks
- premature multi-platform abstractions
- complex CQRS/event sourcing

The interesting complexity belongs in the product model and interaction, not infrastructure theater.

## 33. Open Architecture Decisions

Before implementation freeze:

1. Revisit the iOS 18.0 minimum only when a product requirement needs a newer system API.
2. Post-MVP sync provider and local-library migration path.
3. Post-MVP authentication providers.
4. SwiftData domain-model coupling vs separate persistence models.
5. Place canonicalization source of truth.
6. Background task strategy for pending processing.
7. Whether media originals are always uploaded or user-configurable.
8. Gravity v1 formula.
9. Adaptive orbit-resolution thresholds.
10. Analytics/crash-reporting choice.
