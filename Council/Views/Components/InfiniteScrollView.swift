import SwiftUI

struct InfiniteScrollView<Content: View, Data: RandomAccessCollection>: View where Data.Element: Identifiable {
    var spacing: CGFloat = 10
    var collection: Data
    @ViewBuilder var content: (Data.Element) -> Content
    var uiScrollView: (UIScrollView) -> ()
    var onScroll: () -> ()

    @State private var contentSize: CGSize = .zero

    var body: some View {
        GeometryReader {
            let size = $0.size

            ScrollView(.horizontal) {
                HStack(spacing: spacing) {
                    // Original content
                    HStack(spacing: spacing) {
                        ForEach(collection) { item in
                            content(item)
                        }
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: InfiniteScrollContentSizeKey.self,
                                value: proxy.size
                            )
                        }
                    )

                    // Repeating content for infinite looping
                    let averageWidth = contentSize.width / max(CGFloat(collection.count), 1)
                    let repeatingCount = contentSize.width > 0
                        ? Int((size.width / averageWidth).rounded()) + 1
                        : 1

                    HStack(spacing: spacing) {
                        ForEach(0..<repeatingCount, id: \.self) { index in
                            let item = Array(collection)[index % collection.count]
                            content(item)
                        }
                    }
                }
                .background(
                    InfiniteScrollHelper(
                        contentSize: $contentSize,
                        decelerationRate: .constant(.fast),
                        uiScrollView: uiScrollView,
                        onScroll: onScroll
                    )
                )
            }
            .onPreferenceChange(InfiniteScrollContentSizeKey.self) { newValue in
                contentSize = .init(width: newValue.width + spacing, height: newValue.height)
            }
        }
    }
}

// MARK: - Preference Key

private struct InfiniteScrollContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - UIScrollView Delegate Helper

private struct InfiniteScrollHelper: UIViewRepresentable {
    @Binding var contentSize: CGSize
    @Binding var decelerationRate: UIScrollView.DecelerationRate
    var uiScrollView: (UIScrollView) -> ()
    var onScroll: () -> ()

    func makeCoordinator() -> Coordinator {
        Coordinator(
            decelerationRate: decelerationRate,
            contentSize: contentSize,
            onScroll: onScroll
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear

        DispatchQueue.main.async {
            if let scrollView = view.parentScrollView {
                context.coordinator.defaultDelegate = scrollView.delegate
                scrollView.decelerationRate = decelerationRate
                scrollView.delegate = context.coordinator
                uiScrollView(scrollView)
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.decelerationRate = decelerationRate
        context.coordinator.contentSize = contentSize
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var decelerationRate: UIScrollView.DecelerationRate
        var contentSize: CGSize
        var onScroll: () -> ()
        weak var defaultDelegate: UIScrollViewDelegate?

        init(
            decelerationRate: UIScrollView.DecelerationRate,
            contentSize: CGSize,
            onScroll: @escaping () -> ()
        ) {
            self.decelerationRate = decelerationRate
            self.contentSize = contentSize
            self.onScroll = onScroll
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            scrollView.decelerationRate = decelerationRate

            let minX = scrollView.contentOffset.x

            if minX > contentSize.width {
                scrollView.contentOffset.x -= contentSize.width
            }

            if minX < 0 {
                scrollView.contentOffset.x += contentSize.width
            }

            onScroll()

            defaultDelegate?.scrollViewDidScroll?(scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            defaultDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            defaultDelegate?.scrollViewDidEndDecelerating?(scrollView)
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            defaultDelegate?.scrollViewWillBeginDragging?(scrollView)
        }

        func scrollViewWillEndDragging(
            _ scrollView: UIScrollView,
            withVelocity velocity: CGPoint,
            targetContentOffset: UnsafeMutablePointer<CGPoint>
        ) {
            defaultDelegate?.scrollViewWillEndDragging?(
                scrollView,
                withVelocity: velocity,
                targetContentOffset: targetContentOffset
            )
        }
    }
}

// MARK: - UIView Helper

extension UIView {
    var parentScrollView: UIScrollView? {
        if let superview, superview is UIScrollView {
            return superview as? UIScrollView
        }
        return superview?.parentScrollView
    }
}
