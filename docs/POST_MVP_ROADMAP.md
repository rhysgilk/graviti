# Graviti Post-MVP Roadmap

**Status:** Local V1.0 frozen; post-MVP work in progress

**Baseline tag:** `v1.0-local-mvp`

**Distribution decision:** Complete locally. Do not publish to TestFlight or the App Store unless the owner changes this decision.

This roadmap turns product feedback, dogfood findings, the completed MVP audit, and the Phase 2 review into one ordered plan. The shipped behavior is documented in [CAPABILITIES.md](CAPABILITIES.md). Scoring principles and longer-term product constraints remain in [MVP_STEERING.md](MVP_STEERING.md).

## Current state

The V1.0 local MVP is complete. It supports capture, importing, local enrichment, correction, geographic organization, Gravity, interest patterns, conservative Fit recommendations, actionable Fit Guides, search, backup and restore, accessibility, localization, and debug datasets.

The baseline is tagged `v1.0-local-mvp`. Backup schema version 2 is the first post-MVP maintenance change. It adds Explore recommendation state to exports while preserving version 1 restore compatibility.

External distribution work is intentionally paused. Existing TestFlight and archive documents remain as optional future references; they are not current milestones.

## Product purpose

Graviti should turn a private collection of travel inspiration into increasingly useful understanding:

1. Preserve what the person saved and why it mattered.
2. Organize explicit saves without losing their source or context.
3. Recognize recurring qualities across places, such as forest hiking, rocky coasts, historic architecture, seafood markets, matcha, museums, or national parks.
4. Suggest destinations because those qualities are genuinely strong there.
5. Turn a destination suggestion into concrete places through a Fit Guide.
6. Learn from corrections, saves, dismissals, and eventual visit feedback.

Geographic concentration is useful evidence for Gravity. It cannot be the sole explanation for destination Fit.

## Completed post-MVP foundation

- [x] Freeze the completed local MVP with the annotated `v1.0-local-mvp` tag and push it to GitHub.
- [x] Add backward-compatible backup schema version 2.
- [x] Export and restore the Explore region, preferred interests, avoided interests, saved destination IDs, and Not for Me destination IDs.
- [x] Keep version 1 backups restorable without overwriting current Explore settings.
- [x] Validate preference bounds and normalize restored preference values.
- [x] Cover version compatibility and preference restoration with automated tests.

## Milestone 1: Current design source of truth

**Owner:** user-managed ChatGPT/Figma workflow. Codex will audit the result after the user reports that the Figma update is complete; no Figma write work is part of the current app implementation stream.

The implementation is ahead of the existing Figma exploration. Create and maintain a new page named **05 — Current MVP / V1.0**. Preserve earlier pages as product history.

The current page should represent:

- Home with Gravity bubbles, stars, resolution controls, semantic zoom, selected destinations, and direct bubble switching
- Explore with recurring patterns, Fit, confidence, preferences, Save Destination, Not for Me, and Saved Fit Guides
- Fit Guide loading, grouped suggestions, save actions, empty states, international destinations, and retained guide membership
- Save with links, notes, photos, screenshots, place search, Apple Maps guides, Google Maps lists, Google Takeout CSV, and `.webloc`
- Library Destinations, Places, Saves, Map, review, multi-select, deletion, backup, restore, privacy, and source history
- global Search with local results and live MapKit discovery
- Saved Item detail, generated details, provenance, editing, retry, refresh, and correction
- onboarding, import summaries, confirmations, failures, offline states, and accessibility variants

Create a separate page named **06 — V1.1 Concepts** for unimplemented ideas. Label concepts clearly so they are not mistaken for current behavior.

Connect the highest-value reusable SwiftUI components first:

- `GravitiWordmark`
- Gravity planet/bubble presentation
- destination selection and Fit cards
- save and media cards
- interest tags
- import summary

## Milestone 2: Gravity Insights

**Status: implemented and covered by automated tests.**

Home should explain change over time as well as total strength. Insights must derive from actual Artifact timestamps and current geographic organization.

Candidate insight types:

- a destination gaining Gravity, including recent save count and time window
- an unexpected cross-library pull supported by recurring motifs
- a destination splitting into meaningful child areas after enough evidence accumulates
- an area going quiet after a meaningful period without new saves
- a new interest family appearing across more than one place or region

Each insight should expose the saves and patterns that support it. Sparse or correlated evidence should produce cautious language.

The shipped local implementation uses a four-card maximum and deterministic evidence thresholds. It covers recent 30-day momentum, meaningful country-to-child-area splits, recurring interests across destinations, destinations quiet for at least four months, and a conservative leader fallback. Each card shows its evidence summary, focuses the related Gravity destination, and links to the supporting destination Library.

## Milestone 3: Destination Readiness

**Status: implemented and covered by automated tests.**

Readiness should answer whether a person has enough varied reasons to turn saved interest into a plausible trip. It is separate from Gravity and Fit.

Possible inputs:

- unique canonical places
- category and interest variety
- distinct neighborhoods or geographic spread
- balance among food, culture, scenery, activities, shopping, landmarks, and stays
- the rate and recency of new saves
- repeated saves or multiple Artifacts attached to one place, discounted as correlated evidence
- optional future trip-length preference

Initial output should use understandable bands such as **Still taking shape**, **Strong weekend**, or **Ready for a 4–5 day trip**. The explanation should show what is present and what would make the destination more complete. It must not become an itinerary or booking feature.

The shipped local implementation uses distinct canonical places, category and interest breadth, subarea spread, and recent distinct places. Multiple saves attached to one place count once toward place readiness. Stronger bands require both independent places and category variety. The selected-destination card shows the band, its evidence counts, and the next evidence needed; it does not alter Gravity or Fit.

## Milestone 4: Richer semantic understanding

**Status: implemented as an expanded deterministic local baseline and covered by automated tests.**

The deterministic vocabulary is a solid local baseline. The next system should preserve finer distinctions and explain its evidence.

Requirements:

- distinguish motifs such as forest versus desert hiking, rocky coast versus beach, historic versus modern architecture, and specific dishes versus generic food
- weigh user-authored notes and photo descriptions more strongly than generated text
- retain the exact source used for each inference: note, original text, OCR, place metadata, collection title, or fetched page metadata
- expose provenance and confidence in Saved Item detail
- run asynchronously and keep the original save usable while processing
- never overwrite a user correction
- fail safely and resume after interruption
- prefer on-device or privacy-preserving processing when practical

The shipped local implementation preserves broad compatibility tags while adding forest and desert hiking, rocky coast, historic and modern architecture, and specific dish tags. Every inferred interest can record whether it came from a user note or photo description, original text, OCR, a collection name, link metadata, or Apple Maps, together with source confidence. User-authored descriptions carry the highest weight, Saved Item detail exposes the evidence, older records decode without the new optional field, and user corrections continue to override generated values.

## Milestone 5: Recommendation knowledge and evaluation

Move the destination catalog from hardcoded candidate definitions into a versioned data resource with provenance. Expand coverage only when the added destination has reviewed, specific evidence.

Evaluation must include:

- sparse profiles that cannot produce extreme Fit scores
- concentrated saves that generalize by motif rather than merely repeating their location
- forest, desert, coast, architecture, food, history, parks, and mixed-interest scenarios
- duplicate and single-collection discounting
- note text that changes ranking when it explains why a place mattered
- avoided interests and Not for Me feedback
- international Fit Guide searches that stay within their destination
- diversity, novelty, and serendipity alongside relevance

Displayed Fit remains a score rather than a statistical probability until real feedback supports calibration. Candidate data confidence should limit the score when destination evidence is weak.

## Milestone 6: Feedback and learning

Add explicit **Visited** feedback when the underlying data model can preserve it safely. Useful signals may include:

- visited and liked
- visited and did not fit
- saved from a Fit Guide
- dismissed with Not for Me
- corrected category, interest, or place

These signals should improve recommendations without rewriting the person’s explicit Library history. Future social evidence may supplement personal evidence, but it must remain separately weighted and understandable.

## Fit Guide evolution

The current pattern-grouped Fit Guide completes the core recommendation loop. Later organization may include:

- guide rename
- guide note
- remove a place from a guide without deleting its source save
- reorder places
- archive a guide
- browse many guides independently of whether the destination is currently visible in the top Fit list

Use current provider data only through permitted APIs. Do not scrape, invent, or imply review ratings that MapKit does not expose.

## Product polish backlog

- Add an in-app About surface that states local storage, backup behavior, network boundaries, version, and support information.
- Add a Send Feedback action and an optional Copy Diagnostics report that excludes saved content by default.
- Make slow-network and partial-import states explicit for map resolution, list importing, Fit Guide search, and web previews.
- Add migration tests whenever persisted records or backup schemas change.
- Add focused snapshot or visual regression coverage for the Gravity Field and highest-risk reusable states when the maintenance cost is justified.

## Sync decision

No account or cloud sync is required for the current local product. Revisit sync only after real use shows that cross-device continuity or loss recovery is a frequent problem.

If sync is added:

- make it opt-in
- preserve the local-first model
- define migration from backup schema versions 1 and 2
- preserve original Artifacts, collection memberships, corrections, and media
- specify deterministic conflict handling before enabling writes from multiple devices

## Scope boundaries

The following remain outside the current plan:

- flight and hotel booking
- itinerary scheduling
- reservations
- route optimization
- packing and expense tools
- public feeds and follower mechanics
- a generic chat planning assistant

New work should deepen capture, understanding, Gravity, Fit, and the path from a recommendation to saved places.

## Validation policy

Every milestone should include deterministic fixtures for its core logic, simulator coverage on the oldest and newest supported runtimes, and a concise manual test list for behavior that depends on MapKit, public links, animation, accessibility, or device sharing.

Physical-device checks remain valuable for Share Extension behavior, font rendering, motion, performance, and real Maps imports. They do not require external distribution.
