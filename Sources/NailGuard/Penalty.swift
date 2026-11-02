import AppKit

/// Counts consecutive `touching_mouth` answers so one wrong answer does not black out the screens.
struct Strikes {
    static let threshold = 2
    private var count = 0

    /// Returns whether the penalty should be active after this answer.
    mutating func record(_ choice: String) -> Bool {
        count = choice == "touching_mouth" ? count + 1 : 0
        return count >= Self.threshold
    }

    mutating func reset() {
        count = 0
    }
}

enum Buzzer {
    /// A 1-second mono WAV of two square waves a semitone apart, chopped 8 times per second.
    static func wav() -> Data {
        let sampleRate = 44_100
        let amplitude = 0.35 // Loudness still follows the system volume; kept moderate for headphones.
        let samples = (0..<sampleRate).map { index -> Int16 in
            let time = Double(index) / Double(sampleRate)
            guard Int(time * 16) % 2 == 0 else { return 0 }
            let square = { (frequency: Double) in sin(2 * .pi * frequency * time) > 0 ? 1.0 : -1.0 }
            return Int16((square(880) + square(932)) / 2 * amplitude * Double(Int16.max))
        }

        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36 + samples.count * 2))
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16))
        append(UInt16(1)) // PCM
        append(UInt16(1)) // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: "data".utf8)
        append(UInt32(samples.count * 2))
        samples.forEach(append)
        return data
    }
}

private final class BlackoutWindow: NSWindow {
    // Borderless windows refuse key status by default, and Esc needs it.
    override var canBecomeKey: Bool { true }
}

@MainActor
final class Penalty {
    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private let buzzer: NSSound? = {
        let sound = NSSound(data: Buzzer.wav())
        sound?.loops = true
        return sound
    }()

    func show(onEscape: @escaping @MainActor () -> Void) {
        guard windows.isEmpty else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        windows = NSScreen.screens.map(blackout)
        windows.first?.makeKey()
        NSApplication.shared.activate()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let escape: UInt16 = 53
            if event.keyCode == escape { MainActor.assumeIsolated { onEscape() } }
            return nil
        }
        buzzer?.play()
    }

    func hide() {
        guard !windows.isEmpty else { return }
        buzzer?.stop()
        windows.forEach { $0.orderOut(nil) }
        windows = []
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        previousApp?.activate()
        previousApp = nil
    }

    private func blackout(_ screen: NSScreen) -> NSWindow {
        let window = BlackoutWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hint = NSTextField(labelWithString: "Esc")
        hint.textColor = .darkGray
        hint.frame.origin = NSPoint(x: 20, y: 20)
        hint.sizeToFit()
        window.contentView?.addSubview(hint)

        window.setFrame(screen.frame, display: false)
        window.orderFrontRegardless()
        return window
    }
}
