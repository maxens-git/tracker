@main
struct SettingsRegressionProbe {
    static func main() {
        var state = SettingsLoadState()
        precondition(!state.isReady(for: false), "An unloaded form must not save")

        let failed = state.begin(server: false)
        state.finish(failed, server: false, succeeded: false)
        precondition(!state.isLoading && !state.isReady(for: false),
                     "A failed load must keep saving disabled and allow retry")

        let retry = state.begin(server: false)
        state.finish(retry, server: false, succeeded: true)
        precondition(state.isReady(for: false), "A successful retry must enable saving")
        state.finish(retry, server: false, succeeded: false)
        precondition(state.isReady(for: false), "Deferred cleanup must not undo success")
        precondition(!state.isReady(for: true), "Prod settings must never enable dev saves")

        let oldProd = state.begin(server: false)
        state.invalidate()
        let dev = state.begin(server: true)
        state.finish(oldProd, server: true, succeeded: true)
        precondition(state.isLoading && !state.isReady(for: true),
                     "A stale prod response must not complete the dev request")
        state.finish(dev, server: true, succeeded: true)
        precondition(state.isReady(for: true), "The selected server must become editable")

        state.invalidate()
        let newProd = state.begin(server: false)
        state.finish(oldProd, server: false, succeeded: true)
        precondition(state.isLoading && !state.isReady(for: false),
                     "A prod/dev/prod switch must reject the original prod response")
        state.finish(newProd, server: false, succeeded: true)
        precondition(state.isReady(for: false), "The newest prod response must be accepted")

        let oldRetry = state.begin(server: false)
        let newRetry = state.begin(server: false)
        state.finish(oldRetry, server: false, succeeded: false)
        precondition(state.isLoading, "A stale failure must not finish a replacement request")
        state.finish(newRetry, server: false, succeeded: true)
        precondition(state.isReady(for: false), "The replacement request must enable saving")

        print("PASS: settings failed load, retry, stale responses and server switches")
    }
}
