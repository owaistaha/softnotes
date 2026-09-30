#if DEBUG
import Foundation
import os

/// DEBUG-only main-thread stall detector. A background timer pings the main
/// queue every 20 ms; when the ping runs, the time it waited is how long the
/// main thread was busy. Waits over `threshold` are logged and recorded.
///
/// Used by the `-keyboardCycles N` harness (see `RootContainerView`) and
/// available in any DEBUG run with `-watchdog`. Compiled out of release.
final class MainThreadWatchdog: @unchecked Sendable {
    static let shared = MainThreadWatchdog()

    struct Report: CustomStringConvertible {
        var stalls: [Int]        // ms, each > threshold
        var maxLatency: Int      // ms, worst ping seen
        var pings: Int
        var description: String {
            "stalls=\(stalls.count) max=\(maxLatency)ms pings=\(pings)"
                + (stalls.isEmpty ? "" : " each=\(stalls.map(String.init).joined(separator: ","))ms")
        }
    }

    private let queue = DispatchQueue(label: "softnotes.watchdog", qos: .userInteractive)
    private let lock = NSLock()
    private var timer: DispatchSourceTimer?
    private var inFlight = false
    private var sentAt: UInt64 = 0
    private var stalls: [Int] = []
    private var maxLatency = 0
    private var pings = 0
    /// In-progress stall reports at these waits (ms).
    private static let progressMarks = [500, 1000, 2000, 4000, 8000, 16000, 32000]
    private var lastMark = 0
    private var threshold: UInt64 = 500_000_000
    private let log = Logger(subsystem: "com.owaistaha.softnotes", category: "watchdog")

    /// ms since process start — for lining stalls up with harness events.
    static func clock() -> Int {
        Int((DispatchTime.now().uptimeNanoseconds - processStart) / 1_000_000)
    }
    private static let processStart: UInt64 = {
        var info = kinfo_proc(); var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        sysctl(&mib, 4, &info, &size, nil, 0)
        let tv = info.kp_proc.p_starttime
        let startWall = Double(tv.tv_sec) + Double(tv.tv_usec) / 1e6
        let ago = Date().timeIntervalSince1970 - startWall
        return DispatchTime.now().uptimeNanoseconds - UInt64(max(0, ago) * 1e9)
    }()

    func start(thresholdMs: Int = 500) {
        lock.withLock {
            threshold = UInt64(thresholdMs) * 1_000_000
            stalls = []; maxLatency = 0; pings = 0; inFlight = false
        }
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(20), leeway: .milliseconds(2))
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }

    func reset() {
        lock.withLock { stalls = []; maxLatency = 0; pings = 0 }
    }

    var report: Report {
        lock.withLock { Report(stalls: stalls, maxLatency: maxLatency, pings: pings) }
    }

    private func tick() {
        let now = DispatchTime.now().uptimeNanoseconds
        // A ping still waiting: report the stall *while* it lasts (a hang
        // that never ends would otherwise never be logged).
        let ongoing: Int? = lock.withLock {
            guard inFlight else { return nil }
            let ms = Int((now - sentAt) / 1_000_000)
            guard let next = Self.progressMarks.first(where: { $0 > lastMark }), ms >= next else { return nil }
            lastMark = next
            return ms
        }
        if let ongoing {
            log.error("main thread stall in progress: \(ongoing) ms")
            print("WATCHDOG: main thread stall in progress: \(ongoing) ms")
        }
        let send: Bool = lock.withLock {
            if inFlight { return false }
            lastMark = 0
            inFlight = true
            sentAt = now
            return true
        }
        guard send else { return }
        DispatchQueue.main.async { [self] in
            let waited = DispatchTime.now().uptimeNanoseconds - sentAt
            let ms = Int(waited / 1_000_000)
            let stalled: Bool = lock.withLock {
                inFlight = false
                pings += 1
                maxLatency = max(maxLatency, ms)
                if waited > threshold { stalls.append(ms); return true }
                return false
            }
            if stalled {
                log.error("main thread stalled \(ms) ms")
                print("WATCHDOG: main thread stalled \(ms) ms, ended at t=\(MainThreadWatchdog.clock()) ms")
            }
        }
    }
}
#endif
