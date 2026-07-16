# Sports settings maintenance guide

## Where it lives

- `InterestingNotch/components/Settings/Views/SportsSettingsView.swift` — settings UI, league/team navigation, search, team page, and match rows.
- `InterestingNotch/widgets/model/SportsWidgetModel.swift` — league definitions, persistence helpers, ESPN networking, schedule decoding, and sports widget runtime data.
- `InterestingNotch/models/Constants.swift` — Defaults keys for followed leagues, starred teams, and sports display settings.

## Navigation flow

`SportsSettingsView` uses a `NavigationStack` with three routes:

1. **Leagues** — grouped by sport, with followed leagues at the top.
2. **League teams** — starred teams first, then all teams.
3. **Team page** — header, form, next matches, and recent results.

Match rows are wired to a lightweight match-detail destination and can later be replaced by a full match-detail view.

## Persistence

- Followed leagues: `sportsFollowedLeaguesData`
- Starred teams: `sportsStarredTeamsData`
- Existing runtime team feed: `sportsFollowedTeamsData`

`SportsPreferences.toggleStar(_:)` writes starred teams to both team keys so the existing notch widget continues to work. Star/follow order is preserved by keeping arrays in insertion order.

## ESPN data

Teams are loaded from:

```text
https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/teams
```

Team schedules are loaded from:

```text
https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/teams/{teamId}/schedule
```

Schedule decoding follows the endpoint shape: `events → competitions → competitors`. Match rows derive the opponent, home/away label, crest, venue, state, score, and W/L/D result from those nested fields.

## Match grouping

- **Next matches:** events with state `pre` or a date at/after the current time, sorted soonest first.
- **Recent results:** events with state `post` or a past date, sorted most recent first.
- If there are no upcoming matches, the page shows `No upcoming matches` while still displaying recent results.

## Styling rule

Keep Sports settings built with grouped `Form` and `Section` views so it stays consistent with Media, Calendar, and Mirror settings. Use `Color.effectiveAccent` for active stars and result colors only for W/L/D status.

## Extending it

When adding a league, update `SportsLeagueDefinition.all`. When changing ESPN fields, update the private `ESPNSchedule*` decoding structs and the mapping inside `SportsDataService.schedule(for:)` together. Run:

```bash
swiftc -parse InterestingNotch/components/Settings/Views/SportsSettingsView.swift
swiftc -parse InterestingNotch/widgets/model/SportsWidgetModel.swift
```
