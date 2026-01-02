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
    private let micLevelManager = MicLevelManager()
    private var menu: NSMenu
    private var launchAtLoginItem: NSMenuItem?
    private var globalClickMonitor: Any?

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
    private let micCheckKey = "MicCheckEnabled"
    private let closeBehaviorKey = "ClosePreviewBehavior"

    enum CloseBehavior: String {
        case icon
        case outside
    }

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
        updateCloseBehaviorCheckmarks()
        updateMicCheckState()
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

        builder.appendCameraAndMicSection(
            to: menu,
            devices: webcamManager.availableDevices,
            selectedCameraID: UserDefaults.standard.string(forKey: "SelectedCameraID")
        )

        builder.appendCloseBehaviorSection(to: menu)

        builder.appendMoreMenu(
            to: menu,
            launchAtLoginItem: &launchAtLoginItem
        )

        self.menu = menu
        updateSizeCheckmarks()
        updateCloseBehaviorCheckmarks()
        updateMicCheckState()
        syncLaunchAtLoginState()
    }

    // MARK: - Status Item Action

    @objc private func statusItemClicked(_ sender: AnyObject?) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            updateSizeCheckmarks()   // 🔹 optional but nice
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

        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )

        // Install outside-click monitor ONLY when configured
        if closeBehavior == .outside {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: .leftMouseDown
            ) { [weak self] _ in
                self?.closePopover()
            }
        }

        webcamManager.startSession()

        if UserDefaults.standard.bool(forKey: micCheckKey) {
            micLevelManager.start()
        }
    }

    private func closePopover() {
        popover.performClose(nil)

        // Always remove the monitor
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }

    func popoverDidClose(_ notification: Notification) {
        webcamManager.stopSession()
        micLevelManager.stop()
    }
    
    // MARK: - Size Handling

    @objc func setSmallSize() { updatePopoverSize(384, 216) }
    @objc func setMediumSize() { updatePopoverSize(480, 272) }
    @objc func setLargeSize() { updatePopoverSize(640, 360) }

    private func updatePopoverSize(_ width: CGFloat, _ height: CGFloat) {
        currentPopoverSize = (width, height)
        UserDefaults.standard.set([width, height], forKey: "SavedPopoverSize")
        popover.contentSize = NSSize(width: width, height: height)
        updateSizeCheckmarks()
    }

    private func updateSizeCheckmarks() {
        for item in menu.items {
            switch item.title {
            case "Small":
                item.state = currentPopoverSize == (384, 216) ? .on : .off
            case "Medium":
                item.state = currentPopoverSize == (480, 272) ? .on : .off
            case "Large":
                item.state = currentPopoverSize == (640, 360) ? .on : .off
            default:
                break
            }
        }
    }

    // MARK: - Camera Selection

    @objc func selectCamera(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        webcamManager.selectCamera(with: id)
        setupMenu()
    }

    // MARK: - Mic Check

    @objc func toggleMicCheck() {
        let enabled = !UserDefaults.standard.bool(forKey: micCheckKey)
        UserDefaults.standard.set(enabled, forKey: micCheckKey)
        updateMicCheckState()
    }

    private func updateMicCheckState() {
        for item in menu.items where item.title == "Mic Check" {
            item.state = UserDefaults.standard.bool(forKey: micCheckKey) ? .on : .off
        }
    }

    // MARK: - Close Behavior

    private var closeBehavior: CloseBehavior {
        let raw = UserDefaults.standard.string(forKey: closeBehaviorKey)
        return CloseBehavior(rawValue: raw ?? "") ?? .outside
    }

    @objc func setCloseOnIcon() {
        UserDefaults.standard.set(CloseBehavior.icon.rawValue, forKey: closeBehaviorKey)
        closePopover()                       // important
        updateCloseBehaviorCheckmarks()
    }

    @objc func setCloseOnOutside() {
        UserDefaults.standard.set(CloseBehavior.outside.rawValue, forKey: closeBehaviorKey)
        closePopover()                       // important
        updateCloseBehaviorCheckmarks()
    }

    private func updateCloseBehaviorCheckmarks() {
        for item in menu.items {
            if item.title == "Clicking on Icon" {
                item.state = closeBehavior == .icon ? .on : .off
            } else if item.title == "Clicking Outside" {
                item.state = closeBehavior == .outside ? .on : .off
            }
        }
    }

    // MARK: - Launch at Login

    @objc func toggleLaunchAtLogin() {
        LaunchAtLogin.isEnabled.toggle()
        syncLaunchAtLoginState()
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

        let newImage = NSImage(named: name)
        newImage?.isTemplate = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            button.animator().alphaValue = 0.0
        } completionHandler: {
            button.image = newImage
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                button.animator().alphaValue = 1.0
            }
        }
    }

    @objc func showAbout() {
        let windowWidth: CGFloat = 280
        let windowHeight: CGFloat = 150

        let aboutWindow = NSWindow(
            contentRect: NSMakeRect(0, 0, windowWidth, windowHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        aboutWindow.title = ""
        aboutWindow.isReleasedWhenClosed = false
        aboutWindow.level = .floating
        aboutWindow.center()

        let contentView = NSView(frame: NSMakeRect(0, 0, windowWidth, windowHeight))

        // ---- Dynamic values ----

        let info = Bundle.main.infoDictionary

        let appName =
            info?["CFBundleDisplayName"] as? String ??
            info?["CFBundleName"] as? String ??
            "Web Mirror"

        let version =
            info?["CFBundleShortVersionString"] as? String ?? "1.0"

        let build =
            info?["CFBundleVersion"] as? String ?? "1"

        let developer =
            info?["AppDeveloperName"] as? String ?? "Unknown Developer"

        // ---- Layout ----

        let iconSize: CGFloat = 60
        let spacing: CGFloat = 4
        let totalContentHeight = iconSize + 45
        let startY = (windowHeight - totalContentHeight) / 2 + iconSize

        let appIcon = NSImageView(
            frame: NSRect(
                x: (windowWidth - iconSize) / 2,
                y: startY,
                width: iconSize,
                height: iconSize
            )
        )
        appIcon.image = NSApp.applicationIconImage

        let appNameLabel = NSTextField(labelWithString: appName)
        appNameLabel.frame = NSRect(
            x: 0,
            y: startY - (20 + spacing),
            width: windowWidth,
            height: 20
        )
        appNameLabel.alignment = .center
        appNameLabel.font = NSFont.boldSystemFont(ofSize: 14)

        let versionLabel = NSTextField(
            labelWithString: "Version \(version) (\(build))"
        )
        versionLabel.frame = NSRect(
            x: 0,
            y: startY - (40 + 2 * spacing),
            width: windowWidth,
            height: 20
        )
        versionLabel.alignment = .center
        versionLabel.font = NSFont.systemFont(ofSize: 10)

        let authorLabel = NSTextField(
            labelWithString: "by \(developer)"
        )
        authorLabel.frame = NSRect(
            x: 0,
            y: startY - (65 + 3 * spacing),
            width: windowWidth,
            height: 20
        )
        authorLabel.alignment = .center
        authorLabel.font = NSFont.systemFont(ofSize: 10)
        authorLabel.textColor = .secondaryLabelColor

        contentView.addSubview(appIcon)
        contentView.addSubview(appNameLabel)
        contentView.addSubview(versionLabel)
        contentView.addSubview(authorLabel)

        aboutWindow.contentView = contentView
        aboutWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }


    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
