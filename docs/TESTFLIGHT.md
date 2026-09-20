# TestFlight Preparation

This document contains the copy and checks for Graviti's local-only MVP beta.

## Beta app description

Graviti is a private travel-interest library. Save places, links, notes, screenshots, photos, Apple Maps guides, and Google Maps exports. Graviti organizes them into destinations and interests, shows where your saves have the most Gravity, and suggests future destinations using explainable Fit signals.

## What to test

- Complete onboarding and save a place through Search.
- Save a link, note, and photo inside the app.
- Share a link or image to Graviti from another app, then reopen Graviti.
- Import an Apple Maps guide or Google Takeout Saved CSV.
- Review and correct a place that needs help.
- Edit a saved item's description, category, and interests.
- Inspect Destinations, Places, Saves, and Map in Library.
- Select and remove several place matches; confirm their original saves remain.
- Select and delete several saved items; confirm Gravity and interest patterns update.
- Compare Home and Explore with sparse and diverse libraries.
- Mark a recommendation Not for me and save another recommendation.
- Export a backup, add another item, restore the backup, and confirm existing records are not duplicated.
- Test Dynamic Type, VoiceOver, Reduce Motion, airplane mode, and relaunch after force quitting.

## Data promise shown to testers

This beta stores its Library on the device. Graviti does not require an account and does not sync to a Graviti server. Network requests occur when the tester uses Apple MapKit search or place resolution, when Graviti fetches a preview from a saved public link, or when the tester opens an external link. A backup leaves Graviti only when the tester explicitly exports it. Testers should export a backup before deleting the app because uninstalling removes the local Library.

## Current limitations

- Library data does not sync between devices.
- Place search, place resolution, Apple Maps guide import, and link previews require a network connection.
- Destination recommendations use a small reviewed offline catalog during the MVP beta.
- Some imported or shared items may require manual place matching.

## Latest simulator validation

Validated on September 20, 2026 with an iPhone 17 Pro simulator running iOS 26.2:

- All 46 automated tests passed, including import parsing, Fit scoring, persistence, backup restore, and offline save preservation.
- A clean signed Debug build completed without warnings. The app and Share Extension generated the same App Group entitlement.
- Safari shared a live National Park Service link through the Graviti Share Extension. Reopening Graviti imported it into Library > Saves and displayed the shared-save confirmation.
- Home, Explore, and every Library mode were exercised with 14 varied saves covering scenery, national parks, architecture, history, seafood, coastlines, wildlife, museums, hiking, and drinks.
- Direct bubble switching, bulk place removal confirmation, and bulk save deletion confirmation were exercised without committing destructive test actions.
- Maximum Dynamic Type, increased contrast, right-to-left layout, expanded pseudo-localized strings, and Reduce Motion were inspected in Simulator.
- Spanish coverage was completed for the app and Share Extension. Home, Explore, Library, canonical interest names, singular/plural counts, accessibility labels, and bulk-selection copy were inspected in Spanish without clipping.
- An unsigned arm64 Release archive was produced with an iOS 18 minimum, both privacy manifests, non-exempt encryption disabled, exactly the two registered Sora fonts, and no dogfood CSVs.

Still required before external TestFlight distribution:

- Run the core flow on a physical signed device and on the iOS 18 minimum runtime.
- Publish the privacy policy at a stable public URL.
- Supply the feedback email and App Store Connect review contact.
- Produce and upload the distribution archive in the owner's App Store Connect account.

## App Store Connect checklist

- Increment `CURRENT_PROJECT_VERSION` for every uploaded build.
- Archive a Release build with the app and Share Extension signed by the distribution team.
- Confirm both bundles contain `PrivacyInfo.xcprivacy`.
- Confirm `ITSAppUsesNonExemptEncryption` is `false` in the app bundle.
- Confirm the archive contains no dogfood CSVs and only the registered Sora font weights.
- Confirm the production app icon appears correctly in standard, dark, and tinted Home Screen appearances.
- Supply the beta description, feedback email, review contact, and What to Test text.
- Publish `docs/PRIVACY.md` at a stable URL and enter it as the privacy policy URL.
- Answer App Privacy with **No, we do not collect data from this app** while the implementation remains local-only and contains no telemetry SDK.
- State the local-only data promise and backup instruction in every beta build's notes.
- Complete the device, accessibility, localization, offline, import, backup, and data-loss checks above before inviting external testers.
- Run the core flow on both the iOS 18 minimum and the latest iOS release before inviting external testers.
