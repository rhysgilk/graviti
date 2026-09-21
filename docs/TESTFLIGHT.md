# TestFlight Preparation

This document is optional future distribution guidance. Graviti's local MVP is complete without TestFlight or App Store Connect work.

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
- Build Fit Guides for New York City and then at least one international destination such as Kyoto or Mexico City. Confirm every result is a real place within the selected destination, sections follow the matched patterns, and the destination itself is not returned as a venue.
- Save a place from two different Fit Guides or imported collections and confirm one canonical place retains both source memberships.
- Export a backup, add another item, restore the backup, and confirm existing records are not duplicated.
- Test Dynamic Type, VoiceOver, Reduce Motion, airplane mode, and relaunch after force quitting.

## Data promise shown to testers

This beta stores its Library on the device. Graviti does not require an account and does not sync to a Graviti server. Network requests occur for Apple MapKit search and place resolution, public Apple Maps guide and Google Maps list imports, public-link previews, short-link expansion, and links the tester chooses to open. On-device Vision OCR does not upload images. A backup leaves Graviti only when the tester explicitly exports it. Testers should export a backup before deleting the app because uninstalling removes the local Library.

## Current limitations

- Library data does not sync between devices.
- Place search, place resolution, Apple Maps and Google Maps list imports, and link previews require a network connection.
- Shared Google Maps list import depends on Google's public list response format and may need maintenance if Google changes it.
- Apple and Google collection links must be publicly accessible.
- Destination recommendations use a small reviewed offline catalog during the MVP beta.
- Fit Guide ordering follows Apple Maps relevance; MapKit does not provide Graviti with a review score to display or sort directly.
- Some imported or shared items may require manual place matching.
- Backup schema version 2 includes Explore preferences, Save Destination, and Not for Me. Older version 1 backups still restore their Library content but do not change current Explore settings. Places saved inside Fit Guides keep their guide membership in either version.

## Latest simulator validation

Validated on September 20, 2026 with an iPhone 17 Pro simulator running iOS 26.2 and an iPhone 16 Pro simulator running iOS 18.6:

- All 91 automated tests passed on iOS 18.6 and iOS 26.2 simulators. Coverage includes import parsing and migration, Fit scoring, destination-catalog validation and motif generalization, region-scoped Fit Guide search and fallback behavior, Fit Guide grouping and persistence, backup v1 compatibility and v2 Explore-state restore, offline save preservation and recovery, safe map URL generation, deterministic ten-destination Gravity Field layout, evidence-based Gravity Insights, varied-evidence Destination Readiness, and fine-grained semantic provenance.
- Clean signed Debug and Release archive builds completed. The app and Share Extension generated the same App Group entitlement.
- Safari shared a live National Park Service link through the Graviti Share Extension. Reopening Graviti imported it into Library > Saves and displayed the shared-save confirmation.
- Home, Explore, and every Library mode were exercised with 14 varied saves covering scenery, national parks, architecture, history, seafood, coastlines, wildlife, museums, hiking, and drinks.
- Direct bubble switching, bulk place removal confirmation, and bulk save deletion confirmation were exercised without committing destructive test actions.
- A 30-save crowded-library fixture was exercised across Home, Explore, and Library. Home stayed within its ten-label budget with readable long names, Library exposed bulk selection, Explore synthesized varied interests with 66 FIT recommendations, and the imported library persisted after termination and relaunch.
- A live shared Google Maps list link imported all 28 places from the supplied “Vanessa and Rhys” guide, preserved the guide title, and continued place enrichment in the background.
- The supplied live Apple Maps “Matcha” guide decoded 19 unique identifiers, resolved all 19 through MapKit, imported all 19 through the Save screen across 7 cities in 1 country, and persisted after force quit. Reimporting reported 19 duplicates, backfilled the guide title into all 19 older records, and created no additional places. A generic venue then regenerated as “saved for matcha” with a Matcha interest, and that context persisted after a cold relaunch.
- Imported places preserve multiple distinct guide or list titles when the same venue appears in more than one collection. Saved Item detail shows the retained source history, while generated suggestions refresh without replacing user-edited details.
- Google list imports retain address and coordinate hints for place resolution. A live 28-place check matched 25 automatically, left 3 ambiguous names for review, and had no lookup failures.
- Re-importing the same Google list upgrades unresolved items created by older builds in place and reports how many place details were refreshed without overwriting user-matched places.
- Re-importing a known map collection does not add another generic guide wrapper to Library.
- A saved Apple Maps guide or Google Maps list can retry or refresh its places directly from Saved Item detail. The real collection title replaces the generic Maps label. Upgraded Google lookup hints survived force quit and relaunch; the next import reported only duplicates and no redundant refreshes.
- Transient map lookup failures retry automatically when processing resumes, while the original save remains visible throughout.
- Home's white and yellow stars remain behind the Gravity Field, ignore input, and pulse gently; Reduce Motion keeps them static. The small Graviti wordmark animates both colored i dots.
- A New York Fit recommendation produced live Apple Maps suggestions grouped under Matcha, Tea, Museums, and Coffee. Saving Matcha 108 added it to a persistent New York City Fit Guide, which reopened from Explore with the saved place intact.
- Kyoto and Mexico City Fit Guides were exercised after New York to verify repeated and international searches. Kyoto returned local matcha and tea venues, while Mexico City returned local museums including Templo Mayor Museum and Museo Nacional de Arte instead of the city itself. Fit Guide searches now resolve and cache the destination region, require POI and physical-feature results to remain within it, and retry an empty narrow category with a broader category term.
- Library and Search use Sora for navigation, tabs, segmented controls, search fields, and screen content.
- Saturated Gravity ties now prefer destinations with more saved items before falling back to a stable name order, so a smaller destination cannot displace stronger evidence merely because both scores reached 100.
- Maximum Dynamic Type, increased contrast, right-to-left layout, expanded pseudo-localized strings, and Reduce Motion were inspected in Simulator.
- Spanish coverage was completed for the app and Share Extension. Home, Explore, Library, canonical interest names, singular/plural counts, accessibility labels, and bulk-selection copy were inspected in Spanish without clipping.
- The iOS 18.6 minimum runtime was validated on an iPhone 16 Pro simulator. MapKit search found and saved Nishiki Market, Home generated its Gravity destination, Library showed the enriched save, and the record persisted after force quit and relaunch.
- A device-specific Debug build from the current source, including the Share Extension, was provisioned for and installed on an iPhone 13 Pro Max running iOS 26.3.1. Device services confirmed installation, successful launch, and a live Graviti process after launch. The full 62-test suite then passed on the physical phone with no failures or skips. After restoring the normal build, an Xcode device screenshot confirmed that Home reopened with the retained real Library and a readable ten-destination Gravity Field.
- The public privacy policy URL returned HTTP 200 and exposed the current effective date and support route without repository authentication.
- A signed arm64 Release archive was produced with an iOS 18 minimum, matching app and extension versions, both privacy manifests, non-exempt encryption disabled, exactly the two registered Sora fonts, no dogfood CSVs, valid nested signatures, and matching App Group entitlements.
- The current archive uses a seven-day Apple Development provisioning profile. It verifies the packaged release contents but is not eligible for TestFlight upload; the upload archive must use App Store distribution provisioning.

If external TestFlight distribution is chosen later:

- Complete the remaining hands-on core-flow checklist on the provisioned physical device. Initial manual testing and automated install/launch verification have passed.
- Supply the feedback email and App Store Connect review contact.
- Enroll or associate team `V9W8HRDJQT` with an App Store Connect provider that can create App Store provisioning profiles. The September 20 export attempt reached Apple's signing service but reported no provider for the account and no permission to create profiles for either bundle.
- Produce and upload the distribution archive in the owner's App Store Connect account after that account gate is resolved.

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

## Archive verification

After archiving in Xcode, run the repository check against the generated archive:

```sh
./scripts/verify-release-archive.sh /path/to/graviti.xcarchive
```

The default mode verifies bundle identifiers, versions, minimum OS, encryption metadata, privacy manifests, fonts, absence of CSV fixtures, nested code signatures, and the shared App Group. A development-signed archive passes these package checks with a warning.

Before upload, require a distribution provisioning profile:

```sh
./scripts/verify-release-archive.sh /path/to/graviti.xcarchive --require-distribution
```

The upload gate fails for development provisioning so a locally installable archive cannot be mistaken for a TestFlight-ready archive.

To have Xcode re-sign an archive and export an App Store Connect IPA without uploading it, run:

```sh
./scripts/export-testflight.sh /path/to/graviti.xcarchive
```

The script first runs the package checks, refuses to reuse an existing export directory, asks Xcode for automatic App Store signing, and leaves the IPA in a timestamped directory under `/tmp`. Upload remains a separate, deliberate step.
