import AppKit
import SwiftUI
import LaunchAtLogin
import AVFoundation

final class MenuBarController: NSObject, NSPopoverDelegate {

    // MARK: - Core UI

    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let hostingController: NSHostingController<WebcamView>

    // MARK: - State

    private let webcamManager: WebcamManager
    private var menu: NSMenu
    private var launchAtLoginItem: NSMenuItem?
    private var globalClickMonitor: Any?
    private let micLevelManager = MicLevelManager()
    private var micCheckItem: NSMenuItem?

    private let micCheckDefaultsKey = "MicCheckEnabled"

    private var currentPopoverSize: (width: CGFloat, height: CGFloat) = (480, 272)

    private let iconNames = [
        "camcoder",
        "cybershot",
        "eyes",
        "rearmirror",
        "sidemirror",
        "webcam",
        "webcam2"
    ]

    private let iconDefaultsKey = "SelectedMenuBarIcon"

    // MARK: - Init

    override init() {
        if let savedSize = UserDefaults.standard.array(forKey: "SavedPopoverSize") as? [CGFloat],
           savedSize.count == 2 {
            currentPopoverSize = (savedSize[0], savedSize[1])
        }

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.webcamManager = WebcamManager()
        self.menu = NSMenu()
        self.hostingController = NSHostingController(
            rootView: WebcamView(
                webcamManager: webcamManager,
                micLevelManager: micLevelManager
            )
        )

        super.init()

        configureStatusItem()
        configurePopover()
        setupMenu()
        applyInitialMenuBarIcon()
        syncLaunchAtLoginState()
    }

    // MARK: - Configuration

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        let icon = NSImage(named: "cybershot")
        icon?.isTemplate = true

        button.image = icon
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(
            width: currentPopoverSize.width,
            height: currentPopoverSize.height
        )
    }

    // MARK: - Menu

    private func setupMenu() {
        let builder = MenuBuilder(target: self)

        let menu = builder.makeMainMenu(
            launchAtLoginItem: &launchAtLoginItem
        )

        // ---- Camera section ----
        menu.addItem(.separator())

        let cameraMenu = builder.makeCameraMenu(
            devices: webcamManager.availableDevices,
            selectedID: UserDefaults.standard.string(forKey: "SelectedCameraID")
        )

        let cameraItem = NSMenuItem(
            title: "Choose WebCam",
            action: nil,
            keyEquivalent: ""
        )
        menu.setSubmenu(cameraMenu, for: cameraItem)
        menu.addItem(cameraItem)

        // ---- More section ----
        builder.appendMoreMenu(
            to: menu,
            launchAtLoginItem: &launchAtLoginItem
        )

        micCheckItem = menu.items
            .flatMap { $0.submenu?.items ?? [] }
            .first { $0.title == "Mic Check" }

        self.menu = menu
        updateSizeCheckmarks()
        syncLaunchAtLoginState()
        syncMicCheckState()
    }

    // MARK: - Status Item Action

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover()
        }
    }

    // MARK: - Popover Control

    private func togglePopover() {
        popover.isShown ? closePopover() : showPopover()
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }

        popover.contentSize = NSSize(
            width: currentPopoverSize.width,
            height: currentPopoverSize.height
        )

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .leftMouseDown
        ) { [weak self] _ in
            self?.closePopover()
        }

        webcamManager.startSession()
        if UserDefaults.standard.bool(forKey: micCheckDefaultsKey) {
            micLevelManager.start()
        }
    }

    private func closePopover() {
        popover.performClose(nil)

        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        webcamManager.stopSession()
        micLevelManager.stop()
    }

    // MARK: - Size Handling (Animated)

    @objc func setSmallSize() { updatePopoverSize(384, 216) }
    @objc func setMediumSize() { updatePopoverSize(480, 272) }
    @objc func setLargeSize() { updatePopoverSize(640, 360) }

    private func updatePopoverSize(_ width: CGFloat, _ height: CGFloat) {
        currentPopoverSize = (width, height)
        UserDefaults.standard.set([width, height], forKey: "SavedPopoverSize")

        let newSize = NSSize(width: width, height: height)
        animatePopoverResize(to: newSize)

        updateSizeCheckmarks()
    }

    private func animatePopoverResize(to size: NSSize) {
        guard popover.isShown,
              let contentView = popover.contentViewController?.view else {
            popover.contentSize = size
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            contentView.animator().setFrameSize(size)
        }
    }

    private func updateSizeCheckmarks() {
        for item in menu.items {
            switch item.title {
            case "Smol":
                item.state = currentPopoverSize == (384, 216) ? .on : .off
            case "Average":
                item.state = currentPopoverSize == (480, 272) ? .on : .off
            case "Beeg":
                item.state = currentPopoverSize == (640, 360) ? .on : .off
            default:
                item.state = .off
            }
        }
    }

    // MARK: - Camera Selection

    @objc func selectCamera(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        webcamManager.selectCamera(with: id)
        setupMenu()
    }

    // MARK: - Launch at Login

    @objc func toggleLaunchAtLogin() {
        LaunchAtLogin.isEnabled.toggle()
        syncLaunchAtLoginState()
    }
    
    // MARK: - Mic Check
    
    @objc func toggleMicCheck() {
        let enabled = !UserDefaults.standard.bool(forKey: micCheckDefaultsKey)
        UserDefaults.standard.set(enabled, forKey: micCheckDefaultsKey)

        micCheckItem?.state = enabled ? .on : .off

        // If popover is already open, react immediately
        if popover.isShown {
            enabled ? micLevelManager.start() : micLevelManager.stop()
        }
    }

    private func syncLaunchAtLoginState() {
        launchAtLoginItem?.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    // MARK: - Menu Bar Icon Handling

    private func applyInitialMenuBarIcon() {
        let savedIcon = UserDefaults.standard.string(forKey: iconDefaultsKey)

        let iconName = savedIcon ?? "cybershot"
        updateMenuBarIcon(named: iconName)

        if savedIcon == nil {
            UserDefaults.standard.set(iconName, forKey: iconDefaultsKey)
        }
    }

    @objc func chooseRandomIcon() {
        let currentIcon = UserDefaults.standard.string(forKey: iconDefaultsKey) ?? "cybershot"

        let candidates = iconNames.filter { $0 != currentIcon }
        let nextIcon = candidates.randomElement() ?? currentIcon

        UserDefaults.standard.set(nextIcon, forKey: iconDefaultsKey)
        updateMenuBarIcon(named: nextIcon)
    }

    private func updateMenuBarIcon(named name: String) {
        guard let button = statusItem.button else { return }

        button.wantsLayer = true

        let newImage = NSImage(named: name)
        newImage?.isTemplate = true

        // Fade out
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            button.animator().alphaValue = 0.0
        } completionHandler: {
            // Swap image while invisible
            button.image = newImage

            // Fade back in
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                button.animator().alphaValue = 1.0
            }
        }
    }


    // MARK: - Misc

    @objc func resetPermissions() {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "Try turning it off and on again (it usually works :3)"
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
           ) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func syncMicCheckState() {
        let enabled = UserDefaults.standard.bool(forKey: micCheckDefaultsKey)
        micCheckItem?.state = enabled ? .on : .off
    }

    @objc func openAboutWindow() {
        // unchanged
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
