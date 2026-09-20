# Graviti Privacy

Graviti is a private, local-first travel-interest library.

_Effective September 20, 2026._

## Data stored on the device

Graviti stores saved links, notes, photos, screenshots, place matches, generated descriptions, interests, recommendation feedback, and app preferences on the device. The Share Extension uses an App Group container to pass items that a person explicitly shares into Graviti. A person can export a backup through Library > Actions; Graviti does not upload that backup.

## Network requests

Graviti makes network requests only to provide features a person invokes:

- MapKit searches and resolves places through Apple services.
- Opening an original link uses the destination website selected by the person.
- Link preview processing requests a saved public webpage and, when present, its preview image. The destination website receives the normal network information required for that request, such as the device's IP address.

On-device Vision text recognition reads saved photos and screenshots without uploading the image for recognition.

## Data collection and tracking

Graviti has no account system, advertising SDK, analytics SDK, or crash-reporting SDK in the local-only MVP. Graviti does not collect app data on a developer-controlled server and does not track people across apps or websites.

## Control and deletion

A person can edit inferred details, remove a place association, delete individual or multiple saves, and export or restore a local backup. Deleting a save removes its locally stored record and its associated local photo when applicable.

## Contact

For privacy questions, support requests, or deletion help, [contact Graviti through the public support tracker](https://github.com/rhysgilk/graviti/issues/new). Do not include private or sensitive information in a public support request.
