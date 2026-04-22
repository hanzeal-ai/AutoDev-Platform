import Foundation

extension ShellViewModel {
    func loadIfNeeded() async {
        guard autoHealthCheck, !hasLoaded else {
            return
        }

        hasLoaded = true
        await runHealthCheck()
    }

    func runHealthCheck() async {
        isChecking = true
        defer { isChecking = false }

        switch dataMode {
        case .sampleOnly:
            state.applySampleRefresh()
        case .liveDaemon:
            do {
                let health = try await daemonClient.getHealth()
                state.apply(health: health)
                do {
                    try await refreshLiveSnapshot()
                } catch {
                    state.apply(operationError: error, context: "同步控制面数据")
                }
            } catch {
                if let health = await DaemonBootstrapper.waitForHealth(using: daemonClient) {
                    state.apply(health: health)
                    do {
                        try await refreshLiveSnapshot()
                    } catch {
                        state.apply(operationError: error, context: "同步控制面数据")
                    }
                    return
                }
                state.apply(error: error)
            }
        }
    }
}
