import SwiftUI

struct CollapsedCreationRail: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        DashboardCard(title: title) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
