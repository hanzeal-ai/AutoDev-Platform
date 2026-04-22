import SwiftUI

struct OverviewPage: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        VStack(spacing: AutoDevViewTheme.pageSpacing) {
            OverviewStatusOverviewCard(viewModel: viewModel)

            HStack(alignment: .top, spacing: AutoDevViewTheme.pageSpacing) {
                VStack(spacing: AutoDevViewTheme.pageSpacing) {
                    OverviewFocusProjectCard(viewModel: viewModel)
                    OverviewRunningQueueCard(viewModel: viewModel)
                    OverviewInterventionCard(viewModel: viewModel)
                }
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: AutoDevViewTheme.pageSpacing) {
                    OverviewSystemAlertsCard(viewModel: viewModel)
                    OverviewLifecycleThroughputCard(viewModel: viewModel)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }
}
