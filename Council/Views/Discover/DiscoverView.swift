import SwiftUI
import UIKit

struct DiscoverView: View {
    @StateObject private var viewModel = DiscoverViewModel()
    @State private var selectedCoach: Coach?
    @State private var isJiggling = false
    @State private var orderedCoaches: [Coach] = []
    @State private var coachToDelete: Coach?
    @State private var coachToEdit: Coach?
    @State private var draggingCoach: Coach?
    @State private var cellFrames: [String: CGRect] = [:]
    @State private var dragTranslation: CGSize = .zero
    @State private var dragStartCenter: CGPoint?
    @State private var lastReorderTargetCoachID: String?
    @State private var hoveredTargetCoachID: String?

    @State private var showSession = false

    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
    ]

    // MARK: - Persistence keys
    private static let orderKey = "libraryCoachOrder"
    private static let hiddenKey = "libraryHiddenCoaches"

    var body: some View {
        ZStack {
            // Library
            NavigationStack {
                ZStack(alignment: .topLeading) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Done button for jiggle mode
                            if isJiggling {
                                HStack {
                                    Spacer()
                                    Button("Done") {
                                        withAnimation {
                                            isJiggling = false
                                        }
                                        endDragging()
                                    }
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                                }
                                .padding(.horizontal, 24)
                                .padding(.top, 8)
                            }

                            // Coach grid
                            LazyVGrid(columns: columns, spacing: 28) {
                                ForEach(orderedCoaches) { coach in
                                    coachCell(for: coach)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)
                        }
                        .padding(.bottom, 40)
                    }
                    .scrollDisabled(draggingCoach != nil)

                    if let draggingCoach,
                       let startCenter = dragStartCenter,
                       let sourceFrame = cellFrames[draggingCoach.id] {
                        CoachCell(
                            coach: draggingCoach,
                            isJiggling: false,
                            isLifted: true,
                            isDropTarget: false,
                            onDelete: {},
                            onEdit: {}
                        )
                            .frame(width: sourceFrame.width, height: sourceFrame.height)
                            .position(
                                x: startCenter.x + dragTranslation.width,
                                y: startCenter.y + dragTranslation.height
                            )
                            .scaleEffect(1.03)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)
                            .allowsHitTesting(false)
                            .zIndex(10)
                    }
                }
                .background(AppColors.background)
                .coordinateSpace(name: "discoverDragSpace")
                .onPreferenceChange(CoachCellFramePreferenceKey.self) { frames in
                    cellFrames = frames
                }
                .navigationBarHidden(true)
                .alert("Remove Coach", isPresented: Binding(
                    get: { coachToDelete != nil },
                    set: { if !$0 { coachToDelete = nil } }
                )) {
                    Button("Remove", role: .destructive) {
                        if let coach = coachToDelete {
                            removeCoach(coach)
                        }
                        coachToDelete = nil
                    }
                    Button("Cancel", role: .cancel) {
                        coachToDelete = nil
                    }
                } message: {
                    if let coach = coachToDelete {
                        Text("Remove \(coach.name) from your library?")
                    }
                }
                .sheet(item: $coachToEdit, onDismiss: {
                    Task { await viewModel.loadCoaches() }
                }) { coach in
                    CoachEditSheet(
                        coach: coach,
                        config: viewModel.coachConfigs[coach.id],
                        connectedServices: viewModel.connectedServices
                    )
                }
                .task {
                    if viewModel.featuredCoaches.isEmpty {
                        await viewModel.loadCoaches()
                    }
                    syncOrderedCoaches()
                }
                .onReceive(NotificationCenter.default.publisher(for: .switchToCouncilTab)) { _ in
                    Task { await viewModel.loadCoaches() }
                }
                .onReceive(viewModel.objectWillChange) { _ in
                    guard draggingCoach == nil else { return }
                    DispatchQueue.main.async {
                        syncOrderedCoaches()
                    }
                }
            }
            .scaleEffect(showSession ? 0.92 : 1)
            .blur(radius: showSession ? 10 : 0)
            .allowsHitTesting(!showSession)

            // Session overlay
            if showSession, let coach = selectedCoach {
                SessionView(coach: coach, onDismiss: dismissSession)
                    .zIndex(2)
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.86), value: showSession)
    }

    // MARK: - Data helpers

    private var allCoachesFromVM: [Coach] {
        var seen = Set<String>()
        var result: [Coach] = []
        for coach in viewModel.featuredCoaches {
            if seen.insert(coach.id).inserted { result.append(coach) }
        }
        for (_, coaches) in viewModel.coachesByCategory {
            for coach in coaches {
                if seen.insert(coach.id).inserted { result.append(coach) }
            }
        }
        return result
    }

    private func syncOrderedCoaches() {
        guard draggingCoach == nil else { return }

        let all = allCoachesFromVM
        guard !all.isEmpty else { return }

        let hiddenIds = Set(UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? [])
        let visible = all.filter { !hiddenIds.contains($0.id) }
        let savedOrder = UserDefaults.standard.stringArray(forKey: Self.orderKey) ?? []

        if savedOrder.isEmpty {
            orderedCoaches = visible
        } else {
            let coachMap = Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0) })
            var ordered: [Coach] = []
            for id in savedOrder {
                if let coach = coachMap[id] {
                    ordered.append(coach)
                }
            }
            // Append any new coaches not in saved order
            let orderedIds = Set(ordered.map(\.id))
            for coach in visible where !orderedIds.contains(coach.id) {
                ordered.append(coach)
            }
            orderedCoaches = ordered
        }
    }

    private func saveOrder() {
        let ids = orderedCoaches.map(\.id)
        UserDefaults.standard.set(ids, forKey: Self.orderKey)
    }

    private func removeCoach(_ coach: Coach) {
        withAnimation {
            orderedCoaches.removeAll { $0.id == coach.id }
        }
        var hidden = Set(UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? [])
        hidden.insert(coach.id)
        UserDefaults.standard.set(Array(hidden), forKey: Self.hiddenKey)

        if draggingCoach?.id == coach.id {
            endDragging()
        }

        saveOrder()
    }

    private func selectCoach(_ coach: Coach) {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
            selectedCoach = coach
            showSession = true
        }
    }

    private func dismissSession() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
            showSession = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            selectedCoach = nil
        }
    }

    private func enterJiggleMode() {
        guard !isJiggling else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
            isJiggling = true
        }
    }

    @ViewBuilder
    private func coachCell(for coach: Coach) -> some View {
        let isDraggingThisCell = draggingCoach?.id == coach.id
        let isDropTarget = hoveredTargetCoachID == coach.id && draggingCoach?.id != coach.id
        let tappableCell = CoachCell(
            coach: coach,
            isJiggling: isJiggling,
            isLifted: false,
            isDropTarget: isDropTarget,
            onDelete: { coachToDelete = coach },
            onEdit: { coachToEdit = coach }
        )
        .opacity(isDraggingThisCell ? 0.001 : 1)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: CoachCellFramePreferenceKey.self,
                    value: [coach.id: proxy.frame(in: .named("discoverDragSpace"))]
                )
            }
        )
        .onTapGesture {
            if !isJiggling {
                selectCoach(coach)
            }
        }

        if isJiggling {
            tappableCell
                .gesture(dragGesture(for: coach))
        } else {
            tappableCell
                .contextMenu {
                    Button {
                        selectCoach(coach)
                    } label: {
                        Label("Start Session", systemImage: "mic.fill")
                    }

                    ShareLink(
                        item: coach.shareURL,
                        subject: Text(coach.name),
                        message: Text(coach.shareText)
                    ) {
                        Label("Share Coach", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button {
                        enterJiggleMode()
                    } label: {
                        Label("Edit Library", systemImage: "pencil")
                    }
                }
        }
    }

    private func dragGesture(for coach: Coach) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("discoverDragSpace"))
            .onChanged { value in
                if draggingCoach == nil {
                    draggingCoach = coach
                    dragStartCenter = cellFrames[coach.id].map { CGPoint(x: $0.midX, y: $0.midY) }
                    dragTranslation = .zero
                    lastReorderTargetCoachID = nil
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }

                guard draggingCoach?.id == coach.id else { return }
                dragTranslation = value.translation
                reorderIfNeeded(for: coach)
            }
            .onEnded { _ in
                guard draggingCoach?.id == coach.id else { return }
                endDragging()
            }
    }

    private func reorderIfNeeded(for coach: Coach) {
        guard let startCenter = dragStartCenter else { return }
        let pointer = CGPoint(
            x: startCenter.x + dragTranslation.width,
            y: startCenter.y + dragTranslation.height
        )

        let targetID = reorderTargetID(at: pointer, excluding: coach.id)
        hoveredTargetCoachID = targetID

        guard let targetID else {
            // Leaving all targets should allow revisiting prior slots naturally.
            lastReorderTargetCoachID = nil
            return
        }

        guard targetID != lastReorderTargetCoachID,
              let fromIndex = orderedCoaches.firstIndex(where: { $0.id == coach.id }),
              let toIndex = orderedCoaches.firstIndex(where: { $0.id == targetID })
        else {
            return
        }

        lastReorderTargetCoachID = targetID
        withAnimation(.easeInOut(duration: 0.16)) {
            orderedCoaches.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
        saveOrder()
    }

    private func reorderTargetID(at point: CGPoint, excluding sourceID: String) -> String? {
        // Deterministic hit-testing in visual order prevents path-dependent reordering.
        for coach in orderedCoaches where coach.id != sourceID {
            guard let frame = cellFrames[coach.id] else { continue }
            if frame.insetBy(dx: -8, dy: -8).contains(point) {
                return coach.id
            }
        }

        return nil
    }

    private func endDragging() {
        draggingCoach = nil
        dragTranslation = .zero
        dragStartCenter = nil
        lastReorderTargetCoachID = nil
        hoveredTargetCoachID = nil
    }
}

// MARK: - Coach Cell

private struct CoachCellFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct CoachCell: View {
    let coach: Coach
    let isJiggling: Bool
    let isLifted: Bool
    let isDropTarget: Bool
    let onDelete: () -> Void
    let onEdit: () -> Void

    // Random jiggle direction so cells don't move in sync
    @State private var jiggleDirection: Double = 1

    var body: some View {
        VStack(spacing: 12) {
            orbContent
                .scaleEffect(isLifted ? 1.07 : 1)
                .overlay {
                    if isLifted {
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                            .frame(width: 94, height: 94)
                            .shadow(color: .white.opacity(0.22), radius: 8, x: 0, y: 0)
                    }
                }
                .animation(.easeOut(duration: 0.12), value: isLifted)

            VStack(spacing: 3) {
                Text(coach.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Text(coach.category.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(.vertical, 8)
        .scaleEffect(isDropTarget ? 1.025 : 1)
        .background {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.accent.opacity(0.14))
                    .padding(.horizontal, -6)
                    .padding(.vertical, -2)
            }
        }
        .contentShape(Rectangle())
        .overlay(alignment: .topLeading) {
            if isJiggling {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Color(white: 0.25))
                        .clipShape(Circle())
                }
                .offset(x: -4, y: -2)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay(alignment: .topTrailing) {
            if isJiggling {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(AppColors.accent)
                        .clipShape(Circle())
                }
                .offset(x: 4, y: -2)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .rotationEffect(.degrees(isJiggling ? 2.5 * jiggleDirection : 0))
        .animation(
            isJiggling
                ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true)
                : .default,
            value: isJiggling
        )
        .animation(.easeInOut(duration: 0.1), value: isDropTarget)
        .onAppear {
            jiggleDirection = Bool.random() ? 1 : -1
        }
    }

    private var orbContent: some View {
        OrbAvatar(colors: coach.orbColorPair, size: 120)
            .frame(height: 130)
    }
}
