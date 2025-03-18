import Cocoa

class AboutViewController: NSViewController {
  override func loadView() {
    let view = NSView()

    let imageView = NSImageView(image: NSImage(named: BundleInfo.iconName()) ?? NSImage())
    imageView.wantsLayer = true
    imageView.layer?.cornerRadius = 8
    imageView.layer?.masksToBounds = true

    let appNameLabel = NSTextField(labelWithString: BundleInfo.displayName())
    appNameLabel.font = NSFont.boldSystemFont(ofSize: 16)

    let versionLabel = NSTextField(labelWithString: "Version \(BundleInfo.version()) (\(BundleInfo.build()))")
    versionLabel.font = NSFont.systemFont(ofSize: 12)

    let copyrightLabel = NSTextField(labelWithString: BundleInfo.copyright())
    copyrightLabel.font = NSFont.systemFont(ofSize: 12)
    copyrightLabel.lineBreakMode = .byWordWrapping
    copyrightLabel.alignment = .center

    let stackView = NSStackView(views: [imageView, appNameLabel, versionLabel, copyrightLabel])
    stackView.orientation = .vertical
    stackView.alignment = .centerX
    stackView.spacing = 16
    stackView.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

      imageView.widthAnchor.constraint(equalToConstant: 64),
      imageView.heightAnchor.constraint(equalToConstant: 64),

      copyrightLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 200),
    ])

    self.preferredContentSize = NSSize(width: 215, height: 215)
    self.view = view
  }
}

class BundleInfo {
  private static func bundleInfo(_ key: String) -> String {
    return Bundle.main.infoDictionary?[key] as? String ?? "%\(key)%"
  }

  static func iconName() -> String {
    return bundleInfo("CFBundleIconName")
  }

  static func displayName() -> String {
    return bundleInfo("CFBundleName") // TODO: ? why is this not CFBundleDisplayName
  }

  static func version() -> String {
    return bundleInfo("CFBundleShortVersionString")
  }

  static func build() -> String {
    return bundleInfo("CFBundleVersion")
  }

  static func copyright() -> String {
    return bundleInfo("NSHumanReadableCopyright")
  }
}

