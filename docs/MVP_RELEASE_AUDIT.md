# Graviti MVP Release Audit

**Audit date:** September 29, 2026

**Simulator validation baseline:** current working tree with the local V1.1 lifecycle, Search, Import Inbox, Library, Fit Guide, feedback, Share Extension, onboarding, durability, provider-boundary, and backup v4 work

**Signed archive validation commit:** `cdcc5b4`

**Release candidate:** 1.0 (1)

This audit maps the local MVP Definition of Done to current evidence. External distribution is outside the completion criteria.

The complete implemented feature inventory, data behavior, limitations, and network boundaries are maintained in [CAPABILITIES.md](CAPABILITIES.md).

## Automated release evidence

- 141 of 141 tests passed with no failures or skips on an iPhone 16 Pro simulator running iOS 18.6.
- 141 of 141 tests passed with no failures or skips on an iPhone 17 Pro simulator running iOS 26.2.
- A focused 13-test iOS 26.2 regression run passed after the Home geography repair. It covers automatic country expansion, state grouping, explicit missing-region fallback, iOS 26 state/province parsing, and stable MapKit place adaptation.
- 62 of 62 tests passed with no failures or skips on a physical iPhone 13 Pro Max running iOS 26.3.1.
- The owner completed and confirmed the expanded hands-on physical pass on September 29, 2026, including the final keyboard, card-centering, and Home geography fixes.
- A clean unsigned Debug build of the app and embedded Share Extension succeeded from the final working tree on September 29, 2026.
- A signed arm64 Release archive of commit `cdcc5b4` completed Xcode's store validation phase. Later Fit Guide, destination-catalog, backup v3, visited-feedback, aggregate-diagnostics, network-state, and compatibility changes passed both simulator suites; they have not been externally distributed.
- `scripts/verify-release-archive.sh` passed every package check: bundle identifiers, matching app and extension versions, iOS 18 minimum, encryption declaration, both privacy manifests, exactly two Sora fonts, no CSV fixtures, nested signatures, and matching App Group entitlements.
- The only archive warning is expected: the available seven-day Apple Development profile is suitable for device testing but not TestFlight distribution.

## Definition of Done evidence

| Requirement | Status | Evidence |
| --- | --- | --- |
| Clear local-only data promise and reliable backup/restore | Verified | Onboarding and Library Actions expose the promise. Backup tests cover rich records, embedded media, schema rejection, duplicate-ID rejection, versions 1 through 3 compatibility, and version 4 restoration of durable guides, feedback/outcomes, Import Inbox attempts, and saved filters. |
| A new user understands Graviti without a tutorial | Verified | Onboarding introduces saving, organization, Gravity, and local ownership. The primary tabs expose conventional alternatives to the spatial Home view, and preliminary physical-device testing passed. |
| Capture inside and outside the app | Verified | Link, note, photo, place, CSV, `.webloc`, Apple guide, and Google list capture are implemented. A live Safari Share Extension save was completed and reopened in Library. |
| Saves appear immediately | Verified | Capture preserves the source before background work. Live link, Share Extension, Apple guide, and Google list checks showed immediate Library records. |
| Background processing does not block capture | Verified | Processing and metadata state are persisted separately. Interrupted enrichment and transient map lookup retry tests pass. |
| Places and geographic hierarchy resolve reliably enough for real use | Verified for beta | Live Google and Apple collections resolved through MapKit. The supplied Apple “Matcha” guide resolved 19 of 19 identifiers; the supplied Google list matched 25 automatically and routed three ambiguous names to review. Imported places retain every distinct collection title as enrichment evidence and expose that history in Saved Item detail. |
| Low-confidence cases can be corrected | Verified | Needs Your Help and place review flows were exercised; user-selected matches are protected from automated refresh. |
| Duplicates can be reconciled | Verified | Stable URL and place identity prevent repeated imports. Reimporting the Apple guide avoided all 19 duplicates while backfilling collection context; Google reimport reports duplicates and refreshes eligible older records without replacing user-selected matches. Bulk repeated-place cleanup preserves source saves. |
| Library supports Destinations, Places, Saves, and Map | Verified | All four modes were exercised with varied and crowded datasets; the last mode persists. |
| Gravity Field handles sparse and large libraries | Verified | Deterministic layout tests cover empty through ten-destination fields. A 30-save crowded library remained readable within the ten-label budget. |
| Gravity Insights remain evidence based | Verified | Focused tests cover recent momentum, geographic splits, interests recurring across destinations, quiet destinations, and the conservative sparse-library fallback. |
| Destination Readiness requires varied evidence | Verified | Focused tests cover duplicate-place discounting, weekend and several-day thresholds, category breadth, and subarea spread. |
| Semantic evidence preserves meaning and provenance | Verified | Focused tests cover user-note priority, landscape and architecture distinctions, specific dishes, exact source records, and decoding enrichment created before semantic evidence was added. |
| Adaptive geographic resolution works | Verified | Tests cover country collapse, city expansion, state grouping, missing-region fallback, concentration, and label budgets. Automatic and explicit resolution modes were exercised. |
| Destination Gravity updates correctly | Verified | Live imports changed Home destinations after persistence and relaunch. Orbit builder tests cover stable geographic identity and ranking behavior. |
| Explore produces useful interest-based recommendations | Verified for local MVP catalog | The schema-versioned 23-destination catalog includes reviewed source links and candidate confidence. Diverse fixtures cover sparse evidence, independent evidence, forest and desert hiking, rocky coast, architecture, dishes, preferences, and exclusions. Candidate confidence limits displayed certainty. Each recommendation builds a live Fit Guide grouped by its matched patterns. Destination regions are resolved before category searches and enforced as required, preventing city records and results from another region. Live New York, Kyoto, and Mexico City guides returned relevant local venues; saving a result created a retrievable guide in Explore. A dedicated searchable guide library retrieves saved guides by destination, country, pattern, or saved place independently of current recommendation rank. |
| Recommendation data does not contaminate explicit interest | Verified | Save Destination, Not for Me, and both visited outcomes are persisted separately. Fit tests verify that visited destinations are excluded, liked visits add only conservative reviewed traits, did-not-fit visits invent no interests, and Gravity remains based on explicit saves. |
| Saved media is preserved and browsable | Verified | Photo storage, thumbnails, detail views, OCR provenance, backup round trips, and restored embedded media are covered. |
| Accessibility requirements are tested | Verified in Simulator | VoiceOver labels and ordering, Dynamic Type, increased contrast, Reduce Motion, right-to-left layout, and large pseudo-localized strings were inspected. Conventional Library and Search access remains available. |
| Localization architecture functions | Verified | String catalogs cover the app and Share Extension. Spanish Home, Explore, Library, canonical interests, counts, accessibility labels, and selection copy were inspected. |
| Core Library data remains accessible offline | Verified | SwiftData is authoritative. Tests confirm failed network lookup preserves the original save and resumes later. Backup export remains explicit and local. |
| Existing local records remain compatible | Verified to the local-MVP schema history | A focused test verifies fallback behavior when later processing-state fields are absent. Backup fixtures cover schema versions 1 through 4. The persisted Artifact model remains backward compatible; newer feature state uses versioned value stores and safe defaults. |
| Network and partial-result states preserve user work | Verified to current coverage | Place lookup, link preview, collection import, and Fit Guide surfaces state what remains saved and expose retry or refresh paths. Import summaries retain successful results and identify skipped entries. |
| Support diagnostics preserve saved-content privacy | Verified | Home exposes the local-data promise and public feedback route. Focused tests verify that copied diagnostics contain aggregate state counts and omit saved names, links, notes, coordinates, media, and identifiers. |
| Substantial real-world dogfooding is complete | Verified for internal beta | Focused datasets, a 30-save stress library, live MapKit search, the supplied Google list, the supplied Apple guide, web metadata, Share Extension capture, force quit, and relaunch were exercised. |
| Major crashes and data-loss bugs are resolved | Verified to current coverage | Both runtime suites pass; batch deletion is atomic; persistence, backup, migration, retry, and force-quit checks pass. No known crash or data-loss defect remains open. |
| Repository documentation matches the implementation | Verified | README links to a complete capability reference. Architecture and data-model documents describe the actual SwiftData/App Group system and separate future server, sync, AI, and social direction from shipped behavior. |

## V1.1 requirement audit

| Requirement | Status | Evidence |
| --- | --- | --- |
| Place lifecycle | Verified | Saved, Curious, Shortlist, Visited, Loved, and Didn't fit are stored as user details, applied to every save for the canonical place, included in filtering and backup, and covered by repository, lifecycle, and physical checks. |
| Scoped Search and zero-query suggestions | Automated verification complete | All, Places, Destinations, Interests, Guides, Notes, and Near me scopes are implemented. Recent searches, recently viewed destinations, strong interests, saved guides, and generated suggestions appear before typing. Near me uses real coordinates and distance ordering. |
| Import Inbox | Automated verification complete | The Inbox combines Artifact processing with durable ImportAttempt records for processing, found, needs help, success, unidentified, duplicate, and retry states. Original saves appear immediately and interrupted work recovers through the durable queue. |
| Saved views, sorting, completeness, and Undo | Automated verification complete | Saved filter combinations persist and update against current data. Each Library surface exposes relevant sort options. Completeness identifies six missing-detail types and drives a review queue. Single destructive actions are staged for Undo; bulk operations retain confirmation. |
| Lightweight recommendation feedback | Automated verification complete | Generic one-tap Yes, No, and Not sure prompts persist locally, can be changed or removed, are dismissible and rate limited, and remain separate from ranking until evaluated. |
| Durable Fit Guides | Automated verification complete | Guide records support rename, note, cover image, reordering, per-guide removal, archive, duplication, shortlist, category completion, sorting, search, and clean text export. Membership is independent of Artifact source collections and does not delete places. |
| Fast custom Share Extension | Verified | The custom extension accepts URL, text, or one image, shows title/source, saves immediately, and offers optional note, guide, priority, personal tag, and save-without-identification choices. App Group ingest, keyboard dismissal, and relaunch passed the physical-device check. |
| Interactive onboarding and sample library | Verified | Onboarding teaches capture and explains identification, Gravity, and Fit around a first save. The optional sample library can be added and removed without touching personal saves. Automated coverage and the expanded physical checklist passed. |
| Durable processing queue | Automated verification complete | Metadata, OCR, place identification, enrichment, profile indexing, and thumbnail jobs persist version, attempts, error, retry time, and dependencies. Tests cover interrupted-running recovery, bounded retries, and iOS 18 teardown safety. |
| Rebuildable Library index | Automated verification complete | Persisted place, destination, interest, guide, processing-state, and normalized search indexes rebuild from authoritative Artifacts and guide state. Tests cover deletion and exact rebuilding. |
| Generated-data versions and provider boundaries | Automated verification complete | Generated values carry producer/version provenance. Protocol boundaries cover place search, metadata, social hints, destination knowledge, recommendation ranking, and optional sync; deterministic providers are used in tests. |
| Private recommendation outcomes | Automated verification complete | Shown, opened, saved destination, saved suggested place, dismissed, loved, and did-not-fit events remain local, bounded, inspectable, and included in backup v4. |
| Optional CloudKit readiness | Design complete | [OPTIONAL_CLOUDKIT_SYNC_DESIGN.md](OPTIONAL_CLOUDKIT_SYNC_DESIGN.md) defines local-authoritative migration, immutable IDs, edit precedence, membership merging, tombstones, separate media transfer, and visible sync health. Sync is intentionally not enabled. |
| Current Figma parity | Verified | Page **07 — Local V1.1 Experience** documents Search discovery, mixed-state Import Inbox, place lifecycle, durable Fit Guide planning, instant Share Extension capture, and interactive onboarding across six 393 × 852 screens. A final visual, bounds, and typography audit confirmed the Sora and Inter type system with no unexpected fonts. |
| Current physical iPhone gate | Verified | The owner completed and confirmed the final physical retest on September 29, 2026. The Share Extension note keyboard dismisses correctly, the first destination card is centered on initial presentation, and Home Cities, States & Provinces, and Automatic modes reflect the repaired iOS 26 geography. |

## Optional future distribution work

1. **Apple Developer Program membership:** team `V9W8HRDJQT` currently has no App Store Connect provider and cannot create App Store provisioning profiles for either bundle. The account holder must enroll or associate the team with an active provider.
2. **Distribution export:** rerun `scripts/export-testflight.sh` after enrollment. This creates a locally exported IPA without uploading it.
3. **Additional device confidence:** preliminary manual testing has passed; the current app plus Share Extension were provisioned, installed, launched, and observed running on an iPhone 13 Pro Max with iOS 26.3.1; all 62 tests passed on that device; and a post-test screenshot confirmed the retained Library rendered on Home. The extended hands-on checklist in `docs/TESTFLIGHT.md` can be used before any future wider distribution.
4. **TestFlight metadata:** provide the feedback email and App Store Connect review contact.
5. **Upload authorization:** upload the verified distribution build only after the owner reviews the final archive and metadata.

The local-only MVP contract is complete. The items above apply only if external distribution is chosen later and do not block local completion.
