# Graviti MVP Steering Guide

This document records product decisions and implementation priorities that should guide continued MVP work. Update it when user feedback changes the direction.

## Product principle

Graviti should understand why a person saved something, connect patterns across their whole library, and use those patterns to suggest destinations. Geographic save counts alone are not sufficient evidence. A recommendation must reflect the qualities of the saved experiences: for example forest hiking, coastal scenery, historic architecture, seafood, matcha, or national parks.

The original artifact and user note are primary evidence. Derived descriptions, categories, interests, and places must remain correctable and retain provenance.

## Fit scoring contract

### Separate relevance from confidence

Fit must not be a count of overlapping labels presented as a probability. Compute two concepts:

1. **Relevance**: how well the destination's known qualities match the user's demonstrated interests and stated preferences.
2. **Evidence confidence**: whether Graviti has enough independent, varied evidence to make that claim.

The displayed result should shrink toward a neutral baseline when confidence is low. Do not show a high percentage from a few saves. When evidence is too sparse, use language such as **Early signal** and explain what evidence is missing. Avoid false precision.

### Fit components

Use explainable sub-scores before combining them:

- **Semantic affinity:** specific motifs extracted from titles, notes, descriptions, OCR, and place metadata. Preserve distinctions such as forest trails versus desert hiking, rocky coast versus beach, historic versus modern architecture, and seafood market versus generic food.
- **Destination strength:** how strongly and specifically the candidate is known for each motif. Candidate interests need weighted evidence, not Boolean membership in a tag set.
- **Preference match:** explicit interests, region choices, constraints, and future onboarding preferences.
- **Evidence diversity:** independent saves, distinct places, source types, geographic areas, and interest families. Ten copies of one venue are weaker evidence than ten distinct saves across several contexts.
- **Cross-area consistency:** patterns repeated across different saved areas generalize better than a pattern concentrated in one locality.
- **Novelty and serendipity:** reward useful extensions of known interests without allowing novelty to overwhelm relevance.
- **Negative evidence:** persisted “Not for me” feedback and avoided interests reduce future Fit. They never change Gravity.
- **Candidate data confidence:** a recommendation is limited when Graviti has weak knowledge of what the destination offers, even if the user profile is strong.

Existing saves in or near a candidate destination may contribute modestly, but must not dominate. Gravity describes demonstrated concentration; Fit predicts suitability elsewhere.

### Confidence policy

- Track unique artifacts, unique canonical places, geographic spread, source diversity, note/detail richness, and repeated semantic evidence.
- Discount correlated evidence from duplicates, imports of one list, and many saves at one venue or area.
- Use Bayesian or hierarchical shrinkage so sparse personal evidence falls back toward a conservative population prior.
- Calibrate score bands against held-out examples and later against user feedback. A displayed 80% should earn positive feedback at roughly that rate within a defined evaluation cohort before it is treated as a probability.
- Until calibration data exists, label the value as a **Fit score**, not a statistical probability, and cap results according to evidence confidence.
- Show the strongest supporting patterns and allow the user to inspect the saves that produced them.

Research direction: attribute-aware hierarchical smoothing is useful for sparse profiles; calibrated recommendation aims to reflect the distribution of a user's interests; recommender quality should include accuracy, diversity, novelty, and serendipity rather than one engagement signal. See [Google Research on hierarchically smoothed preferences](https://research.google/pubs/latent-factor-models-with-additive-hierarchically-smoothed-user-preferences/), [Google Research on exploration and recommendation quality](https://research.google/pubs/values-of-exploration-in-recommender-systems/), and [Google Research on bootstrapping sparse recommendation systems](https://research.google/pubs/bootstrapping-recommendations-at-chrome-web-store/).

### Required Fit fixtures

- A few saves must never produce a 90–95 Fit score.
- Ten matcha saves in Rhode Island should strengthen matcha/tea affinity and may support Japan, Uji, Kyoto, New York, or other destinations known for that motif; Rhode Island must not win solely because the saves occurred there.
- Woodland trail notes should favor destinations known for forest hiking, such as Maine, Vermont, or the Seattle region, over a generic national-park match.
- Five independent places across several areas should produce more confidence than five artifacts connected to one place.
- Notes that say why a place matters must change the ranking when they contain specific evidence.
- Negative feedback must lower future Fit without changing saved-place Gravity.

## Prioritized MVP work

### Now

- [x] Add multi-select to Library > Places with a bulk remove action. Preserve source saves and return them to place review.
- [x] Add multi-select to Library > Saves with an atomic bulk delete action and a destructive confirmation.
- [x] Replace the saturating Fit equation with weighted destination traits, evidence diversity, duplicate discounting, confidence bands, and conservative score shrinkage.
- [x] Add an XCTest target and deterministic `DestinationFitEngine` fixtures for sparse evidence, semantic specificity, duplicate discounting, and avoid rules.
- [x] Extend deterministic XCTest coverage to `InterestProfileBuilder`, `DestinationOrbitBuilder`, `OrbitLayoutEngine`, and import parsers.
- [x] Add local Vision OCR for screenshots and photos, preserve OCR provenance, and use detected text to seed enrichment and place review.
- [x] Feed safe link metadata (title, preview text, site, and image where available) into asynchronous artifact enrichment and cache it.

### Next

- [x] Improve Automatic geographic resolution using Gravity concentration, meaningful child clusters, state/province usefulness, and the available label budget.
- [x] Make Search global across artifacts, interests, destinations, saved places, and MapKit results.
- [x] Add richer thumbnails and media cards to the Saves library with graceful note/link fallbacks.
- [x] Add persisted recommendation actions: **Save destination** and **Not for me**.
- [x] Persist the last Library mode; use Destinations as the initial mode for a new user.
- [x] Replace repeated explanatory copy with concise headers such as Interests, Patterns, and Your saves.
- [x] Make the local-only data promise visible during onboarding and from Library Actions, including network and backup behavior.
- [x] Lower the minimum deployment target to iOS 18 and isolate iOS 26 MapKit address APIs behind a compatibility adapter.
- [x] Keep dogfood datasets and unused font weights out of Release archives while preserving the dataset switcher in Debug builds.
- [x] Add a production app icon with standard, dark, and tinted appearances, plus the branded system accent color.
- [x] Import public Apple Maps guides and shared Google Maps lists directly from pasted links, while retaining Google Takeout CSV as a bulk export path.
- [x] Preserve Google list address and coordinate evidence so MapKit can disambiguate results while still sending unsafe matches to review.
- [x] Refresh unresolved items from earlier Google list imports in place when the same list is imported again.
- [x] Avoid duplicate guide-wrapper saves when a known Apple or Google collection is imported again.
- [x] Let saved Apple and Google collections retry or refresh their place imports from the saved-item screen, retain their discovered list titles, and persist upgraded lookup hints across relaunches.
- [x] Preserve multiple guide/list memberships for the same imported place and expose that source history without overwriting user-edited details.
- [x] Retry transient failed map lookups when the app next launches or returns to the foreground.
- [x] Keep ambient Home stars decorative, noninteractive, and motion accessible; apply Sora consistently to Library and Search.
- [x] Turn each Fit recommendation into a retrievable Fit Guide with live destination-scoped suggestions grouped by the interests that produced the recommendation.
- [x] Save suggested places into their Fit Guide without duplicating an existing Library item, and retain guide membership in exports and restores.
- [x] Resolve each Fit Guide destination before searching, require results to stay inside that region, and use category-specific fallback terms so international guides return local venues instead of the destination itself.

### MVP decision gate

**Decision: local-only MVP.** Library > Actions provides a versioned JSON export and restore flow. The backup preserves saved records, place matches, enrichment, cached link details, and embedded photo bytes; restore skips stable-ID duplicates and resumes background processing. Any future distributed beta must state that data stays on the device unless the user exports a backup. Sign in and cloud sync remain a post-MVP option.

### Repository and architecture

- [x] Add XCTest targets before declaring MVP complete.
- [x] Add `.gitignore`; untrack `.DS_Store`, `xcuserdata`, and Xcode UI state.
- [x] Remove stray document title lines and expand the README with setup, architecture, testing, and current MVP status.
- [x] Add current product screenshots to the README before the public repository or external beta announcement.
- [x] Extract import, processing, and enrichment coordinators incrementally. Keep `ArtifactLibrary` as the observable facade instead of adding every workflow to it.
- [x] Add privacy manifests, export-compliance metadata, a local-only privacy policy draft, and TestFlight beta guidance before producing an external build.
- [x] Exercise rich-artifact round trips, batch updates, and deletion through an in-memory SwiftData container to guard the production persistence adapter.

## Scope guardrail

Keep the MVP focused on capture, understanding, organization, Gravity, and destination discovery. Social profiles, collaboration, itineraries, booking, flights, hotels, events, reservations, and chat-style planning remain outside the current scope.
