# Graviti Privacy

Graviti is a private, local-first travel-interest library.

_Effective September 20, 2026._

## Data stored on the device

Graviti stores the data needed to provide its features locally:

- saved links and original text
- notes and optional photo descriptions
- photos and screenshots
- on-device detected text
- place matches and geographic coordinates
- generated descriptions, categories, interests, confidence, and provenance
- user corrections
- Apple Maps, Google Maps, and Fit Guide collection membership
- recommendation preferences, saved destinations, Not for Me exclusions, and visited feedback
- app display preferences

The main Library is stored with SwiftData. Images and Share Extension envelopes use the app's private App Group container.

Graviti does not require an account and does not synchronize the Library to a Graviti-operated server.

## Backups

A person can export a versioned JSON backup through Library → Actions. The backup includes Artifact records, place matches, generated and edited details, source collection history, cached link details, embedded saved image bytes, Explore preferences, saved destinations, Not for Me exclusions, and visited feedback.

The backup leaves Graviti only when the person chooses an export destination through the system file interface. Graviti does not upload exported backups.

Current exports use backup schema version 3. Graviti can also restore version 2 backups without visited feedback and version 1 backups without Explore preferences. Saved places inside Fit Guides retain their guide membership because that membership belongs to the Artifact record.

Deleting Graviti removes its local Library and App Group media. Export a backup before uninstalling if the Library should be retained.

## Network requests

Graviti makes network requests only for invoked features or eligible saved content:

- Apple MapKit searches for places and resolves saved Map links.
- Fit Guides use Apple MapKit to search for points of interest and physical features inside the recommended destination.
- Public Apple Maps guide links are retrieved so their place identifiers and title can be imported.
- Public shared Google Maps list links are retrieved from Google so their title, places, notes, addresses, and coordinate hints can be imported.
- Supported Apple and Google short links may be expanded to determine their destination.
- Saved public webpages may be requested to cache a title, description, site name, resolved URL, and bounded preview image.
- Opening an original link or Apple Maps result contacts the selected external service.
- Choosing Open Google Takeout opens Google's website.

Those providers and destination websites receive normal network information needed to serve the request, such as the device's IP address. Their own privacy terms apply.

Public-link metadata fetching uses an ephemeral, cookie-free session and blocks private, loopback, and link-local targets. Collection importers validate provider hosts and bound response sizes.

## On-device processing

Apple Vision text recognition reads saved photos and screenshots on the device. Graviti does not upload an image for OCR.

The current description, category, interest, Gravity, Fit, and layout systems run in the app. There is no remote Graviti AI service in the local MVP.

## Data collection and tracking

Graviti has no:

- account system
- advertising SDK
- analytics SDK
- crash-reporting SDK
- tracking domains
- Graviti-operated data collection backend

The app and Share Extension privacy manifests declare no collected data and no tracking.

## Control and deletion

A person can:

- edit a generated description, category, interests, or note
- replace or remove a place match
- delete one saved item
- select and atomically delete multiple saved items
- select and remove multiple place associations while preserving their source saves
- remove previously recorded trip feedback
- export and restore a backup

Deleting a saved image removes its local file after the Artifact record is deleted. Derived Places, Gravity, patterns, and recommendations are recalculated from the remaining Library.

## Permissions

Graviti uses the system photo picker when a person chooses an image. The MVP does not require continuous background location access and does not request location for passive tracking.

## Contact

For privacy questions, support requests, or deletion help, [contact Graviti through the public support tracker](https://github.com/rhysgilk/graviti/issues/new). GitHub issues are public; do not include private or sensitive information.
