# Technical notes

`alarm` is a native arm64 command-line executable using AppKit, LocalAuthentication, IOKit, SwiftUI, Core Audio, and AVFoundation. It reads the internal `AppleSPUHIDDevice` IMU on supported Apple Silicon MacBooks. Unsupported hardware falls back to keyboard and trackpad interaction detection. Motion detection combines sample-to-sample acceleration with displacement from the calibrated resting orientation, so both sharp touches and slow pickups are covered.

The motion format is undocumented by Apple and may change. See [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md) for research attribution.

While armed, AppKit covers connected displays, hides the Dock and menu bar, and disables ordinary app switching, Force Quit UI, hiding, and session termination. The on-screen owner-unlock control opens macOS authentication with Touch ID and password fallback. The command never sees the password or biometric data. When triggered, Core Audio unmutes the active output and sets it to maximum volume, then restores the prior settings when the alarm stops.

Like any unprivileged process, it cannot prevent hard power-off, reboot, recovery-mode access, or `kill -9` from an already-authorized remote session.

It does not request administrator privileges or change system sleep settings. Closing the MacBook lid puts the machine to sleep and prevents the alarm from operating until the Mac wakes again.
