//
//  SportsWidgetModel.swift
//  InterestingNotch
//
//  Created by Codex on 2026-07-15.
//

import AppKit
import Defaults
import Foundation
import SwiftUI

struct SportsLeagueDefinition: Identifiable, Hashable, Sendable {
    let sport: String
    let league: String
    let title: String
    let subtitle: String
    let sportPath: String
    let espnGamePath: String

    var id: String { "\(sport)/\(league)" }

    static let all: [SportsLeagueDefinition] = [
        .init(sport: "soccer", league: "eng.1", title: "Soccer", subtitle: "Premier League", sportPath: "soccer", espnGamePath: "soccer/match"),
        .init(sport: "soccer", league: "esp.1", title: "Soccer", subtitle: "La Liga", sportPath: "soccer", espnGamePath: "soccer/match"),
        .init(sport: "soccer", league: "ita.1", title: "Soccer", subtitle: "Serie A", sportPath: "soccer", espnGamePath: "soccer/match"),
        .init(sport: "soccer", league: "ger.1", title: "Soccer", subtitle: "Bundesliga", sportPath: "soccer", espnGamePath: "soccer/match"),
        .init(sport: "soccer", league: "fra.1", title: "Soccer", subtitle: "Ligue 1", sportPath: "soccer", espnGamePath: "soccer/match"),
        .init(sport: "soccer", league: "usa.1", title: "Soccer", subtitle: "MLS", sportPath: "soccer", espnGamePath: "soccer/match"),
        .init(sport: "soccer", league: "fifa.world", title: "Soccer", subtitle: "World Cup", sportPath: "soccer", espnGamePath: "soccer/match"),
        .init(sport: "soccer", league: "uefa.champions", title: "Soccer", subtitle: "UEFA Champions League", sportPath: "soccer", espnGamePath: "soccer/match"),
        .init(sport: "soccer", league: "uefa.europa", title: "Soccer", subtitle: "UEFA Europa League", sportPath: "soccer", espnGamePath: "soccer/match"),
        .init(sport: "basketball", league: "nba", title: "Basketball", subtitle: "NBA", sportPath: "basketball", espnGamePath: "nba/game"),
        .init(sport: "football", league: "nfl", title: "Football", subtitle: "NFL", sportPath: "football", espnGamePath: "nfl/game"),
        .init(sport: "hockey", league: "nhl", title: "Hockey", subtitle: "NHL", sportPath: "hockey", espnGamePath: "nhl/game"),
        .init(sport: "baseball", league: "mlb", title: "Baseball", subtitle: "MLB", sportPath: "baseball", espnGamePath: "mlb/game"),
    ]

    static let defaultLeague = all[0]

    static func league(forSport sport: String, league: String) -> SportsLeagueDefinition? {
        all.first { $0.sport == sport && $0.league == league }
    }

    static func leagues(forSportTitle title: String) -> [SportsLeagueDefinition] {
        all.filter { $0.title == title }
    }
}

struct FollowedLeague: Codable, Equatable, Hashable, Identifiable, Sendable {
    let sport: String
    let league: String

    var id: String { "\(sport)/\(league)" }

    var definition: SportsLeagueDefinition {
        SportsLeagueDefinition.league(forSport: sport, league: league) ?? .defaultLeague
    }
}

struct FollowedTeam: Codable, Equatable, Hashable, Identifiable, Sendable {
    let sport: String
    let league: String
    let teamId: String
    let name: String
    let logoURL: String

    var id: String { "\(sport):\(league):\(teamId)" }

    var leagueDefinition: SportsLeagueDefinition {
        SportsLeagueDefinition.league(forSport: sport, league: league) ?? .defaultLeague
    }
}

struct SportsTeamSearchResult: Identifiable, Equatable, Hashable, Sendable {
    let sport: String
    let league: String
    let id: String
    let name: String
    let abbreviation: String
    let logoURL: String

    init(sport: String, league: String, id: String, name: String, abbreviation: String, logoURL: String) {
        self.sport = sport
        self.league = league
        self.id = id
        self.name = name
        self.abbreviation = abbreviation
        self.logoURL = logoURL
    }

    init(followedTeam: FollowedTeam) {
        sport = followedTeam.sport
        league = followedTeam.league
        id = followedTeam.teamId
        name = followedTeam.name
        abbreviation = ""
        logoURL = followedTeam.logoURL
    }
}

enum SportsScheduleState: String, Hashable, Sendable {
    case pre
    case live
    case post
    case unknown

    static func fromESPN(_ value: String?) -> Self {
        switch value {
        case "pre": return .pre
        case "in", "live": return .live
        case "post": return .post
        default: return .unknown
        }
    }
}

struct SportsTeamScheduleMatch: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let sport: String
    let league: String
    let teamID: String
    let teamName: String
    let teamLogoURL: String
    let date: Date
    let state: SportsScheduleState
    let opponentName: String
    let opponentLogoURL: String
    let isHome: Bool
    let venueName: String?
    let teamScore: Int?
    let opponentScore: Int?

    var result: String? {
        guard let teamScore, let opponentScore else { return nil }
        if teamScore == opponentScore { return "D" }
        return teamScore > opponentScore ? "W" : "L"
    }
}

enum SportsGameState: String, Codable, Equatable, Sendable {
    case pre
    case live
    case post
    case unknown

    var isLive: Bool { self == .live }
    var isPre: Bool { self == .pre }
    var isPost: Bool { self == .post }

    static func fromESPN(_ value: String?) -> SportsGameState {
        switch value {
        case "in", "live": return .live
        case "pre": return .pre
        case "post": return .post
        default: return .unknown
        }
    }
}

struct SportsTeamSide: Equatable, Sendable {
    let teamId: String
    let name: String
    let abbreviation: String
    let logoURL: String
    let score: String
    let record: String?
}

struct GoalEvent: Equatable, Hashable, Identifiable, Sendable {
    let teamId: String
    let player: String
    let minute: String

    var id: String { "\(teamId)-\(player)-\(minute)" }
}

struct GameSnapshot: Equatable, Identifiable, Sendable {
    let id: String
    let competition: String
    let state: SportsGameState
    let clock: String
    let statusDetail: String
    let home: SportsTeamSide
    let away: SportsTeamSide
    let events: [GoalEvent]
    let eventURL: URL?
    let startDate: Date?
    let followedTeamID: String
    let leagueDefinition: SportsLeagueDefinition

    var isToday: Bool {
        guard let startDate else { return state.isLive || state.isPost || state.isPre }
        return Calendar.current.isDateInToday(startDate)
    }

    var isStartingSoonToday: Bool {
        state.isPre && isToday
    }

    var displayStatus: String {
        if !clock.isEmpty { return clock }
        if !statusDetail.isEmpty { return statusDetail }
        if let startDate {
            return startDate.formatted(date: .omitted, time: .shortened)
        }
        return "No status"
    }

    var matchupTitle: String {
        "\(away.abbreviation.isEmpty ? away.name : away.abbreviation) at \(home.abbreviation.isEmpty ? home.name : home.abbreviation)"
    }
}

struct SportsMatchDetail: Equatable, Sendable {
    enum EventSide: String, Equatable, Sendable {
        case home
        case away
        case neutral
    }

    struct TeamSummary: Equatable, Sendable {
        let id: String
        let name: String
        let logoURL: String
        let score: String?
        let homeAway: EventSide
    }

    struct HeroEvent: Equatable, Identifiable, Sendable {
        let id: String
        let text: String
        let minute: String
        let side: EventSide
    }

    struct TeamStat: Equatable, Identifiable, Sendable {
        let id: String
        let name: String
        let label: String
        let homeValue: String
        let awayValue: String
        let homeFraction: Double
    }

    struct Event: Equatable, Identifiable, Sendable {
        let id: String
        let text: String
        let minute: String
        let icon: String
        let side: EventSide
        let periodNumber: Int
        let sortValue: Int
    }

    struct InfoRow: Equatable, Identifiable, Sendable {
        let id: String
        let label: String
        let value: String
    }

    let title: String
    let competition: String
    let statusText: String
    let home: TeamSummary
    let away: TeamSummary
    let heroEvents: [HeroEvent]
    let teamStats: [TeamStat]
    let keyEvents: [Event]
    let infoRows: [InfoRow]
    let commentary: [String]
}

enum SportsPreferences {
    static func loadFollowedLeagues() -> [FollowedLeague] {
        guard let data = Defaults[.sportsFollowedLeaguesData] else { return [] }
        return (try? JSONDecoder().decode([FollowedLeague].self, from: data)) ?? []
    }

    static func saveFollowedLeagues(_ leagues: [FollowedLeague]) {
        Defaults[.sportsFollowedLeaguesData] = try? JSONEncoder().encode(leagues)
    }

    static func isFollowing(_ league: SportsLeagueDefinition) -> Bool {
        loadFollowedLeagues().contains { $0.id == league.id }
    }

    static func toggleFollow(_ league: SportsLeagueDefinition) {
        var leagues = loadFollowedLeagues()
        if let index = leagues.firstIndex(where: { $0.id == league.id }) {
            leagues.remove(at: index)
        } else {
            leagues.append(FollowedLeague(sport: league.sport, league: league.league))
        }
        saveFollowedLeagues(leagues)
    }

    static func starredTeams() -> [FollowedTeam] {
        if let data = Defaults[.sportsStarredTeamsData],
           let teams = try? JSONDecoder().decode([FollowedTeam].self, from: data) {
            return teams
        }
        return loadFollowedTeams()
    }

    static func saveStarredTeams(_ teams: [FollowedTeam]) {
        let data = try? JSONEncoder().encode(teams)
        Defaults[.sportsStarredTeamsData] = data
        // Keep the runtime's existing source of followed teams in sync.
        Defaults[.sportsFollowedTeamsData] = data
    }

    static func isStarred(_ team: SportsTeamSearchResult) -> Bool {
        starredTeams().contains { $0.id == "\(team.sport):\(team.league):\(team.id)" }
    }

    static func toggleStar(_ team: SportsTeamSearchResult) {
        var teams = starredTeams()
        if let index = teams.firstIndex(where: { $0.id == "\(team.sport):\(team.league):\(team.id)" }) {
            teams.remove(at: index)
        } else {
            teams.append(FollowedTeam(sport: team.sport, league: team.league, teamId: team.id, name: team.name, logoURL: team.logoURL))
        }
        saveStarredTeams(teams)
    }

    static func loadFollowedTeams() -> [FollowedTeam] {
        guard let data = Defaults[.sportsFollowedTeamsData] else { return [] }
        return (try? JSONDecoder().decode([FollowedTeam].self, from: data)) ?? []
    }

    static func saveFollowedTeams(_ teams: [FollowedTeam]) {
        Defaults[.sportsFollowedTeamsData] = try? JSONEncoder().encode(teams)
        Defaults[.sportsStarredTeamsData] = Defaults[.sportsFollowedTeamsData]
    }

    static func isFollowing(teamID: String, sport: String, league: String) -> Bool {
        loadFollowedTeams().contains { $0.teamId == teamID && $0.sport == sport && $0.league == league }
    }

    static func toggleFollow(_ team: SportsTeamSearchResult) {
        var teams = loadFollowedTeams()
        if let index = teams.firstIndex(where: { $0.teamId == team.id && $0.sport == team.sport && $0.league == team.league }) {
            teams.remove(at: index)
        } else {
            teams.append(
                FollowedTeam(
                    sport: team.sport,
                    league: team.league,
                    teamId: team.id,
                    name: team.name,
                    logoURL: team.logoURL
                )
            )
        }
        saveFollowedTeams(teams)
    }

    static func removeFollowedTeam(_ team: FollowedTeam) {
        saveFollowedTeams(loadFollowedTeams().filter { $0.id != team.id })
    }

    static func moveFollowedTeam(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        var teams = loadFollowedTeams()
        teams.move(fromOffsets: offsets, toOffset: destination)
        saveFollowedTeams(teams)
    }
}

actor SportsDataService {
    static let shared = SportsDataService()

    private var teamCache: [String: [SportsTeamSearchResult]] = [:]
    private let decoder = JSONDecoder()

    func teams(for league: SportsLeagueDefinition) async throws -> [SportsTeamSearchResult] {
        if let cached = teamCache[league.id] {
            return cached
        }

        let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(league.sport)/\(league.league)/teams")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try decoder.decode(ESPNTeamsResponse.self, from: data)
        let teams = response.sports
            .flatMap(\.leagues)
            .flatMap(\.teams)
            .compactMap { wrapper -> SportsTeamSearchResult? in
                guard let team = wrapper.team else { return nil }
                return SportsTeamSearchResult(
                    sport: league.sport,
                    league: league.league,
                    id: team.id ?? UUID().uuidString,
                    name: team.displayName ?? team.shortDisplayName ?? team.name ?? "Unknown Team",
                    abbreviation: team.abbreviation ?? "",
                    logoURL: team.logo ?? team.logos?.first?.href ?? ""
                )
            }
        let dedupedTeams = dedupeTeamResults(teams)

        teamCache[league.id] = dedupedTeams
        return dedupedTeams
    }

    func searchTeams(query: String, league: SportsLeagueDefinition) async throws -> [SportsTeamSearchResult] {
        let teams = try await teams(for: league)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return teams }

        return teams.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.abbreviation.localizedCaseInsensitiveContains(trimmed)
        }
    }

    func searchTeams(query: String, leagues: [SportsLeagueDefinition]) async throws -> [SportsTeamSearchResult] {
        var results: [SportsTeamSearchResult] = []
        for league in leagues {
            results.append(contentsOf: try await searchTeams(query: query, league: league))
        }
        return dedupeTeamResults(results)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func dedupeTeamResults(_ teams: [SportsTeamSearchResult]) -> [SportsTeamSearchResult] {
        var seen = Set<String>()
        return teams.filter { team in
            let key = "\(team.sport)|\(team.league)|\(team.id)"
            return seen.insert(key).inserted
        }
    }

    func schedule(for team: SportsTeamSearchResult) async throws -> [SportsTeamScheduleMatch] {
        guard let league = SportsLeagueDefinition.league(forSport: team.sport, league: team.league),
              let encodedTeamID = team.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(league.sport)/\(league.league)/teams/\(encodedTeamID)/schedule")
        else { return [] }

        let recentResults = try await fetchAndMapSchedule(from: url, team: team)
            .filter { $0.state == .post || $0.date < Date() }

        let upcomingMatches = try await fetchUpcomingMatches(from: league, team: team)

        return mergeTeamScheduleMatches(recentResults: recentResults, upcomingMatches: upcomingMatches)
    }

    private func fetchAndMapSchedule(from url: URL, team: SportsTeamSearchResult) async throws -> [SportsTeamScheduleMatch] {
        let (data, _) = try await URLSession.shared.data(from: url)

        let response: ESPNScheduleResponse
        do {
            response = try decoder.decode(ESPNScheduleResponse.self, from: data)
        } catch let DecodingError.keyNotFound(key, context) {
            print("🟥 Sports schedule missing key:", key.stringValue, "at", context.codingPath.map(\.stringValue), "url:", url.absoluteString)
            throw DecodingError.keyNotFound(key, context)
        } catch let DecodingError.typeMismatch(type, context) {
            print("🟥 Sports schedule type mismatch:", type, "at", context.codingPath.map(\.stringValue), "url:", url.absoluteString)
            throw DecodingError.typeMismatch(type, context)
        } catch let DecodingError.valueNotFound(type, context) {
            print("🟥 Sports schedule value missing:", type, "at", context.codingPath.map(\.stringValue), "url:", url.absoluteString)
            throw DecodingError.valueNotFound(type, context)
        } catch let DecodingError.dataCorrupted(context) {
            print("🟥 Sports schedule data corrupted at", context.codingPath.map(\.stringValue), "-", context.debugDescription, "url:", url.absoluteString)
            throw DecodingError.dataCorrupted(context)
        } catch {
            print("🟥 Sports schedule decode failed:", error, "url:", url.absoluteString)
            throw error
        }

        return response.events.compactMap { event -> SportsTeamScheduleMatch? in
            guard let competition = event.competitions.first else { return nil }

            let date = ESPNDate.parse(event.date) ?? ESPNDate.parse(competition.date)
            guard let date else {
                print("🟥 Sports schedule could not parse date for event:", event.id, event.date, competition.date)
                return nil
            }

            let competitors = competition.competitors
            guard competitors.count >= 2 else {
                print("🟥 Sports schedule missing competitors for event:", event.id)
                return nil
            }

            let selected = scheduleCompetitor(matching: team, in: competitors) ?? competitors.first
            guard let selected,
                  let opponent = competitors.first(where: { $0.id != selected.id }) ?? competitors.dropFirst().first
            else {
                print("🟥 Sports schedule could not resolve matchup for event:", event.id, "team:", team.id)
                return nil
            }

            return SportsTeamScheduleMatch(
                id: event.id,
                sport: team.sport,
                league: team.league,
                teamID: selected.team.id,
                teamName: selected.team.displayName,
                teamLogoURL: selected.team.logoURL ?? "",
                date: date,
                state: SportsScheduleState.fromESPN(competition.status?.type?.state),
                opponentName: opponent.team.displayName,
                opponentLogoURL: opponent.team.logoURL ?? "",
                isHome: selected.homeAway == "home",
                venueName: competition.venue?.fullName,
                teamScore: scoreValue(selected.score),
                opponentScore: scoreValue(opponent.score)
            )
        }.sorted { $0.date < $1.date }
    }

    private func fetchUpcomingMatches(
        from league: SportsLeagueDefinition,
        team: SportsTeamSearchResult
    ) async throws -> [SportsTeamScheduleMatch] {
        let primary = try await fetchUpcomingMatches(from: league, team: team, daysAhead: 14)
        if !primary.isEmpty {
            return primary
        }
        return try await fetchUpcomingMatches(from: league, team: team, daysAhead: 30)
    }

    private func fetchUpcomingMatches(
        from league: SportsLeagueDefinition,
        team: SportsTeamSearchResult,
        daysAhead: Int
    ) async throws -> [SportsTeamScheduleMatch] {
        guard let url = scoreboardURL(for: league, daysAhead: daysAhead) else { return [] }
        let response = try await fetchScoreboardResponse(from: url)

        return response.events.compactMap { event in
            guard let competition = event.competitions.first else { return nil }
            let competitors = competition.competitors
            guard competitors.count >= 2 else { return nil }

            let selected = scoreboardCompetitor(matching: team, in: competitors) ?? competitors.first
            guard let selected,
                  let opponent = competitors.first(where: { ($0.team?.id ?? "") != (selected.team?.id ?? "") }) ?? competitors.dropFirst().first
            else {
                return nil
            }

            let dateString = event.date ?? ""
            guard let date = ESPNDate.parse(dateString) else { return nil }

            let state = SportsScheduleState.fromESPN((competition.status ?? event.status)?.type?.state)
            guard state == .pre || state == .live || date >= Date() else { return nil }

            return SportsTeamScheduleMatch(
                id: event.id ?? UUID().uuidString,
                sport: league.sport,
                league: league.league,
                teamID: selected.team?.id ?? team.id,
                teamName: selected.team?.displayName ?? selected.team?.shortDisplayName ?? selected.team?.name ?? team.name,
                teamLogoURL: selected.team?.logo ?? selected.team?.logos?.first?.href ?? team.logoURL,
                date: date,
                state: state,
                opponentName: opponent.team?.displayName ?? opponent.team?.shortDisplayName ?? opponent.team?.name ?? "Opponent",
                opponentLogoURL: opponent.team?.logo ?? opponent.team?.logos?.first?.href ?? "",
                isHome: selected.homeAway == "home",
                venueName: competition.venue?.fullName,
                teamScore: scoreValue(selected.score),
                opponentScore: scoreValue(opponent.score)
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func mergeTeamScheduleMatches(
        recentResults: [SportsTeamScheduleMatch],
        upcomingMatches: [SportsTeamScheduleMatch]
    ) -> [SportsTeamScheduleMatch] {
        var mergedByID = Dictionary(uniqueKeysWithValues: recentResults.map { ($0.id, $0) })
        for match in upcomingMatches {
            mergedByID[match.id] = match
        }
        return mergedByID.values.sorted { $0.date < $1.date }
    }

    private func scoreboardURL(for league: SportsLeagueDefinition, daysAhead: Int) -> URL? {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .day, value: daysAhead, to: startDate) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd"

        let range = "\(formatter.string(from: startDate))-\(formatter.string(from: endDate))"
        return URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(league.sport)/\(league.league)/scoreboard?dates=\(range)")
    }

    private func fetchScoreboardResponse(from url: URL) async throws -> ESPNScoreboardResponse {
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(ESPNScoreboardResponse.self, from: data)
    }

    private func scoreValue(_ score: ESPNScheduleScore?) -> Int? {
        if let value = score?.value { return Int(value.rounded()) }
        if let displayValue = score?.displayValue { return Int(displayValue) }
        return nil
    }

    private func scoreValue(_ score: String?) -> Int? {
        guard let score else { return nil }
        return Int(score)
    }

    private func scheduleCompetitor(
        matching team: SportsTeamSearchResult,
        in competitors: [ESPNScheduleCompetitor]
    ) -> ESPNScheduleCompetitor? {
        if let exactTeamID = competitors.first(where: { $0.team.id == team.id }) {
            return exactTeamID
        }

        if let competitorID = competitors.first(where: { $0.id == team.id }) {
            return competitorID
        }

        if let exactName = competitors.first(where: { $0.team.displayName.caseInsensitiveCompare(team.name) == .orderedSame }) {
            return exactName
        }

        if !team.abbreviation.isEmpty,
           let abbreviation = competitors.first(where: { ($0.team.abbreviation ?? "").caseInsensitiveCompare(team.abbreviation) == .orderedSame }) {
            return abbreviation
        }

        return nil
    }

    private func scoreboardCompetitor(
        matching team: SportsTeamSearchResult,
        in competitors: [ESPNCompetitor]
    ) -> ESPNCompetitor? {
        if let exactTeamID = competitors.first(where: { $0.team?.id == team.id }) {
            return exactTeamID
        }

        if let exactName = competitors.first(where: {
            guard let displayName = $0.team?.displayName ?? $0.team?.shortDisplayName ?? $0.team?.name else { return false }
            return displayName.caseInsensitiveCompare(team.name) == .orderedSame
        }) {
            return exactName
        }

        if !team.abbreviation.isEmpty,
           let abbreviation = competitors.first(where: { ($0.team?.abbreviation ?? "").caseInsensitiveCompare(team.abbreviation) == .orderedSame }) {
            return abbreviation
        }

        return nil
    }

    func snapshots(for followedTeams: [FollowedTeam]) async throws -> [GameSnapshot] {
        let grouped = Dictionary(grouping: followedTeams, by: { "\($0.sport)|\($0.league)" })
        var snapshots: [GameSnapshot] = []

        for groupValue in grouped.values {
            guard let first = groupValue.first,
                  let league = SportsLeagueDefinition.league(forSport: first.sport, league: first.league)
            else { continue }

            let scoreboard = try await fetchScoreboard(for: league)
            snapshots.append(
                contentsOf: matchSnapshots(
                    from: scoreboard,
                    followedTeams: groupValue,
                    league: league,
                    includeUpcoming: false
                )
            )

            let upcomingScoreboard = try await fetchScoreboard(for: league, daysAhead: 30)
            snapshots.append(
                contentsOf: matchSnapshots(
                    from: upcomingScoreboard,
                    followedTeams: groupValue,
                    league: league,
                    includeUpcoming: true
                )
            )
        }

        let deduped = Dictionary(grouping: snapshots, by: \.id).compactMap { _, matches in
            matches.min(by: SportsSnapshotPriority.compare)
        }

        return deduped.sorted(by: SportsSnapshotPriority.compare)
    }

    func matchDetail(for game: GameSnapshot) async throws -> SportsMatchDetail {
        guard let eventID = game.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(game.leagueDefinition.sport)/\(game.leagueDefinition.league)/summary?event=\(eventID)")
        else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try decoder.decode(ESPNMatchSummaryResponse.self, from: data)
        return response.detail(fallbackGame: game)
    }

    func matchDetail(for match: SportsTeamScheduleMatch) async throws -> SportsMatchDetail {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(match.sport)/\(match.league)/summary?event=\(match.id)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try decoder.decode(ESPNMatchSummaryResponse.self, from: data)
        return response.detail(fallbackMatch: match)
    }

    private func fetchScoreboard(for league: SportsLeagueDefinition) async throws -> ESPNScoreboardResponse {
        let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(league.sport)/\(league.league)/scoreboard")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(ESPNScoreboardResponse.self, from: data)
    }

    private func fetchScoreboard(for league: SportsLeagueDefinition, daysAhead: Int) async throws -> ESPNScoreboardResponse {
        guard let url = scoreboardURL(for: league, daysAhead: daysAhead) else {
            return try await fetchScoreboard(for: league)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(ESPNScoreboardResponse.self, from: data)
    }

    private func matchSnapshots(
        from response: ESPNScoreboardResponse,
        followedTeams: [FollowedTeam],
        league: SportsLeagueDefinition,
        includeUpcoming: Bool
    ) -> [GameSnapshot] {
        let followedByID = Dictionary(uniqueKeysWithValues: followedTeams.map { ($0.teamId, $0) })

        return response.events.compactMap { event in
            guard let competition = event.competitions.first else { return nil }
            let competitors = competition.competitors.compactMap { $0 }
            guard competitors.count >= 2 else { return nil }

            let matchingCompetitor = competitors.first {
                guard let teamID = $0.team?.id else { return false }
                return followedByID[teamID] != nil
            }
            guard let matchingCompetitor,
                  let followedID = matchingCompetitor.team?.id,
                  let followedTeam = followedByID[followedID]
            else {
                return nil
            }

            guard let homeCompetitor = competitors.first(where: { $0.homeAway == "home" }) ?? competitors.first,
                  let awayCompetitor = competitors.first(where: { $0.homeAway == "away" }) ?? competitors.dropFirst().first
            else {
                return nil
            }

            let status = competition.status ?? event.status
            let state = SportsGameState.fromESPN(status?.type?.state)
            let startDate = ESPNDate.parse(event.date ?? "")
            let snapshot = GameSnapshot(
                id: event.id ?? UUID().uuidString,
                competition: event.shortName ?? event.name ?? league.subtitle,
                state: state,
                clock: status?.displayClock ?? "",
                statusDetail: status?.type?.shortDetail ?? "",
                home: mapSide(homeCompetitor),
                away: mapSide(awayCompetitor),
                events: mapGoalEvents(competition.details ?? []),
                eventURL: Self.eventURL(for: event.id, league: league),
                startDate: startDate,
                followedTeamID: followedTeam.id,
                leagueDefinition: league
            )

            // Live games must always be retained. ESPN can return a UTC date that
            // falls on a different local calendar day around midnight.
            if snapshot.state.isLive || snapshot.isToday {
                return snapshot
            }

            if includeUpcoming,
               let startDate = snapshot.startDate,
               startDate >= Date() {
                return snapshot
            }

            return nil
        }
    }

    private func mapSide(_ competitor: ESPNCompetitor) -> SportsTeamSide {
        let record = competitor.records?.first(where: { ($0.summary ?? "").isEmpty == false })?.summary
        return SportsTeamSide(
            teamId: competitor.team?.id ?? "",
            name: competitor.team?.displayName ?? competitor.team?.shortDisplayName ?? competitor.team?.name ?? "Unknown Team",
            abbreviation: competitor.team?.abbreviation ?? "",
            logoURL: competitor.team?.logo ?? competitor.team?.logos?.first?.href ?? "",
            score: competitor.score ?? "-",
            record: record
        )
    }

    private func mapGoalEvents(_ details: [ESPNCompetitionDetail]) -> [GoalEvent] {
        details.compactMap { detail in
            guard detail.scoringPlay == true else { return nil }
            return GoalEvent(
                teamId: detail.team?.id ?? "",
                player: detail.athletesInvolved?.first?.displayName ?? detail.text ?? "Goal",
                minute: detail.clock?.displayValue ?? ""
            )
        }
    }

    private static func eventURL(for eventID: String?, league: SportsLeagueDefinition) -> URL? {
        guard let eventID, !eventID.isEmpty else {
            return URL(string: "https://www.espn.com")
        }
        return URL(string: "https://www.espn.com/\(league.espnGamePath)/_/gameId/\(eventID)")
    }
}

enum SportsSnapshotPriority {
    static func score(for snapshot: GameSnapshot) -> Int {
        if snapshot.state.isLive { return 0 }
        if snapshot.isStartingSoonToday { return 1 }
        if snapshot.state.isPost && snapshot.isToday { return 2 }
        return 3
    }

    static func compare(lhs: GameSnapshot, rhs: GameSnapshot) -> Bool {
        let lhsScore = score(for: lhs)
        let rhsScore = score(for: rhs)
        if lhsScore != rhsScore { return lhsScore < rhsScore }

        let lhsDate = lhs.startDate ?? .distantFuture
        let rhsDate = rhs.startDate ?? .distantFuture
        if lhsDate != rhsDate { return lhsDate < rhsDate }

        return lhs.followedTeamID < rhs.followedTeamID
    }
}

@MainActor
final class SportsSearchModel: ObservableObject {
    @Published var selectedLeague: SportsLeagueDefinition = .defaultLeague
    @Published var query = ""
    @Published private(set) var results: [SportsTeamSearchResult] = []
    @Published private(set) var followedTeams: [FollowedTeam] = SportsPreferences.loadFollowedTeams()
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var searchTask: Task<Void, Never>?
    private var defaultsObserver: NSObjectProtocol?

    init() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.followedTeams = SportsPreferences.loadFollowedTeams()
            }
        }

        runSearch()
    }

    deinit {
        searchTask?.cancel()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    func runSearch() {
        searchTask?.cancel()
        let selectedLeague = selectedLeague
        let query = query

        searchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.isLoading = true
            self.errorMessage = nil

            do {
                let results = try await SportsDataService.shared.searchTeams(query: query, league: selectedLeague)
                guard !Task.isCancelled else { return }
                self.results = results
            } catch {
                guard !Task.isCancelled else { return }
                self.results = []
                self.errorMessage = error.localizedDescription
            }

            self.isLoading = false
        }
    }

    func toggleFollow(_ team: SportsTeamSearchResult) {
        SportsPreferences.toggleFollow(team)
        followedTeams = SportsPreferences.loadFollowedTeams()
    }

    func remove(_ team: FollowedTeam) {
        SportsPreferences.removeFollowedTeam(team)
        followedTeams = SportsPreferences.loadFollowedTeams()
    }

    func isFollowing(_ team: SportsTeamSearchResult) -> Bool {
        followedTeams.contains { $0.teamId == team.id && $0.sport == team.sport && $0.league == team.league }
    }
}

@MainActor
final class SportsWidgetModel: ObservableObject, InteractiveWidgetRuntime {
    let interactiveKind: WidgetManifest.Interactive.Kind = .sports
    let widgetID: String

    @Published private(set) var followedTeams: [FollowedTeam]
    @Published private(set) var games: [GameSnapshot] = []
    @Published private(set) var primaryGame: GameSnapshot?
    @Published var focusedGameID: String?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var matchDetails: [String: SportsMatchDetail] = [:]
    @Published private(set) var detailLoadingGameID: String?
    @Published private(set) var detailErrorMessage: String?

    private var refreshTask: Task<Void, Never>?
    private var appIsActive = NSApp.isActive
    private var activityObservers: [NSObjectProtocol] = []

    init(widgetID: String) {
        self.widgetID = widgetID
        self.followedTeams = SportsPreferences.loadFollowedTeams()
        registerNotifications()
        startPollingLoop()
    }

    deinit {
        refreshTask?.cancel()
        activityObservers.forEach(NotificationCenter.default.removeObserver)
    }

    var focusedGame: GameSnapshot? {
        if let focusedGameID, let match = games.first(where: { $0.id == focusedGameID }) {
            return match
        }
        return primaryGame
    }

    var compactGame: GameSnapshot? {
        guard Defaults[.sportsShowLiveInClosedNotch] else { return nil }
        return primaryGame?.state.isLive == true ? primaryGame : nil
    }

    func focus(game: GameSnapshot) {
        focusedGameID = game.id
    }

    func focusAdjacentGame(step: Int) {
        guard !games.isEmpty else { return }

        let currentIndex: Int
        if let focusedGameID,
           let index = games.firstIndex(where: { $0.id == focusedGameID }) {
            currentIndex = index
        } else if let primaryGame,
                  let index = games.firstIndex(where: { $0.id == primaryGame.id }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }

        let nextIndex = min(max(currentIndex + step, 0), games.count - 1)
        focusedGameID = games[nextIndex].id
    }

    func hasAdjacentGame(step: Int) -> Bool {
        guard !games.isEmpty else { return false }

        let currentIndex: Int
        if let focusedGameID,
           let index = games.firstIndex(where: { $0.id == focusedGameID }) {
            currentIndex = index
        } else if let primaryGame,
                  let index = games.firstIndex(where: { $0.id == primaryGame.id }) {
            currentIndex = index
        } else {
            currentIndex = 0
        }

        let nextIndex = currentIndex + step
        return games.indices.contains(nextIndex)
    }

    func detail(for game: GameSnapshot) -> SportsMatchDetail? {
        matchDetails[game.id]
    }

    func loadDetail(for game: GameSnapshot) async {
        if matchDetails[game.id] != nil { return }
        detailLoadingGameID = game.id
        detailErrorMessage = nil
        defer {
            if detailLoadingGameID == game.id { detailLoadingGameID = nil }
        }

        do {
            matchDetails[game.id] = try await SportsDataService.shared.matchDetail(for: game)
        } catch {
            detailErrorMessage = error.localizedDescription
        }
    }

    func openFocusedGame() {
        guard let url = focusedGame?.eventURL else { return }
        NSWorkspace.shared.open(url)
    }

    func refreshNow() async {
        followedTeams = SportsPreferences.loadFollowedTeams()
        guard !followedTeams.isEmpty else {
            games = []
            primaryGame = nil
            focusedGameID = nil
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let snapshots = try await SportsDataService.shared.snapshots(for: followedTeams)
            let visibleMatches = Array(snapshots.prefix(max(2, min(7, Defaults[.sportsMaximumMatches]))))
            games = visibleMatches
            primaryGame = visibleMatches.first(where: { $0.state.isLive }) ?? visibleMatches.first
            if focusedGame == nil {
                focusedGameID = primaryGame?.id
            } else if let focusedGameID, !visibleMatches.contains(where: { $0.id == focusedGameID }) {
                self.focusedGameID = primaryGame?.id
            }
            errorMessage = nil
        } catch {
            games = []
            primaryGame = nil
            errorMessage = error.localizedDescription
        }
    }

    private func startPollingLoop() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                // InterestingNotch is an accessory/menu-bar app and can report
                // itself inactive while the notch is visible. Live sports must
                // continue polling in that state so clocks and scores do not
                // freeze after the widget is mounted.
                await refreshNow()

                let delay = nextRefreshInterval()
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private func nextRefreshInterval() -> TimeInterval {
        if !appIsActive { return 300 }
        if games.contains(where: { $0.state.isLive }) { return 30 }
        if games.contains(where: { $0.isStartingSoonToday || ($0.state.isPost && $0.isToday) }) { return 900 }

        let nextMidnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 5),
            matchingPolicy: .nextTimePreservingSmallerComponents
        ) ?? Date().addingTimeInterval(21_600)
        return max(1_800, nextMidnight.timeIntervalSinceNow)
    }

    private func registerNotifications() {
        let center = NotificationCenter.default

        activityObservers.append(
            center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.appIsActive = true
                }
            }
        )
        activityObservers.append(
            center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.appIsActive = false
                }
            }
        )
        activityObservers.append(
            center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: nil) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let updatedTeams = SportsPreferences.loadFollowedTeams()
                    let teamsChanged = updatedTeams != self.followedTeams
                    self.followedTeams = updatedTeams
                    self.objectWillChange.send()
                    if teamsChanged {
                        await self.refreshNow()
                    }
                }
            }
        )
    }
}

private struct ESPNTeamsResponse: Decodable {
    let sports: [ESPNSportGroup]
}

private struct ESPNScheduleResponse: Decodable {
    let events: [ESPNScheduleEvent]
}

private enum ESPNDate {
    private static let formatters: [DateFormatter] = {
        let patterns = [
            "yyyy-MM-dd'T'HH:mm'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mmZ",
            "yyyy-MM-dd'T'HH:mm:ssZ"
        ]

        return patterns.map { pattern in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = pattern
            return formatter
        }
    }()

    static func parse(_ string: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}

private struct ESPNScheduleEvent: Decodable {
    let id: String
    let date: String
    let name: String
    let shortName: String?
    let competitions: [ESPNScheduleCompetition]
}

private struct ESPNScheduleCompetition: Decodable {
    let id: String
    let date: String
    let venue: ESPNScheduleVenue?
    let competitors: [ESPNScheduleCompetitor]
    let status: ESPNScheduleStatus?
}

private struct ESPNScheduleCompetitor: Decodable {
    let id: String
    let homeAway: String
    let winner: Bool?
    let team: ESPNScheduleTeam
    let score: ESPNScheduleScore?
}

private struct ESPNScheduleTeam: Decodable {
    let id: String
    let displayName: String
    let shortDisplayName: String?
    let abbreviation: String?
    let logos: [ESPNScheduleLogo]?

    var logoURL: String? {
        logos?.first(where: { ($0.rel ?? []).contains("default") })?.href
            ?? logos?.first?.href
    }
}

private struct ESPNScheduleLogo: Decodable {
    let href: String
    let rel: [String]?
}

private struct ESPNScheduleScore: Decodable {
    let value: Double?
    let displayValue: String?
}

private struct ESPNScheduleStatus: Decodable {
    let type: ESPNScheduleStatusType?
}

private struct ESPNScheduleStatusType: Decodable {
    let state: String?
    let completed: Bool?
    let detail: String?
    let shortDetail: String?
}

private struct ESPNScheduleVenue: Decodable {
    let fullName: String?
}

private struct ESPNSportGroup: Decodable {
    let leagues: [ESPNTeamLeague]
}

private struct ESPNTeamLeague: Decodable {
    let teams: [ESPNTeamWrapper]
}

private struct ESPNTeamWrapper: Decodable {
    let team: ESPNTeam?
}

private struct ESPNScoreboardResponse: Decodable {
    let events: [ESPNEvent]
}

private struct ESPNEvent: Decodable {
    let id: String?
    let name: String?
    let shortName: String?
    let date: String?
    let competitions: [ESPNCompetition]
    let status: ESPNStatus?
}

private struct ESPNCompetition: Decodable {
    let competitors: [ESPNCompetitor]
    let details: [ESPNCompetitionDetail]?
    let status: ESPNStatus?
    let venue: ESPNVenue?
}

private struct ESPNCompetitionDetail: Decodable {
    let scoringPlay: Bool?
    let text: String?
    let team: ESPNTeam?
    let athletesInvolved: [ESPNAthlete]?
    let clock: ESPNDisplayClock?
}

private struct ESPNAthlete: Decodable {
    let displayName: String?
}

private struct ESPNDisplayClock: Decodable {
    let displayValue: String?
}

private struct ESPNCompetitor: Decodable {
    let homeAway: String?
    let team: ESPNTeam?
    let score: String?
    let records: [ESPNRecord]?
}

private struct ESPNRecord: Decodable {
    let summary: String?
}

private struct ESPNTeam: Decodable {
    let id: String?
    let displayName: String?
    let shortDisplayName: String?
    let name: String?
    let abbreviation: String?
    let logo: String?
    let logos: [ESPNLogo]?

    var logoURL: String? {
        logo
            ?? logos?.compactMap(\.href).first
    }
}

private struct ESPNLogo: Decodable {
    let href: String?
}

private struct ESPNStatus: Decodable {
    let displayClock: String?
    let type: ESPNStatusType?
}

private struct ESPNStatusType: Decodable {
    let state: String?
    let detail: String?
    let shortDetail: String?
}

private struct ESPNMatchSummaryResponse: Decodable {
    let header: ESPNMatchHeader?
    let gameInfo: ESPNGameInfo?
    let boxscore: ESPNBoxscore?
    let keyEvents: [ESPNKeyEvent]?
    let commentary: [ESPNCommentary]?
    let rosters: [ESPNRosterTeam]?

    enum CodingKeys: String, CodingKey {
        case header
        case gameInfo
        case boxscore
        case keyEvents
        case commentary
        case rosters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // ESPN occasionally adds or changes one summary section while the
        // scoreboard remains valid. Decode each section independently so one
        // optional section cannot leave the detail view spinning forever.
        header = try? container.decode(ESPNMatchHeader.self, forKey: .header)
        gameInfo = try? container.decode(ESPNGameInfo.self, forKey: .gameInfo)
        boxscore = try? container.decode(ESPNBoxscore.self, forKey: .boxscore)
        keyEvents = try? container.decode([ESPNKeyEvent].self, forKey: .keyEvents)
        commentary = try? container.decode([ESPNCommentary].self, forKey: .commentary)
        rosters = try? container.decode([ESPNRosterTeam].self, forKey: .rosters)
    }

    func detail(
        fallbackGame: GameSnapshot? = nil,
        fallbackMatch: SportsTeamScheduleMatch? = nil
    ) -> SportsMatchDetail {
        let competitors = header?.competitions?.first?.competitors ?? []
        let resolved = resolvedTeams(competitors: competitors, fallbackGame: fallbackGame, fallbackMatch: fallbackMatch)
        let timeline = timelineEvents(home: resolved.home, away: resolved.away)
        let heroEvents = timeline.filter { $0.icon == "soccerball" }
            .map {
                SportsMatchDetail.HeroEvent(
                    id: $0.id,
                    text: $0.text,
                    minute: $0.minute,
                    side: $0.side
                )
            }

        return SportsMatchDetail(
            title: matchTitle(home: resolved.home.name, away: resolved.away.name),
            competition: competitionText(fallbackGame: fallbackGame),
            statusText: statusText(fallbackGame: fallbackGame, fallbackMatch: fallbackMatch),
            home: resolved.home,
            away: resolved.away,
            heroEvents: heroEvents,
            teamStats: teamStats(),
            keyEvents: timeline,
            infoRows: infoRows(fallbackMatch: fallbackMatch),
            commentary: (commentary ?? []).compactMap { $0.text }.filter { !$0.isEmpty }
        )
    }

    private func matchTitle(home: String, away: String) -> String {
        "\(home) vs \(away)"
    }

    private func competitionText(fallbackGame: GameSnapshot?) -> String {
        header?.competitions?.first?.league?.shortName
            ?? header?.competitions?.first?.league?.name
            ?? fallbackGame?.competition
            ?? "Match"
    }

    private func statusText(fallbackGame: GameSnapshot?, fallbackMatch: SportsTeamScheduleMatch?) -> String {
        header?.competitions?.first?.status?.type?.shortDetail
            ?? header?.competitions?.first?.status?.type?.detail
            ?? fallbackGame?.displayStatus
            ?? fallbackMatch?.date.formatted(date: .omitted, time: .shortened)
            ?? "Match"
    }

    private func resolvedTeams(
        competitors: [ESPNHeaderCompetitor],
        fallbackGame: GameSnapshot?,
        fallbackMatch: SportsTeamScheduleMatch?
    ) -> (home: SportsMatchDetail.TeamSummary, away: SportsMatchDetail.TeamSummary) {
        let homeCompetitor = competitors.first(where: { $0.homeAway == "home" })
        let awayCompetitor = competitors.first(where: { $0.homeAway == "away" })

        let fallbackHomeName = fallbackMatch?.isHome == true ? fallbackMatch?.teamName : fallbackMatch?.opponentName
        let fallbackAwayName = fallbackMatch?.isHome == true ? fallbackMatch?.opponentName : fallbackMatch?.teamName
        let fallbackHomeLogo = fallbackMatch?.isHome == true ? fallbackMatch?.teamLogoURL : fallbackMatch?.opponentLogoURL
        let fallbackAwayLogo = fallbackMatch?.isHome == true ? fallbackMatch?.opponentLogoURL : fallbackMatch?.teamLogoURL

        let home = SportsMatchDetail.TeamSummary(
            id: homeCompetitor?.team?.id ?? fallbackGame?.home.teamId ?? fallbackMatch?.teamID ?? "home",
            name: homeCompetitor?.team?.displayName ?? homeCompetitor?.team?.shortDisplayName ?? homeCompetitor?.team?.name ?? fallbackGame?.home.name ?? fallbackHomeName ?? "Home",
            logoURL: homeCompetitor?.team?.logoURL ?? fallbackGame?.home.logoURL ?? fallbackHomeLogo ?? "",
            score: homeCompetitor?.score ?? fallbackGame?.home.score,
            homeAway: .home
        )
        let away = SportsMatchDetail.TeamSummary(
            id: awayCompetitor?.team?.id ?? fallbackGame?.away.teamId ?? fallbackMatch?.opponentName ?? "away",
            name: awayCompetitor?.team?.displayName ?? awayCompetitor?.team?.shortDisplayName ?? awayCompetitor?.team?.name ?? fallbackGame?.away.name ?? fallbackAwayName ?? "Away",
            logoURL: awayCompetitor?.team?.logoURL ?? fallbackGame?.away.logoURL ?? fallbackAwayLogo ?? "",
            score: awayCompetitor?.score ?? fallbackGame?.away.score,
            homeAway: .away
        )
        return (home, away)
    }

    private func timelineEvents(
        home: SportsMatchDetail.TeamSummary,
        away: SportsMatchDetail.TeamSummary
    ) -> [SportsMatchDetail.Event] {
        let rosterLookup = rosterNamesByTeamID()
        return (keyEvents ?? [])
            .compactMap { event -> SportsMatchDetail.Event? in
                let type = event.type?.type ?? ""
                let isCard = type.localizedCaseInsensitiveContains("card")
                guard event.scoringPlay == true || isCard else { return nil }

                let side = resolvedSide(for: event, home: home, away: away, rosterLookup: rosterLookup)
                let minute = event.clock?.displayValue ?? "–"
                let text = event.primaryText
                return SportsMatchDetail.Event(
                    id: event.id ?? "\(type)-\(minute)-\(text)",
                    text: text,
                    minute: minute,
                    icon: iconName(for: type, scoringPlay: event.scoringPlay == true),
                    side: side,
                    periodNumber: event.period?.number ?? 0,
                    sortValue: event.clock?.sortValue ?? 0
                )
            }
            .sorted {
                if $0.periodNumber != $1.periodNumber { return $0.periodNumber < $1.periodNumber }
                if $0.sortValue != $1.sortValue { return $0.sortValue < $1.sortValue }
                return $0.minute.localizedStandardCompare($1.minute) == .orderedAscending
            }
    }

    private func teamStats() -> [SportsMatchDetail.TeamStat] {
        let orderedNames = ["possessionPct", "totalShots", "shotsOnTarget", "wonCorners", "foulsCommitted", "yellowCards", "redCards"]
        let labels: [String: String] = [
            "possessionPct": "Possession",
            "totalShots": "Shots",
            "shotsOnTarget": "On target",
            "wonCorners": "Corners",
            "foulsCommitted": "Fouls",
            "yellowCards": "Yellow cards",
            "redCards": "Red cards"
        ]

        let homeTeam = boxscore?.teams?.first(where: { $0.homeAway == "home" }) ?? boxscore?.teams?.first
        let awayTeam = boxscore?.teams?.first(where: { $0.homeAway == "away" }) ?? boxscore?.teams?.dropFirst().first

        return orderedNames.compactMap { name in
            let homeValue = homeTeam?.statistics?.first(where: { ($0.name ?? $0.label) == name })?.displayValue
            let awayValue = awayTeam?.statistics?.first(where: { ($0.name ?? $0.label) == name })?.displayValue
            guard homeValue != nil || awayValue != nil else { return nil }

            let homeNumber = numericStatValue(homeValue)
            let awayNumber = numericStatValue(awayValue)
            let total = max(homeNumber + awayNumber, 0.0001)

            return SportsMatchDetail.TeamStat(
                id: name,
                name: name,
                label: labels[name] ?? name,
                homeValue: homeValue ?? "–",
                awayValue: awayValue ?? "–",
                homeFraction: homeNumber / total
            )
        }
    }

    private func infoRows(fallbackMatch: SportsTeamScheduleMatch?) -> [SportsMatchDetail.InfoRow] {
        var rows: [SportsMatchDetail.InfoRow] = []
        if let venue = gameInfo?.venue?.fullName, !venue.isEmpty {
            rows.append(.init(id: "venue", label: "Venue", value: venue))
        }
        if let location = gameInfo?.venue?.locationText, !location.isEmpty {
            rows.append(.init(id: "location", label: "Location", value: location))
        }
        if let attendance = gameInfo?.attendance {
            rows.append(.init(id: "attendance", label: "Attendance", value: attendance.formatted(.number.grouping(.automatic))))
        }
        if let kickoff = header?.competitions?.first?.date,
           let date = ESPNDate.parse(kickoff) {
            rows.append(.init(id: "kickoff", label: "Kickoff", value: date.formatted(date: .abbreviated, time: .shortened)))
        } else if let fallbackMatch {
            rows.append(.init(id: "kickoff", label: "Kickoff", value: fallbackMatch.date.formatted(date: .abbreviated, time: .shortened)))
        }
        return rows
    }

    private func resolvedSide(
        for event: ESPNKeyEvent,
        home: SportsMatchDetail.TeamSummary,
        away: SportsMatchDetail.TeamSummary,
        rosterLookup: [String: Set<String>]
    ) -> SportsMatchDetail.EventSide {
        if let teamID = event.team?.id {
            if teamID == home.id { return .home }
            if teamID == away.id { return .away }
        }

        let text = event.primaryText.lowercased()
        if let homeNames = rosterLookup[home.id], homeNames.contains(where: text.contains) {
            return .home
        }
        if let awayNames = rosterLookup[away.id], awayNames.contains(where: text.contains) {
            return .away
        }

        return .neutral
    }

    private func rosterNamesByTeamID() -> [String: Set<String>] {
        Dictionary(uniqueKeysWithValues: (rosters ?? []).map { roster in
            let names = Set((roster.roster ?? []).compactMap { $0.displayName?.lowercased() })
            return (roster.team?.id ?? "", names)
        })
    }

    private func iconName(for type: String, scoringPlay: Bool) -> String {
        if scoringPlay { return "soccerball" }
        if type.localizedCaseInsensitiveContains("red-card") { return "rectangle.fill" }
        if type.localizedCaseInsensitiveContains("yellow-card") { return "rectangle.fill" }
        return "circle.fill"
    }

    private func numericStatValue(_ value: String?) -> Double {
        guard let value else { return 0 }
        return Double(value.replacingOccurrences(of: "%", with: "")) ?? 0
    }
}

private struct ESPNGameInfo: Decodable {
    let attendance: Int?
    let venue: ESPNVenue?
}

private struct ESPNBoxscore: Decodable {
    let teams: [ESPNBoxscoreTeam]?
}

private struct ESPNBoxscoreTeam: Decodable {
    let homeAway: String?
    let team: ESPNTeam?
    let statistics: [ESPNStat]?
}

private struct ESPNStat: Decodable {
    let name: String?
    let label: String?
    let displayValue: String?
}

private struct ESPNVenue: Decodable {
    let fullName: String?
    let address: ESPNVenueAddress?

    var locationText: String? {
        [address?.city, address?.state].compactMap { $0 }.joined(separator: ", ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }
}

private struct ESPNKeyEvent: Decodable {
    let id: String?
    let text: String?
    let clock: ESPNDisplayClock?
    let scoringPlay: Bool?
    let type: ESPNEventType?
    let period: ESPNEventPeriod?
    let team: ESPNTeam?

    var primaryText: String {
        text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Match event"
    }
}

private struct ESPNCommentary: Decodable {
    let text: String?
}

private struct ESPNMatchHeader: Decodable {
    let competitions: [ESPNHeaderCompetition]?
}

private struct ESPNHeaderCompetition: Decodable {
    let date: String?
    let competitors: [ESPNHeaderCompetitor]?
    let status: ESPNStatus?
    let league: ESPNLeague?
}

private struct ESPNHeaderCompetitor: Decodable {
    let homeAway: String?
    let score: String?
    let team: ESPNTeam?
}

private struct ESPNLeague: Decodable {
    let name: String?
    let shortName: String?
}

private struct ESPNEventType: Decodable {
    let type: String?
}

private struct ESPNEventPeriod: Decodable {
    let number: Int?
}

private struct ESPNVenueAddress: Decodable {
    let city: String?
    let state: String?
}

private struct ESPNRosterTeam: Decodable {
    let team: ESPNTeam?
    let roster: [ESPNAthlete]?
}

private extension ESPNDisplayClock {
    var sortValue: Int {
        Int(displayValue?.filter(\.isNumber) ?? "") ?? 0
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
