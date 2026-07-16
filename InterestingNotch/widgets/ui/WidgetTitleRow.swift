//
//  WidgetTitleRow.swift
//  InterestingNotch
//

import SwiftUI

struct WidgetTitleRow<Accessory: View>: View {
    let title: String
    let caption: String
    var titleColor: Color = .white
    @ViewBuilder var accessory: () -> Accessory

    private let rowHeight: CGFloat = 44

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
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

            accessory()
        }
        .frame(height: rowHeight, alignment: .center)
    }
}

extension WidgetTitleRow where Accessory == EmptyView {
    init(title: String, caption: String, titleColor: Color = .white) {
        self.init(title: title, caption: caption, titleColor: titleColor) { EmptyView() }
    }
}
