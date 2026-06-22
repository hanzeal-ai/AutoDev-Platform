import Foundation

extension ShellViewModel {
    func loadIfNeeded() async {
        guard autoHealthCheck, !hasLoaded else {
            return
        }

        hasLoaded = true
        restoreSidebarState()
        await runHealthCheck()
        startPeriodicHealthCheck()
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
                if state.isAuthenticated {
                    do {
                        try await refreshLiveSnapshot()
                    } catch {
                        state.apply(operationError: error, context: "同步控制面数据")
                    }
                }
            } catch {
                if let health = await DaemonBootstrapper.waitForHealth(using: daemonClient) {
                    state.apply(health: health)
                    if state.isAuthenticated {
                        do {
                            try await refreshLiveSnapshot()
                        } catch {
                            state.apply(operationError: error, context: "同步控制面数据")
                        }
                    }
                    return
                }
                state.apply(error: error)
            }
        }
    }

    /// Start a periodic health check that re-probes when daemon is offline.
    func startPeriodicHealthCheck() {
        healthCheckTask?.cancel()
        healthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                guard !Task.isCancelled else { break }
                guard let self else { break }
                guard self.dataMode == .liveDaemon else { continue }
                if self.state.daemonStatus != "OK" {
                    await self.runHealthCheck()
                }
            }
        }
    }

    func stopPeriodicHealthCheck() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
    }
}
