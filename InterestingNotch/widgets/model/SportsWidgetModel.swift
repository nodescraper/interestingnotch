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

enum GameFormat: Hashable, Sendable {
    case teamScore
    case leaderboard
    case sets
    case innings
}

struct SportsLeagueDefinition: Identifiable, Hashable, Sendable {
    let sport: String
    let league: String
    let name: String
    let group: String
    let format: GameFormat
    let sportPath: String
    let espnGamePath: String

    var id: String { "\(sport)/\(league)" }

    static let all: [SportsLeagueDefinition] = teamScoreLeagues + futureLeagues

    private static let teamScoreLeagues: [SportsLeagueDefinition] = [
        // Soccer
        teamScore("soccer", "eng.1", "Premier League", "soccer/match"),
        teamScore("soccer", "esp.1", "La Liga", "soccer/match"),
        teamScore("soccer", "ita.1", "Serie A", "soccer/match"),
        teamScore("soccer", "ger.1", "Bundesliga", "soccer/match"),
        teamScore("soccer", "fra.1", "Ligue 1", "soccer/match"),
        teamScore("soccer", "por.1", "Primeira Liga", "soccer/match"),
        teamScore("soccer", "ned.1", "Eredivisie", "soccer/match"),
        teamScore("soccer", "usa.1", "MLS", "soccer/match"),
        teamScore("soccer", "mex.1", "Liga MX", "soccer/match"),
        teamScore("soccer", "bra.1", "Brasileirão", "soccer/match"),
        teamScore("soccer", "arg.1", "Liga Profesional", "soccer/match"),
        teamScore("soccer", "sco.1", "Scottish Premiership", "soccer/match"),
        teamScore("soccer", "tur.1", "Süper Lig", "soccer/match"),
        teamScore("soccer", "bel.1", "Pro League", "soccer/match"),
        teamScore("soccer", "uefa.champions", "Champions League", "soccer/match"),
        teamScore("soccer", "uefa.europa", "Europa League", "soccer/match"),
        teamScore("soccer", "fifa.world", "World Cup", "soccer/match"),
        teamScore("soccer", "fifa.wwc", "Women's World Cup", "soccer/match"),
        teamScore("soccer", "uefa.euro", "Euros", "soccer/match"),
        teamScore("soccer", "conmebol.america", "Copa América", "soccer/match"),
        // Basketball
        teamScore("basketball", "nba", "NBA", "nba/game"),
        teamScore("basketball", "wnba", "WNBA", "wnba/game"),
        teamScore("basketball", "mens-college-basketball", "NCAAM", "mens-college-basketball/game"),
        teamScore("basketball", "womens-college-basketball", "NCAAW", "womens-college-basketball/game"),
        // American football
        teamScore("football", "nfl", "NFL", "nfl/game"),
        teamScore("football", "college-football", "NCAAF", "college-football/game"),
        // Hockey and baseball
        teamScore("hockey", "nhl", "NHL", "nhl/game"),
        teamScore("baseball", "mlb", "MLB", "mlb/game"),
        teamScore("baseball", "college-baseball", "NCAA Baseball", "college-baseball/game"),
    ]

    private static let futureLeagues: [SportsLeagueDefinition] = [
        // Defined now for future layouts; these remain hidden from settings/search.
        .init(sport: "racing", league: "f1", name: "Formula 1", group: "Motorsport", format: .leaderboard, sportPath: "racing", espnGamePath: "f1/race"),
        .init(sport: "golf", league: "pga", name: "PGA Tour", group: "Golf", format: .leaderboard, sportPath: "golf", espnGamePath: "golf/leaderboard"),
        .init(sport: "golf", league: "lpga", name: "LPGA Tour", group: "Golf", format: .leaderboard, sportPath: "golf", espnGamePath: "golf/leaderboard"),
        .init(sport: "tennis", league: "atp", name: "ATP", group: "Tennis", format: .sets, sportPath: "tennis", espnGamePath: "tennis/match"),
        .init(sport: "tennis", league: "wta", name: "WTA", group: "Tennis", format: .sets, sportPath: "tennis", espnGamePath: "tennis/match"),
        .init(sport: "mma", league: "ufc", name: "UFC", group: "MMA", format: .leaderboard, sportPath: "mma", espnGamePath: "mma/fight"),
        .init(sport: "cricket", league: "ipl", name: "IPL", group: "Cricket", format: .innings, sportPath: "cricket", espnGamePath: "cricket/match"),
    ]

    static let defaultLeague = all[0]
    static let supported: [SportsLeagueDefinition] = all.filter { formatIsSupported($0.format) }

    static func formatIsSupported(_ format: GameFormat) -> Bool {
        switch format {
        case .teamScore, .leaderboard, .sets:
            return true
        case .innings:
            return false
        }
    }

    var supportsTeamSelection: Bool {
        switch format {
        case .teamScore, .leaderboard, .sets:
            return true
        case .innings:
            return false
        }
    }

    var supportsCompetitorDetail: Bool { format == .teamScore }

    private static func teamScore(_ sport: String, _ league: String, _ name: String, _ espnGamePath: String) -> SportsLeagueDefinition {
        .init(sport: sport, league: league, name: name, group: sport == "football" ? "American Football" : sport.capitalized, format: .teamScore, sportPath: sport, espnGamePath: espnGamePath)
    }

    var title: String { group }
    var subtitle: String { name }

    static func league(forSport sport: String, league: String) -> SportsLeagueDefinition? {
        all.first { $0.sport == sport && $0.league == league }
    }

    static func leagues(forSportTitle title: String) -> [SportsLeagueDefinition] {
        supported.filter { $0.group == title }
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

struct FollowedPlayer: Codable, Equatable, Hashable, Identifiable, Sendable {
    let sport: String
    let league: String
    let playerId: String
    let name: String

    var id: String { "\(sport):\(league):\(playerId)" }
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
    let setScores: [String]
    let isWinner: Bool

    init(
        teamId: String,
        name: String,
        abbreviation: String,
        logoURL: String,
        score: String,
        record: String?,
        setScores: [String] = [],
        isWinner: Bool = false
    ) {
        self.teamId = teamId
        self.name = name
        self.abbreviation = abbreviation
        self.logoURL = logoURL
        self.score = score
        self.record = record
        self.setScores = setScores
        self.isWinner = isWinner
    }
}

struct GoalEvent: Equatable, Hashable, Identifiable, Sendable {
    let teamId: String
    let player: String
    let minute: String

    var id: String { "\(teamId)-\(player)-\(minute)" }
}

struct SportsLeaderboardEntry: Equatable, Hashable, Identifiable, Sendable {
    let position: Int
    let name: String
    let secondaryText: String?
    let trailingText: String?
    let flagURL: String?

    var id: String { "\(position)-\(name)" }
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
    let leaderboardEntries: [SportsLeaderboardEntry]
    let eventURL: URL?
    let startDate: Date?
    let followedTeamID: String
    let leagueDefinition: SportsLeagueDefinition
    let venueName: String?
    let venueCountry: String?

    var isLeagueScopedFollow: Bool {
        followedTeamID == "league" || followedTeamID == leagueDefinition.id
    }

    var isSpecificCompetitorFollow: Bool {
        !isLeagueScopedFollow
    }

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

    static func starredPlayers() -> [FollowedPlayer] {
        guard let data = Defaults[.sportsStarredPlayersData] else { return [] }
        let decoded = (try? JSONDecoder().decode([FollowedPlayer].self, from: data)) ?? []
        print("🎾 Starred players loaded:", decoded.map { "\($0.league):\($0.name)[\($0.playerId)]" }.joined(separator: ", "))
        return decoded
    }

    static func togglePlayer(_ player: SportsTeamSearchResult) {
        var players = starredPlayers()
        let id = "\(player.sport):\(player.league):\(player.id)"
        if let index = players.firstIndex(where: { $0.id == id }) {
            players.remove(at: index)
        } else {
            players.append(FollowedPlayer(sport: player.sport, league: player.league, playerId: player.id, name: player.name))
        }
        Defaults[.sportsStarredPlayersData] = try? JSONEncoder().encode(players)
        print("🎾 Starred players saved:", players.map { "\($0.league):\($0.name)[\($0.playerId)]" }.joined(separator: ", "))
    }

    static func isStarred(_ player: SportsTeamSearchResult, asPlayer: Bool) -> Bool {
        if asPlayer {
            return starredPlayers().contains { $0.id == "\(player.sport):\(player.league):\(player.id)" }
        }
        return isStarred(player)
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

        if league.sport == "tennis" {
            let players = try await tennisPlayers(for: league)
            teamCache[league.id] = players
            return players
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
        if dedupedTeams.isEmpty, league.format != .teamScore {
            let competitors = try await scoreboardParticipants(for: league)
            teamCache[league.id] = competitors
            return competitors
        }
        teamCache[league.id] = dedupedTeams
        return dedupedTeams
    }

    private func tennisPlayers(for league: SportsLeagueDefinition) async throws -> [SportsTeamSearchResult] {
        let response = try await fetchTennisScoreboard(for: league, daysAhead: 30)
        var players: [SportsTeamSearchResult] = []
        var groupingCount = 0
        var matchCount = 0
        var competitorCount = 0
        var missingIDCount = 0
        var missingNameCount = 0
        for event in response.events {
            for grouping in event.groupings ?? [] {
                groupingCount += 1
                for match in grouping.competitions ?? [] {
                    matchCount += 1
                    for competitor in match.competitors ?? [] {
                        competitorCount += 1
                        guard let id = tennisCompetitorID(for: competitor) else {
                            missingIDCount += 1
                            continue
                        }
                        guard let name = tennisCompetitorName(for: competitor) else {
                            missingNameCount += 1
                            continue
                        }
                        players.append(SportsTeamSearchResult(sport: league.sport, league: league.league, id: id, name: name, abbreviation: "", logoURL: ""))
                    }
                }
            }
        }
        let result = dedupeTeamResults(players).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        print("🎾 Tennis players (\(league.id)): events=\(response.events.count), groupings=\(groupingCount), matches=\(matchCount), competitors=\(competitorCount), uniquePlayers=\(result.count), missingIDs=\(missingIDCount), missingNames=\(missingNameCount)")
        return result
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

    private func scoreboardParticipants(for league: SportsLeagueDefinition) async throws -> [SportsTeamSearchResult] {
        let response = try await fetchScoreboard(for: league)
        let participants = response.events
            .flatMap(\.competitions)
            .flatMap(\.competitors)
            .compactMap { competitor -> SportsTeamSearchResult? in
                if let team = competitor.team {
                    return SportsTeamSearchResult(
                        sport: league.sport,
                        league: league.league,
                        id: team.id ?? competitor.id ?? UUID().uuidString,
                        name: team.displayName ?? team.shortDisplayName ?? team.name ?? "Unknown Team",
                        abbreviation: team.abbreviation ?? "",
                        logoURL: team.logoURL ?? ""
                    )
                }

                if let athlete = competitor.athlete {
                    return SportsTeamSearchResult(
                        sport: league.sport,
                        league: league.league,
                        id: competitor.id ?? athlete.id ?? UUID().uuidString,
                        name: athlete.displayName ?? athlete.shortName ?? athlete.fullName ?? "Unknown Competitor",
                        abbreviation: athlete.shortName ?? "",
                        logoURL: athlete.flag?.href ?? ""
                    )
                }

                if let roster = competitor.roster {
                    let firstAthlete = roster.athletes?.first
                    return SportsTeamSearchResult(
                        sport: league.sport,
                        league: league.league,
                        id: competitor.id ?? UUID().uuidString,
                        name: roster.displayName ?? roster.shortDisplayName ?? firstAthlete?.displayName ?? "Unknown Competitor",
                        abbreviation: roster.shortDisplayName ?? firstAthlete?.shortName ?? "",
                        logoURL: firstAthlete?.flag?.href ?? ""
                    )
                }

                return nil
            }

        return dedupeTeamResults(participants)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

            guard let selected = scheduleCompetitor(matching: team, in: competitors),
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

        return response.events.compactMap { event -> SportsTeamScheduleMatch? in
            guard let competition = event.competitions.first else { return nil }
            let competitors = competition.competitors
            guard competitors.count >= 2 else { return nil }

            guard let selected = scoreboardCompetitor(matching: team, in: competitors) else { return nil }
            let selectedTeamID = selected.team?.id ?? ""
            let opponent = competitors.first { competitor in
                competitor.team?.id != selectedTeamID
            } ?? competitors.dropFirst().first
            guard let opponent else { return nil }

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
        if league.sport == "racing", league.league == "f1" {
            return URL(string: "https://site.api.espn.com/apis/site/v2/sports/racing/f1/scoreboard?dates=20260101-20261231")
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        guard let endDate = calendar.date(byAdding: .day, value: daysAhead, to: startDate) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
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
                  let league = SportsLeagueDefinition.league(forSport: first.sport, league: first.league),
                  SportsLeagueDefinition.formatIsSupported(league.format)
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

    func snapshots(
        for followedTeams: [FollowedTeam],
        followedLeagues: [FollowedLeague],
        followedPlayers: [FollowedPlayer] = []
    ) async throws -> [GameSnapshot] {
        print("🏟️ Sports snapshots request: teams=\(followedTeams.count) leagues=\(followedLeagues.count) players=\(followedPlayers.count)")
        if !followedPlayers.isEmpty {
            print("🎾 Widget followed players:", followedPlayers.map { "\($0.league):\($0.name)[\($0.playerId)]" }.joined(separator: ", "))
        }
        var snapshots: [GameSnapshot] = []
        let followedLeagueIDs = Set(followedLeagues.map(\.id))
        let teamGroups = Dictionary(grouping: followedTeams, by: { "\($0.sport)|\($0.league)" })
        let leagueDefinitions = followedLeagues.compactMap { followedLeague -> SportsLeagueDefinition? in
            guard let definition = SportsLeagueDefinition.league(forSport: followedLeague.sport, league: followedLeague.league),
                  SportsLeagueDefinition.formatIsSupported(definition.format) else { return nil }
            return definition
        }

        // A team follow and a league follow can point at the same scoreboard.
        // Fetch it once, then apply the appropriate filter to the response.
        let playerDefinitions = followedPlayers.compactMap { SportsLeagueDefinition.league(forSport: $0.sport, league: $0.league) }
        let definitions = Set(teamGroups.values.compactMap { $0.first?.leagueDefinition } + leagueDefinitions + playerDefinitions)
        for league in definitions {
            let teamGroup = teamGroups["\(league.sport)|\(league.league)"] ?? []
            if let scoreboard = try? await fetchScoreboard(for: league) {
                if league.format == .teamScore, !teamGroup.isEmpty {
                    snapshots.append(contentsOf: matchSnapshots(from: scoreboard, followedTeams: teamGroup, league: league, includeUpcoming: false))
                } else if league.format == .leaderboard, !teamGroup.isEmpty {
                    snapshots.append(contentsOf: leaderboardSnapshots(from: scoreboard, followedTeams: teamGroup, league: league, includeUpcoming: false))
                }
                if followedLeagueIDs.contains(league.id) {
                    snapshots.append(contentsOf: leagueSnapshots(from: scoreboard, league: league, includeUpcoming: false))
                }
            }

            do {
                if league.sport == "tennis" {
                    let players = followedPlayers.filter { $0.sport == league.sport && $0.league == league.league }
                    if players.isEmpty {
                        print("🎾 Tennis league \(league.id) is followed, but no starred competitors were loaded for the widget.")
                    }
                    if !players.isEmpty {
                        snapshots.append(contentsOf: try await tennisSnapshots(for: league, players: players))
                    }
                    if followedLeagueIDs.contains(league.id) {
                        snapshots.append(contentsOf: try await tennisLeagueSnapshots(for: league))
                    }
                    continue
                }
                let upcomingScoreboard = try await fetchScoreboard(for: league, daysAhead: 30)
                if league.format == .teamScore, !teamGroup.isEmpty {
                    snapshots.append(contentsOf: matchSnapshots(from: upcomingScoreboard, followedTeams: teamGroup, league: league, includeUpcoming: true))
                } else if league.format == .leaderboard, !teamGroup.isEmpty {
                    snapshots.append(contentsOf: leaderboardSnapshots(from: upcomingScoreboard, followedTeams: teamGroup, league: league, includeUpcoming: true))
                }
                if followedLeagueIDs.contains(league.id) {
                    snapshots.append(contentsOf: leagueSnapshots(from: upcomingScoreboard, league: league, includeUpcoming: true))
                }
            } catch {
                print("🟨 Sports scoreboard unavailable for \(league.id):", error)
            }
        }

        let deduped = Dictionary(grouping: snapshots, by: \.id).compactMap { _, matches in
            matches.min(by: SportsSnapshotPriority.compare)
        }
        return deduped.sorted(by: SportsSnapshotPriority.compare)
    }

    private func tennisSnapshots(for league: SportsLeagueDefinition, players: [FollowedPlayer]) async throws -> [GameSnapshot] {
        guard !players.isEmpty else { return [] }
        let response = try await fetchTennisScoreboard(for: league, daysAhead: 30)
        let followedIDs = Set(players.map(\.playerId))
        print("🎾 Tennis scan (\(league.id)): followedPlayers=\(players.map(\.name).joined(separator: ", ")), events=\(response.events.count)")
        var matchedCompetitions = 0
        let candidates = response.events.flatMap { event in
            (event.groupings ?? []).flatMap { grouping in
                (grouping.competitions ?? []).compactMap { match -> GameSnapshot? in
                    guard let competitors = match.competitors,
                          competitors.count >= 2,
                          competitors.contains(where: { competitor in
                              tennisCompetitorIdentifiers(for: competitor).contains(where: followedIDs.contains)
                          }),
                          let first = competitors.first,
                          let second = competitors.dropFirst().first else { return nil }

                    matchedCompetitions += 1
                    let status = match.status
                    let date = ESPNDate.parse(match.date ?? "")
                    let names = competitors.map { tennisCompetitorName(for: $0) ?? "?" }.joined(separator: " vs ")
                    print("🎾 Matched tennis competition (\(league.id)): id=\(match.id) state=\(status?.type?.state ?? "?") detail=\(status?.type?.detail ?? status?.type?.shortDetail ?? "?") date=\(match.date ?? "?") players=\(names)")
                    let snapshot = GameSnapshot(
                        id: match.id,
                        competition: event.name,
                        state: SportsGameState.fromESPN(status?.type?.state),
                        clock: status?.displayClock ?? "",
                        statusDetail: status?.type?.shortDetail ?? "",
                        home: mapTennisSide(first),
                        away: mapTennisSide(second),
                        events: [],
                        leaderboardEntries: [],
                        eventURL: Self.eventURL(for: match.id, league: league),
                        startDate: date,
                        followedTeamID: players.first(where: { followedIDs.contains($0.playerId) })?.id ?? "player",
                        leagueDefinition: league,
                        venueName: match.round?.displayName,
                        venueCountry: nil
                    )

                    if snapshot.state.isLive { return snapshot }
                    if snapshot.state == .pre, let date, date >= Date() { return snapshot }
                    if snapshot.state == .post, let date, date >= Date().addingTimeInterval(-86_400) { return snapshot }
                    print("🎾 Skipped tennis match after retention (\(league.id)): id=\(match.id) state=\(snapshot.state.rawValue) parsedDate=\(String(describing: date))")
                    return nil
                }
            }
        }
        print("🎾 Tennis competitions matched before retention (\(league.id)): \(matchedCompetitions)")
        let sorted = candidates.sorted { lhs, rhs in
            let rank: (GameSnapshot) -> Int = { snapshot in
                switch snapshot.state {
                case .live: return 0
                case .pre: return 1
                case .post: return 2
                case .unknown: return 3
                }
            }
            let lhsRank = rank(lhs)
            let rhsRank = rank(rhs)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            if lhs.state == .post {
                return (lhs.startDate ?? .distantPast) > (rhs.startDate ?? .distantPast)
            }
            return (lhs.startDate ?? .distantFuture) < (rhs.startDate ?? .distantFuture)
        }
        print("🎾 Tennis matches retained (\(league.id)): \(sorted.count)")
        return sorted
    }

    private func tennisLeagueSnapshots(for league: SportsLeagueDefinition) async throws -> [GameSnapshot] {
        let response = try await fetchTennisScoreboard(for: league, daysAhead: 30)
        print("🎾 Tennis league scan (\(league.id)): events=\(response.events.count)")

        let candidates = response.events.flatMap { event in
            (event.groupings ?? []).flatMap { grouping in
                (grouping.competitions ?? []).compactMap { match -> GameSnapshot? in
                    guard let competitors = match.competitors,
                          competitors.count >= 2,
                          let first = competitors.first,
                          let second = competitors.dropFirst().first else { return nil }

                    let firstName = tennisCompetitorName(for: first) ?? "?"
                    let secondName = tennisCompetitorName(for: second) ?? "?"
                    guard isMeaningfulTennisName(firstName) || isMeaningfulTennisName(secondName) else {
                        print("🎾 Skipped tennis league match with unknown competitors (\(league.id)): id=\(match.id) players=\(firstName) vs \(secondName)")
                        return nil
                    }

                    let status = match.status
                    let date = ESPNDate.parse(match.date ?? "")
                    let snapshot = GameSnapshot(
                        id: match.id,
                        competition: event.name,
                        state: SportsGameState.fromESPN(status?.type?.state),
                        clock: status?.displayClock ?? "",
                        statusDetail: status?.type?.shortDetail ?? "",
                        home: mapTennisSide(first),
                        away: mapTennisSide(second),
                        events: [],
                        leaderboardEntries: [],
                        eventURL: Self.eventURL(for: match.id, league: league),
                        startDate: date,
                        followedTeamID: league.id,
                        leagueDefinition: league,
                        venueName: match.round?.displayName,
                        venueCountry: nil
                    )

                    if snapshot.state.isLive { return snapshot }
                    if snapshot.state == .pre, let date, date >= Date() { return snapshot }
                    if snapshot.state == .post, let date, date >= Date().addingTimeInterval(-86_400) { return snapshot }
                    return nil
                }
            }
        }

        let sorted = candidates.sorted { lhs, rhs in
            let rank: (GameSnapshot) -> Int = { snapshot in
                switch snapshot.state {
                case .live: return 0
                case .pre: return 1
                case .post: return 2
                case .unknown: return 3
                }
            }
            let lhsRank = rank(lhs)
            let rhsRank = rank(rhs)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            if lhs.state == .post {
                return (lhs.startDate ?? .distantPast) > (rhs.startDate ?? .distantPast)
            }
            return (lhs.startDate ?? .distantFuture) < (rhs.startDate ?? .distantFuture)
        }
        print("🎾 Tennis league matches retained (\(league.id)): \(sorted.count)")
        return sorted
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
        return try await fetchScoreboard(from: url, league: league)
    }

    private func fetchScoreboard(for league: SportsLeagueDefinition, daysAhead: Int) async throws -> ESPNScoreboardResponse {
        guard let url = scoreboardURL(for: league, daysAhead: daysAhead) else {
            return try await fetchScoreboard(for: league)
        }
        return try await fetchScoreboard(from: url, league: league)
    }

    private func fetchScoreboard(from url: URL, league: SportsLeagueDefinition) async throws -> ESPNScoreboardResponse {
        let (data, _) = try await URLSession.shared.data(from: url)

        do {
            let decoded = try decoder.decode(ESPNScoreboardResponse.self, from: data)
            return decoded
        } catch let error as DecodingError {
            throw error
        }
    }

    private func fetchTennisScoreboard(for league: SportsLeagueDefinition, daysAhead: Int) async throws -> TennisScoreboardResponse {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: daysAhead, to: start) ?? start
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd"
        let range = "\(formatter.string(from: start))-\(formatter.string(from: end))"
        let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/tennis/\(league.league)/scoreboard?dates=\(range)")!
        print("🎾 Tennis request:", url.absoluteString)
        let (data, response) = try await URLSession.shared.data(from: url)
        print("🎾 Tennis response: status=\((response as? HTTPURLResponse)?.statusCode ?? -1), bytes=\(data.count)")
        debugLogLiveTennisPayload(data, leagueID: league.id)
        do {
            let decoded = try decoder.decode(TennisScoreboardResponse.self, from: data)
            print("🎾 Tennis decoded events:", decoded.events.count)
            return decoded
        } catch let error as DecodingError {
            print("🟥 Tennis decode error:", error)
            throw error
        }
    }

    private func debugLogLiveTennisPayload(_ data: Data, leagueID: String) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = root["events"] as? [[String: Any]] else { return }

        for event in events {
            let eventName = event["name"] as? String ?? "?"
            let groupings = event["groupings"] as? [[String: Any]] ?? []

            for grouping in groupings {
                let competitions = grouping["competitions"] as? [[String: Any]] ?? []

                for competition in competitions {
                    let status = ((competition["status"] as? [String: Any])?["type"] as? [String: Any]) ?? [:]
                    let state = status["state"] as? String ?? "?"
                    guard state == "in" || state == "live" else { continue }

                    let matchID = competition["id"] as? String ?? "?"
                    let detail = status["detail"] as? String ?? status["shortDetail"] as? String ?? "?"
                    let competitors = competition["competitors"] as? [[String: Any]] ?? []
                    let competitorNames = competitors.compactMap {
                        (($0["athlete"] as? [String: Any])?["displayName"] as? String)
                    }
                    let competitorKeys = competitors.map { Array($0.keys).sorted() }
                    let athleteKeys = competitors.map {
                        Array((($0["athlete"] as? [String: Any]) ?? [:]).keys).sorted()
                    }
                    let linescoreKeys = competitors.map { competitor in
                        let linescores = competitor["linescores"] as? [[String: Any]] ?? []
                        return linescores.first.map { Array($0.keys).sorted() } ?? []
                    }

                    print("🎾 Live tennis raw (\(leagueID)): event=\(eventName) match=\(matchID) detail=\(detail) players=\(competitorNames.joined(separator: " vs "))")
                    print("🎾 Live tennis competitor keys (\(leagueID)): \(competitorKeys)")
                    print("🎾 Live tennis athlete keys (\(leagueID)): \(athleteKeys)")
                    print("🎾 Live tennis first linescore keys (\(leagueID)): \(linescoreKeys)")
                    print("🎾 Live tennis competitors payload (\(leagueID)): \(competitors)")
                }
            }
        }
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
                leaderboardEntries: [],
                eventURL: Self.eventURL(for: event.id, league: league),
                startDate: startDate,
                followedTeamID: followedTeam.id,
                leagueDefinition: league,
                venueName: competition.venue?.fullName,
                venueCountry: nil
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

    private func leagueSnapshots(
        from response: ESPNScoreboardResponse,
        league: SportsLeagueDefinition,
        includeUpcoming: Bool
    ) -> [GameSnapshot] {
        response.events.compactMap { event in
            guard let competition = event.competitions.first else { return nil }

            if league.format == .leaderboard, league.sport == "racing" {
                return raceSnapshot(from: event, competition: competition, league: league, includeUpcoming: includeUpcoming)
            }

            guard competition.competitors.count >= 2,
                  let home = competition.competitors.first(where: { $0.homeAway == "home" }) ?? competition.competitors.first,
                  let away = competition.competitors.first(where: { $0.homeAway == "away" }) ?? competition.competitors.dropFirst().first
            else { return nil }

            let status = competition.status ?? event.status
            let snapshot = GameSnapshot(
                id: event.id ?? UUID().uuidString,
                competition: event.shortName ?? event.name ?? league.subtitle,
                state: SportsGameState.fromESPN(status?.type?.state),
                clock: status?.displayClock ?? "",
                statusDetail: status?.type?.shortDetail ?? "",
                home: mapSide(home),
                away: mapSide(away),
                events: mapGoalEvents(competition.details ?? []),
                leaderboardEntries: [],
                eventURL: Self.eventURL(for: event.id, league: league),
                startDate: ESPNDate.parse(event.date ?? ""),
                followedTeamID: "league",
                leagueDefinition: league,
                venueName: competition.venue?.fullName,
                venueCountry: nil
            )

            if snapshot.state.isLive || snapshot.isToday { return snapshot }
            if includeUpcoming, let startDate = snapshot.startDate, startDate >= Date() { return snapshot }
            return nil
        }
    }

    private func leaderboardSnapshots(
        from response: ESPNScoreboardResponse,
        followedTeams: [FollowedTeam],
        league: SportsLeagueDefinition,
        includeUpcoming: Bool
    ) -> [GameSnapshot] {
        return response.events.compactMap { event in
            guard let competition = event.competitions.first else { return nil }

            let matchedFollow = competition.competitors.compactMap { competitor -> FollowedTeam? in
                followedTeams.first(where: { leaderboardCompetitorMatches($0, competitor: competitor) })
            }.first

            // ESPN publishes upcoming F1 races before it publishes their driver
            // field, so pre-race competitions commonly have zero competitors.
            // A driver follow still means the user wants that race in the notch.
            let followedTeam = matchedFollow ?? (league.sport == "racing" ? followedTeams.first : nil)
            guard let followedTeam else { return nil }

            if matchedFollow == nil, league.sport == "racing" {
                print(
                    "🏎️ F1 race has no matching driver payload; keeping race for followed driver:",
                    followedTeam.name,
                    event.name ?? event.id ?? "unknown event",
                    "competitors=\(competition.competitors.count)"
                )
            }

            if league.sport == "racing",
               let snapshot = raceSnapshot(from: event, competition: competition, league: league, includeUpcoming: includeUpcoming) {
                return GameSnapshot(
                    id: snapshot.id,
                    competition: snapshot.competition,
                    state: snapshot.state,
                    clock: snapshot.clock,
                    statusDetail: snapshot.statusDetail,
                    home: snapshot.home,
                    away: snapshot.away,
                    events: snapshot.events,
                    leaderboardEntries: snapshot.leaderboardEntries,
                    eventURL: snapshot.eventURL,
                    startDate: snapshot.startDate,
                    followedTeamID: followedTeam.id,
                    leagueDefinition: snapshot.leagueDefinition,
                    venueName: snapshot.venueName,
                    venueCountry: snapshot.venueCountry
                )
            }

            return nil
        }
    }

    private func raceSnapshot(
        from event: ESPNEvent,
        competition: ESPNCompetition,
        league: SportsLeagueDefinition,
        includeUpcoming: Bool
    ) -> GameSnapshot? {
        let status = competition.status ?? event.status
        let parsedDate = ESPNDate.parse(event.date ?? "")
        let snapshot = GameSnapshot(
            id: event.id ?? UUID().uuidString,
            competition: event.name ?? event.shortName ?? league.subtitle,
            state: SportsGameState.fromESPN(status?.type?.state),
            clock: status?.displayClock ?? "",
            statusDetail: status?.type?.shortDetail ?? "",
            home: SportsTeamSide(teamId: "", name: "", abbreviation: "", logoURL: "", score: "", record: nil),
            away: SportsTeamSide(teamId: "", name: "", abbreviation: "", logoURL: "", score: "", record: nil),
            events: [],
            leaderboardEntries: raceEntries(from: competition),
            eventURL: Self.eventURL(for: event.id, league: league),
            startDate: parsedDate,
            followedTeamID: "league",
            leagueDefinition: league,
            venueName: event.circuit?.fullName,
            venueCountry: event.circuit?.address?.country
        )

        if snapshot.state.isLive || snapshot.isToday { return snapshot }
        if includeUpcoming, let startDate = snapshot.startDate, startDate >= Date() {
            return snapshot
        }
        return nil
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

    private func mapTennisSide(_ competitor: TennisCompetitor) -> SportsTeamSide {
        SportsTeamSide(
            teamId: tennisCompetitorID(for: competitor) ?? "",
            name: tennisCompetitorName(for: competitor) ?? "Unknown Player",
            abbreviation: "",
            logoURL: competitor.athlete?.flag?.href ?? "",
            score: competitor.linescores?.last.flatMap { $0.value.map { String(Int($0)) } } ?? "-",
            record: nil,
            setScores: competitor.linescores?.compactMap { $0.value.map { String(Int($0)) } } ?? [],
            isWinner: competitor.winner == true
        )
    }

    private func raceEntries(from competition: ESPNCompetition) -> [SportsLeaderboardEntry] {
        competition.competitors
            .sorted { lhs, rhs in
                (lhs.order ?? Int.max) < (rhs.order ?? Int.max)
            }
            .prefix(3)
            .enumerated()
            .map { index, competitor in
                let position = competitor.order ?? (index + 1)
                let name = competitor.athlete?.displayName
                    ?? competitor.athlete?.fullName
                    ?? competitor.athlete?.shortName
                    ?? "Driver"
                let secondary = competitor.team?.displayName
                    ?? competitor.team?.shortDisplayName
                    ?? competitor.team?.name
                    ?? competitor.athlete?.flag?.alt
                let trailing: String?
                if position == 1 {
                    trailing = "Leader"
                } else if let score = competitor.score, !score.isEmpty {
                    trailing = score
                } else {
                    trailing = nil
                }

                return SportsLeaderboardEntry(
                    position: position,
                    name: name,
                    secondaryText: secondary,
                    trailingText: trailing,
                    flagURL: competitor.athlete?.flag?.href
                )
            }
    }

    private func leaderboardCompetitorIdentifiers(for competitor: ESPNCompetitor) -> [String] {
        [
            competitor.id,
            competitor.team?.id,
            competitor.athlete?.id
        ]
        .compactMap { $0 }
    }

    private func leaderboardCompetitorMatches(_ followedTeam: FollowedTeam, competitor: ESPNCompetitor) -> Bool {
        if leaderboardCompetitorIdentifiers(for: competitor).contains(followedTeam.teamId) {
            return true
        }

        let followedName = followedTeam.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let candidateNames = [
            competitor.team?.displayName,
            competitor.team?.shortDisplayName,
            competitor.team?.name,
            competitor.athlete?.displayName,
            competitor.athlete?.shortName,
            competitor.athlete?.fullName,
            competitor.roster?.displayName,
            competitor.roster?.shortDisplayName
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        return candidateNames.contains(followedName)
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

    private func tennisCompetitorID(for competitor: TennisCompetitor) -> String? {
        competitor.id
            ?? competitor.athlete?.id
            ?? competitor.athlete?.guid
    }

    private func tennisCompetitorName(for competitor: TennisCompetitor) -> String? {
        competitor.athlete?.displayName
            ?? competitor.athlete?.shortName
            ?? competitor.athlete?.fullName
    }

    private func tennisCompetitorIdentifiers(for competitor: TennisCompetitor) -> [String] {
        [
            competitor.id,
            competitor.athlete?.id,
            competitor.athlete?.guid
        ]
        .compactMap { $0 }
    }

    private func isMeaningfulTennisName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lowered = trimmed.lowercased()
        return lowered != "tbd" && lowered != "?"
    }
}

enum SportsSnapshotPriority {
    static func score(for snapshot: GameSnapshot) -> Int {
        if snapshot.state.isLive { return 0 }
        if snapshot.state.isPre { return 1 }
        if snapshot.state.isPost { return 3 }
        return 2
    }

    static func compare(lhs: GameSnapshot, rhs: GameSnapshot) -> Bool {
        let lhsScore = score(for: lhs)
        let rhsScore = score(for: rhs)
        if lhsScore != rhsScore { return lhsScore < rhsScore }

        let lhsDate = lhs.startDate ?? .distantFuture
        let rhsDate = rhs.startDate ?? .distantFuture
        if lhsDate != rhsDate { return lhsDate < rhsDate }

        if lhs.isSpecificCompetitorFollow != rhs.isSpecificCompetitorFollow {
            return lhs.isSpecificCompetitorFollow && !rhs.isSpecificCompetitorFollow
        }

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
    @Published private(set) var followedLeagues: [FollowedLeague]
    @Published private(set) var followedPlayers: [FollowedPlayer]
    @Published private(set) var games: [GameSnapshot] = []
    @Published private(set) var primaryGame: GameSnapshot?
    @Published var focusedGameID: String?
    @Published private(set) var compactPinnedGameID: String?
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
        self.followedLeagues = SportsPreferences.loadFollowedLeagues()
        self.followedPlayers = SportsPreferences.starredPlayers()
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
        let liveGames = games.filter { $0.state.isLive }
        guard !liveGames.isEmpty else { return nil }

        if let compactPinnedGameID,
           let pinned = liveGames.first(where: { $0.id == compactPinnedGameID }) {
            return pinned
        }

        return fallbackCompactLiveGame(from: liveGames)
    }

    var compactAdditionalLiveCount: Int {
        guard let compactGame else { return 0 }
        return max(0, games.filter { $0.state.isLive && $0.id != compactGame.id }.count)
    }

    func focus(game: GameSnapshot) {
        focusedGameID = game.id
        compactPinnedGameID = game.id
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
        let nextGame = games[nextIndex]
        focusedGameID = nextGame.id
        compactPinnedGameID = nextGame.id
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
        followedLeagues = SportsPreferences.loadFollowedLeagues()
        followedPlayers = SportsPreferences.starredPlayers()
        print("🏟️ Sports widget refresh: teams=\(followedTeams.count) leagues=\(followedLeagues.count) players=\(followedPlayers.count)")
        if !followedPlayers.isEmpty {
            print("🎾 Sports widget refresh players:", followedPlayers.map { "\($0.league):\($0.name)[\($0.playerId)]" }.joined(separator: ", "))
        }
        guard !followedTeams.isEmpty || !followedLeagues.isEmpty || !followedPlayers.isEmpty else {
            games = []
            primaryGame = nil
            focusedGameID = nil
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let snapshots = try await SportsDataService.shared.snapshots(
                for: followedTeams,
                followedLeagues: followedLeagues,
                followedPlayers: followedPlayers
            )
            let visibleMatches = Array(snapshots.prefix(max(2, min(7, Defaults[.sportsMaximumMatches]))))
            games = visibleMatches
            let liveMatches = visibleMatches.filter { $0.state.isLive }
            let fallbackLiveGame = fallbackCompactLiveGame(from: liveMatches)
            primaryGame = fallbackLiveGame ?? visibleMatches.first

            if let compactPinnedGameID,
               !liveMatches.contains(where: { $0.id == compactPinnedGameID }) {
                self.compactPinnedGameID = fallbackLiveGame?.id
            } else if self.compactPinnedGameID == nil {
                self.compactPinnedGameID = fallbackLiveGame?.id
            }

            if focusedGame == nil {
                focusedGameID = primaryGame?.id
            } else if let focusedGameID, !visibleMatches.contains(where: { $0.id == focusedGameID }) {
                self.focusedGameID = primaryGame?.id
            }
            errorMessage = nil
        } catch {
            games = []
            primaryGame = nil
            compactPinnedGameID = nil
            errorMessage = error.localizedDescription
        }
    }

    private func fallbackCompactLiveGame(from liveGames: [GameSnapshot]) -> GameSnapshot? {
        liveGames.min { lhs, rhs in
            if lhs.isSpecificCompetitorFollow != rhs.isSpecificCompetitorFollow {
                return lhs.isSpecificCompetitorFollow && !rhs.isSpecificCompetitorFollow
            }

            let lhsDate = lhs.startDate ?? .distantFuture
            let rhsDate = rhs.startDate ?? .distantFuture
            if lhsDate != rhsDate { return lhsDate < rhsDate }

            return lhs.followedTeamID < rhs.followedTeamID
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
                    let updatedLeagues = SportsPreferences.loadFollowedLeagues()
                    let updatedPlayers = SportsPreferences.starredPlayers()
                    let teamsChanged = updatedTeams != self.followedTeams
                    let leaguesChanged = updatedLeagues != self.followedLeagues
                    let playersChanged = updatedPlayers != self.followedPlayers
                    self.followedTeams = updatedTeams
                    self.followedLeagues = updatedLeagues
                    self.followedPlayers = updatedPlayers
                    self.objectWillChange.send()
                    if teamsChanged || leaguesChanged || playersChanged {
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

        // ESPN sometimes varies only by fractional seconds. Keep the explicit
        // no-seconds UTC format above, then use Foundation's ISO parser as a
        // tolerant fallback for F1 session/event timestamps.
        return ISO8601DateFormatter().date(from: string)
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

private struct TennisScoreboardResponse: Decodable {
    let events: [TennisEvent]
}

private struct TennisEvent: Decodable {
    let id: String
    let name: String
    let groupings: [TennisGrouping]?
}

private struct TennisGrouping: Decodable {
    let competitions: [TennisMatch]?
}

private struct TennisMatch: Decodable {
    let id: String
    let date: String?
    let status: ESPNStatus?
    let round: TennisRound?
    let competitors: [TennisCompetitor]?
}

private struct TennisRound: Decodable {
    let displayName: String?
}

private struct TennisCompetitor: Decodable {
    let id: String?
    let winner: Bool?
    let athlete: TennisAthlete?
    let linescores: [TennisLineScore]?
}

private struct TennisAthlete: Decodable {
    let guid: String?
    let id: String?
    let displayName: String?
    let shortName: String?
    let fullName: String?
    let flag: ESPNFlag?
}

private struct TennisLineScore: Decodable {
    let value: Double?
}

private struct ESPNEvent: Decodable {
    let id: String?
    let name: String?
    let shortName: String?
    let date: String?
    let competitions: [ESPNCompetition]
    let status: ESPNStatus?
    let circuit: ESPNCircuit?
}

private struct ESPNCircuit: Decodable {
    let fullName: String?
    let address: ESPNCircuitAddress?
}

private struct ESPNCircuitAddress: Decodable {
    let city: String?
    let country: String?
}

private struct ESPNCompetition: Decodable {
    let competitors: [ESPNCompetitor]
    let details: [ESPNCompetitionDetail]?
    let status: ESPNStatus?
    let venue: ESPNVenue?

    enum CodingKeys: String, CodingKey {
        case competitors, details, status, venue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        competitors = try container.decodeIfPresent([ESPNCompetitor].self, forKey: .competitors) ?? []
        details = try container.decodeIfPresent([ESPNCompetitionDetail].self, forKey: .details)
        status = try container.decodeIfPresent(ESPNStatus.self, forKey: .status)
        venue = try container.decodeIfPresent(ESPNVenue.self, forKey: .venue)
    }
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
    let id: String?
    let homeAway: String?
    let order: Int?
    let team: ESPNTeam?
    let athlete: ESPNScoreboardAthlete?
    let roster: ESPNScoreboardRoster?
    let score: String?
    let records: [ESPNRecord]?
}

private struct ESPNScoreboardAthlete: Decodable {
    let id: String?
    let displayName: String?
    let shortName: String?
    let fullName: String?
    let flag: ESPNFlag?
}

private struct ESPNScoreboardRoster: Decodable {
    let displayName: String?
    let shortDisplayName: String?
    let athletes: [ESPNScoreboardAthlete]?
}

private struct ESPNFlag: Decodable {
    let href: String?
    let alt: String?
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
