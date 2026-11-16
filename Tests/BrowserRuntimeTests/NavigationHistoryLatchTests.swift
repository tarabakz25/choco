import Testing
@testable import BrowserRuntime

@Suite struct NavigationHistoryLatchTests {
    @Test func backAndForwardStayEnabledThroughATransientDrop() {
        var latch = NavigationHistoryLatch()
        latch.update(liveBack: true, liveForward: true, navigating: false)
        latch.beginNavigation()
        // WebKit clears both flags before `isLoading` becomes true.
        latch.update(liveBack: false, liveForward: false, navigating: false)
        #expect(latch.canGoBack && latch.canGoForward)
        latch.update(liveBack: false, liveForward: false, navigating: true)
        #expect(latch.canGoBack && latch.canGoForward)
        // The load landed on the first page: back is really gone, forward is not.
        latch.update(liveBack: false, liveForward: true, navigating: false)
        #expect(!latch.canGoBack && latch.canGoForward)
    }

    @Test func aFreshLoadDoesNotInventHistory() {
        var latch = NavigationHistoryLatch()
        latch.update(liveBack: false, liveForward: false, navigating: true)
        #expect(!latch.canGoBack && !latch.canGoForward)
        latch.update(liveBack: true, liveForward: false, navigating: true)
        #expect(latch.canGoBack && !latch.canGoForward)
        latch.update(liveBack: true, liveForward: false, navigating: false)
        #expect(latch.canGoBack && !latch.canGoForward)
    }

    @Test func settlingWhileTheLoadIsStillRunningWaitsUntilItFinishes() {
        var latch = NavigationHistoryLatch()
        latch.update(liveBack: true, liveForward: false, navigating: false)
        latch.beginNavigation()
        latch.update(liveBack: false, liveForward: false, navigating: true, settle: true)
        #expect(latch.canGoBack)
        latch.update(liveBack: false, liveForward: false, navigating: false)
        #expect(!latch.canGoBack)
    }

    @Test func settlingPublishesTheLiveFlagsEvenIfTheLoadNeverReportedItself() {
        var latch = NavigationHistoryLatch()
        latch.update(liveBack: true, liveForward: false, navigating: false)
        latch.beginNavigation()
        latch.update(liveBack: false, liveForward: true, navigating: false, settle: true)
        #expect(!latch.canGoBack && latch.canGoForward)
        // A later idle update is not stuck on the anchored value.
        latch.update(liveBack: true, liveForward: false, navigating: false)
        #expect(latch.canGoBack && !latch.canGoForward)
    }
}
