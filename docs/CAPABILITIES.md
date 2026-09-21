# Graviti Capability Reference

**Status:** Implemented local MVP

**Last reviewed:** September 20, 2026

**Minimum OS:** iOS 18.0

**Primary storage:** local SwiftData plus App Group image files

This is the canonical inventory of what the current app does. Product direction lives in [MVP_STEERING.md](MVP_STEERING.md); implementation details live in [ARCHITECTURE.md](ARCHITECTURE.md) and [DATA_MODEL.md](DATA_MODEL.md).

## 1. Product loop

Graviti supports this complete local workflow:

1. Capture something that inspires travel.
2. Persist the original source immediately.
3. Resolve a place and derive useful details in the background.
4. Let the user inspect and correct the result.
5. Organize the Library by destination, place, save, map, category, and interest.
6. Build Gravity from explicit saved-place evidence.
7. infer recurring interests across the full Library.
8. Recommend destinations with a Fit score and separate evidence confidence.
9. Search real places within a recommended destination and save them into a retrievable Fit Guide.

## 2. Onboarding and navigation

The first-run screen explains saving, Gravity, pattern discovery, and local data ownership. It offers direct entry into place search, Save/import, or the app.

The five tabs are:

| Tab | Purpose |
| --- | --- |
| Home | Interactive Gravity Field, destination drill-down, and a Library insight |
| Explore | Interest patterns, categories, destination Fit, preferences, and saved Fit Guides |
| Save | Link, note, photo, screenshot, Maps collection, CSV, and `.webloc` capture |
| Library | Destinations, canonical Places, original Saves, Map, review, backup, privacy, and deletion |
| Search | Unified Library search and live MapKit place discovery |

The Sora font is applied to navigation titles, tab labels, segmented controls, search fields, headings, and core Latin-script UI. System font fallback remains available for scripts Sora does not cover.

## 3. Capture inside the app

### Web link

A valid HTTP or HTTPS URL can be saved with an optional note. The URL is persisted before metadata work begins.

For public non-Maps pages, Graviti can fetch and cache:

- page title
- description
- site name
- final resolved URL
- a bounded preview image
- fetch time

The fetcher uses an ephemeral, cookie-free session, rejects loopback and private-network destinations, validates content type, and enforces size limits.

### Manual note

A user can save free-form text even when no place can be resolved. Notes remain useful evidence for generated categories and interests.

### Photo or screenshot

A user can select one image and optionally describe what caught their eye. Accepted local formats include JPEG, PNG, HEIC/HEIF, WebP, and GIF, subject to a 50 MB per-image limit.

After the image is stored, Apple Vision performs text recognition on device. Detected text is stored separately from user-authored text and can feed enrichment and search.

### Place search

Search provides live Apple MapKit results. Selecting a result saves a canonical place with coordinates and an Apple Maps source URL.

### Maps place links

Apple Maps and Google Maps place links can be pasted or shared. Short links are expanded when possible. Graviti searches MapKit using the place name, address/query hints, and coordinates when supplied.

A match is accepted only when name and proximity evidence are strong enough. Ambiguous items remain visible as **Needs Your Help** for manual selection.

## 4. Capture outside the app

The iOS Share Extension accepts:

- one web URL
- text
- one image
- an optional note typed in the share sheet

The extension writes a small envelope and any image into the shared App Group container, then exits. The main app imports queued envelopes on launch or when returning to the foreground and shows a confirmation banner.

Place resolution, OCR, web metadata, and enrichment happen in the main app. Extension failure never silently deletes a successfully queued source.

## 5. Maps collection imports

### Apple Maps guides

Graviti accepts public Apple Maps guide links from the pasted-link field or a `.webloc` file.

The importer:

- follows the public guide response
- decodes the guide title and stable Apple place identifiers
- deduplicates identifiers within the guide
- requests current MapKit records
- creates one saved artifact per place
- reports imported, refreshed, duplicate, skipped, city, and country counts
- preserves the guide title as collection context
- keeps the guide wrapper save from duplicating on reimport

A saved guide can retry or refresh its places from Saved Item detail.

### Shared Google Maps lists

Graviti accepts a public shared-list URL, including `maps.app.goo.gl` links. It loads the public page, discovers and validates Google's list data endpoint, and extracts:

- list title
- place names
- addresses
- list notes
- coordinates
- stable feature identifiers where present

The importer generates stable Google source links with address and coordinate hints. MapKit then resolves the place. Ambiguous matches go to review.

Reimport can upgrade unresolved records created by older builds, backfill the real list title, preserve user-selected matches, and avoid duplicate list wrappers. A saved list can retry or refresh from its detail screen.

Google can change its undocumented public list response format, so this integration may need maintenance.

### Google Takeout CSV

Graviti imports the Google Maps Saved CSV produced by Google Takeout. The parser supports quoted commas, embedded newlines, escaped quotes, notes, and repeated rows. Imported records resolve asynchronously; the summary reports imported, duplicate, and skipped rows.

The Save screen links to Google Takeout because Takeout is a Google service used to export saved Maps data. Graviti does not require Takeout for ordinary shared-list links.

### `.webloc`

A `.webloc` containing an Apple Maps or Google Maps URL can be imported. Graviti saves the link and, when it represents a supported collection, starts the collection importer.

## 6. Background understanding

Capture and interpretation have separate lifecycles. Each eligible artifact can independently perform:

1. Maps place resolution
2. on-device image text extraction
3. public link metadata fetching
4. generated description, category, and interest enrichment

Interrupted, transiently failed, and in-progress work resumes on launch or foreground activation. An offline or provider failure leaves the original save visible.

### Generated details

The current deterministic enricher combines:

- Apple MapKit point-of-interest category
- user note
- original saved text
- Apple/Google collection titles
- detected image text
- cached link title and description

It can produce:

- a short description
- one broad category
- granular interests
- provenance
- confidence
- generation time

Broad categories are:

- Food & drink
- Scenery & nature
- Arts & culture
- Activities
- Shopping
- Landmarks
- Stay
- Place/other

The vocabulary recognizes signals such as matcha, tea, coffee, desserts, seafood, scenic views, hiking, forests, mountains, national parks, nature, beaches, coast and water, architecture, history, museums, gardens, shopping, and wildlife. It also preserves finer distinctions such as forest versus desert hiking, rocky coast versus beach, historic versus modern architecture, and specific dishes including ramen, sushi, tacos, pizza, pasta, pho, dim sum, and barbecue.

Each inferred interest can retain its exact evidence source and confidence. Sources distinguish the user's note or photo description, original saved text, detected image text, source collection name, cached link metadata, and Apple Maps place category. User-authored notes and photo descriptions receive the strongest weight. Saved Item detail exposes this information under **Why these interests**.

### User corrections

Users can edit the effective:

- description
- category
- interests
- note
- place match

Corrections are stored separately from generated enrichment. Refreshing generated details does not overwrite user edits. Removing a place match preserves the source artifact and returns it to review.

## 7. Library

### Destinations

Groups placed artifacts by adaptive geography and shows save count and Gravity. A destination detail exposes the contributing saves.

### Places

Shows canonical places deduplicated by provider identity. Multiple source artifacts can connect to one place. Repeated-place detail shows every contributing save.

Place multi-select removes selected place associations in one action. Source saves remain in the Library and move to review.

### Saves

Shows original artifacts with photo, link, note, collection, place, and generated-detail fallbacks. Saved Item detail exposes source material, source collection history, detected text provenance, processing state, place, generated or edited details, and refresh/retry actions.

Saves can be deleted individually. Multi-select performs an atomic bulk delete after confirmation. Deleting saves updates Places, Gravity, patterns, and Fit evidence, and removes associated local image files.

### Map

Plots saved places geographically and provides a conventional spatial alternative to Home.

### Actions

Library Actions provides:

- Export backup
- Restore backup
- Data & Privacy
- repeated-place cleanup and review access through the relevant Library modes

The last selected Library mode persists. New users start in Destinations.

## 8. Search

One query searches the local Library across:

- original text
- notes
- detected image text
- link title, description, and site
- generated or edited description
- category
- canonical and localized interest names
- place name and geographic subtitle
- destination names
- interest evidence areas

Results are grouped into Your Saves, Your Destinations, Your Interests, and Your Places.

The same screen also performs live Apple MapKit search. External results can be saved directly; already-saved place identity is recognized.

## 9. Gravity Field

Gravity represents explicit saved-place concentration. Recommended destinations do not gain Gravity merely by being shown or bookmarked.

The builder derives country, state/province, and city nodes from resolved places. Automatic mode:

- keeps a country grouped when child areas do not add enough information
- expands a country when it has enough saves, at least two meaningful child clusters, sufficient coverage, and space in the label budget
- uses state/province grouping when several cities in the same region make that level useful
- displays at most ten labeled destinations
- ranks by Gravity, then save count, then stable name order

Users can force Countries, States & Provinces, or Cities. The choice persists.

Planet size uses bounded nonlinear scaling so a strong destination does not overwhelm the field. Layout is deterministic, bounded, and collision-aware. Planets drift gently unless Reduce Motion is enabled.

Selecting another visible bubble switches directly to it. Selecting the same destination or drilling deeper supports semantic navigation through available geographic children and saved items.

White and bright yellow star shapes pulse subtly behind the planets. They are decorative, noninteractive, have no collision behavior, and do not affect layout or movement. Reduce Motion keeps them static.

The small Home wordmark animates both colored dots above the two `i` characters while keeping their centers fixed.

### Gravity Insights

The Insights control opens a browsable carousel derived from the current Library. Each card focuses its supporting destination in the Gravity Field and can open that destination's saved evidence.

The deterministic insight builder can surface:

- recent momentum when a destination receives at least three saves across at least two places in 30 days and clearly exceeds the prior 30-day period
- a country coming into focus when at least two visible child destinations have meaningful independent evidence
- an interest recurring across at least three saves and two destinations without one destination dominating the evidence
- a meaningful destination that has received no new saves for at least four months
- a conservative field-leader summary when the Library does not support a stronger conclusion

At most four insights appear. Counts, time windows, and interest names stay visible so the result can be interpreted rather than presented as an unexplained conclusion.

### Destination Readiness

Selecting a destination shows a separate readiness band alongside Gravity:

- **Still taking shape**
- **Strong weekend**
- **Ready for 4–5 days**

Readiness uses distinct canonical places, experience-category variety, interest variety, geographic spread within broader destinations, and recent evidence. It discounts multiple Artifacts attached to one place by counting that place once. Stronger bands require both a minimum number of places and multiple experience categories, so a large collection of one repeated type cannot imply a complete trip on its own.

The destination card shows the place, experience, and interest counts behind the band, followed by a concrete next step. Readiness does not change Gravity or Fit and does not attempt to build an itinerary.

## 10. Interests, Fit, and recommendations

### Interest profile

The profile groups accepted effective interests across all artifacts. It records:

- save count
- distinct canonical place count
- distinct geographic area count
- supporting artifacts
- category counts

Patterns spanning different places and areas rank above a pile of repeated records from one place.

### Fit inputs

The deterministic local candidate catalog is a bundled schema-versioned JSON resource spanning Asia, Europe, and North America. Each destination has weighted strengths, a conservative reviewed-data confidence value, review date, and one or more HTTPS sources. Invalid, duplicate, unsourced, or unsupported catalog data is rejected.

Fit considers:

- semantic interest overlap
- how characteristic each matched interest is of the destination
- breadth of matched interests
- explicit preferred interests
- region selection
- avoided interests
- excluded destinations
- whether the destination is already represented in the Library
- evidence count
- distinct places
- geographic spread
- source-type diversity
- note and description richness

Repeated artifacts receive diminishing weight. Evidence concentrated in one imported collection receives an additional modest discount. Per-interest evidence from a user note or photo description carries more weight than collection-title or link-metadata inference. Explicit preference adds signal but cannot bypass confidence limits.

### Relevance, confidence, and displayed Fit

Raw relevance is computed separately from evidence confidence. Personal evidence confidence rises with independent places, areas, source kinds, and rich notes/descriptions and is capped below certainty. It is combined with destination-knowledge confidence by taking the more conservative value.

The displayed Fit score shrinks relevance toward a neutral 50 when evidence is weak. Sparse evidence is labeled **Early signal** instead of showing an intense percentage. Confidence bands are Early, Developing, and Strong.

The app shows matched patterns, supporting-save count, explicit preference matches, combined confidence, destination-knowledge confidence, and links to the reviewed sources. **Not for me** persists an exclusion without changing Gravity. **Save destination** persists the recommendation as a retrievable guide without turning it into an explicit saved-place signal.

### Current candidate coverage

The local reviewed catalog contains 23 destinations: Uji, Kyoto, Taipei, Seoul, Hanoi, Madeira, the Norwegian Fjords, the Scottish Highlands, Copenhagen, Barcelona, Lisbon, New York City, Mexico City, Oaxaca, Vancouver, Seattle, the Olympic Peninsula, Vermont, Maine, California, Sedona, Alaska, and Kauai. Its fine-grained strengths cover examples such as forest hiking, desert hiking, rocky coast, historic and modern architecture, tacos, pizza, and pho while retaining broad compatibility interests.

This catalog is intentionally small. Future expansion should use reviewed destination knowledge while preserving explainability, confidence, and the separation between Gravity and Fit.

## 11. Fit Guides

A recommendation can build a Fit Guide using up to four strongest matching patterns.

For each pattern, Graviti:

1. resolves the destination center
2. applies a destination-specific search span
3. performs an Apple MapKit query constrained to the required region
4. requests points of interest and physical features
5. retries an empty specific term with a broader category term
6. deduplicates a place across sections
7. shows up to six results per pattern

Examples include matcha cafés, tea houses, museums, historic landmarks, scenic viewpoints, hiking trails, botanical gardens, seafood restaurants, beaches, and markets.

Each row opens its Apple Maps listing for current ratings, hours, and details. MapKit does not expose a reliable rating field to this app, so Graviti does not invent, scrape, or display review scores.

Saving a suggestion records collection membership such as `Mexico City Fit Guide · Museums`. If that canonical place already exists, Graviti adds the guide membership to the existing artifact instead of duplicating it. Explore lists saved Fit Guides and reconstructs them from the destination catalog plus the current interest profile; saved membership survives backup and restore.

## 12. Backup, restore, and deletion

Backup schema version 2 includes every Artifact field, embeds local image bytes, and preserves the Explore recommendation region, preferred and avoided interests, saved destinations, and Not for Me exclusions. Version 1 archives remain restorable. Current safeguards include:

- schema-version check
- 500 MB maximum archive input
- 100,000 artifact maximum
- duplicate Artifact ID rejection
- 50 MB maximum per embedded image
- media metadata consistency checks
- bounded and normalized Explore preference values
- second-based date encoding
- pretty printed, sorted output

Restore skips Artifact IDs already present, recreates image files, inserts new records, and resumes pending background work. A failed restore removes image files created during that failed attempt.

The backup does not include external server data because the MVP has no Graviti server.

## 13. Privacy and network behavior

Stored locally:

- links and notes
- images and screenshots
- detected text
- place and geographic data
- generated and edited details
- collection history
- recommendation preferences and feedback
- backup data until the user exports it

Network access occurs when the user invokes or has saved content eligible for:

- Apple MapKit search and place resolution
- Apple Maps guide retrieval
- public Google Maps shared-list retrieval
- public webpage title/description/preview fetching
- opening an external link
- opening the Google Takeout website

Apple Vision OCR runs on device. Graviti has no account system, Graviti-operated backend, advertising SDK, analytics SDK, or crash-reporting SDK in the local MVP.

Uninstalling removes the app's local Library. Export a backup first if the data should be retained.

## 14. Accessibility, localization, and visual behavior

Implemented and inspected:

- Dynamic Type, including accessibility sizes
- VoiceOver labels and logical ordering
- Reduce Motion
- increased contrast
- differentiation through labels and values in addition to color and size
- minimum practical touch targets
- right-to-left layout behavior
- expanded pseudo-localized strings
- Spanish app and Share Extension strings
- system font fallback for non-Latin scripts
- conventional Library and Search access to all core content

The app uses a dark spatial visual system, violet Iris accent, restrained planet glow, Sora typography, standard/dark/tinted app icons, and a branded accent color.

## 15. Debug and dogfood support

Debug builds include a Save-tab dataset switcher for:

- National parks & scenery
- Culture, architecture & history
- Seafood, markets & water
- Diverse mixed library
- Crowded 30-save stress library

The tracked fixture can be removed without deleting unrelated saves. Release packaging excludes these CSVs and excludes unused Sora font files; only Sora Regular and SemiBold are registered.

## 16. Current limitations

- Data does not sync between devices.
- Deleting the app deletes the local Library unless a backup was exported.
- Map search, place resolution, collection imports, Fit Guide suggestions, and web previews require connectivity.
- Google shared-list import depends on a public Google response format that may change.
- Apple and Google collection links must be publicly accessible.
- Ambiguous place matches require user review.
- Generated enrichment is deterministic and vocabulary based; it is not a general AI understanding service.
- Fit uses a small reviewed offline destination catalog rather than worldwide candidate coverage.
- Fit Guide ordering follows Apple Maps relevance. Graviti cannot directly rank by a MapKit review score.
- No account, cloud sync, collaboration, social profiles, public recommendations, itinerary builder, booking, or reservation features are included.
- Video files and live social-platform media ingestion are not implemented; ordinary public links can still be saved and previewed when metadata is available.

## 17. Verification summary

The current automated suite has 91 tests and passes on iOS 18.6 and iOS 26.2 simulators. A prior 62-test suite passed on a physical iPhone 13 Pro Max running iOS 26.3.1 before the latest Fit Guide, backup v2, Gravity Insights, Destination Readiness, semantic-evidence, and destination-catalog tests were added.

Manual and live-service checks include:

- Safari Share Extension capture
- supplied 19-place Apple Maps guide
- supplied 28-place Google Maps shared list
- Google collection reimport, title backfill, and unresolved-record refresh
- multi-collection provenance
- force quit and relaunch persistence
- iOS 18.6 MapKit place save
- New York City, Kyoto, and Mexico City Fit Guides
- crowded Gravity Field and Library
- bulk action confirmation flows
- accessibility, localization, and layout variants
- signed development archive package checks

See [MVP_RELEASE_AUDIT.md](MVP_RELEASE_AUDIT.md) and [TESTFLIGHT.md](TESTFLIGHT.md) for detailed evidence and optional distribution work.
