import AppKit
import AVFoundation

struct MenuBuilder {

    let target: AnyObject

    func makeMainMenu(
        launchAtLoginItem: inout NSMenuItem?
    ) -> NSMenu {

        let menu = NSMenu()
        menu.addItem(.separator())

        menu.addItem(label("Change Preview Size"))

        menu.addItem(item("Smol", #selector(MenuBarController.setSmallSize)))
        menu.addItem(item("Average", #selector(MenuBarController.setMediumSize)))
        menu.addItem(item("Beeg", #selector(MenuBarController.setLargeSize)))

        return menu
    }

    func appendMoreMenu(
        to menu: NSMenu,
        launchAtLoginItem: inout NSMenuItem?
    ) {

        menu.addItem(.separator())

        let moreMenu = NSMenu()

        moreMenu.addItem(item(
            "Choose Random Icon",
            #selector(MenuBarController.chooseRandomIcon)
        ))

        moreMenu.addItem(.separator())
        
        moreMenu.addItem(item(
            "Mic Check",
            #selector(MenuBarController.toggleMicCheck)
        ))

        let launchItem = item(
            "Launch at Login",
            #selector(MenuBarController.toggleLaunchAtLogin)
        )
        launchAtLoginItem = launchItem
        moreMenu.addItem(launchItem)

        moreMenu.addItem(item(
            "Reset Permissions",
            #selector(MenuBarController.resetPermissions)
        ))

        moreMenu.addItem(item(
            "About",
            #selector(MenuBarController.openAboutWindow)
        ))

        let moreItem = NSMenuItem(title: "More", action: nil, keyEquivalent: "")
        menu.setSubmenu(moreMenu, for: moreItem)
        menu.addItem(moreItem)

        menu.addItem(.separator())

        menu.addItem(item(
            "Quit WebMirror",
            #selector(MenuBarController.quitApp),
            keyEquivalent: "q"
        ))
    }

    func makeCameraMenu(
        devices: [AVCaptureDevice],
        selectedID: String?
    ) -> NSMenu {

        let menu = NSMenu()

        if devices.isEmpty {
            let item = NSMenuItem(title: "No Cameras Found", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return menu
        }

        for device in devices {
            let item = NSMenuItem(
                title: device.localizedName,
                action: #selector(MenuBarController.selectCamera(_:)),
                keyEquivalent: ""
            )
            item.target = target
            item.representedObject = device.uniqueID
            item.state = (device.uniqueID == selectedID) ? .on : .off
            menu.addItem(item)
        }

        return menu
    }

    // MARK: - Helpers

    private func item(
        _ title: String,
        _ action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        return item
    }

    private func label(_ title: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: NSFont.systemFont(ofSize: 11)]
        )
        return item
    }
}
