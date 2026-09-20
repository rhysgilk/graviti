# Graviti — Data Model

**Version:** 0.1  
**Status:** Implemented local MVP model with future sync references
**Storage direction:** SwiftData local authority + versioned backup; optional backend after MVP

---

## 1. Design Goals

The data model must support:

1. original source preservation
2. multiple Experiences extracted from one Artifact
3. multiple Artifacts referring to one Place
4. automatic geographic hierarchy
5. many-to-many Interest relationships
6. separation of explicit user signals from system recommendations
7. confidence and provenance for machine-generated metadata
8. duplicate detection without destructive merging
9. adaptive geographic resolution
10. offline-first local caching
11. future social/Guide expansion without requiring a V1 rewrite

## 2. Identity Rules

Every canonical Graviti entity owns its own UUID.

External provider IDs are aliases, never primary keys.

```text
Place.id = Graviti UUID

PlaceAlias:
  provider = apple_maps
  provider_id = ...
```

## 3. Core Entity Graph

```text
User
 ├── Artifact
 │    └── Experience
 │         ├── Place
 │         │    └── GeoArea
 │         └── Interest
 │
 ├── UserPlaceSignal
 ├── UserExperienceSignal
 ├── UserInterestProfile
 ├── RecommendationFeedback
 └── DestinationAggregate
```

## 4. User

```text
User
- id: UUID
- created_at
- updated_at
- locale
- preferred_language
- home_geo_area_id: UUID?
- orbit_resolution_mode: enum
```

`orbit_resolution_mode`:

```text
automatic
countries
states_provinces
cities
```

## 5. Artifact

An Artifact is the original thing the user supplied.

```text
Artifact
- id: UUID
- user_id: UUID
- artifact_type: enum
- source_url: string?
- source_app: string?
- original_text: string?
- user_note: string?
- media_asset_id: UUID?
- extracted_text: string?
- extracted_text_source: enum?
- text_extraction_state: enum
- link_metadata: JSON? (title, summary, site name, resolved URL, optional preview image, fetched time)
- link_metadata_state: enum
- processing_state: enum
- processing_error_code: string?
- captured_at
- created_at
- updated_at
```

`artifact_type`:

```text
url
photo
screenshot
video
social_post
maps_link
manual
import_record
```

`processing_state`:

```text
saved
processing
processed
needs_review
failed
```

Place resolution and descriptive enrichment are tracked separately. Enrichment uses:

```text
pending
processing
processed
unavailable
failed
```

This lets a save remain safely captured while richer descriptions, categories, and interests are generated locally or by a future background service. `unavailable` means the current inputs were insufficient; it is distinct from a processing failure and can return to `pending` when the user adds a place or description.

Image text extraction has the same resumable state vocabulary. The MVP runs Apple Vision locally after the media asset is secure, stores detected text separately from user-authored text, and records `apple_vision` as its source. Detected text can seed category and interest enrichment, while the saved-item detail keeps the extracted text and its provenance visible to the user.

Link metadata also uses this resumable lifecycle. Metadata fetches run after capture with an ephemeral, cookie-free session; reject loopback and private-network targets; enforce response type and size limits; and cache title, description, site name, resolved URL, and a bounded preview image. Cached title and description become enrichment evidence without replacing the original URL or the user's note.

The Artifact is never deleted merely because extraction fails.

`user_note` may contain the optional description a user supplied with a photo. Keep user-authored text separate from generated descriptions and preserve it when enrichment is rerun.

User corrections to a save's description, category, and interests are stored separately from generated enrichment. Explore uses the corrected values when present. Refreshing enrichment must not overwrite corrections; users can explicitly return to the suggested values.

## 6. MediaAsset

```text
MediaAsset
- id: UUID
- user_id: UUID
- media_type: enum
- storage_key: string
- thumbnail_storage_key: string?
- mime_type: string
- width: int?
- height: int?
- duration_ms: int?
- sha256: string?
- created_at
```

Large media belongs in object storage, not relational rows.

## 7. Experience

An Experience captures why the user cared about an Artifact.

```text
Experience
- id: UUID
- user_id: UUID
- artifact_id: UUID
- place_id: UUID?
- title: string
- normalized_title: string?
- description: string?
- category_id: UUID?
- extraction_confidence: decimal?
- extraction_source: enum
- extraction_model_version: string?
- created_at
- updated_at
```

Enrichment for an Experience should retain provenance, confidence, and the last successful processing time. Categories and interests should reflect what the user wanted to do or see, not only the venue type. For example, a café save may also imply matcha, desserts, interior design, or neighborhood exploration when supported by the artifact or user note. Recommendation signals derive from accepted or sufficiently confident enrichment across all destinations, while explicit saves remain a separate signal.

Examples:

- “Try the strawberry matcha parfait.”
- “Visit teamLab Planets.”
- “See the skyline from this viewpoint.”
- “Ride this scenic train.”

## 8. Place

A Place is a canonical physical location.

```text
Place
- id: UUID
- canonical_name: string
- latitude: decimal?
- longitude: decimal?
- geo_area_id: UUID?
- address_text: string?
- place_type: string?
- status: enum
- created_at
- updated_at
```

Provider identities live in `PlaceAlias`.

## 9. PlaceAlias

```text
PlaceAlias
- id: UUID
- place_id: UUID
- provider: enum
- provider_id: string
- provider_url: string?
- valid_from: timestamp?
- valid_to: timestamp?
- is_current: bool
- created_at
```

Example providers:

```text
apple_maps
google_places
openstreetmap
manual
other
```

## 10. GeoArea

GeoArea forms a recursive geographic tree.

```text
GeoArea
- id: UUID
- parent_geo_area_id: UUID?
- type: enum
- canonical_name: string
- country_code: string?
- administrative_code: string?
- centroid_latitude: decimal?
- centroid_longitude: decimal?
- bounds_json: jsonb?
- created_at
- updated_at
```

`type`:

```text
country
state_province
region
city
district
neighborhood
other
```

No code should assume every country uses a U.S.-style city → state → country hierarchy.

## 11. GeoAreaLocalizedName

```text
GeoAreaLocalizedName
- id: UUID
- geo_area_id: UUID
- locale: string
- name: string
- name_type: enum
```

`name_type`:

```text
localized
native
alternate
short
```

## 12. Category

Categories are controlled and intentionally broad.

```text
Category
- id: UUID
- slug: string
- localization_key: string
- sort_order: int
- is_active: bool
```

Suggested initial categories:

```text
food_drink
sights_scenery
culture_attractions
experiences
shopping
outdoors
stays
events
other
```

## 13. Interest

Interests are extensible concepts.

```text
Interest
- id: UUID
- slug: string
- canonical_name: string
- parent_interest_id: UUID?
- is_system_defined: bool
- created_at
```

Examples include matcha, tea, ramen, anime, architecture, bookstores, scenic trains, and contemporary art.

## 14. ExperienceInterest

```text
ExperienceInterest
- experience_id: UUID
- interest_id: UUID
- confidence: decimal?
- source: enum
- model_version: string?
- created_at
```

Unique key:

```text
(experience_id, interest_id)
```

`source`:

```text
user
system_rule
model
import
```

## 15. UserExperienceSignal

Tracks intentional user behavior against an Experience.

```text
UserExperienceSignal
- id: UUID
- user_id: UUID
- experience_id: UUID
- signal_type: enum
- strength: decimal?
- created_at
```

`signal_type`:

```text
saved
visited
loved
liked
neutral
disliked
dismissed
```

## 16. UserPlaceSignal

```text
UserPlaceSignal
- id: UUID
- user_id: UUID
- place_id: UUID
- signal_type: enum
- strength: decimal?
- created_at
```

Useful for repeated saves and visited-place tracking.

## 17. ArtifactPlaceCandidate

Used during extraction and low-confidence review.

```text
ArtifactPlaceCandidate
- id: UUID
- artifact_id: UUID
- place_id: UUID?
- raw_candidate_name: string?
- confidence: decimal
- rank: int
- extraction_source: string
- model_version: string?
- selected: bool
- created_at
```

## 18. InferenceRecord

Generalized provenance for inferred fields.

```text
InferenceRecord
- id: UUID
- user_id: UUID
- entity_type: string
- entity_id: UUID
- field_name: string
- proposed_value_json: jsonb
- confidence: decimal
- source_type: enum
- model_version: string?
- accepted_at: timestamp?
- rejected_at: timestamp?
- corrected_value_json: jsonb?
- created_at
```

## 19. DuplicateGroup

```text
DuplicateGroup
- id: UUID
- user_id: UUID
- canonical_place_id: UUID?
- resolution_state: enum
- confidence: decimal?
- created_at
```

```text
DuplicateGroupMember
- duplicate_group_id: UUID
- artifact_id: UUID
```

`resolution_state`:

```text
candidate
auto_merged
user_merged
rejected
```

Artifacts remain intact when Places are reconciled.

## 20. UserInterestProfile

Cached learned-preference signal.

```text
UserInterestProfile
- user_id: UUID
- interest_id: UUID
- explicit_score: decimal
- behavioral_score: decimal
- recommendation_score: decimal
- confidence: decimal
- updated_at
```

Recommendation exposure alone must not increase `explicit_score`.

## 21. RecommendationFeedback

```text
RecommendationFeedback
- id: UUID
- user_id: UUID
- recommendation_id: UUID
- action: enum
- created_at
```

`action`:

```text
shown
opened
saved
dismissed
not_for_me
visited
```

## 22. DestinationAggregate

Cached user + GeoArea aggregate.

```text
DestinationAggregate
- user_id: UUID
- geo_area_id: UUID
- explicit_save_count: int
- experience_count: int
- distinct_place_count: int
- category_count: int
- gravity_score: decimal
- fit_score: decimal?
- recent_save_count: int
- last_signal_at: timestamp?
- updated_at
```

Primary key:

```text
(user_id, geo_area_id)
```

Update incrementally rather than recomputing the entire user graph on every save.

## 23. Adaptive Orbit Resolution

Orbit rendering operates on the GeoArea tree plus `DestinationAggregate`.

Conceptual algorithm:

```text
resolve(node):
    if user forced a geography level:
        return nodes at requested level

    if node has weak or diffuse child-level signal:
        keep node grouped

    if meaningful child clusters exist
       AND children fit within visual capacity:
        replace node with selected children

    recurse where useful
```

Inputs:

- Gravity score
- number of child clusters
- share of Gravity concentrated in children
- label capacity
- maximum ~10 labeled nodes
- minimum legible visual size
- user resolution preference

The output may contain mixed geographic levels.

## 24. Gravity Score Inputs

Initial Gravity should remain interpretable.

Potential components:

```text
explicit_save_weight
distinct_experience_weight
repeat_source_bonus
recency_weight
category_diversity_bonus
manual_interest_bonus
```

Do not include passive recommendation exposure.

A first implementation should use deterministic weights and be easy to inspect.

## 25. Fit Score Inputs

Fit may consider:

- UserInterestProfile overlap
- explicit Explore preferences
- hard geographic/travel constraints
- negative preferences
- destination category composition
- destination interest composition

Fit remains separate from Gravity.

## 26. Sync Metadata

Locally persisted user-owned entities should support sync state such as:

```text
local_only
pending_upload
synced
pending_delete
conflict
```

Related fields may include server version, last synced time, soft-delete time, and local update time.

## 27. Indexing Guidance

Likely indexes:

```text
Artifact(user_id, created_at desc)
Artifact(user_id, processing_state)
Experience(user_id, place_id)
Place(geo_area_id)
PlaceAlias(provider, provider_id)
GeoArea(parent_geo_area_id)
ExperienceInterest(interest_id, experience_id)
DestinationAggregate(user_id, gravity_score desc)
RecommendationFeedback(user_id, created_at desc)
```

Add PostGIS indexes if server-side spatial queries become part of the MVP.

## 28. Deletion and Privacy

Deleting an Artifact should not automatically delete globally canonical Place/GeoArea records.

User-owned deletion must remove or sever:

- Artifact
- MediaAsset
- Experience
- user-specific signals
- user-specific inference/provenance
- derived destination aggregates

Derived caches must never become the only source of truth.

## 29. Future-Compatible Entities

Possible future entities:

```text
Guide
GuideEntry
PublicProfile
Follow
GuideSave
TasteSimilarity
```

Do not implement these until needed.

## 30. Open Questions

Before schema freeze:

1. Are canonical Place records global or user-scoped for MVP?
2. Which provider owns initial place resolution?
3. How much original social-source metadata can legally/reliably be retained?
4. Can Experience remain locationless indefinitely?
5. Which inference metadata should be normalized versus generalized in `InferenceRecord`?
6. Does GeoArea use an external gazetteer, provider hierarchy, or Graviti-maintained canonical tree?
7. What threshold moves an inference into `needs_review`?
8. What exact inputs and weights make up Gravity v1?
