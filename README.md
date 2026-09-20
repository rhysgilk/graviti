# Graviti

Graviti is a private iOS travel-interest library. Save a place, link, note, screenshot, photo, Apple Maps guide, shared Google Maps list, or Google Maps export; Graviti preserves the source, organizes it by place and interest, and reveals the destinations and experiences that repeatedly draw you.

## Current MVP

- Fast in-app capture and an iOS Share Extension
- SwiftData persistence with original source preservation
- Apple Maps and Google Maps place links
- Apple Maps guide, shared Google Maps list link, and Google Takeout CSV imports
- Photo and screenshot storage with optional descriptions and on-device Vision text recognition
- Asynchronous place resolution and editable enrichment
- Cached link titles, descriptions, site names, and preview images
- Library views for destinations, places, saves, and a map
- Global search across saved items, destinations, interests, places, and MapKit results
- Versioned local library backup and restore, including saved photos
- Bulk saved-item deletion and bulk place cleanup
- Gravity visualization with adaptive geographic resolution and an ambient, noninteractive starfield
- Interest patterns across categories and geographic areas
- Destination Fit recommendations with evidence confidence
- Accessibility, Reduce Motion support, and localization infrastructure
- Focused dogfood datasets for scenery, culture, food, water, and mixed interests

Graviti's local MVP is complete and verified. External distribution is optional future work. See [Product Specification](docs/PRODUCT_SPEC.md), [Architecture](docs/ARCHITECTURE.md), [Data Model](docs/DATA_MODEL.md), [MVP Steering](docs/MVP_STEERING.md), [MVP Release Audit](docs/MVP_RELEASE_AUDIT.md), [Privacy](docs/PRIVACY.md), and [Optional TestFlight Preparation](docs/TESTFLIGHT.md).

## Screenshots

| Gravity Field | Explore |
| --- | --- |
| ![A city-level Gravity Field built from a diverse saved-place library](docs/screenshots/gravity-field.png) | ![Explainable destination Fit recommendations and recurring interests](docs/screenshots/explore-fit.png) |

| Places | Saves |
| --- | --- |
| ![The Places Library with review and repeated-place tools](docs/screenshots/library-places.png) | ![The rich Saves Library with generated descriptions and categories](docs/screenshots/library-saves.png) |

## Project structure

```text
graviti/
├── graviti/                  iOS application
│   ├── App/                  app composition and observable library
│   ├── Data/                 SwiftData storage and repositories
│   ├── DesignSystem/         colors, typography, and reusable visuals
│   ├── Domain/               models, parsers, scoring, and enrichment
│   ├── Features/             Home, Capture, Library, Explore, and Search
│   └── Integrations/         MapKit and Share Extension support
├── GravitiShareExtension/    iOS share target
├── gravitiTests/             deterministic XCTest coverage
└── graviti.xcodeproj/
docs/                         product and engineering contracts
test-data/                    import and recommendation dogfood fixtures
```

Views depend on domain models and repository interfaces. SwiftData and provider-specific behavior remain behind adapters. Capture completes before place lookup or enrichment, so source material is never held hostage by background processing.

## Requirements

- macOS with Xcode 26.2 or newer
- iOS 18.0 or newer simulator or device
- An Apple development team for device signing and Share Extension testing

## Build

Open `graviti/graviti.xcodeproj`, select the `graviti` scheme, and run on an iPhone simulator.

Command-line build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project graviti/graviti.xcodeproj \
  -scheme graviti \
  -sdk iphonesimulator \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/graviti-derived \
  CODE_SIGNING_ALLOWED=NO build
```

## Tests

The shared `graviti` scheme includes the `gravitiTests` target. Run it from Xcode with **Product → Test**, or provide an installed simulator destination to `xcodebuild test`.

Current regression tests cover sparse Fit evidence, semantic destination specificity, duplicate evidence discounting, independent place confidence, avoided interests, parsers, deterministic crowded Orbit layout, interest profiles, backup round trips, OCR, link metadata, bulk deletion, and rich-artifact persistence through the real SwiftData repository.

## Test data

Debug builds expose a dataset switcher at the bottom of the Save tab. Each dataset can be loaded, inspected across Home, Explore, and Library, and removed without affecting other saved items. Source CSV fixtures live in `test-data/dogfood` and are mirrored in the app resources.

## Data status

The MVP beta is local only. Data remains on the device unless the user exports a versioned JSON backup from Library > Actions. Backups include saved records, derived details, place matches, and saved photo bytes, and can be restored without duplicating existing records. Sign in and cloud sync are post-MVP options.
