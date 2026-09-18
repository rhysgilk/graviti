PRODUCT_SPEC
# Graviti — MVP Product Specification

**Version:** 0.1  
**Status:** Draft / MVP Contract  
**Platform:** iOS  
**Product:** Graviti  
**Tagline:** *Save what pulls you.*

---

## 1. Product Promise

Graviti is a private travel-interest library that lets people save anything that makes them want to go somewhere, automatically organizes those saves geographically and by interest, and helps reveal which destinations are pulling them most strongly.

A user should be able to give Graviti a place, link, screenshot, photo, or shared piece of content without first deciding what trip, folder, city, or category it belongs to.

The core loop is:

> **Save something → Graviti understands it → Graviti organizes it → destinations accumulate Gravity → the user discovers where their interests are leading them.**

## 2. Problem Statement

People discover potential travel experiences constantly: restaurants, cafés, food and drinks, scenery, architecture, museums, attractions, shops, activities, social posts, screenshots, recommendations, and places found in Maps.

Those ideas are commonly scattered across Instagram saves, TikTok, screenshots, Apple Maps, Google Maps, Notes, messages, browser bookmarks, and photos.

Most travel-planning products begin after a user has selected a destination. Graviti serves the earlier stage:

> “I don't know where I'm going next, but I keep finding things around the world that I want to remember.”

The user should not have to manually maintain travel folders to make those saves useful.

## 3. Target MVP User

The primary MVP user:

- regularly saves interesting places or travel-related content
- has saves distributed across multiple apps or sources
- may not yet know where their next trip will be
- values discovering food, attractions, scenery, experiences, culture, and shopping
- wants organization without manually maintaining lists
- wants personalized destination discovery based on actual behavior

The MVP should work extremely well for one person maintaining a private travel universe. Social travel planning is out of scope for V1.

## 4. Core Jobs to Be Done

### Capture
> “I saw something interesting. Don't make me lose it.”

Saving should require almost no organizational work.

### Organize
> “Figure out where this belongs and what it is.”

Graviti should infer geography, category, interests, source, and relationships between saves.

### Surface
> “Show me what I've actually accumulated.”

Users should be able to browse by destination, place, source artifact, or map.

### Discover
> “Based on everything I've shown you, where should I consider going?”

Graviti should use explicit saves and preferences to surface relevant destinations without pretending recommendations are equivalent to things the user explicitly saved.

## 5. MVP Success Condition

The MVP succeeds if this workflow feels complete:

> A user encounters something interesting outside Graviti, shares or imports it, immediately receives confirmation that it is saved, and can later find that content correctly represented as an experience associated with a place, geographic destination, category, and set of interests.

That save should contribute appropriately to destination Gravity and eventually help Graviti surface useful destination insights.

If this loop does not work reliably, other features do not compensate for it.

## 6. Authentication and First Run

The user can:

- Sign in with Apple
- Sign in with Google
- optionally use email authentication if implementation cost remains low
- enter a lightweight first-run experience
- immediately import existing saves, add a photo/screenshot, search for a place, or skip setup

No long preference questionnaire is required before using the app.

### Brand motion

On Sign In and Start Your Orbit, the two dots above the `i` characters in `graviti` subtly alternate sizes:

- left dot: small → large → small
- right dot: large → small → large
- approximately 1.8 seconds
- ease-in-out
- autoreversing
- dot centers remain stationary
- size only changes
- Reduce Motion: static dots at different sizes

This motion is limited to brand-focused screens.

## 7. Capture

### Inside Graviti

Users can:

- search for a place
- paste a URL
- add a screenshot or photo
- manually create a save/place
- import supported existing saved-place data

### Outside Graviti

An iOS Share Extension allows supported content to be shared into Graviti.

The fundamental rule is:

> **Capture first. Organize later.**

The Share Extension must not require folders, trips, destinations, categories, or tags. An optional note may be added.

## 8. Save Behavior

Saving must succeed before automated processing finishes.

The user should receive immediate confirmation such as:

> **Saved to Graviti**

Processing happens asynchronously.

Artifact processing states:

- Saved
- Processing
- Processed
- Needs Review
- Failed

A processing failure must never cause the original artifact to disappear.

## 9. Core Information Model

Graviti preserves the distinction between:

### Artifact
The original thing supplied by the user: social post, URL, screenshot, photo, Maps link, or manual note.

### Experience
The specific thing that interested the user: try a matcha parfait, visit teamLab Planets, see a viewpoint, ride a scenic train.

### Place
The canonical physical location where an experience occurs.

### Geographic Area
A hierarchy such as Shinjuku → Tokyo → Japan or Boston → Massachusetts → United States.

### Interest
Concepts such as matcha, tea, ramen, anime, architecture, museums, or scenic trains.

One Artifact may produce multiple Experiences. Multiple Artifacts may refer to the same Place.

## 10. Geographic Organization

Users do not create geographic folders.

Graviti automatically associates Places with a hierarchy that can include:

- country
- state / province / region
- city
- district / neighborhood where useful

The Gravity Field uses **adaptive geographic resolution**. A visible planet is not always a city.

A single Home field may contain Japan, California, Montreal, Portugal, and Chicago at the same time.

## 11. Adaptive Geographic Resolution

Default mode: **Automatic**.

A geographic node remains grouped while child areas do not provide enough useful distinction.

Example: `Japan — 8 saves` may remain one planet.

As interest becomes concentrated, Japan may resolve into Tokyo, Kyoto, Osaka, and Uji.

The decision should consider:

- explicit-save count
- Gravity concentration among child areas
- number of meaningful child clusters
- available screen capacity
- relative importance compared with other destinations
- label legibility

The Gravity Field displays at most approximately **10 labeled destinations** at once. Lower-priority locations may appear as unlabeled background bodies.

Users may override Automatic resolution with:

- Countries
- States & provinces
- Cities

Automatic remains recommended.

## 12. Gravity

**Gravity represents explicit accumulated user interest in a geographic destination.**

Potential inputs include:

- explicit saves
- number of distinct Experiences
- repeated independent saves of the same Place
- recency
- category/interest diversity
- explicit “want to visit” behavior

The exact formula may evolve during dogfooding.

Gravity must not increase merely because Graviti recommended something.

## 13. Fit

Fit is separate from Gravity.

**Gravity:** How much evidence has the user already provided that they want this destination?

**Fit:** How strongly does the destination match the user's interests and constraints?

A recommendation with high Fit but low Gravity remains distinguishable from an explicitly saved destination.

## 14. Recommendations

MVP recommendations use:

- user saves
- inferred interests
- visited/saved behavior if available
- explicit Explore constraints
- geographic restrictions
- negative preferences

Recommendations should not constantly over-explain themselves.

Recommendation synthesis must look across the full Library. Repeated interests such as scenery, matcha, architecture, or hiking across many saved destinations should influence Fit for new destinations that match those interests. The app should explain a recommendation using the underlying pattern and supporting saves, even when the recommended destination has little or no explicit Gravity yet.

Prefer concise evidence:

> **Taipei · 93% fit**  
> Tea & matcha  
> Transit-friendly cities  
> Night markets & food  
> Contemporary design

Detailed reasoning may be accessible when useful.

## 15. Explore

Explore begins with:

> **What are you looking for?**

Users can specify hard constraints, preferences, and things to avoid.

Examples of hard constraints:

- United States only
- Europe only
- under five hours from home
- no car required
- exclude destinations already visited

Examples of preferences:

- matcha
- great food
- scenery
- architecture
- museums
- walkability
- quiet
- nightlife

Examples of avoid rules:

- beach-only trips
- huge resorts
- car-dependent travel

## 16. Gravity Field

The Gravity Field is the signature Home experience.

Planet behavior:

- size represents relative Gravity
- maximum approximately 10 labeled planets
- lower-priority destinations may appear as smaller unlabeled bodies
- differences in Gravity are visible without allowing one planet to dominate the screen
- subtle internal gradients
- thin same-color-family iridescent/holographic edge
- restrained glow
- gentle ambient motion
- no cartoon or realistic planets

Users always have conventional alternatives through Library and Search.

## 17. Semantic Zoom

Selecting a planet allows the user to move deeper into the geographic cluster.

Example:

> World → Japan → Tokyo / Kyoto / Osaka → saved experiences

The system must not require every hierarchy to contain the same number of levels.

## 18. Library

MVP Library modes:

- **Destinations** — automatically grouped geography
- **Places** — canonical physical places
- **Saves** — original saved/imported artifacts
- **Map** — spatial representation

Everything must remain reachable without the Gravity Field.

## 19. Saved Media

The MVP preserves and displays original source material when available:

- photos
- screenshots
- video/Reel previews
- links
- map places
- manual saves

Media becomes visually prominent after drilling into a destination or saved item.

Visual principle:

> **Space = organization and possibility**  
> **Media = the actual things that inspired you**

## 20. Saved Item Detail

A Saved Item screen can show:

- original image/video/link preview
- Experience
- associated Place
- Destination
- category
- interests
- user note/reason
- source
- source history
- date saved

Users can correct inferred metadata without destroying the original Artifact.

Each save should gain a short, useful description of what it represents, such as a restaurant, attraction, food, viewpoint, or activity. The description, category, interests, and richer details may be filled in asynchronously after the original save is secure. A user can add their own description when saving a photo or screenshot; their words remain distinct from generated text and are never silently overwritten.

Enrichment should identify the specific attraction of a save where possible: a scenic overlook, a matcha dessert, a museum collection, or a walking trail, rather than only a place name. Store the evidence and confidence behind generated details so users can review or correct them.

Users can delete individual saved items. They can also remove a place from their Library, with a clear explanation of what happens to saves associated with that place. Deletion updates Library, map, Gravity, and interest signals.

## 21. Duplicate Handling

Multiple Artifacts that refer to the same Place should not create unnecessary duplicate Place records.

The Place remains canonical and singular while the original Artifacts remain preserved.

Repeated independent saves may strengthen explicit-interest signals.

## 22. Confidence and Correction

Automated inference retains confidence information.

Low-confidence results should not silently affect major organization or Gravity calculations.

When confidence is insufficient, Graviti surfaces a **Needs your help** state.

The user can correct:

- Place
- Destination
- Experience
- category
- interests

The user may preserve an Artifact as a note even if Graviti cannot resolve it to a Place.

Background enrichment may use place data, source metadata, user notes, and, with appropriate permission, image understanding. It should run without blocking capture. A failed or uncertain enrichment leaves the original save intact and visible.

## 23. Import Payoff

After importing existing saves, Graviti communicates the organizational work it performed.

Example:

> **243 places imported**  
> 7 countries  
> 18 cities  
> 11 duplicates merged  
> 5 need review

This is a core value moment.

## 24. Visual Identity

The MVP uses the established visual language:

- dark spatial Gravity environment
- Graviti Iris / violet as primary brand accent
- mint, blue, amber, coral, and other destination accents
- Sora for Latin display/destination typography
- highly readable body typography
- script-appropriate/system fallback fonts for non-Latin writing systems
- restrained holographic planet treatments
- real media provides stronger color deeper in the experience

The app should feel calm, futuristic, curious, premium, and approachable.

It should not feel childish, crypto-like, overly “AI,” like a booking website, or like a social feed.

## 25. Accessibility Requirements

Accessibility is part of MVP completeness.

The MVP accounts for:

- Dynamic Type
- VoiceOver
- Reduce Motion
- increased contrast
- color-blind accessibility
- practical touch targets
- logical focus ordering
- conventional alternative navigation to the Gravity Field

Planet size/color must not be the sole method of communicating important information.

## 26. Internationalization Requirements

The architecture and layouts are localization-ready from the beginning.

Requirements:

- no important strings embedded directly in layouts
- support text expansion
- headings wrap rather than clip
- layouts reflow instead of excessively shrinking typography
- leading/trailing semantics rather than hardcoded left/right
- appropriate fallback fonts for non-Latin scripts
- place names preserve native/localized forms where available
- geography must not assume U.S.-style city/state/country conventions

Design testing includes English, long Latin-script strings, German-style expansion, Chinese/Japanese, and at least one RTL language before release.

## 27. Privacy

The travel-interest library is private by default.

The user controls what is imported. Graviti collects only data required to provide its features.

Where practical, extraction and processing should occur locally.

Graviti does not require continuous background location access. Location permission is requested only when a feature such as Near Me needs it.

## 28. Offline Behavior

Users must be able to access their existing Library during poor or absent connectivity.

Core saved metadata is cached locally.

Network-dependent discovery and processing may wait for connectivity.

A failed network request must never make an existing save appear lost.

## 29. MVP Technical Direction

Initial direction:

- **UI:** SwiftUI
- **Local persistence:** SwiftData behind repositories
- **Mapping/place resolution:** MapKit behind provider abstractions
- **Backend:** PostgreSQL / Supabase-style relational service
- **Media:** object storage for source/preview assets
- **Processing:** asynchronous artifact-ingestion pipeline

The UI communicates through repositories/services rather than directly depending on persistence implementations.

## 30. Explicit Non-goals for Graviti 1.0

V1 will not include:

- flight booking
- hotel booking
- itinerary scheduling
- packing lists
- expense splitting
- full route optimization
- restaurant reservations
- public social feeds
- followers
- likes
- direct messaging
- collaborative trips
- public guide marketplace
- influencer profiles
- comprehensive events engine
- airfare monitoring
- travel deal alerts
- complex seasonal opportunity scoring
- Android app
- web app

These are not rejected forever; they are not required to ship the MVP.

## 31. Definition of Done

Graviti MVP is ready for external TestFlight users when:

- authentication works reliably
- a new user understands Graviti without a tutorial
- users can capture content from inside and outside the app
- saves appear immediately
- background processing does not block capture
- places and geographic hierarchy resolve reliably enough for real usage
- low-confidence cases can be corrected
- duplicates can be reconciled
- Library supports Destinations, Places, Saves, and Map
- the Gravity Field handles sparse and large libraries gracefully
- adaptive geographic resolution works
- destination Gravity updates correctly
- Explore produces useful interest-based recommendations
- recommendation-created data does not contaminate explicit-interest signals
- saved media is preserved and browsable
- accessibility requirements are tested
- localization architecture is functioning
- core Library data remains accessible offline
- substantial real-world dogfooding has been completed
- major crashes and data-loss bugs are resolved

## 32. North-Star MVP Test

Whenever a new feature is proposed:

> **Does this make it meaningfully easier to capture, organize, understand, or act on the places that are pulling someone toward travel?**

If yes, it may belong in V1.

If the answer is “No, but travel apps usually have it,” it probably does not.
