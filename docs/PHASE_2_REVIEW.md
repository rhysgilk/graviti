# Phase 2 Product Review

**Captured:** September 20, 2026

**Role:** Advisory review that informed the maintained [Post-MVP Roadmap](POST_MVP_ROADMAP.md). The roadmap controls current status and ordering.

I went through the current main branch again, including the new capability/release/steering docs, the recent commits through 57932d4, the test inventory, and the current Figma file. My conclusion is pretty different from a few days ago:

Graviti’s MVP is actually done. At this point I would stop treating the project as “finish the MVP” and formally move it into Beta → Learn → V1.1.

You closed essentially every gap I flagged last time: OCR, arbitrary-link metadata, global search, rich Saves, improved geographic resolution, persisted recommendation feedback, backup/restore, tests, repo hygiene, coordinator extraction, Google/Apple collection importing, Fit Guides, localization, accessibility hardening, physical-device testing, release archive checks, privacy docs, etc. The repo now documents 67 passing tests on both iOS 18.6 and 26.2, a physical-device suite, backup/media round trips, Share Extension validation, crowded Gravity Field testing, and real Apple/Google import testing. That is a serious amount of validation. README · MVP release audit · Capability reference

The biggest gap now is actually the Figma

I inspected the Figma file too. The version accessible there currently only exposes 01 — Core Experience, and it has fallen pretty far behind the real product.

For example, the Figma still contains:

a Profile tab instead of the current Search tab
the old simplistic Library
the old Explore concept rather than Fit + confidence + Fit Guides
the old Save/Import concept
older copy such as “Why it pulls you”
no backup/restore or local-data controls
no global Search
no Fit Guides
no OCR/review provenance
no Apple/Google collection handling
no current Gravity resolution controls
no current rich Saves implementation
none of the release/beta states

Meanwhile the actual app has blown way past it.

So before designing more features, I would create a new Figma page:

05 — Current MVP / V1.0

and make that the new design source of truth.

It should contain the actual current Home, selected destination, semantic zoom, Explore/Fit, Fit Guide, Save, Library Destinations/Places/Saves/Map, global Search, Saved Item detail, review/correction, onboarding, import summary, backup/privacy Actions, and empty/error states.

I would not delete the old Figma explorations. They’re useful product history. Just stop treating them as current.

After that, I’d start Code Connecting the highest-value reusable pieces: GravitiWordmark, GravityPlanet, destination card, save/media cards, interest tags, import summary, and maybe Fit cards. That would finally reconnect the design system and actual SwiftUI implementation.

What I would do next
Phase 1 — Freeze the local MVP

I’d formally tag what you have now rather than immediately piling another feature on top of it.

Something like:

v1.0-local-mvp

From that point on, anything new is explicitly post-MVP.

I would also do the one small data-portability improvement still called out in your own docs: backup schema v2 should include Save Destination, Not for Me, and Explore preference state. Right now those are local preferences but are excluded from backup schema v1. Your own capability reference explicitly lists that as a limitation. Capabilities §16

That feels more like completing the product's data-ownership promise than adding scope.

Phase 2 — Get this into people's hands

This is the most important next step.

I would not spend another month adding features without outside users.

Your remaining distribution blocker is basically administrative now: the Apple team does not currently have the App Store Connect provider/profile capability necessary for TestFlight distribution. The code side is already unusually well prepared: privacy manifests, archive verifier, TestFlight script, support/privacy docs, release icon, iOS 18 support, etc. TestFlight preparation

I would:

Resolve the Apple Developer / App Store Connect provider issue.
Build a fresh distribution archive from the final post-MVP commit.
Run the current 67-test suite on the physical device too—the physical run documented in the audit was still the earlier 62-test suite.
Invite maybe 5–10 people, not 100.

Give them almost no explanation beyond:

Save things you want to remember for travel and see what happens.

That will answer a much more valuable question than another code feature:

Do people naturally understand what Graviti is for?

What I would watch during beta

Not vanity metrics. These:

Can someone successfully get their first save into Graviti?
Do they understand why the Home bubbles exist?
Do they naturally use Share → Graviti?
How many saves need manual place correction?
Do imported collections feel magical or confusing?
Do people understand Gravity vs Fit without explanation?
Does Explore actually cause someone to say, “Oh shit, I would go there”?
Do Fit Guides make the recommendation actionable?
Does anyone care about the country/state/city resolution control?
What do people search for?
What do they expect when tapping a destination?
What do they try to save that Graviti can't handle?

Because you intentionally have no analytics SDK, I’d keep that privacy philosophy. TestFlight/Xcode crash reporting plus a Send Feedback action and perhaps an optional Copy Diagnostics report are enough for early beta.

Phase 3 — V1.1 should make Graviti more insightful, not broader

Your own MVP Steering Guide has good post-MVP ideas. I would narrow them into three product bets.

1. Make Home substantially smarter

This is the next feature area I’m most excited about.

Right now Gravity mostly tells you what is strongest.

Post-MVP Home should start telling you what changed.

You already have timestamps and the data necessary for things like:

Tokyo is gaining Gravity
+6 saves this month

Unexpected pull: Maine
Coast, seafood and forests keep showing up

Japan just split
Tokyo and Kyoto now have enough Gravity to stand on their own

Chicago has gone quiet
No new saves in 4 months

This was actually one of the strongest early Figma concepts, and now the backend/domain behavior exists to make it real rather than fake demo copy.

I'd call this Gravity Insights.

2. Bring back Destination Readiness

This is one idea from our earlier designs that isn't really present in the current MVP and I think is genuinely distinctive.

Not itinerary planning.

Something simpler:

Tokyo
Ready for a 4–5 day trip

because you've accumulated:

9 food saves
5 cultural experiences
4 neighborhoods
3 attractions
2 shopping ideas
enough geographic spread

or:

Providence
Strong weekend

or:

Madeira
Still taking shape
4 saved experiences, mostly scenery

That's a perfect Graviti feature because it answers:

“Do I have enough reasons to actually turn this interest into a trip?”

without turning the app into Wanderlog.

It gives Gravity an actionable consequence.

3. Make understanding more semantic

Your deterministic enrichment system is extremely good for an MVP, but your documentation correctly identifies its limit: it's still vocabulary-based. Post-MVP steering: Richer understanding

Today Graviti understands things like:

hiking
architecture
seafood
matcha

Eventually it should distinguish:

forest hiking vs desert hiking
rocky coastline vs beach resort
historic architecture vs contemporary architecture
specialty matcha dessert vs generic café
observation deck vs scenic natural viewpoint

I would investigate a privacy-preserving/on-device model-assisted enrichment layer while keeping your existing deterministic system as fallback.

And I would preserve one thing you already designed very well:

every inference has evidence, provenance and confidence.

No mysterious “AI says you're a beach person.”

Phase 4 — Recommendation quality before recommendation quantity

Your current reviewed destination catalog is intentionally small—roughly a couple dozen destinations. That's completely fine for MVP.

I would not immediately dump 5,000 cities into it.

Instead:

move destination knowledge into a versioned data resource rather than hard-coded Swift
attach reviewed strengths and provenance
build a larger evaluation fixture
slowly expand to maybe 50 → 100 → 250 destinations
evaluate rankings using your dogfood profiles
collect Not for Me / Save Destination feedback from beta users
calibrate confidence bands

Your steering guide is correct here: Fit should be evaluated on relevance + diversity + novelty + evidence confidence, not just matching tags.

Eventually Fit could include additional constraints:

travel time
season
no-car requirement
budget
weather preference
trip length

but only when you have reliable data for them.

One feature I'd add that isn't emphasized enough in the docs
Visited

At some point, Graviti needs to understand:

I wanted to go there, and then I actually went.

I'd add a lightweight:

Mark as visited

to a Place or destination.

Not trip tracking. Not itinerary history.

It gives you an incredibly valuable signal:

Saved
→ wanted to go

Visited + loved
→ recommendation system was right

Visited + disliked
→ recommendation system learned something

It also prevents a weird long-term future where someone has already traveled to Tokyo three times and Tokyo permanently dominates their “where should I go next?” universe.

Your data-model thinking already supports this kind of signal.

I would consider it a V1.1/V1.2 feature after beta.

Data sync: important, but I wouldn't build it first

The biggest utility limitation right now is obviously:

uninstall app → Library disappears unless exported

and:

no second-device sync

But you now have a robust local model and backup format, which gives you room to be deliberate.

I would not immediately build Supabase sync before beta.

First see whether users actually care.

If they do, then make the architectural decision intentionally:

Option A: CloudKit/iCloud

excellent fit for private Apple-only app
no separate account
aligns beautifully with Graviti's privacy positioning

Option B: Supabase/account sync

more portable
better future web/Android path
more infrastructure/account complexity

Your current docs wisely leave this post-MVP. Keep it that way until there's evidence.

Fit Guides are good enough for now

Codex went farther here than I expected.

You now have destination-scoped MapKit searches, pattern grouping, geographic validation, international testing, persistent membership, collection provenance, and duplicate-safe saving.

I wouldn't keep enhancing them immediately.

Later, good additions would be:

rename Guide
note on Guide
archive Guide
remove saved suggestion from Guide
maybe sort/reorder
eventually current ratings from a permitted provider

But those are not where I'd spend the next month.

Some smaller gaps I would clean up

The app is at the point where polish matters more than another giant subsystem.

I'd consider:

Backup schema v2, as mentioned above.
A proper Settings/About surface behind a small Home/avatar/settings affordance instead of Library Actions carrying every utility forever.
Physical-device manual testing of maximum Dynamic Type + VoiceOver on the current build, not just simulator inspection.
A lightweight feedback/support screen for beta.
Review network error states for Apple/Google imports on slow connections, not just outright failures.
Verify upgrades/migrations across at least one real prior SwiftData schema before App Store release.
Add screenshot/snapshot tests for a handful of high-value visual states if UI regressions become frequent.

I would not introduce a full settings tab.

The design roadmap I would put into Figma next

I'd make two new pages.

05 — Current MVP / V1.0

Actual source-of-truth screens:

Onboarding / local privacy promise
Gravity Field — sparse
Gravity Field — 10-destination stress state
selected destination
semantic geographic zoom
Gravity resolution menu
Explore
Fit detail
Fit Guide
Save
import result
Library — Destinations
Places
rich Saves
Map
Saved Item
Needs Your Help
global Search
Library Actions / backup / privacy

And I'd update the foundations board to match current behavior.

06 — V1.1 Concepts

Only four explorations initially:

Gravity Insights

Tokyo is gaining Gravity.

Destination Readiness

Strong for a 4–5 day trip.

Visited

You've been here. How was it?

Inference Evidence

Architecture
Detected from your photo caption, Apple Maps category and two saved notes.

Those feel like natural evolutions of Graviti rather than bolting random travel-app features onto it.

My preferred order from here

If this were my project, the roadmap would be:

NOW
│
├─ Freeze/tag local MVP
├─ Backup schema v2
├─ Bring Figma up to current app
├─ Resolve Apple distribution account
└─ TestFlight with 5–10 people

↓ LEARN

V1.1
│
├─ Gravity Insights
├─ Destination Readiness
├─ richer semantic enrichment
└─ visited / post-trip feedback

↓ LEARN

V1.2
│
├─ significantly broader Fit catalog
├─ Fit calibration from feedback
├─ better Fit Guide management
└─ optional cloud sync decision

↓ MUCH LATER

social / taste compatibility
shared guides
collaboration

And I would continue explicitly not building flights, hotels, itineraries, booking, reservations, public feeds, follower counts, or a chat assistant.

The app is interesting because it isn't those things.

The most important shift now is that you don't need Codex to keep proving it can add another feature. You need actual humans to start showing you which parts of Graviti they instinctively understand, which parts they completely misread, and which parts make them go wait, this is fucking cool. That should determine the next major build.