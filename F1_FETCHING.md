# Current Formula 1 fetching

Formula 1 is represented by the `racing/f1` ESPN league definition in
`InterestingNotch/widgets/model/SportsWidgetModel.swift`.

## Settings and persistence

Following “Formula 1” saves a `FollowedLeague` with:

```text
sport: racing
league: f1
```

It is persisted in `sportsFollowedLeaguesData`. A selected F1 competitor is
stored separately in `sportsStarredTeamsData`, but the current F1 card is driven
by the league follow because a pre-race event has no two opposing teams.

## ESPN request

The F1 fetch uses the same keyless ESPN endpoint as the other sports:

```text
https://site.api.espn.com/apis/site/v2/sports/racing/f1/scoreboard?dates=20260101-20261231
```

The full-season range is intentional. ESPN represents F1 weekends as session
events, and a short generic date window can miss the race event metadata. The
full response currently contains past and upcoming 2026 events.

## Filtering and mapping

For a followed league, `SportsDataService.snapshots(for:followedLeagues:)`:

1. Loads the current scoreboard.
2. Loads the F1 full-season scoreboard independently.
3. Passes F1 events to `raceSnapshot`.
4. Keeps live events, today’s events, and future events whose start date is at
   or after the current time.
5. Uses the event’s `circuit.fullName` as the venue.
6. Sorts snapshots by live/today priority and then start date.

Upcoming Belgian Grand Prix data is therefore mapped from:

```text
event.name       → race title
event.date       → start date
event.circuit.fullName → circuit name
event.id         → ESPN event URL and snapshot ID
```

Pre-race F1 events commonly have zero competitors. They are still valid race
snapshots; the app does not require two competitors for the next-race card.
Some F1 session events omit the `competitors` key entirely. The ESPN decoder
maps a missing competitors field to an empty array, allowing those sessions to
be skipped without rejecting the whole scoreboard response.

## Rendering

F1 uses `GameFormat.leaderboard`. `SportsWidgetPageView` detects that format and
renders the leaderboard-style “Next race” card instead of the two-team score
layout. The card shows the race name, circuit, and local formatted start time.

## Refresh behavior

The sports model refreshes on startup and in its polling loop. Changes to either
followed teams or followed leagues trigger an immediate `refreshNow()` through
`UserDefaults.didChangeNotification`.

If ESPN fails for one league, the other leagues continue loading; a single stale
or seasonal league must not clear the entire sports widget.
