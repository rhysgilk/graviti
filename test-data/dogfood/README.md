# Graviti dogfood datasets

These Google Saved compatible CSV files isolate different interest patterns so recommendation behavior can be checked without keeping one permanent sample library.

## Datasets

- `national-parks-and-scenery.csv`: national parks, mountains, forests, waterfalls, hiking, wildlife, and coastlines. Expected destination matches include California, Alaska, Maine, the Norwegian Fjords, and the Scottish Highlands.
- `culture-and-history.csv`: architecture, museums, heritage, historic buildings, and gardens. Expected matches include Copenhagen, Mexico City, Kyoto, Lisbon, and Scotland.
- `food-and-water.csv`: seafood, markets, waterfronts, beaches, and local food. Expected matches include California, Maine, and other coastal destinations.
- `diverse-library.csv`: a mixed set for visual and end-to-end testing across all of those signals.
- `crowded-library.csv`: 30 saves across Japan, North America, Europe, Latin America, and Vietnam. It stresses the ten-label Gravity Field budget, repeated cities, long place names, dense Library modes, and recommendations synthesized from scenery, food, architecture, history, art, coastlines, and hiking.

## Use

In Graviti, open Save, choose the Google Maps CSV import option, and select one CSV. Delete its imported saves from Library before loading the next focused dataset when you want an isolated signal. The files use public Google Maps place URLs and notes written specifically to exercise Graviti's enrichment vocabulary.
