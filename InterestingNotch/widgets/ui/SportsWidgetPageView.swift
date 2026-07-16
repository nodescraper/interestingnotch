//
//  SportsWidgetPageView.swift
//  InterestingNotch
//
//  Paging is a real filmstrip: every game lives side-by-side in one row and the
//  whole strip translates under your cursor, so the current page slides out while
//  the next slides in, edges touching. Release snaps to the nearest page with a
//  springy settle. The paginator dot tracks the live drag, and the title
//  crossfades as the committed page changes.
//

import AppKit
import SwiftUI

struct SportsWidgetPageView: View {
    let widget: Widget
    @ObservedObject var model: SportsWidgetModel

    private let accent = Color.effectiveAccent
    private let tennisWinnerColor = Color(red: 0.3569, green: 0.7412, blue: 0.3882)
    private let subtitleColor = Color.white.opacity(0.55)
    private let dividerColor = Color.white.opacity(0.08)
    private let bigScoreSize: CGFloat = 32
    private let crestSize: CGFloat = 40
    private let middleBandHeight: CGFloat = 92
    private let scrollCommitThreshold: CGFloat = 85
    private let scrollPreviewLimit: CGFloat = 42

    // Paging tuning.
    private let commitFraction: CGFloat = 0.28    // fraction of a page you must drag to flip on distance
    private let commitVelocity: CGFloat = 320     // points/sec flick that flips regardless of distance
    private let rubberBandStiffness: CGFloat = 0.55 // <1 = resistance past the ends

    // Live drag translation, in points, on top of the resting page position.
    @State private var dragOffset: CGFloat = 0
    @State private var isInteracting = false

    // Trackpad scroll accumulates here (no single translation like a drag has).
    @State private var scrollAccumulated: CGFloat = 0
    @State private var lastScrollDelta: CGFloat = 0
    @State private var scrollGestureCommitted = false
    @State private var scrollLockUntil: Date = .distantPast
    @State private var dragGestureCommitted = false

    // MARK: - Derived

    private var games: [GameSnapshot] { model.games }

    private var currentIndex: Int {
        guard let id = model.focusedGame?.id,
              let idx = games.firstIndex(where: { $0.id == id }) else { return 0 }
        return idx
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetTitleRow(
                title: titleText,
                caption: captionText,
                titleColor: .white,
                rightText: headerRightText,
                rightTextColor: headerRightTextColor,
                showsRightIndicator: headerShowsIndicator
            )
                .id(model.focusedGame?.id ?? "empty")
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.28), value: model.focusedGame?.id)

            middleBand
                .frame(height: middleBandHeight)

            if let game = model.focusedGame {
                footerMeta(for: game)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sports")
    }

    // MARK: - Filmstrip

    private var middleBand: some View {
        GeometryReader { geo in
            let pageWidth = geo.size.width

            filmstrip(pageWidth: pageWidth)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
                .contentShape(Rectangle())
                .background(
                    SportsPageScrollCatcher(
                        onScroll: { deltaX, _ in
                            handleScroll(deltaX: deltaX, pageWidth: pageWidth)
                        },
                        onEnded: {
                            if !scrollGestureCommitted {
                                settle(velocity: lastScrollDelta * 60, pageWidth: pageWidth)
                            }
                            scrollAccumulated = 0
                            lastScrollDelta = 0
                            if Date() >= scrollLockUntil {
                                scrollGestureCommitted = false
                            }
                        }
                    )
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { value in
                            isInteracting = true
                            dragOffset = resist(value.translation.width, pageWidth: pageWidth)
                            handleDragCommitPreview(value: value, pageWidth: pageWidth)
                        }
                        .onEnded { value in
                            settle(velocity: value.velocity.width, pageWidth: pageWidth)
                        }
                )
        }
    }

    private func filmstrip(pageWidth: CGFloat) -> some View {
        Group {
            if games.isEmpty {
                emptyState
                    .frame(width: pageWidth, alignment: .leading)
            } else {
                HStack(spacing: 0) {
                    ForEach(games, id: \.id) { game in
                        matchupContent(game)
                            .frame(width: pageWidth, alignment: .leading)
                    }
                }
                // Translate the whole strip: rest at the current page, plus the
                // live drag. This is the wipe — pages move together, touching.
                .offset(x: -CGFloat(currentIndex) * pageWidth + dragOffset)
                .frame(width: pageWidth, alignment: .leading)
            }
        }
    }

    // MARK: - Gesture math

    /// Rubber-band resistance only kicks in past the *ends* of the strip.
    private func resist(_ raw: CGFloat, pageWidth: CGFloat) -> CGFloat {
        let atFirst = currentIndex == 0
        let atLast = currentIndex == games.count - 1

        // Dragging right (positive) at the first page, or left (negative) at the
        // last, is pulling past an edge → damp it.
        let pastEdge = (raw > 0 && atFirst) || (raw < 0 && atLast)
        guard pastEdge else { return raw }

        let limit = pageWidth
        let sign: CGFloat = raw < 0 ? -1 : 1
        let magnitude = min(abs(raw), limit)
        let eased = limit * (1 - pow(1 - magnitude / limit, rubberBandStiffness + 0.25))
        return sign * eased * rubberBandStiffness
    }

    private func handleScroll(deltaX: CGFloat, pageWidth: CGFloat) {
        guard Date() >= scrollLockUntil else { return }

        isInteracting = true
        scrollAccumulated += deltaX
        lastScrollDelta = deltaX

        guard !scrollGestureCommitted else { return }

        dragOffset = resist(
            min(max(scrollAccumulated, -scrollPreviewLimit), scrollPreviewLimit),
            pageWidth: pageWidth
        )

        if scrollAccumulated <= -scrollCommitThreshold {
            let nextIndex = currentIndex + 1
            if games.indices.contains(nextIndex) {
                fireCommitHaptic()
                scrollGestureCommitted = true
                scrollLockUntil = Date().addingTimeInterval(0.32)
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                    model.focusAdjacentGame(step: 1)
                    dragOffset = 0
                }
            } else {
                fireWallHaptic()
                scrollGestureCommitted = true
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    dragOffset = 0
                }
            }
            scrollAccumulated = 0
            return
        }

        if scrollAccumulated >= scrollCommitThreshold {
            let previousIndex = currentIndex - 1
            if games.indices.contains(previousIndex) {
                fireCommitHaptic()
                scrollGestureCommitted = true
                scrollLockUntil = Date().addingTimeInterval(0.32)
                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                    model.focusAdjacentGame(step: -1)
                    dragOffset = 0
                }
            } else {
                fireWallHaptic()
                scrollGestureCommitted = true
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    dragOffset = 0
                }
            }
            scrollAccumulated = 0
        }
    }

    private func handleDragCommitPreview(value: DragGesture.Value, pageWidth: CGFloat) {
        guard !dragGestureCommitted else { return }

        let translation = value.translation.width
        let predicted = value.predictedEndTranslation.width
        let direction = predicted == 0 ? translation : predicted
        let towardNext = direction < 0
        let step = towardNext ? 1 : -1
        let targetIndex = currentIndex + step
        let canGo = games.indices.contains(targetIndex)

        let passedDistance = abs(translation) > pageWidth * commitFraction
        let passedPredictedDistance = abs(predicted) > pageWidth * commitFraction
        let passedVelocityLikePreview = abs(predicted - translation) > scrollCommitThreshold
        let shouldPreviewCommit = canGo && (passedDistance || passedPredictedDistance || passedVelocityLikePreview)

        if shouldPreviewCommit {
            fireCommitHaptic()
            dragGestureCommitted = true
        } else if !canGo && (passedDistance || passedPredictedDistance) {
            fireWallHaptic()
            dragGestureCommitted = true
        }
    }

    /// On release, snap to the nearest page. Distance past commitFraction OR a
    /// fast flick flips one page; otherwise it springs back to the current one.
    private func settle(velocity: CGFloat, pageWidth: CGFloat) {
        let distance = dragOffset
        let velocityIndicatesNext = velocity < 0
        let velocityCommit = abs(velocity) > commitVelocity
        let towardNext = velocityCommit && abs(distance) < pageWidth * commitFraction
            ? velocityIndicatesNext
            : distance < 0
        let step = towardNext ? 1 : -1

        let passedDistance = abs(distance) > pageWidth * commitFraction
        let passedVelocity = velocityCommit &&
            (velocityIndicatesNext == towardNext)

        let targetIndex = currentIndex + step
        let canGo = targetIndex >= 0 && targetIndex < games.count
        let shouldCommit = canGo && (passedDistance || passedVelocity)

        // Springy settle with a touch of snap (lower damping = more snap).
        let settleSpring = Animation.spring(response: 0.42, dampingFraction: 0.78)

        if shouldCommit {
            if !dragGestureCommitted {
                fireCommitHaptic()
            }
            // Move the committed index by one AND cancel the drag offset in the
            // same animated transaction. Because the strip rests on currentIndex,
            // shifting the index by one page while zeroing dragOffset keeps the
            // pixels continuous — the strip just keeps gliding the last bit.
            withAnimation(settleSpring) {
                model.focusAdjacentGame(step: step)
                dragOffset = 0
            }
        } else {
            if !canGo && abs(distance) > pageWidth * commitFraction * 0.5 && !dragGestureCommitted {
                fireWallHaptic()
            }
            withAnimation(settleSpring) {
                dragOffset = 0
            }
        }

        isInteracting = false
        dragGestureCommitted = false
    }

    // MARK: - Haptics

    private func fireCommitHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    private func fireWallHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    // MARK: - Content

    @ViewBuilder
    private func matchupContent(_ game: GameSnapshot) -> some View {
        if game.leagueDefinition.format == .leaderboard {
            leaderboardContent(game)
        } else if game.leagueDefinition.format == .sets {
            setsContent(game)
        } else {
            HStack(alignment: .center, spacing: 18) {
            teamColumn(for: game.home)

            Spacer(minLength: 6)

            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    scoreText(game.home.score)
                    Text("–")
                        .font(.system(size: bigScoreSize, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                    scoreText(game.away.score)
                }

                Text(centerStatusText(for: game))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(subtitleColor)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(minWidth: 118)

            Spacer(minLength: 6)

            teamColumn(for: game.away)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .onTapGesture { openGamePage(game) }
        }
    }

    @ViewBuilder
    private func setsContent(_ game: GameSnapshot) -> some View {
        if game.state == .pre {
            upcomingSetsContent(game)
        } else {
            liveSetsContent(game)
        }
    }

    private func liveSetsContent(_ game: GameSnapshot) -> some View {
        VStack {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 12) {
                setPlayerRow(game.home, isCurrent: game.state.isLive)
                setPlayerRow(game.away, isCurrent: game.state.isLive)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .contentShape(Rectangle())
        .onTapGesture { openGamePage(game) }
    }

    private func upcomingSetsContent(_ game: GameSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer(minLength: 12)
            }

            VStack(alignment: .leading, spacing: 14) {
                upcomingSetPlayerRow(game.home)
                upcomingSetPlayerRow(game.away)
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { openGamePage(game) }
    }

    private func setPlayerRow(_ player: SportsTeamSide, isCurrent: Bool) -> some View {
        HStack(spacing: 10) {
            Text(player.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(player.isWinner ? tennisWinnerColor : .white.opacity(0.7))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 9) {
                ForEach(Array(player.setScores.enumerated()), id: \.offset) { index, score in
                    Text(score)
                        .font(.system(size: 17, weight: index == player.setScores.count - 1 ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(index == player.setScores.count - 1 && isCurrent ? accent : .white.opacity(0.85))
                        .monospacedDigit()
                        .frame(minWidth: 20, alignment: .trailing)
                }
            }
        }
    }

    private func upcomingSetPlayerRow(_ player: SportsTeamSide) -> some View {
        HStack(spacing: 10) {
            Text(player.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("–")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(subtitleColor)
                .frame(minWidth: 20, alignment: .trailing)
        }
    }

    private func leaderboardContent(_ game: GameSnapshot) -> some View {
        Group {
            if game.state.isLive || game.state.isPost {
                leaderboardRaceContent(game)
            } else {
                leaderboardUpcomingContent(game)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openGamePage(game) }
    }

    private func leaderboardRaceContent(_ game: GameSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.competition)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(leaderboardSubtitle(for: game))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                statusBadge(text: leaderboardBadgeText(for: game))
            }

            VStack(spacing: 7) {
                ForEach(Array(game.leaderboardEntries.enumerated()), id: \.element.id) { index, entry in
                    leaderboardRow(entry, highlighted: index == 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func leaderboardUpcomingContent(_ game: GameSnapshot) -> some View {
        HStack(alignment: .center, spacing: 18) {
            leaderboardFlag(for: game)
                .padding(.leading, 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(game.competition)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                if let venueName = game.venueName, !venueName.isEmpty {
                    Text(venueName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                if let startDate = game.startDate {
                    Text(startDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 32, weight: .regular, design: .rounded))
                        .foregroundStyle(accent)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(upcomingDayLabel(for: startDate))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                } else {
                    Text("TBD")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(.trailing, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func leaderboardRow(_ entry: SportsLeaderboardEntry, highlighted: Bool) -> some View {
        HStack(spacing: 12) {
            Text("P\(entry.position)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(highlighted ? accent : .white.opacity(0.45))
                .frame(width: 38, alignment: .leading)

            if let flagURL = entry.flagURL, !flagURL.isEmpty {
                crest(flagURL, size: 18)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let secondaryText = entry.secondaryText, !secondaryText.isEmpty {
                    Text(secondaryText)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let trailingText = entry.trailingText, !trailingText.isEmpty {
                Text(trailingText)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(highlighted ? 0.75 : 0.55))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(highlighted ? accent.opacity(0.16) : .clear)
        )
    }

    private func teamColumn(for team: SportsTeamSide) -> some View {
        VStack(spacing: 8) {
            crest(team.logoURL, size: crestSize)

            Text(team.name)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(subtitleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 110)
    }

    private func footerMeta(for game: GameSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let supportingText = supportingText(for: game) {
                Text(supportingText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
            }

            Rectangle()
                .fill(dividerColor)
                .frame(maxWidth: .infinity)
                .frame(height: 1)

            ZStack(alignment: .trailing) {
                HStack {
                    Spacer()
                    paginatorDots
                    Spacer()
                }

                if let footerLabel = footerTrailingText(for: game) {
                    Text(footerLabel)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(subtitleColor)
                }
            }
        }
    }

    private var paginatorDots: some View {
        HStack(spacing: 5) {
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                let isActive = index == currentIndex
                Capsule()
                    .fill(paginatorColor(for: game, isActive: isActive))
                    .frame(width: isActive ? 14 : 6, height: 6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        fireCommitHaptic()
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                            model.focus(game: game)
                            dragOffset = 0
                        }
                    }
            }
        }
        // Dot morphs (width + color) animate live with the committed page.
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: currentIndex)
    }

    private func paginatorColor(for game: GameSnapshot, isActive: Bool) -> Color {
        if game.state.isPost { return tennisWinnerColor }
        if isActive { return accent }
        return Color.white.opacity(0.18)
    }

    private var titleText: String {
        guard let game = model.focusedGame else { return "Sports" }
        if game.leagueDefinition.format == .leaderboard {
            return game.leagueDefinition.subtitle
        }
        if game.leagueDefinition.format == .sets {
            return "\(game.home.name) vs \(game.away.name)"
        }
        let home = game.home.name.isEmpty ? game.home.abbreviation : game.home.name
        let away = game.away.name.isEmpty ? game.away.abbreviation : game.away.name
        return "\(home) vs \(away)"
    }

    private var captionText: String {
        guard let game = model.focusedGame else { return "Follow teams to see upcoming matches" }
        if game.leagueDefinition.format == .leaderboard {
            return game.state == .pre ? "Next race" : (game.venueName ?? game.competition)
        }
        if game.leagueDefinition.format == .sets {
            return [game.competition, game.venueName].compactMap { $0 }.joined(separator: " · ")
        }
        return game.competition
    }

    private var headerRightText: String? {
        guard let game = model.focusedGame else { return nil }
        if game.leagueDefinition.format == .sets {
            switch game.state {
            case .pre:
                return upcomingSetsBadgeText(for: game)
            case .live:
                return setsBadgeText(for: game)
            case .post:
                return "FINAL"
            default:
                return nil
            }
        }
        return nil
    }

    private var headerRightTextColor: Color {
        guard let game = model.focusedGame else { return .white }
        if game.leagueDefinition.format == .sets, (game.state == .pre || game.state == .live || game.state == .post) {
            return accent
        }
        return .white
    }

    private var headerShowsIndicator: Bool {
        guard let game = model.focusedGame else { return false }
        return game.leagueDefinition.format == .sets && game.state == .live
    }

    private func centerStatusText(for game: GameSnapshot) -> String {
        switch game.state {
        case .live:
            return game.clock.isEmpty ? "Live" : game.clock
        case .pre:
            guard let startDate = game.startDate else { return game.displayStatus }
            return "\(upcomingDayLabel(for: startDate)) \(startDate.formatted(date: .omitted, time: .shortened))"
        case .post:
            return "Full time"
        case .unknown:
            return game.displayStatus
        }
    }

    private func scoreText(_ value: String) -> some View {
        Text(value)
            .font(.system(size: bigScoreSize, weight: .regular, design: .rounded))
            .foregroundStyle(.white.opacity(0.92))
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    private func supportingText(for game: GameSnapshot) -> String? {
        if game.leagueDefinition.format == .leaderboard || game.leagueDefinition.format == .sets {
            return nil
        }
        if let firstEvent = game.events.first {
            return "\(scorerPrefix(for: game, teamID: firstEvent.teamId)) \(firstEvent.player) \(firstEvent.minute)"
        }
        return game.state == .pre ? nil : game.competition
    }

    private func footerTrailingText(for game: GameSnapshot) -> String? {
        switch game.leagueDefinition.format {
        case .leaderboard:
            return (game.state.isLive || game.state.isPost) ? "Top \(max(game.leaderboardEntries.count, 1))" : nil
        case .sets:
            return nil
        case .teamScore:
            return nil
        case .innings:
            return nil
        }
    }

    private func leaderboardSubtitle(for game: GameSnapshot) -> String {
        let prefix = game.leagueDefinition.subtitle
        if !game.statusDetail.isEmpty {
            return "\(prefix) · \(game.statusDetail)"
        }
        if !game.clock.isEmpty {
            return "\(prefix) · \(game.clock)"
        }
        return [prefix, game.venueName].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " · ")
    }

    private func leaderboardBadgeText(for game: GameSnapshot) -> String {
        if game.state.isLive {
            return "LIVE"
        }
        if game.state.isPost {
            return "FINAL"
        }
        return "RACE"
    }

    private func setsBadgeText(for game: GameSnapshot) -> String {
        if game.state.isLive {
            return currentSetLabel(for: game)
        }
        if game.state.isPost {
            return "FINAL"
        }
        return centerStatusText(for: game).uppercased()
    }

    private func currentSetLabel(for game: GameSnapshot) -> String {
        let setCount = max(game.home.setScores.count, game.away.setScores.count)
        guard setCount > 0 else {
            return game.clock.isEmpty ? "LIVE" : game.clock.uppercased()
        }
        return "Set \(setCount)"
    }

    private func upcomingSetsBadgeText(for game: GameSnapshot) -> String {
        game.startDate?.formatted(date: .omitted, time: .shortened) ?? "TBD"
    }

    private func upcomingSetsFooterText(for game: GameSnapshot) -> String? {
        guard let startDate = game.startDate else { return game.venueName }
        let dayText = upcomingDayLabel(for: startDate)
        if let venueName = game.venueName, !venueName.isEmpty {
            return "\(dayText) · \(venueName)"
        }
        return dayText
    }

    private func upcomingDayLabel(for date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        }

        if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        }

        return date.formatted(
            Date.FormatStyle()
                .month(.twoDigits)
                .day(.twoDigits)
        )
    }

    private func leaderboardFlag(for game: GameSnapshot) -> some View {
        Group {
            if let url = leaderboardFlagURL(for: game) {
                crest(url.absoluteString, size: 42)
                    .frame(width: 42, height: 42)
            } else {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 42, height: 42)
            }
        }
    }

    private func leaderboardFlagURL(for game: GameSnapshot) -> URL? {
        guard let country = game.venueCountry,
              let code = espnCountryCode(for: country) else { return nil }
        return URL(string: "https://a.espncdn.com/i/teamlogos/countries/500/\(code).png")
    }

    private func espnCountryCode(for country: String) -> String? {
        let countryToCode: [String: String] = [
            "australia": "aus",
            "bahrain": "brn",
            "saudi arabia": "sau",
            "japan": "jpn",
            "china": "chn",
            "united states": "usa",
            "italy": "ita",
            "monaco": "mco",
            "canada": "can",
            "spain": "esp",
            "austria": "aut",
            "united kingdom": "gbr",
            "belgium": "bel",
            "hungary": "hun",
            "netherlands": "ned",
            "azerbaijan": "aze",
            "singapore": "sgp",
            "mexico": "mex",
            "brazil": "bra",
            "qatar": "qat",
            "united arab emirates": "are"
        ]
        return countryToCode[country.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    private func statusBadge(text: String) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
        }
        .padding(.top, 3)
    }

    private func scorerPrefix(for game: GameSnapshot, teamID: String) -> String {
        if teamID == game.home.teamId {
            return game.home.name
        }
        if teamID == game.away.teamId {
            return game.away.name
        }
        return "Goal"
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "sportscourt")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(accent)
                .padding(.bottom, 2)

            Text("Nothing to show yet")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Follow a league or team to see upcoming matches here.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func crest(_ logoURL: String, size: CGFloat) -> some View {
        RemoteSportsLogoView(urlString: logoURL)
            .frame(width: size, height: size)
    }

    private func openGamePage(_ game: GameSnapshot) {
        guard let url = game.eventURL else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct SportsPageScrollCatcher: NSViewRepresentable {
    let onScroll: (_ deltaX: CGFloat, _ deltaY: CGFloat) -> Void
    let onEnded: () -> Void

    func makeNSView(context: Context) -> ScrollCatcherView {
        let view = ScrollCatcherView()
        view.onScroll = onScroll
        view.onEnded = onEnded
        return view
    }

    func updateNSView(_ nsView: ScrollCatcherView, context: Context) {
        nsView.onScroll = onScroll
        nsView.onEnded = onEnded
    }

    static func dismantleNSView(_ nsView: ScrollCatcherView, coordinator: ()) {
        nsView.teardownMonitor()
    }

    final class ScrollCatcherView: NSView {
        var onScroll: ((CGFloat, CGFloat) -> Void)?
        var onEnded: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil { installMonitor() } else { teardownMonitor() }
        }

        private func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let window = self.window, event.window == window else { return event }

                let pointInView = self.convert(event.locationInWindow, from: nil)
                guard self.bounds.contains(pointInView) else { return event }

                self.onScroll?(event.scrollingDeltaX, event.scrollingDeltaY)
                if event.phase == .ended || event.momentumPhase == .ended {
                    self.onEnded?()
                }
                return nil
            }
        }

        func teardownMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
