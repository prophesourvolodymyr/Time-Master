import Foundation
import TimeMasterCore

extension MusicLibraryItem {
    func musicClip(lane: WorkoutMusicLane = .background, start: Double = 0) -> WorkoutMusicClip {
        let music: [WorkoutMusicTrack]
        if isCollection {
            music = tracks.map {
                WorkoutMusicTrack(id: $0.id, title: $0.name, filename: $0.localReference?.filename,
                                  duration: $0.duration, provider: $0.source?.provider?.rawValue,
                                  providerReference: $0.source?.referenceID)
            }
        } else {
            music = [WorkoutMusicTrack(id: id, title: name, filename: localReference?.filename,
                                       duration: totalDuration, provider: source.provider?.rawValue,
                                       providerReference: source.referenceID)]
        }
        return WorkoutMusicClip(sourceItemID: id, title: name, lane: lane, start: start,
                                duration: music.reduce(0) { $0 + $1.duration }, tracks: music)
    }
}

extension Workout {
    var musicBoundaries: [Double] {
        var boundaries: [Double] = [0]
        var time: Double = 0
        for section in sections {
            for (index, slot) in section.effectiveSlots.enumerated() {
                time += Double(section.preparationTime(for: slot))
                boundaries.append(time)
                if section.mode == .timed { time += Double(slot.duration) }
                boundaries.append(time)
                for drop in slot.drops {
                    if section.mode == .timed { time += Double(drop.duration) }
                    boundaries.append(time)
                    time += Double(drop.restAfter)
                    boundaries.append(time)
                }
                if index < section.effectiveSlots.count - 1 {
                    time += Double(slot.restRow?.duration ?? slot.restAfter)
                    boundaries.append(time)
                }
            }
            time += Double(section.bigRestRow?.duration ?? (section.customRestAfter == 0 ? 0 : restBetweenSections))
            boundaries.append(time)
        }
        return boundaries
    }
}

@MainActor
extension MusicLibraryStore {
    func assignedMusic(for workout: Workout) -> [MusicLibraryItem] {
        let specific = items(for: .workout(id: workout.id))
        if !specific.isEmpty { return specific }
        if !workout.musicTrackFilenames.isEmpty {
            return workout.musicTrackFilenames.compactMap { filename in
                items.first { $0.localReference?.filename == filename }
            }
        }
        let typeMusic = items(for: .workoutType(id: workout.type.id))
        return typeMusic.isEmpty ? generalItems : typeMusic
    }
}

func musicTimestamp(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds < Double(Int.max) else { return "—" }
    let total = Int(max(0, seconds).rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
}
