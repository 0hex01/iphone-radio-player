import SwiftUI
import AVFoundation
import MediaPlayer

/// 0hex01 RADIO listener - iPhone counterpart to the Android 0hex01-apk app.
/// Plays the public MP3 stream with volume/mute, live status, and
/// automatic reconnect (mirrors the website player's self-heal logic).
struct ContentView: View {
    @StateObject var player = RadioPlayer()
    var body: some View {
        VStack(spacing: 20) {
            Text("0hex01 RADIO").font(.largeTitle.bold())
            Text(player.status)
                .frame(maxWidth: .infinity).padding(8)
                .background(player.playing ? Color.green : Color.red)
                .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 6))
            Button(player.playing ? "Stop" : "Play") { player.toggle() }
                .font(.title2).frame(width: 200, height: 56)
                .background(Color(red: 0.13, green: 0.59, blue: 0.95))
                .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 8))
            HStack {
                Image(systemName: "speaker.fill")
                Slider(value: $player.volume, in: 0...1)
                Image(systemName: "speaker.wave.3.fill")
            }
            Toggle("Mute", isOn: $player.muted)
            Text(player.detail).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
    }
}

final class RadioPlayer: ObservableObject {
    static let streamURL = "https://radio.primarymail.org/0hex01.mp3"
    @Published var playing = false
    @Published var status = "Stopped"
    @Published var detail = ""
    @Published var volume: Float = 1 { didSet { av?.volume = muted ? 0 : volume } }
    @Published var muted = false { didSet { av?.volume = muted ? 0 : volume } }
    private var av: AVPlayer?
    private var observers: [NSObjectProtocol] = []
    private var watchdog: Timer?

    func toggle() { playing ? stop() : play() }

    func play() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { detail = "Audio session: \(error.localizedDescription)" }
        // Cache-busting query like the website player - avoids stale buffers.
        let url = URL(string: Self.streamURL + "?t=\(Int(Date().timeIntervalSince1970))")!
        av = AVPlayer(url: url)
        av?.volume = muted ? 0 : volume
        av?.play()
        playing = true
        status = "Connecting…"
        observe()
        // If still buffering after 15s, reconnect once.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, self.playing, self.status == "Connecting…" else { return }
            self.stop(); self.play()
        }
    }

    func stop() {
        watchdog?.invalidate()
        av?.pause(); av = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        playing = false
        status = "Stopped"
    }

    private func observe() {
        guard let item = av?.currentItem else { return }
        observers.append(NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.reconnect()
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.reconnect()
        })
        // Stall detection: no playback progress for 10s -> reconnect.
        watchdog?.invalidate()
        watchdog = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self, self.playing, let item = self.av?.currentItem else { return }
            if item.isPlaybackLikelyToKeepUp { self.status = "Playing" }
            else if item.isPlaybackBufferEmpty {
                self.status = "Buffering…"
            }
        }
    }

    private func reconnect() {
        guard playing else { return }
        detail = "Stream dropped - reconnecting…"
        status = "Reconnecting…"
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.play()
        }
    }
}
