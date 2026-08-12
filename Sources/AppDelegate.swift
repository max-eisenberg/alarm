import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let state: AppState
    private let commandLineMode: Bool

    private var mainWindow: NSWindow?
    private var shieldWindows: [NSWindow] = []
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var originalFrame: NSRect?
    private var originalStyleMask: NSWindow.StyleMask?
    private var isQuittingAfterAuthentication = false

    init(state: AppState, commandLineMode: Bool = false) {
        self.state = state
        self.commandLineMode = commandLineMode
        super.init()
        state.onEngageKiosk = { [weak self] in self?.engageKiosk() }
        state.onReleaseKiosk = { [weak self] in self?.releaseKiosk() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(commandLineMode ? .accessory : .regular)
        if !commandLineMode {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async { [weak self] in self?.configureMainWindow() }
        }

        let mask: NSEvent.EventTypeMask = [
            .keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown,
            .otherMouseDown, .scrollWheel, .mouseMoved, .leftMouseDragged,
            .rightMouseDragged, .otherMouseDragged
        ]
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else { return event }
            self.state.registerHumanInteraction()
            if self.state.isLocked, event.type == .keyDown, event.keyCode == 53 {
                return nil
            }
            return event
        }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.state.registerHumanInteraction()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let localEventMonitor { NSEvent.removeMonitor(localEventMonitor) }
        if let globalEventMonitor { NSEvent.removeMonitor(globalEventMonitor) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if state.isLocked && !isQuittingAfterAuthentication {
            state.requestOwnerUnlock()
            return .terminateCancel
        }
        return .terminateNow
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if state.isLocked {
            state.requestOwnerUnlock()
            return false
        }
        return true
    }

    func requestQuit() {
        if state.isLocked {
            state.requestOwnerUnlock()
        } else {
            isQuittingAfterAuthentication = true
            NSApp.terminate(nil)
        }
    }

    private func configureMainWindow() {
        guard let window = NSApp.windows.first(where: { $0.contentView != nil }) else { return }
        mainWindow = window
        window.delegate = self
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.acceptsMouseMovedEvents = true
        window.setContentSize(NSSize(width: 1120, height: 760))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func engageKiosk() {
        let targetScreen = mainWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen else { return }

        if mainWindow == nil {
            let window = NSWindow(
                contentRect: targetScreen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: targetScreen
            )
            window.contentView = NSHostingView(rootView: LockedCompanionView(state: state))
            window.delegate = self
            window.acceptsMouseMovedEvents = true
            mainWindow = window
        }
        guard let mainWindow else { return }
        if !commandLineMode {
            originalFrame = mainWindow.frame
            originalStyleMask = mainWindow.styleMask
        }

        NSApp.presentationOptions = [
            .hideDock,
            .hideMenuBar,
            .disableAppleMenu,
            .disableProcessSwitching,
            .disableForceQuit,
            .disableSessionTermination,
            .disableHideApplication,
            .disableCursorLocationAssistance
        ]

        NSApp.setActivationPolicy(.regular)
        mainWindow.styleMask = [.borderless]
        mainWindow.level = .screenSaver
        mainWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        mainWindow.isMovable = false
        mainWindow.hasShadow = false
        mainWindow.setFrame(targetScreen.frame, display: true)
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        for screen in NSScreen.screens where screen != targetScreen {
            let shield = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            shield.level = .screenSaver
            shield.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            shield.isOpaque = true
            shield.backgroundColor = NSColor(calibratedRed: 0.06, green: 0.09, blue: 0.13, alpha: 1)
            shield.contentView = NSHostingView(rootView: LockedCompanionView(state: state))
            shield.orderFrontRegardless()
            shieldWindows.append(shield)
        }
    }

    private func releaseKiosk() {
        shieldWindows.forEach { $0.orderOut(nil) }
        shieldWindows.removeAll()
        NSApp.presentationOptions = []

        guard let mainWindow else { return }
        if commandLineMode {
            mainWindow.orderOut(nil)
            self.mainWindow = nil
            return
        }
        mainWindow.level = .normal
        mainWindow.collectionBehavior = []
        mainWindow.styleMask = originalStyleMask ?? [.titled, .closable, .miniaturizable, .resizable]
        mainWindow.isMovable = true
        mainWindow.hasShadow = true
        if let originalFrame { mainWindow.setFrame(originalFrame, display: true, animate: true) }
        mainWindow.makeKeyAndOrderFront(nil)
    }
}
