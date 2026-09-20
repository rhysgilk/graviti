# TestFlight Preparation

This document contains the copy and checks for Graviti's local-only MVP beta.

## Beta app description

Graviti is a private travel-interest library. Save places, links, notes, screenshots, photos, Apple Maps guides, shared Google Maps lists, and Google Maps exports. Graviti organizes them into destinations and interests, shows where your saves have the most Gravity, and suggests future destinations using explainable Fit signals.

## What to test

- Complete onboarding and save a place through Search.
- Save a link, note, and photo inside the app.
- Share a link or image to Graviti from another app, then reopen Graviti.
- Paste an Apple Maps guide or shared Google Maps list link and confirm its places import. Import a Google Takeout Saved CSV.
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
- Place search, place resolution, Apple Maps and Google Maps list imports, and link previews require a network connection.
- Shared Google Maps list import depends on Google's public list response format and may need maintenance if Google changes it.
- Destination recommendations use a small reviewed offline catalog during the MVP beta.
- Some imported or shared items may require manual place matching.

## Latest simulator validation

Validated on September 20, 2026 with an iPhone 17 Pro simulator running iOS 26.2 and an iPhone 16 Pro simulator running iOS 18.6:

- All 53 automated tests passed on iOS 26.2 and iOS 18.6, including import parsing, Fit scoring, persistence, backup restore, offline save preservation, safe map URL generation, and deterministic ten-destination Gravity Field layout.
- A clean signed Debug build completed without warnings. The app and Share Extension generated the same App Group entitlement.
- Safari shared a live National Park Service link through the Graviti Share Extension. Reopening Graviti imported it into Library > Saves and displayed the shared-save confirmation.
- Home, Explore, and every Library mode were exercised with 14 varied saves covering scenery, national parks, architecture, history, seafood, coastlines, wildlife, museums, hiking, and drinks.
- Direct bubble switching, bulk place removal confirmation, and bulk save deletion confirmation were exercised without committing destructive test actions.
- A 30-save crowded-library fixture was exercised across Home, Explore, and Library. Home stayed within its ten-label budget with readable long names, Library exposed bulk selection, Explore synthesized varied interests with 66 FIT recommendations, and the imported library persisted after termination and relaunch.
- A live shared Google Maps list link imported all 28 places from the supplied “Vanessa and Rhys” guide, preserved the guide title, and continued place enrichment in the background.
- Home's white and yellow stars remain behind the Gravity Field, ignore input, and pulse gently; Reduce Motion keeps them static. The small Graviti wordmark animates both colored i dots.
- Library and Search use Sora for navigation, tabs, segmented controls, search fields, and screen content.
- Saturated Gravity ties now prefer destinations with more saved items before falling back to a stable name order, so a smaller destination cannot displace stronger evidence merely because both scores reached 100.
- Maximum Dynamic Type, increased contrast, right-to-left layout, expanded pseudo-localized strings, and Reduce Motion were inspected in Simulator.
- Spanish coverage was completed for the app and Share Extension. Home, Explore, Library, canonical interest names, singular/plural counts, accessibility labels, and bulk-selection copy were inspected in Spanish without clipping.
- The iOS 18.6 minimum runtime was validated on an iPhone 16 Pro simulator. MapKit search found and saved Nishiki Market, Home generated its Gravity destination, Library showed the enriched save, and the record persisted after force quit and relaunch.
- The public privacy policy URL returned HTTP 200 and exposed the current effective date and support route without repository authentication.
- An unsigned arm64 Release archive was produced with an iOS 18 minimum, both privacy manifests, non-exempt encryption disabled, exactly the two registered Sora fonts, and no dogfood CSVs.

Still required before external TestFlight distribution:

- Run the core flow on a physical signed device.
- Supply the feedback email and App Store Connect review contact.
- Produce and upload the distribution archive in the owner's App Store Connect account.

Public privacy policy URL: <https://github.com/rhysgilk/graviti/blob/main/docs/PRIVACY.md>

## App Store Connect checklist

- Increment `CURRENT_PROJECT_VERSION` for every uploaded build.
- Archive a Release build with the app and Share Extension signed by the distribution team.
- Confirm both bundles contain `PrivacyInfo.xcprivacy`.
- Confirm `ITSAppUsesNonExemptEncryption` is `false` in the app bundle.
- Confirm the archive contains no dogfood CSVs and only the registered Sora font weights.
- Confirm the production app icon appears correctly in standard, dark, and tinted Home Screen appearances.
- Supply the beta description, feedback email, review contact, and What to Test text.
- Enter <https://github.com/rhysgilk/graviti/blob/main/docs/PRIVACY.md> as the privacy policy URL.
- Answer App Privacy with **No, we do not collect data from this app** while the implementation remains local-only and contains no telemetry SDK.
- State the local-only data promise and backup instruction in every beta build's notes.
- Complete the device, accessibility, localization, offline, import, backup, and data-loss checks above before inviting external testers.
- Run the core flow on both the iOS 18 minimum and the latest iOS release before inviting external testers.
