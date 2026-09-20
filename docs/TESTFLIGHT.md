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

## App Store Connect checklist

- Increment `CURRENT_PROJECT_VERSION` for every uploaded build.
- Archive a Release build with the app and Share Extension signed by the distribution team.
- Confirm both bundles contain `PrivacyInfo.xcprivacy`.
- Confirm `ITSAppUsesNonExemptEncryption` is `false` in the app bundle.
- Supply the beta description, feedback email, review contact, and What to Test text.
- Publish `docs/PRIVACY.md` at a stable URL and enter it as the privacy policy URL.
- Answer App Privacy with **No, we do not collect data from this app** while the implementation remains local-only and contains no telemetry SDK.
- State the local-only data promise and backup instruction in every beta build's notes.
- Complete the device, accessibility, localization, offline, import, backup, and data-loss checks above before inviting external testers.
