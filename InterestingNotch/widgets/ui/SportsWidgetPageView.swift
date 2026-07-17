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
    private enum LeaderboardMoveFlash: String {
        case gain
        case loss

        var color: Color {
            switch self {
            case .gain:
                return Color(red: 0.3569, green: 0.7412, blue: 0.3882)
            case .loss:
                return Color(red: 0.92, green: 0.28, blue: 0.28)
            }
        }
    }

    let widget: Widget
    @ObservedObject var model: SportsWidgetModel

    private let accent = Color.effectiveAccent
    private let tennisWinnerColor = Color(red: 0.3569, green: 0.7412, blue: 0.3882)
    private let subtitleColor = Color.white.opacity(0.55)
    private let dividerColor = Color.white.opacity(0.08)
    private let bigScoreSize: CGFloat = 32
    private let crestSize: CGFloat = 40
    private let middleBandHeight: CGFloat = 92
    private let leaderboardRowHeight: CGFloat = 42
    private let leaderboardViewportMaxHeight: CGFloat = 120
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
    @State private var leaderboardPreviousPositions: [String: [String: Int]] = [:]
    @State private var leaderboardPositionFlashes: [String: LeaderboardMoveFlash] = [:]
    @State private var leaderboardBlocksCloseGesture = false
    @State private var leaderboardScrollOffset: CGFloat = 0
    @State private var leaderboardScrollInteractionActive = false

    // MARK: - Derived

    private var games: [GameSnapshot] { model.games }

    private var currentMiddleBandHeight: CGFloat {
        guard let game = model.focusedGame,
              game.leagueDefinition.format == .leaderboard else {
            return middleBandHeight
        }

        if game.state.isPre {
            return middleBandHeight
        }

        return min(leaderboardRowHeight * 5, leaderboardViewportMaxHeight)
    }

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
                .frame(height: currentMiddleBandHeight)

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
        .onAppear {
            syncLeaderboardPositionState(with: games)
        }
        .onChange(of: games) { newGames in
            syncLeaderboardPositionState(with: newGames)
            if !newGames.contains(where: isScrollableF1Leaderboard) {
                setLeaderboardCloseGestureBlocked(false)
            }
        }
        .onChange(of: model.focusedGame?.id) { _, _ in
            guard let focusedGame = model.focusedGame,
                  isScrollableF1Leaderboard(focusedGame) else {
                leaderboardScrollOffset = 0
                leaderboardScrollInteractionActive = false
                setLeaderboardCloseGestureBlocked(false)
                return
            }
        }
        .onDisappear {
            setLeaderboardCloseGestureBlocked(false)
        }
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
                        allowsVerticalPassthrough: model.focusedGame.map(isScrollableF1Leaderboard) ?? false,
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
                setPlayerRow(game.home, opponent: game.away, gameState: game.state)
                setPlayerRow(game.away, opponent: game.home, gameState: game.state)
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

    private func setPlayerRow(_ player: SportsTeamSide, opponent: SportsTeamSide, gameState: SportsGameState) -> some View {
        HStack(spacing: 10) {
            Text(player.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(tennisPlayerNameColor(for: player, gameState: gameState))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 9) {
                ForEach(Array(player.setScores.enumerated()), id: \.offset) { index, score in
                    Text(score)
                        .font(.system(size: 17, weight: index == player.setScores.count - 1 ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(tennisSetScoreColor(for: player, opponent: opponent, scoreIndex: index, gameState: gameState))
                        .monospacedDigit()
                        .frame(minWidth: 20, alignment: .trailing)
                }
            }
        }
    }

    private func tennisPlayerNameColor(for player: SportsTeamSide, gameState: SportsGameState) -> Color {
        if gameState.isPost {
            return player.isWinner ? tennisWinnerColor : .white
        }
        return .white
    }

    private func tennisSetScoreColor(for player: SportsTeamSide, opponent: SportsTeamSide, scoreIndex: Int, gameState: SportsGameState) -> Color {
        if gameState.isPost {
            let playerScore = Int(player.setScores[scoreIndex]) ?? 0
            let opponentScore = scoreIndex < opponent.setScores.count ? (Int(opponent.setScores[scoreIndex]) ?? 0) : 0
            return playerScore > opponentScore ? .white : .white.opacity(0.45)
        }

        if gameState.isLive {
            let playerScore = Int(player.setScores[scoreIndex]) ?? 0
            let opponentScore = scoreIndex < opponent.setScores.count ? (Int(opponent.setScores[scoreIndex]) ?? 0) : 0
            let isCurrentSet = scoreIndex == player.setScores.count - 1

            if isCurrentSet {
                return accent
            }

            return playerScore > opponentScore ? .white : .white.opacity(0.45)
        }

        return .white.opacity(0.85)
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
        VStack(alignment: .leading, spacing: 10) {
            if game.leaderboardEntries.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.competition)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(leaderboardEmptyStateSubtitle(for: game))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                NativeLeaderboardScrollView(
                    onOffsetChanged: { offset in
                        leaderboardScrollOffset = -offset
                        guard isScrollableF1Leaderboard(game) else {
                            setLeaderboardCloseGestureBlocked(false)
                            return
                        }

                        // While a physical gesture or its momentum is active,
                        // reaching the top must not hand the same gesture to the
                        // notch-close recognizer. Release only after native
                        // scrolling reports that the full gesture has ended.
                        if !leaderboardScrollInteractionActive {
                            setLeaderboardCloseGestureBlocked(offset > 1)
                        }
                    },
                    onScrollActivityChanged: { isActive in
                        if isActive {
                            beginLeaderboardVerticalScroll()
                        } else {
                            endLeaderboardVerticalScroll()
                        }
                    }
                ) {
                    VStack(spacing: 6) {
                        ForEach(game.leaderboardEntries) { entry in
                            leaderboardRow(
                                entry,
                                highlighted: entry.position == 1,
                                flash: leaderboardPositionFlashes[leaderboardFlashKey(gameID: game.id, entryID: entry.id)]
                            )
                            .id(entry.sourceID ?? entry.id)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: entry.position)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8),
                    value: game.leaderboardEntries.map { "\($0.id):\($0.position)" }
                )
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

    private func leaderboardRow(
        _ entry: SportsLeaderboardEntry,
        highlighted: Bool,
        flash: LeaderboardMoveFlash?
    ) -> some View {
        HStack(spacing: 12) {
            if let teamColorHex = entry.teamColorHex,
               let teamColor = Color(hex: teamColorHex) {
                Capsule(style: .continuous)
                    .fill(teamColor)
                    .frame(width: 3)
                    .frame(height: 34)
            }

            Text("P\(entry.position)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(highlighted ? accent : .white.opacity(0.45))
                .frame(width: 38, alignment: .leading)

            if let flagURL = entry.flagURL, !flagURL.isEmpty {
                crest(flagURL, size: 20)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(highlighted ? accent : .white)
                    .lineLimit(1)

                if let secondaryText = entry.secondaryText, !secondaryText.isEmpty {
                    Text(secondaryText)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(subtitleColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let statusText = entry.statusText,
               statusText.localizedCaseInsensitiveContains("pit") {
                Text("IN PIT")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow.opacity(0.95))
                    .lineLimit(1)
            } else if let trailingText = entry.trailingText, !trailingText.isEmpty {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(trailingText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(highlighted ? 0.9 : 0.55))
                        .lineLimit(1)

                    if let lapText = entry.lapText, !lapText.isEmpty {
                        Text(lapText)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(subtitleColor)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: leaderboardRowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill((flash?.color ?? .clear).opacity(flash == nil ? 0 : 0.18))
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
            return game.state == .pre ? game.leagueDefinition.subtitle : game.competition
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
            return game.state == .pre ? "Next race" : leaderboardSubtitle(for: game)
        }
        if game.leagueDefinition.format == .sets {
            return [game.competition, game.venueName].compactMap { $0 }.joined(separator: " · ")
        }
        return game.competition
    }

    private var headerRightText: String? {
        guard let game = model.focusedGame else { return nil }
        if game.leagueDefinition.format == .leaderboard {
            switch game.state {
            case .live:
                return "LIVE"
            case .post:
                return "FINAL"
            default:
                return nil
            }
        }
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
        if game.leagueDefinition.format == .leaderboard, (game.state == .live || game.state == .post) {
            return accent
        }
        if game.leagueDefinition.format == .sets, (game.state == .pre || game.state == .live || game.state == .post) {
            return accent
        }
        return .white
    }

    private var headerShowsIndicator: Bool {
        guard let game = model.focusedGame else { return false }
        if game.leagueDefinition.format == .leaderboard {
            return game.state == .live
        }
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
            return nil
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

    private func leaderboardEmptyStateSubtitle(for game: GameSnapshot) -> String {
        let prefix = game.leagueDefinition.subtitle
        let status = !game.statusDetail.isEmpty ? game.statusDetail : "In Progress"

        if let venueName = game.venueName, !venueName.isEmpty {
            return "\(prefix) · \(status) · \(venueName)"
        }

        return "\(prefix) · \(status)"
    }

    private func leaderboardFlashKey(gameID: String, entryID: String) -> String {
        "\(gameID)|\(entryID)"
    }

    private func isScrollableF1Leaderboard(_ game: GameSnapshot) -> Bool {
        game.leagueDefinition.sport == "racing"
            && game.leagueDefinition.league == "f1"
            && (game.state.isLive || game.state.isPost)
    }

    private func setLeaderboardCloseGestureBlocked(_ shouldBlock: Bool) {
        guard leaderboardBlocksCloseGesture != shouldBlock else { return }
        leaderboardBlocksCloseGesture = shouldBlock
        if shouldBlock {
            SharingStateManager.shared.beginInteraction()
        } else {
            SharingStateManager.shared.endInteraction()
        }
    }

    private func beginLeaderboardVerticalScroll() {
        leaderboardScrollInteractionActive = true
        setLeaderboardCloseGestureBlocked(true)
    }

    private func endLeaderboardVerticalScroll() {
        leaderboardScrollInteractionActive = false
        if leaderboardScrollOffset >= -1 {
            setLeaderboardCloseGestureBlocked(false)
        }
    }

    private func syncLeaderboardPositionState(with games: [GameSnapshot]) {
        let leaderboardGames = games.filter {
            $0.leagueDefinition.format == .leaderboard && ($0.state.isLive || $0.state.isPost)
        }

        var nextPreviousPositions = leaderboardPreviousPositions
        let activeGameIDs = Set(leaderboardGames.map(\.id))
        nextPreviousPositions = nextPreviousPositions.filter { activeGameIDs.contains($0.key) }

        for game in leaderboardGames {
            let previousPositions = nextPreviousPositions[game.id] ?? [:]
            var currentPositions: [String: Int] = [:]

            for entry in game.leaderboardEntries {
                currentPositions[entry.id] = entry.position
                guard let previousPosition = previousPositions[entry.id],
                      previousPosition != entry.position else { continue }

                let flash: LeaderboardMoveFlash = entry.position < previousPosition ? .gain : .loss
                let flashKey = leaderboardFlashKey(gameID: game.id, entryID: entry.id)
                leaderboardPositionFlashes[flashKey] = flash

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(900))
                    if leaderboardPositionFlashes[flashKey] == flash {
                        withAnimation(.easeOut(duration: 0.25)) {
                            leaderboardPositionFlashes.removeValue(forKey: flashKey)
                        }
                    }
                }
            }

            nextPreviousPositions[game.id] = currentPositions
        }

        leaderboardPreviousPositions = nextPreviousPositions
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
    let allowsVerticalPassthrough: Bool
    let onScroll: (_ deltaX: CGFloat, _ deltaY: CGFloat) -> Void
    let onEnded: () -> Void

    func makeNSView(context: Context) -> ScrollCatcherView {
        let view = ScrollCatcherView()
        view.allowsVerticalPassthrough = allowsVerticalPassthrough
        view.onScroll = onScroll
        view.onEnded = onEnded
        return view
    }

    func updateNSView(_ nsView: ScrollCatcherView, context: Context) {
        nsView.allowsVerticalPassthrough = allowsVerticalPassthrough
        nsView.onScroll = onScroll
        nsView.onEnded = onEnded
    }

    static func dismantleNSView(_ nsView: ScrollCatcherView, coordinator: ()) {
        nsView.teardownMonitor()
    }

    final class ScrollCatcherView: NSView {
        var allowsVerticalPassthrough = false
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

                if self.allowsVerticalPassthrough,
                   abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
                    return event
                }

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

/// A real AppKit scroll view for the F1 field. Keeping scrolling inside
/// `NSScrollView` preserves macOS trackpad momentum, rubber-banding and native
/// deceleration instead of replaying wheel deltas through SwiftUI overlays.
private struct NativeLeaderboardScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    let onOffsetChanged: (CGFloat) -> Void
    let onScrollActivityChanged: (Bool) -> Void

    init(
        onOffsetChanged: @escaping (CGFloat) -> Void,
        onScrollActivityChanged: @escaping (Bool) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.onOffsetChanged = onOffsetChanged
        self.onScrollActivityChanged = onScrollActivityChanged
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onOffsetChanged: onOffsetChanged,
            onScrollActivityChanged: onScrollActivityChanged
        )
    }

    func makeNSView(context: Context) -> NativeMomentumScrollView {
        let scrollView = NativeMomentumScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .none

        context.coordinator.install(content: content, in: scrollView)
        return scrollView
    }

    func updateNSView(_ nsView: NativeMomentumScrollView, context: Context) {
        context.coordinator.onOffsetChanged = onOffsetChanged
        context.coordinator.onScrollActivityChanged = onScrollActivityChanged
        context.coordinator.update(content: content)
    }

    static func dismantleNSView(_ nsView: NativeMomentumScrollView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    @MainActor
    final class Coordinator: NSObject {
        var onOffsetChanged: (CGFloat) -> Void
        var onScrollActivityChanged: (Bool) -> Void

        private weak var scrollView: NativeMomentumScrollView?
        private var hostingView: NSHostingView<Content>?
        private var boundsObserver: NSObjectProtocol?
        private var endTask: Task<Void, Never>?
        private var isScrolling = false

        init(
            onOffsetChanged: @escaping (CGFloat) -> Void,
            onScrollActivityChanged: @escaping (Bool) -> Void
        ) {
            self.onOffsetChanged = onOffsetChanged
            self.onScrollActivityChanged = onScrollActivityChanged
        }

        func install(content: Content, in scrollView: NativeMomentumScrollView) {
            self.scrollView = scrollView

            let hostingView = NSHostingView(rootView: content)
            hostingView.isFlipped = true
            hostingView.autoresizingMask = [.width]
            self.hostingView = hostingView
            scrollView.documentView = hostingView
            scrollView.contentView.postsBoundsChangedNotifications = true
            scrollView.onVerticalScroll = { [weak self] event in
                self?.handleScrollEvent(event)
            }

            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.reportOffset()
                }
            }

            layoutDocumentView()
        }

        func update(content: Content) {
            hostingView?.rootView = content
            layoutDocumentView()
        }

        func teardown() {
            endTask?.cancel()
            endTask = nil
            if let boundsObserver {
                NotificationCenter.default.removeObserver(boundsObserver)
            }
            boundsObserver = nil
            scrollView?.onVerticalScroll = nil
            scrollView = nil
            hostingView = nil

            if isScrolling {
                isScrolling = false
                DispatchQueue.main.async { [onScrollActivityChanged] in
                    onScrollActivityChanged(false)
                }
            }
        }

        private func layoutDocumentView() {
            guard let scrollView, let hostingView else { return }

            DispatchQueue.main.async { [weak self, weak scrollView, weak hostingView] in
                guard let self, let scrollView, let hostingView else { return }

                let width = max(scrollView.contentView.bounds.width, 1)
                hostingView.frame.size.width = width
                hostingView.layoutSubtreeIfNeeded()
                let fittingHeight = hostingView.fittingSize.height
                let height = max(fittingHeight, scrollView.contentView.bounds.height)
                hostingView.frame = NSRect(x: 0, y: 0, width: width, height: height)

                let maximumOffset = max(0, height - scrollView.contentView.bounds.height)
                let clampedOffset = min(max(0, scrollView.contentView.bounds.origin.y), maximumOffset)
                if scrollView.contentView.bounds.origin.y != clampedOffset {
                    scrollView.contentView.scroll(to: NSPoint(x: 0, y: clampedOffset))
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
                self.reportOffset()
            }
        }

        private func reportOffset() {
            guard let scrollView else { return }
            onOffsetChanged(max(0, scrollView.contentView.bounds.origin.y))
        }

        private func handleScrollEvent(_ event: NSEvent) {
            endTask?.cancel()
            endTask = nil

            if !isScrolling {
                isScrolling = true
                onScrollActivityChanged(true)
            }

            if event.momentumPhase == .ended {
                scheduleEnd(after: .milliseconds(40))
            } else if event.phase == .ended {
                // A momentum phase can begin just after the finger phase ends.
                // Keep ownership briefly so that handoff cannot close the notch.
                scheduleEnd(after: .milliseconds(180))
            } else if event.phase.isEmpty && event.momentumPhase.isEmpty {
                // Mouse wheels do not provide gesture phases.
                scheduleEnd(after: .milliseconds(180))
            }
        }

        private func scheduleEnd(after delay: Duration) {
            endTask?.cancel()
            endTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: delay)
                guard let self, !Task.isCancelled, self.isScrolling else { return }
                self.isScrolling = false
                self.onScrollActivityChanged(false)
            }
        }
    }
}

private final class NativeMomentumScrollView: NSScrollView {
    var onVerticalScroll: ((NSEvent) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
            onVerticalScroll?(event)
        }
        super.scrollWheel(with: event)
    }
}
