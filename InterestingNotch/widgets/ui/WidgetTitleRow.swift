//
//  WidgetTitleRow.swift
//  InterestingNotch
//

import SwiftUI

struct WidgetTitleRow<Accessory: View>: View {
    let title: String
    let caption: String
    var titleColor: Color = .white
    var rightText: String?
    var rightTextColor: Color = .white
    var showsRightIndicator: Bool = false
    @ViewBuilder var accessory: () -> Accessory

    private let rowHeight: CGFloat = 44
    @State private var indicatorVisible = true

    init(
        title: String,
        caption: String,
        titleColor: Color = .white,
        rightText: String? = nil,
        rightTextColor: Color = .white,
        showsRightIndicator: Bool = false,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.title = title
        self.caption = caption
        self.titleColor = titleColor
        self.rightText = rightText
        self.rightTextColor = rightTextColor
        self.showsRightIndicator = showsRightIndicator
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(caption)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 8)

            if let rightText, !rightText.isEmpty {
                HStack(spacing: 8) {
                    if showsRightIndicator {
                        Circle()
                            .fill(rightTextColor)
                            .frame(width: 8, height: 8)
                            .opacity(indicatorVisible ? 1 : 0.3)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                                    indicatorVisible = false
                                }
                            }
                    }

                    Text(rightText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(rightTextColor)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            accessory()
        }
        .frame(height: rowHeight, alignment: .center)
    }
}

extension WidgetTitleRow where Accessory == EmptyView {
    init(title: String, caption: String, titleColor: Color = .white, rightText: String? = nil, rightTextColor: Color = .white, showsRightIndicator: Bool = false) {
        self.init(title: title, caption: caption, titleColor: titleColor, rightText: rightText, rightTextColor: rightTextColor, showsRightIndicator: showsRightIndicator) { EmptyView() }
    }
}
