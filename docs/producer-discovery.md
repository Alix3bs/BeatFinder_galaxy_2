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

The local test path uses `MockYouTubeChannelClient` and fixture data from `backend/tests/fixtures/mock_youtube_channel_videos.json`. That fixture simulates producer uploads such as `Burgermarty x I Luv Bani Type Beat - Slide`, `Philly x Dallas Type Beat - Motion`, and `Milwaukee x Detroit Type Beat - Fast Money` without touching YouTube.

The module does not implement live YouTube scraping. A future live mode should use permitted YouTube APIs only when a YouTube API key is provided through environment configuration, should be disabled by default, and should respect rate limits, robots/terms, and copyright boundaries.

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

Seed producers from `data/seeds/producer_youtube_profiles.txt` provide the first channel graph. Mock backfill then proves how later discovery can expand from hashtags, artist combos, city/region combos, and eventually related producer-channel signals before any live API integration exists.

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

`match_producer_tag()` normalizes detected producer tags and known producer/channel aliases before comparing them. It supports:

- exact normalized alias matches, such as `beats by slimy`
- compact alias matches, such as `baby on the track` -> `babyonthetrack`
- loose joiner-insensitive matches, such as `prod by salishan` -> `prod.salishan`
- conservative token overlap when there are enough meaningful non-generic words

The matcher avoids treating common tag fragments like `prod by`, `beats by`, `the track`, or `producer tag` as enough evidence by themselves.

`infer_sold_deleted_status()` runs only when another layer supplies a detected producer tag. It:

- matches the tag against known producer aliases
- searches indexed visible videos for likely title, phrase, or strong nearest-audio candidate matches
- returns `found_candidate` when an indexed public upload plausibly matches
- returns `insufficient_evidence` when the producer-tag match is weak or no known producer channel matches
- returns `possible_sold_or_deleted` when a known producer tag matches but no indexed visible upload appears to match

The system must not say the beat is definitely sold or deleted. The status is intentionally named `possible_sold_or_deleted` because producer tags can appear on beats that are unavailable for many different reasons. Possible reasons include:

- `sold_and_deleted`
- `unlisted`
- `private`
- `renamed`
- `hosted_on_beatstars`
- `hosted_on_traktrain`
- `not_yet_indexed`
- `producer_tag_false_positive`

`not_yet_indexed` remains in the reason list until the channel checkpoint says the channel was fully backfilled. Even then, BeatFinder still keeps uncertainty in the result because a beat can be renamed, moved to BeatStars or Traktrain, private, deleted, or misattributed by a false-positive producer tag.

## Search Response Enrichment

`enrich_search_discovery()` connects the local discovery index to ordinary BeatFinder search responses. It runs after the main hybrid retrieval/reranking step and adds a top-level optional `discovery` object to `/search/audio`, `/search/text`, and `/search/hybrid` responses.

The enrichment layer accepts the detected producer tag, expanded query metadata, ranked BeatFinder candidates, and the local `ProducerDiscoveryStore`. It does not call live YouTube, download audio, or use external APIs.

The response can include:

- `detected_producer_tag`
- `matched_producer_channel`
- `producer_tag_confidence`
- `youtube_video_match`
- `discovery_status`
- `possible_reasons`
- `evidence`
- `recommended_next_searches`

`discovery_status` is one of:

- `found_candidate` when an indexed producer YouTube video plausibly matches the query or top BeatFinder candidate.
- `possible_sold_or_deleted` when a producer tag matches a known producer but no indexed visible video matches.
- `insufficient_evidence` when the tag is weak, generic, or unmatched.
- `not_applicable` when no detected producer tag was supplied.

Recommended follow-up searches are generated from matched producer aliases, hashtags, artist combos, city/region combos, and type-beat phrases, such as `prod salishan type beat`, `philly type beat`, or `sza summer walker type beat`.

## Storage

The verified v1 path stores discovery data in local JSON tables under the BeatFinder state directory. A separate Supabase migration, `202605310001_producer_discovery_v1.sql`, defines future production tables without changing the core beat retrieval tables.

## Confidence Boundaries

This layer can say that a producer channel, hashtag, title phrase, or city/style phrase was observed in public metadata. It can suggest related producer discovery searches. It can mark a beat as possibly sold/deleted/unavailable only when evidence supports that possibility.

It cannot prove ownership, sales status, deletion, privacy status, or exact audio identity without stronger audio matching and authorized source data.
