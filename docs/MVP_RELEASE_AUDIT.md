# Graviti MVP Release Audit

**Audit date:** September 20, 2026

**Simulator-validated app commit:** `2c0a0fd`

**Signed archive validation commit:** `cdcc5b4`

**Release candidate:** 1.0 (1)

This audit maps the local MVP Definition of Done to current evidence. External distribution is outside the completion criteria.

The complete implemented feature inventory, data behavior, limitations, and network boundaries are maintained in [CAPABILITIES.md](CAPABILITIES.md).

## Automated release evidence

- 67 of 67 tests passed with no failures or skips on an iPhone 16 Pro simulator running iOS 18.6.
- 67 of 67 tests passed with no failures or skips on an iPhone 17 Pro simulator running iOS 26.2.
- 62 of 62 tests passed with no failures or skips on a physical iPhone 13 Pro Max running iOS 26.3.1.
- A signed arm64 Release archive of commit `cdcc5b4` completed Xcode's store validation phase. The later `2c0a0fd` change affects MapKit query scoping and passed both simulator suites.
- `scripts/verify-release-archive.sh` passed every package check: bundle identifiers, matching app and extension versions, iOS 18 minimum, encryption declaration, both privacy manifests, exactly two Sora fonts, no CSV fixtures, nested signatures, and matching App Group entitlements.
- The only archive warning is expected: the available seven-day Apple Development profile is suitable for device testing but not TestFlight distribution.

## Definition of Done evidence

| Requirement | Status | Evidence |
| --- | --- | --- |
| Clear local-only data promise and reliable backup/restore | Verified | Onboarding and Library Actions expose the promise. Backup tests cover rich records, embedded media, schema rejection, and duplicate-ID rejection. |
| A new user understands Graviti without a tutorial | Verified | Onboarding introduces saving, organization, Gravity, and local ownership. The primary tabs expose conventional alternatives to the spatial Home view, and preliminary physical-device testing passed. |
| Capture inside and outside the app | Verified | Link, note, photo, place, CSV, `.webloc`, Apple guide, and Google list capture are implemented. A live Safari Share Extension save was completed and reopened in Library. |
| Saves appear immediately | Verified | Capture preserves the source before background work. Live link, Share Extension, Apple guide, and Google list checks showed immediate Library records. |
| Background processing does not block capture | Verified | Processing and metadata state are persisted separately. Interrupted enrichment and transient map lookup retry tests pass. |
| Places and geographic hierarchy resolve reliably enough for real use | Verified for beta | Live Google and Apple collections resolved through MapKit. The supplied Apple “Matcha” guide resolved 19 of 19 identifiers; the supplied Google list matched 25 automatically and routed three ambiguous names to review. Imported places retain every distinct collection title as enrichment evidence and expose that history in Saved Item detail. |
| Low-confidence cases can be corrected | Verified | Needs Your Help and place review flows were exercised; user-selected matches are protected from automated refresh. |
| Duplicates can be reconciled | Verified | Stable URL and place identity prevent repeated imports. Reimporting the Apple guide avoided all 19 duplicates while backfilling collection context; Google reimport reports duplicates and refreshes eligible older records without replacing user-selected matches. Bulk repeated-place cleanup preserves source saves. |
| Library supports Destinations, Places, Saves, and Map | Verified | All four modes were exercised with varied and crowded datasets; the last mode persists. |
| Gravity Field handles sparse and large libraries | Verified | Deterministic layout tests cover empty through ten-destination fields. A 30-save crowded library remained readable within the ten-label budget. |
| Adaptive geographic resolution works | Verified | Tests cover country collapse, city expansion, state grouping, missing-region fallback, concentration, and label budgets. Automatic and explicit resolution modes were exercised. |
| Destination Gravity updates correctly | Verified | Live imports changed Home destinations after persistence and relaunch. Orbit builder tests cover stable geographic identity and ranking behavior. |
| Explore produces useful interest-based recommendations | Verified for local MVP catalog | Diverse fixtures produced varied recommendations and explanations. Each recommendation builds a live Fit Guide grouped by its matched patterns. Destination regions are resolved before category searches and enforced as required, preventing city records and results from another region. Live New York, Kyoto, and Mexico City guides returned relevant local venues; saving a result created a retrievable guide in Explore. |
| Recommendation data does not contaminate explicit interest | Verified | Save Destination and Not for Me are persisted separately. Fit tests cover exclusions and avoided interests while Gravity remains based on explicit saves. |
| Saved media is preserved and browsable | Verified | Photo storage, thumbnails, detail views, OCR provenance, backup round trips, and restored embedded media are covered. |
| Accessibility requirements are tested | Verified in Simulator | VoiceOver labels and ordering, Dynamic Type, increased contrast, Reduce Motion, right-to-left layout, and large pseudo-localized strings were inspected. Conventional Library and Search access remains available. |
| Localization architecture functions | Verified | String catalogs cover the app and Share Extension. Spanish Home, Explore, Library, canonical interests, counts, accessibility labels, and selection copy were inspected. |
| Core Library data remains accessible offline | Verified | SwiftData is authoritative. Tests confirm failed network lookup preserves the original save and resumes later. Backup export remains explicit and local. |
| Substantial real-world dogfooding is complete | Verified for internal beta | Focused datasets, a 30-save stress library, live MapKit search, the supplied Google list, the supplied Apple guide, web metadata, Share Extension capture, force quit, and relaunch were exercised. |
| Major crashes and data-loss bugs are resolved | Verified to current coverage | Both runtime suites pass; batch deletion is atomic; persistence, backup, migration, retry, and force-quit checks pass. No known crash or data-loss defect remains open. |
| Repository documentation matches the implementation | Verified | README links to a complete capability reference. Architecture and data-model documents describe the actual SwiftData/App Group system and separate future server, sync, AI, and social direction from shipped behavior. |

## Optional future distribution work

1. **Apple Developer Program membership:** team `V9W8HRDJQT` currently has no App Store Connect provider and cannot create App Store provisioning profiles for either bundle. The account holder must enroll or associate the team with an active provider.
2. **Distribution export:** rerun `scripts/export-testflight.sh` after enrollment. This creates a locally exported IPA without uploading it.
3. **Additional device confidence:** preliminary manual testing has passed; the current app plus Share Extension were provisioned, installed, launched, and observed running on an iPhone 13 Pro Max with iOS 26.3.1; all 62 tests passed on that device; and a post-test screenshot confirmed the retained Library rendered on Home. The extended hands-on checklist in `docs/TESTFLIGHT.md` can be used before any future wider distribution.
4. **TestFlight metadata:** provide the feedback email and App Store Connect review contact.
5. **Upload authorization:** upload the verified distribution build only after the owner reviews the final archive and metadata.

The local-only MVP contract is complete. The items above apply only if external distribution is chosen later and do not block local completion.
