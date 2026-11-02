import SwiftUI
import Vision

@MainActor
final class Monitor: ObservableObject {
    let camera = Camera()
    @Published var label: String?
    @Published var error: String?
    @Published var isRunning = false
    @Published var interval = 0.5
    private var loop: Task<Void, Never>?
    private var strikes = Strikes()
    private let penalty = Penalty()

    func startCamera() async {
        do {
            try await camera.start()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    private func start() {
        isRunning = true
        camera.setDelivering(true)
        loop = Task {
            let clock = ContinuousClock()
            while !Task.isCancelled {
                // Checks never overlap, so one slower than the interval delays the next instead of piling up.
                let next = clock.now + .seconds(interval)
                await detect()
                try? await clock.sleep(until: next)
            }
        }
    }

    private func stop() {
        loop?.cancel()
        loop = nil
        isRunning = false
        camera.setDelivering(false)
        liftPenalty()
    }

    private func detect() async {
        // Delivery has only just started; the next tick will have a frame.
        guard let buffer = camera.latestBuffer() else { return }
        do {
            // Off the main actor: Vision's first run took about 7 seconds and would freeze the window.
            let label = try await Task.detached {
                try AppleVision.classify(
                    VNImageRequestHandler(cvPixelBuffer: buffer),
                    width: CVPixelBufferGetWidth(buffer),
                    height: CVPixelBufferGetHeight(buffer)
                )
            }.value
            guard !Task.isCancelled else { return }
            self.label = label
            error = nil
            if strikes.record(label) {
                penalty.show { [weak self] in self?.stop() }
            } else {
                penalty.hide()
            }
        } catch {
            guard !Task.isCancelled else { return }
            liftPenalty()
            self.error = error.localizedDescription
        }
    }

    /// Without a fresh answer nothing justifies keeping the screens black.
    private func liftPenalty() {
        strikes.reset()
        penalty.hide()
    }
}

struct ContentView: View {
    @StateObject private var monitor = Monitor()

    var body: some View {
        VStack(spacing: 12) {
            CameraPreview(session: monitor.camera.session)
                .frame(minWidth: 640, minHeight: 360)
            HStack(alignment: .top) {
                Button(monitor.isRunning ? "Stop" : "Start", action: monitor.toggle)
                VStack(alignment: .leading) {
                    Text(monitor.isRunning ? "Running" : "Stopped")
                        .foregroundStyle(monitor.isRunning ? .primary : .secondary)
                    Slider(value: $monitor.interval, in: 0.1...5, step: 0.1) {
                        Text("Interval \(monitor.interval, specifier: "%.1f") s").monospaced()
                    }
                    .frame(width: 360)
                }
                Spacer()
                VStack(alignment: .leading) {
                    ForEach(AppleVision.labels, id: \.self) { label in
                        Text(label)
                            .fontWeight(monitor.label == label ? .bold : .regular)
                            .foregroundStyle(monitor.label == label ? .primary : .secondary)
                    }
                }
                .monospaced()
            }
            if let error = monitor.error {
                Text(error).foregroundStyle(.red)
            }
        }
        .padding()
        .task {
            await monitor.startCamera()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?

    // SwiftUI's WindowGroup opened no window on some relaunches, so the window is created here.
    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: ContentView()))
        window.title = "Nail Guard"
        window.setContentSize(NSSize(width: 900, height: 640))
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApplication.shared.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
enum NailGuardApp {
    @MainActor
    static func main() {
        let delegate = AppDelegate()
        let app = NSApplication.shared
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        // NSApplication holds its delegate weakly.
        withExtendedLifetime(delegate) { app.run() }
    }
}
