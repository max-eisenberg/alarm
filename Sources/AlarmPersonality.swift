import Foundation

enum AlarmPersonality: String, CaseIterable, Identifiable {
    case screamingMan
    case angryGoose
    case carAlarm
    case medievalVillager
    case disappointedMother
    case tinyCreature

    var id: String { rawValue }

    var name: String {
        switch self {
        case .screamingMan: "SCREAMING MAN"
        case .angryGoose: "ANGRY GOOSE"
        case .carAlarm: "CAR ALARM"
        case .medievalVillager: "MEDIEVAL VILLAGER"
        case .disappointedMother: "DISAPPOINTED MOTHER"
        case .tinyCreature: "TINY CREATURE"
        }
    }

    var symbol: String {
        switch self {
        case .screamingMan: "figure.wave"
        case .angryGoose: "bird.fill"
        case .carAlarm: "car.side.fill"
        case .medievalVillager: "building.columns.fill"
        case .disappointedMother: "person.crop.circle.badge.exclamationmark"
        case .tinyCreature: "ant.fill"
        }
    }

    var tagline: String {
        switch self {
        case .screamingMan: "PURE PANIC"
        case .angryGoose: "HONK VIOLENCE"
        case .carAlarm: "THE 90s CLASSIC"
        case .medievalVillager: "UNHAND THE SPELLBOOK"
        case .disappointedMother: "EMOTIONAL DAMAGE"
        case .tinyCreature: "MEEEEEEEEP"
        }
    }

    var phrase: String {
        switch self {
        case .screamingMan: "Put me down! Put me down! That is not your laptop!"
        case .angryGoose: "Honk! Honk! Thief! Honk!"
        case .carAlarm: "Wee woo! Wee woo! Step away from the MacBook!"
        case .medievalVillager: "Stop, varlet! Unhand that silver spellbook!"
        case .disappointedMother: "I am not angry. I am just deeply disappointed in this choice."
        case .tinyCreature: "Meeeeeeep! Meep meep meeeeeeeep!"
        }
    }

    var speechRate: Float {
        switch self {
        case .disappointedMother: 135
        case .medievalVillager: 165
        case .tinyCreature: 275
        default: 210
        }
    }
}

enum AlarmSensitivity: String, CaseIterable, Identifiable {
    case chill = "CHILL"
    case balanced = "BALANCED"
    case feral = "FERAL"

    var id: String { rawValue }

    var threshold: Double {
        switch self {
        case .chill: 0.008
        case .balanced: 0.0025
        case .feral: 0.0009
        }
    }

    var noiseMultiplier: Double {
        switch self {
        case .chill: 6
        case .balanced: 3.5
        case .feral: 2
        }
    }

    /// Movement away from the calibrated resting orientation. This catches a
    /// slow, careful pickup that might not create a large adjacent-sample jerk.
    var pickupThreshold: Double {
        switch self {
        case .chill: 0.035
        case .balanced: 0.012
        case .feral: 0.004
        }
    }
}
