//
//  SportsSettingsView.swift
//  InterestingNotch
//

import Defaults
import SwiftUI

private enum SportsSettingsRoute: Hashable {
    case league(SportsLeagueDefinition)
    case team(SportsTeamSearchResult)
    case match(SportsTeamScheduleMatch)
}

@MainActor
private final class SportsSettingsModel: ObservableObject {
    @Published var query = "" {
        didSet { search() }
    }
    @Published private(set) var teamResults: [SportsTeamSearchResult] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var followedLeagues = SportsPreferences.loadFollowedLeagues()
    @Published private(set) var starredTeams = SportsPreferences.starredTeams()

    private var searchTask: Task<Void, Never>?

    deinit { searchTask?.cancel() }

    func search() {
        searchTask?.cancel()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            teamResults = []
            isLoading = false
            errorMessage = nil
            return
        }

        searchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            isLoading = true
            errorMessage = nil
            do {
                let teams = try await SportsDataService.shared.searchTeams(
                    query: query,
                    leagues: SportsLeagueDefinition.supported.filter(\.supportsTeamSelection)
                )
                guard !Task.isCancelled else { return }
                teamResults = Self.dedupeGlobalTeamResults(teams)
            } catch {
                guard !Task.isCancelled else { return }
                teamResults = []
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func refreshPreferences() {
        followedLeagues = SportsPreferences.loadFollowedLeagues()
        starredTeams = SportsPreferences.starredTeams()
    }

    func toggleLeague(_ league: SportsLeagueDefinition) {
        SportsPreferences.toggleFollow(league)
        refreshPreferences()
    }

    func toggleTeam(_ team: SportsTeamSearchResult) {
        if SportsLeagueDefinition.league(forSport: team.sport, league: team.league)?.format == .sets {
            SportsPreferences.togglePlayer(team)
        } else {
            SportsPreferences.toggleStar(team)
        }
        refreshPreferences()
    }

    func isFollowing(_ league: SportsLeagueDefinition) -> Bool {
        followedLeagues.contains { $0.id == league.id }
    }

    func isStarred(_ team: SportsTeamSearchResult) -> Bool {
        if SportsLeagueDefinition.league(forSport: team.sport, league: team.league)?.format == .sets {
            return SportsPreferences.isStarred(team, asPlayer: true)
        }
        return starredTeams.contains { $0.id == "\(team.sport):\(team.league):\(team.id)" }
    }

    func starredCount(for league: SportsLeagueDefinition) -> Int {
        if league.format == .sets {
            return SportsPreferences.starredPlayers().filter { $0.sport == league.sport && $0.league == league.league }.count
        }
        return starredTeams.filter { $0.sport == league.sport && $0.league == league.league }.count
    }

    private static func dedupeGlobalTeamResults(_ teams: [SportsTeamSearchResult]) -> [SportsTeamSearchResult] {
        var results: [SportsTeamSearchResult] = []

        for team in teams {
            let key = globalSearchKey(for: team)
            if let index = results.firstIndex(where: { globalSearchKey(for: $0) == key }) {
                if globalSearchResultScore(team) > globalSearchResultScore(results[index]) {
                    results[index] = team
                }
            } else {
                results.append(team)
            }
        }

        return results
    }

    private static func globalSearchKey(for team: SportsTeamSearchResult) -> String {
        let name = team.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return "\(team.sport)|\(team.league)|\(name)"
    }

    private static func globalSearchResultScore(_ team: SportsTeamSearchResult) -> Int {
        var score = 0
        if !team.logoURL.isEmpty { score += 4 }
        if !team.abbreviation.isEmpty { score += 2 }
        if Int(team.id) != nil { score += 1 }
        return score
    }
}

@MainActor
private final class SportsLeagueTeamsModel: ObservableObject {
    let league: SportsLeagueDefinition
    @Published private(set) var teams: [SportsTeamSearchResult] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var starredTeams = SportsPreferences.starredTeams()

    init(league: SportsLeagueDefinition) {
        self.league = league
        load()
    }

    func load() {
        isLoading = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                teams = try await SportsDataService.shared.teams(for: league)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func toggle(_ team: SportsTeamSearchResult) {
        if league.format == .sets {
            SportsPreferences.togglePlayer(team)
        } else {
            SportsPreferences.toggleStar(team)
        }
        starredTeams = SportsPreferences.starredTeams()
    }

    func isStarred(_ team: SportsTeamSearchResult) -> Bool {
        if league.format == .sets {
            return SportsPreferences.isStarred(team, asPlayer: true)
        }
        return starredTeams.contains { $0.id == "\(team.sport):\(team.league):\(team.id)" }
    }

    var starred: [SportsTeamSearchResult] {
        if league.format == .sets {
            return SportsPreferences.starredPlayers().compactMap { player in
                teams.first { $0.id == player.playerId }
            }
        }
        return starredTeams.compactMap { starredTeam in
            teams.first { $0.id == starredTeam.teamId }
        }
    }

    var allTeams: [SportsTeamSearchResult] {
        teams.filter { !isStarred($0) }
    }
}

struct SportsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = SportsSettingsModel()
    @State private var path: [SportsSettingsRoute] = []
    @Default(.pinnedWidgetIDs) private var pinnedWidgetIDs
    @Default(.sportsShowLiveInClosedNotch) private var showLiveInClosedNotch
    @Default(.sportsMaximumMatches) private var sportsMaximumMatches

    private var filteredLeagues: [SportsLeagueDefinition] {
        let query = model.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return SportsLeagueDefinition.supported }
        return SportsLeagueDefinition.supported.filter {
            $0.subtitle.localizedCaseInsensitiveContains(query)
                || $0.title.localizedCaseInsensitiveContains(query)
                || $0.league.localizedCaseInsensitiveContains(query)
        }
    }

    private var followingLeagues: [SportsLeagueDefinition] {
        filteredLeagues
            .filter(model.isFollowing)
            .sorted { lhs, rhs in
                let lhsIndex = model.followedLeagues.firstIndex { $0.id == lhs.id } ?? Int.max
                let rhsIndex = model.followedLeagues.firstIndex { $0.id == rhs.id } ?? Int.max
                return lhsIndex < rhsIndex
            }
    }

    private var pinnedTeams: [SportsTeamSearchResult] {
        model.starredTeams.map(SportsTeamSearchResult.init(followedTeam:))
    }

    private var sportGroups: [(String, [SportsLeagueDefinition])] {
        Dictionary(grouping: filteredLeagues.filter { !model.isFollowing($0) }, by: \.group)
            .map { ($0.key, $0.value.sorted { $0.subtitle < $1.subtitle }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    Button(WidgetPinStore.isPinned("sports", in: pinnedWidgetIDs) ? "Unpin Sports widget" : "Pin Sports widget") {
                        pinnedWidgetIDs = WidgetPinStore.toggle("sports", in: pinnedWidgetIDs)
                    }
                    Toggle("Show live games in the closed notch", isOn: $showLiveInClosedNotch)
                    Picker("Maximum matches in the notch", selection: $sportsMaximumMatches) {
                        ForEach(2...7, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                } header: {
                    Text("Sports Widget")
                }

                if !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchResults
                } else {
                    if !pinnedTeams.isEmpty {
                        Section("Pinned teams") {
                            ForEach(pinnedTeams) { team in
                                pinnedTeamRow(team)
                            }
                        }
                    }
                    if !followingLeagues.isEmpty {
                        Section("Following") {
                            ForEach(followingLeagues) { leagueRow($0) }
                        }
                    }
                    ForEach(sportGroups, id: \.0) { sport, leagues in
                        Section(sport) {
                            ForEach(leagues) { leagueRow($0) }
                        }
                    }
                }
            }
            .searchable(text: $model.query, placement: .toolbar, prompt: "Search leagues and teams")
            .overlay { if model.isLoading { ProgressView().tint(.effectiveAccent) } }
            .navigationTitle("Leagues")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: SportsSettingsRoute.self) { route in
                switch route {
                case .league(let league):
                    SportsLeagueTeamsView(league: league)
                case .team(let team):
                    SportsTeamPageView(team: team)
                case .match(let match):
                    SportsMatchDetailView(match: match)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
                model.refreshPreferences()
            }
        }
        .tint(.effectiveAccent)
    }

    @ViewBuilder
    private var searchResults: some View {
        if let errorMessage = model.errorMessage {
            Section { Text(errorMessage).foregroundStyle(.secondary) }
        }
        Section("Teams") {
            if model.teamResults.isEmpty && !model.isLoading {
                Text("No teams found").foregroundStyle(.secondary)
            }
            ForEach(model.teamResults) { team in
                teamSearchRow(team)
            }
        }
        Section("Leagues") {
            ForEach(filteredLeagues) { league in
                leagueRow(league, tag: "League")
            }
        }
    }

    private func leagueRow(_ league: SportsLeagueDefinition, tag: String? = nil) -> some View {
        HStack(spacing: 10) {
            Text(league.badge)
                .font(.title3)
                .frame(width: 28)
            NavigationLink(value: SportsSettingsRoute.league(league)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(league.subtitle)
                    Text(league.subtitleForSettings(starredCount: model.starredCount(for: league), tag: tag))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                model.toggleLeague(league)
            } label: {
                Image(systemName: model.isFollowing(league) ? "star.fill" : "star")
                    .foregroundStyle(model.isFollowing(league) ? Color.effectiveAccent : .secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.isFollowing(league) ? "Unfollow \(league.subtitle)" : "Follow \(league.subtitle)")
        }
    }

    private func teamSearchRow(_ team: SportsTeamSearchResult) -> some View {
        let league = SportsLeagueDefinition.league(forSport: team.sport, league: team.league)

        return HStack(spacing: 10) {
            RemoteSportsLogoView(urlString: team.logoURL).frame(width: 28, height: 28)
            if league?.supportsCompetitorDetail == true {
                NavigationLink(value: SportsSettingsRoute.team(team)) {
                    searchRowLabel(name: team.name, subtitle: league?.subtitle ?? "Team")
                }
            } else {
                searchRowLabel(name: team.name, subtitle: league?.subtitle ?? "Team")
            }
            Button { model.toggleTeam(team) } label: {
                Image(systemName: model.isStarred(team) ? "star.fill" : "star")
                    .foregroundStyle(model.isStarred(team) ? Color.effectiveAccent : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func pinnedTeamRow(_ team: SportsTeamSearchResult) -> some View {
        let league = SportsLeagueDefinition.league(forSport: team.sport, league: team.league)

        return HStack(spacing: 10) {
            RemoteSportsLogoView(urlString: team.logoURL).frame(width: 28, height: 28)
            if league?.supportsCompetitorDetail == true {
                NavigationLink(value: SportsSettingsRoute.team(team)) {
                    searchRowLabel(name: team.name, subtitle: league?.subtitle ?? "Team")
                }
            } else {
                searchRowLabel(name: team.name, subtitle: league?.subtitle ?? "Team")
            }
            Button { model.toggleTeam(team) } label: {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.effectiveAccent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Unstar \(team.name)")
        }
    }

    private func searchRowLabel(name: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SportsLeagueTeamsView: View {
    let league: SportsLeagueDefinition
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: SportsLeagueTeamsModel
    @State private var query = ""

    init(league: SportsLeagueDefinition) {
        self.league = league
        _model = StateObject(wrappedValue: SportsLeagueTeamsModel(league: league))
    }

    private var filteredStarred: [SportsTeamSearchResult] { filtered(model.starred) }
    private var filteredAll: [SportsTeamSearchResult] { filtered(model.allTeams) }

    var body: some View {
        Form {
            if model.isLoading {
                ProgressView().tint(.effectiveAccent)
            }
            if !filteredStarred.isEmpty {
                Section("Starred") { ForEach(filteredStarred) { teamRow($0) } }
            }
            Section(league.format == .teamScore ? "All teams" : "All competitors") {
                if filteredAll.isEmpty && !model.isLoading { Text(emptyStateText).foregroundStyle(.secondary) }
                ForEach(filteredAll) { teamRow($0) }
            }
            Section {
                Text(league.format == .teamScore ? "Starred teams get priority in the notch." : "Starred competitors stay easy to find while we finish the new non-team sports flow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .searchable(text: $query, placement: .toolbar, prompt: league.format == .teamScore ? "Search teams" : "Search competitors")
        .navigationTitle(league.subtitle)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
    }

    private func filtered(_ teams: [SportsTeamSearchResult]) -> [SportsTeamSearchResult] {
        guard !query.isEmpty else { return teams }
        return teams.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.abbreviation.localizedCaseInsensitiveContains(query) }
    }

    private func teamRow(_ team: SportsTeamSearchResult) -> some View {
        HStack(spacing: 10) {
            RemoteSportsLogoView(urlString: team.logoURL).frame(width: 28, height: 28)
            if league.supportsCompetitorDetail {
                NavigationLink(value: SportsSettingsRoute.team(team)) {
                    Text(team.name).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text(team.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { model.toggle(team) } label: {
                Image(systemName: model.isStarred(team) ? "star.fill" : "star")
                    .foregroundStyle(model.isStarred(team) ? Color.effectiveAccent : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyStateText: String {
        league.format == .teamScore ? "No teams found" : "No competitors found"
    }
}

private struct SportsTeamPageView: View {
    let team: SportsTeamSearchResult
    @State private var schedule: [SportsTeamScheduleMatch] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    RemoteSportsLogoView(urlString: team.logoURL).frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(team.name).font(.title3.weight(.semibold))
                        Text(SportsLeagueDefinition.league(forSport: team.sport, league: team.league)?.subtitle ?? "Team")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                if !recentResults.isEmpty {
                    HStack(spacing: 5) {
                        Text("Form")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(Array(recentResults.prefix(5).reversed())) { match in
                            Text(match.result ?? "–")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(resultColor(match.result))
                                .frame(width: 22, height: 22)
                                .background(resultColor(match.result).opacity(0.14), in: Circle())
                        }
                    }
                }
            }

            Section("Next matches") {
                if isLoading {
                    ProgressView().tint(.effectiveAccent)
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.secondary)
                } else if nextMatches.isEmpty {
                    Text("No upcoming matches")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(nextMatches) { matchRow($0) }
                }
            }

            if !isLoading && errorMessage == nil {
                Section("Recent results") {
                    if recentResults.isEmpty {
                        Text("No recent results")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentResults) { matchRow($0) }
                    }
                }
            }
        }
        .navigationTitle(team.name)
        .task {
            do {
                schedule = try await SportsDataService.shared.schedule(for: team)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private var nextMatches: [SportsTeamScheduleMatch] {
        schedule
            .filter { $0.state == .pre || $0.date >= Date() }
            .sorted { $0.date < $1.date }
    }

    private var recentResults: [SportsTeamScheduleMatch] {
        schedule
            .filter { $0.state == .post || $0.date < Date() }
            .sorted { $0.date > $1.date }
    }

    private func matchRow(_ match: SportsTeamScheduleMatch) -> some View {
        NavigationLink(value: SportsSettingsRoute.match(match)) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(match.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.caption.weight(.medium))
                    Text(match.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 84, alignment: .leading)

                HStack(spacing: 7) {
                    Text(match.isHome ? "vs" : "@")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    RemoteSportsLogoView(urlString: match.opponentLogoURL)
                        .frame(width: 24, height: 24)
                    Text(match.opponentName)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if let teamScore = match.teamScore, let opponentScore = match.opponentScore {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(teamScore)–\(opponentScore) \(match.result ?? "")")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(resultColor(match.result))
                        if let venue = match.venueName {
                            Text(venue)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else if let venue = match.venueName {
                    Text(venue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 3)
        }
    }

    private func resultColor(_ result: String?) -> Color {
        switch result {
        case "W": return .green
        case "L": return .red
        case "D": return .secondary
        default: return .secondary
        }
    }
}

private struct SportsMatchDetailView: View {
    let match: SportsTeamScheduleMatch
    @State private var detail: SportsMatchDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let detail {
                    SportsMatchHeroCard(detail: detail)

                    if !detail.keyEvents.isEmpty {
                        detailSectionTitle("Key events")
                        SportsMatchTimeline(detail: detail)
                    }

                    if !detail.teamStats.isEmpty {
                        detailSectionTitle("Match stats")
                        SportsMatchStatsSection(stats: detail.teamStats)
                    }

                    if !detail.infoRows.isEmpty {
                        detailSectionTitle("Match info")
                        SportsMatchInfoSection(rows: detail.infoRows)
                    }

                    if !detail.commentary.isEmpty {
                        detailSectionTitle("Commentary")
                        SportsCommentarySection(lines: Array(detail.commentary.prefix(8)))
                    }
                } else if isLoading {
                    HStack {
                        Spacer()
                        ProgressView().tint(.effectiveAccent)
                        Spacer()
                    }
                    .padding(.top, 40)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                } else {
                    Text("No match details available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(NSColor.controlBackgroundColor))
                        )
                }
            }
            .padding(20)
        }
        .background(Color.clear)
        .navigationTitle(detail?.title ?? "\(match.teamName) vs \(match.opponentName)")
        .task(id: match.id) {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await SportsDataService.shared.matchDetail(for: match)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @ViewBuilder
    private func detailSectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .tracking(1.1)
    }
}

private struct SportsMatchHeroCard: View {
    let detail: SportsMatchDetail

    private var homeGoals: [SportsMatchDetail.HeroEvent] {
        detail.heroEvents.filter { $0.side == .home }
    }

    private var awayGoals: [SportsMatchDetail.HeroEvent] {
        detail.heroEvents.filter { $0.side == .away }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text(detail.competition.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(1.1)

                Spacer()

                Text(detail.statusText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.effectiveAccent)
            }

            HStack(alignment: .center) {
                SportsHeroTeamColumn(team: detail.home)

                Spacer(minLength: 24)

                Text(scoreText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.primary)

                Spacer(minLength: 24)

                SportsHeroTeamColumn(team: detail.away)
            }

            if !homeGoals.isEmpty || !awayGoals.isEmpty {
                Divider()

                HStack(alignment: .top) {
                    SportsHeroScorersList(events: homeGoals, alignment: .leading, isLeading: true)
                    Spacer()
                    SportsHeroScorersList(events: awayGoals, alignment: .trailing, isLeading: false)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sportsSettingsCard(cornerRadius: 18)
    }

    private var scoreText: String {
        "\(detail.home.score ?? "–")–\(detail.away.score ?? "–")"
    }
}

private struct SportsHeroTeamColumn: View {
    let team: SportsMatchDetail.TeamSummary

    var body: some View {
        VStack(spacing: 6) {
            RemoteSportsLogoView(urlString: team.logoURL)
                .frame(width: 52, height: 52)

            Text(team.name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SportsHeroScorersList: View {
    let events: [SportsMatchDetail.HeroEvent]
    let alignment: HorizontalAlignment
    let isLeading: Bool

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            ForEach(events) { event in
                HStack(spacing: 4) {
                    Text(compactLabel(for: event))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(event.minute)
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: isLeading ? .leading : .trailing)
    }

    private func compactLabel(for event: SportsMatchDetail.HeroEvent) -> String {
        let text = event.text
            .replacingOccurrences(of: "Goal! ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count > 30 ? String(text.prefix(30)).trimmingCharacters(in: .whitespaces) + "…" : text
    }
}

private struct SportsMatchTimeline: View {
    private enum EventAlignment {
        case leading
        case center
        case trailing
    }

    let detail: SportsMatchDetail

    var body: some View {
        VStack(spacing: 12) {
            ForEach(detail.keyEvents) { event in
                switch event.side {
                case .home:
                    sidedRow(event, onLeadingSide: true)
                case .away:
                    sidedRow(event, onLeadingSide: false)
                case .neutral:
                    neutralRow(event)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .sportsSettingsCard()
    }

    @ViewBuilder
    private func sidedRow(_ event: SportsMatchDetail.Event, onLeadingSide: Bool) -> some View {
        HStack(alignment: .center, spacing: 18) {
            if onLeadingSide {
                eventLabel(event, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
                    .frame(maxWidth: .infinity)
            }

            minutePill(event.minute)

            if onLeadingSide {
                Spacer(minLength: 0)
                    .frame(maxWidth: .infinity)
            } else {
                eventLabel(event, alignment: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private func neutralRow(_ event: SportsMatchDetail.Event) -> some View {
        VStack(spacing: 8) {
            minutePill(event.minute)
            eventLabel(event, alignment: .center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func eventLabel(_ event: SportsMatchDetail.Event, alignment: EventAlignment) -> some View {
        let iconColor = color(for: event)
        HStack(spacing: 8) {
            if alignment != .trailing {
                Image(systemName: event.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(event.text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .lineLimit(3)
                .foregroundStyle(.primary)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)

            if alignment == .trailing {
                Image(systemName: event.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
        }
    }

    @ViewBuilder
    private func minutePill(_ minute: String) -> some View {
        Text(minute)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.035))
            )
    }

    private func color(for event: SportsMatchDetail.Event) -> Color {
        switch event.icon {
        case "soccerball":
            return .primary
        case "rectangle.fill":
            return event.text.localizedCaseInsensitiveContains("red") ? .red : .yellow
        default:
            return .secondary
        }
    }
}

private struct SportsMatchStatsSection: View {
    let stats: [SportsMatchDetail.TeamStat]

    var body: some View {
        VStack(spacing: 18) {
            ForEach(stats) { stat in
                VStack(spacing: 8) {
                    HStack {
                        Text(stat.homeValue)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Spacer()
                        Text(stat.label)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(stat.awayValue)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }

                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let homeWidth = max(0, min(width, width * stat.homeFraction))

                        ZStack(alignment: .leading) {
                            Capsule(style: .continuous)
                                .fill(Color.secondary.opacity(0.22))

                            Capsule(style: .continuous)
                                .fill(Color.effectiveAccent)
                                .frame(width: homeWidth)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .sportsSettingsCard()
    }
}

private struct SportsMatchInfoSection: View {
    let rows: [SportsMatchDetail.InfoRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack {
                    Text(row.label)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(row.value)
                        .multilineTextAlignment(.trailing)
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if index < rows.count - 1 {
                    Divider()
                        .padding(.leading, 14)
                }
            }
        }
        .sportsSettingsCard()
    }
}

private struct SportsCommentarySection: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .sportsSettingsCard()
    }
}

private extension View {
    func sportsSettingsCard(cornerRadius: CGFloat = 16) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(NSColor.quaternarySystemFill))
        )
    }
}

private extension SportsLeagueDefinition {
    var badge: String {
        switch sport {
        case "soccer": return "⚽️"
        case "basketball": return "🏀"
        case "football": return "🏈"
        case "hockey": return "🏒"
        case "baseball": return "⚾️"
        case "racing": return "🏎️"
        case "golf": return "⛳️"
        case "tennis": return "🎾"
        default: return "🏆"
        }
    }

    func subtitleForSettings(starredCount: Int, tag: String?) -> String {
        let noun = format == .sets ? "competitor" : "team"
        let count = starredCount == 0 ? "No \(noun)s starred" : "\(starredCount) \(starredCount == 1 ? noun : "\(noun)s") starred"
        return [country, count, tag].compactMap { $0 }.joined(separator: " · ")
    }

    var country: String {
        switch league {
        case "eng.1": return "England"
        case "esp.1": return "Spain"
        case "ita.1": return "Italy"
        case "ger.1": return "Germany"
        case "fra.1": return "France"
        case "usa.1", "nba", "nfl", "mlb": return "United States"
        case "nhl": return "United States / Canada"
        case "fifa.world": return "International"
        case "uefa.champions", "uefa.europa": return "Europe"
        default: return title
        }
    }
}

struct RemoteSportsLogoView: View {
    let urlString: String
    @StateObject private var loader = RemoteSportsLogoLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Circle().fill(.white.opacity(0.08))
            }
        }
        .task(id: urlString) {
            await loader.load(from: urlString)
        }
    }
}

@MainActor
private final class RemoteSportsLogoLoader: ObservableObject {
    @Published var image: NSImage?

    private static let cache = NSCache<NSString, NSImage>()
    private var currentURLString: String?

    func load(from urlString: String) async {
        currentURLString = urlString

        guard !urlString.isEmpty else {
            image = nil
            return
        }

        if let cached = Self.cache.object(forKey: urlString as NSString) {
            image = cached
            return
        }

        guard let url = URL(string: urlString) else {
            image = nil
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard currentURLString == urlString else { return }
            guard let downloaded = NSImage(data: data) else {
                image = nil
                return
            }
            Self.cache.setObject(downloaded, forKey: urlString as NSString)
            image = downloaded
        } catch {
            guard currentURLString == urlString else { return }
            image = nil
        }
    }
}
