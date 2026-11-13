import AppKit
import Foundation
import iPomoCore

@MainActor
final class SoundPlayer {
    private var tickingTimer: Timer?
    private var alarmWorkItems: [DispatchWorkItem] = []
    private var retainedSounds: [NSSound] = []

    func playAlarm(settings: SoundSettings) {
        guard settings.soundsEnabled else { return }
        stopAlarm()
        let repeats = max(1, settings.alarmRepeatCount)
        for index in 0..<repeats {
            let item = DispatchWorkItem { [weak self] in
                self?.playSound(
                    named: settings.alarmSound.systemSoundName,
                    volume: settings.alarmVolume
                )
            }
            alarmWorkItems.append(item)
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Double(index) * 1.25,
                execute: item
            )
        }
    }

    func previewAlarm(settings: SoundSettings) {
        guard settings.soundsEnabled else { return }
        stopAlarm()
        playSound(named: settings.alarmSound.systemSoundName, volume: settings.alarmVolume)
    }

    func stopAlarm() {
        alarmWorkItems.forEach { $0.cancel() }
        alarmWorkItems.removeAll()
    }

    func startTicking(settings: SoundSettings) {
        stopTicking()
        guard settings.soundsEnabled, let interval = settings.tickingSound.interval else { return }
        tick(volume: settings.tickingVolume)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick(volume: settings.tickingVolume)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickingTimer = timer
    }

    func stopTicking() {
        tickingTimer?.invalidate()
        tickingTimer = nil
    }

    func stopAll() {
        stopAlarm()
        stopTicking()
    }

    private func tick(volume: Double) {
        playSound(named: "Tink", volume: volume)
    }

    private func playSound(named name: String, volume: Double) {
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.volume = Float(min(1, max(0, volume)))
        sound.play()
        retainedSounds.append(sound)
        // Retain only the most recently played sounds so audio buffers do not
        // accumulate indefinitely (each NSSound holds decoded audio data).
        if retainedSounds.count > 2 {
            retainedSounds.removeFirst(retainedSounds.count - 2)
        }
    }
}
