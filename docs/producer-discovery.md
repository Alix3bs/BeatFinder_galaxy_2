# Producer Discovery + YouTube Beat Backfill

BeatFinder's producer discovery layer indexes producer YouTube beat catalogs as metadata. It does not download copyrighted audio and does not call live YouTube from tests.

## Seeding Known Producers

Known producer profiles are added through `ProducerDiscoveryStore.upsert_channel()` or `YouTubeBeatBackfill.ingest_producer_profile()`.

The initial manual seed list lives at `data/seeds/producer_youtube_profiles.txt`. It stores one producer YouTube profile per line and is loaded with `load_producer_seed_file()`. The loader strips query and fragment tracking parameters, normalizes YouTube handles, dedupes repeated channel references, and creates local `ProducerChannel` records. It does not call YouTube or start a backfill.

Accepted seed forms include:

- YouTube channel URLs like `https://www.youtube.com/channel/UC...`
- YouTube handles like `https://www.youtube.com/@producer`
- Raw channel IDs or handles

Each seed becomes a `ProducerChannel` with platform, channel id, channel URL, producer name, aliases, city/style tags, source, confidence, and scan timestamps.

Later discovery expands beyond the manual list through hashtag seeds, artist-combo phrases, city/region combo searches, and related producer/channel signals produced by the backfill pipeline.

## Channel Backfill

`YouTubeBeatBackfill.backfill_channel()` walks a channel's public beat videos from newest to oldest through an injected client interface. The current implementation is intentionally local and mockable:

- stores checkpoints/page tokens after every page
- caps pages per run with `max_pages`
- dedupes by producer channel plus YouTube video id
- skips already indexed videos unless `refresh=True`
- stores public/unavailable visibility status when provided by the client
- extracts metadata from title, description, and hashtags

The module does not implement live YouTube scraping. A production adapter should use permitted APIs and respect rate limits, robots/terms, and copyright boundaries.

## Metadata Extraction

For each video, the backfill uses BeatFinder's existing metadata parser to extract:

- hashtags such as `#phillytypebeat`
- type beat phrases such as `sza x summer walker type beat`
- artist refs and artist combo refs
- producer refs and producer combo refs
- normalized search phrases
- BeatStars, Traktrain, Airbit, or `bsta.rs` beat-store links
- city, region, and style tags from the first-pass classifier

## Hashtag And Combo Discovery

`expand_discovery_seeds()` turns discovered phrases into producer-search seeds. Examples:

- `#phillytypebeat` -> `philly type beat producers`
- `#newyorkdrilltypebeat` -> `new york drill type beat producers`
- `philly x dallas type beat` -> `philly dallas type beat producers`
- `burgermarty x iluvbani type beat` -> `burgermarty iluvbani type beat producers`

These seeds are stored locally as `DiscoverySeed` records and can be processed later by an approved search/provider adapter.

## City And Scene Classification

`classify_city_style()` is a conservative first-pass classifier. It maps explicit phrases to tags with confidence and evidence:

- `philly`, `philadelphia` -> `philly`
- `detroit` -> `detroit`
- `milwaukee` -> `milwaukee`
- `dallas` -> `dallas`
- `arkansas` -> `arkansas`
- `new york drill`, `ny drill` -> `new_york_drill`

It does not infer a scene without phrase evidence.

## Possible Sold Or Deleted Inference

`infer_possible_sold_or_deleted()` runs only when another layer supplies a detected producer tag. It:

- matches the tag against known producer aliases
- searches indexed visible videos for a likely title match
- records `possible_sold_or_deleted` when a channel matches but no visible upload appears to match

The system must not say the beat is definitely sold or deleted. Stored possible reasons include:

- `sold_and_deleted`
- `unlisted`
- `private`
- `renamed`
- `hosted_on_beatstars`
- `hosted_on_traktrain`
- `not_yet_indexed`
- `producer_tag_false_positive`

## Storage

The verified v1 path stores discovery data in local JSON tables under the BeatFinder state directory. A separate Supabase migration, `202605310001_producer_discovery_v1.sql`, defines future production tables without changing the core beat retrieval tables.

## Confidence Boundaries

This layer can say that a producer channel, hashtag, title phrase, or city/style phrase was observed in public metadata. It can suggest related producer discovery searches. It can mark a beat as possibly sold/deleted/unavailable only when evidence supports that possibility.

It cannot prove ownership, sales status, deletion, privacy status, or exact audio identity without stronger audio matching and authorized source data.
