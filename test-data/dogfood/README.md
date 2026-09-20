# Graviti dogfood datasets

These Google Saved compatible CSV files isolate different interest patterns so Gravity, enrichment, Fit, Fit Guides, Search, and dense Library behavior can be checked without keeping one permanent sample library.

## Datasets

- `national-parks-and-scenery.csv`: national parks, mountains, forests, waterfalls, hiking, wildlife, and coastlines. Expected destination matches include California, Alaska, Maine, the Norwegian Fjords, and the Scottish Highlands.
- `culture-and-history.csv`: architecture, museums, heritage, historic buildings, and gardens. Expected matches include Copenhagen, Mexico City, Kyoto, Lisbon, and Scotland.
- `food-and-water.csv`: seafood, markets, waterfronts, beaches, and local food. Expected matches include California, Maine, and other coastal destinations.
- `diverse-library.csv`: a mixed set for visual and end-to-end testing across all of those signals.
- `crowded-library.csv`: 30 saves across Japan, North America, Europe, Latin America, and Vietnam. It stresses the ten-label Gravity Field budget, repeated cities, long place names, dense Library modes, and recommendations synthesized from scenery, food, architecture, history, art, coastlines, and hiking.

## Use

In a Debug build, open Save and use **Load test dataset**. Graviti tracks the fixture Artifact IDs, removes the previously loaded fixture before switching, and can remove the active fixture without affecting unrelated saves.

The same files can be exercised through **Import Google Saved CSV**. If that path is used, delete the imported saves from Library before loading another focused dataset when an isolated signal is needed.

The files use public Google Maps place URLs and notes written specifically to exercise Graviti's enrichment vocabulary. They are mirrored in `graviti/graviti/Resources/Dogfood` for Debug builds and excluded from Release archives.

## Expected checks

- Home stays within the ten-destination label budget and allows direct switching between visible bubbles.
- Explore ranks specific semantic matches instead of simply recommending the geography with the most source saves.
- Sparse libraries show Early signal instead of an intense Fit percentage.
- Independent places and areas raise confidence more than repeated records for one place.
- Fit Guides return real venues inside the recommended destination and group them by matched pattern.
- Library bulk removal and deletion update Gravity and interest evidence without leaving stale groups.
