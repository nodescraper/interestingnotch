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
    private let subtitleColor = Color.white.opacity(0.55)
    private let dividerColor = Color.white.opacity(0.08)
    private let bigScoreSize: CGFloat = 32
    private let crestSize: CGFloat = 40
    private let middleBandHeight: CGFloat = 96
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

    // MARK: - Derived

    private var games: [GameSnapshot] { model.games }

    private var currentIndex: Int {
        guard let id = model.focusedGame?.id,
              let idx = games.firstIndex(where: { $0.id == id }) else { return 0 }
        return idx
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetTitleRow(title: titleText, caption: captionText)
                .id(model.focusedGame?.id ?? "empty")
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.28), value: model.focusedGame?.id)

            middleBand
                .frame(height: middleBandHeight)

            if let game = model.focusedGame {
                footerMeta(for: game)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 5)
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

    /// On release, snap to the nearest page. Distance past commitFraction OR a
    /// fast flick flips one page; otherwise it springs back to the current one.
    private func settle(velocity: CGFloat, pageWidth: CGFloat) {
        let distance = dragOffset
        let towardNext = distance < 0
        let step = towardNext ? 1 : -1

        let passedDistance = abs(distance) > pageWidth * commitFraction
        let passedVelocity = abs(velocity) > commitVelocity &&
            ((velocity < 0) == towardNext)

        let targetIndex = currentIndex + step
        let canGo = targetIndex >= 0 && targetIndex < games.count
        let shouldCommit = canGo && (passedDistance || passedVelocity)

        // Springy settle with a touch of snap (lower damping = more snap).
        let settleSpring = Animation.spring(response: 0.42, dampingFraction: 0.78)

        if shouldCommit {
            fireCommitHaptic()
            // Move the committed index by one AND cancel the drag offset in the
            // same animated transaction. Because the strip rests on currentIndex,
            // shifting the index by one page while zeroing dragOffset keeps the
            // pixels continuous — the strip just keeps gliding the last bit.
            withAnimation(settleSpring) {
                model.focusAdjacentGame(step: step)
                dragOffset = 0
            }
        } else {
            if !canGo && abs(distance) > pageWidth * commitFraction * 0.5 {
                fireWallHaptic()
            }
            withAnimation(settleSpring) {
                dragOffset = 0
            }
        }

        isInteracting = false
    }

    // MARK: - Haptics

    private func fireCommitHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    private func fireWallHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    // MARK: - Content

    private func matchupContent(_ game: GameSnapshot) -> some View {
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

            HStack {
                Spacer()
                paginatorDots
                Spacer()
            }
        }
    }

    private var paginatorDots: some View {
        HStack(spacing: 5) {
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                let isActive = index == currentIndex
                Capsule()
                    .fill(isActive ? accent : Color.white.opacity(0.18))
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

    private var titleText: String {
        guard let game = model.focusedGame else { return "Sports" }
        let home = game.home.name.isEmpty ? game.home.abbreviation : game.home.name
        let away = game.away.name.isEmpty ? game.away.abbreviation : game.away.name
        return "\(home) vs \(away)"
    }

    private var captionText: String {
        model.focusedGame?.competition ?? "Follow teams to see upcoming matches"
    }

    private func centerStatusText(for game: GameSnapshot) -> String {
        switch game.state {
        case .live:
            return game.clock.isEmpty ? "Live" : game.clock
        case .pre:
            return game.startDate?.formatted(date: .abbreviated, time: .shortened) ?? game.displayStatus
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
        if let firstEvent = game.events.first {
            return "\(scorerPrefix(for: game, teamID: firstEvent.teamId)) \(firstEvent.player) \(firstEvent.minute)"
        }
        return game.state == .pre ? nil : game.competition
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
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)

            Text("No matches yet")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Follow teams to show their next match here.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(subtitleColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private func crest(_ logoURL: String, size: CGFloat) -> some View {
        AsyncImage(url: URL(string: logoURL)) { image in
            image
                .resizable()
                .scaledToFit()
        } placeholder: {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.08))
        }
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
