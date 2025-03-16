import Foundation.NSUserDefaults

class UserDefaultsMigration {
  private init() {}

  /// Increment this for new migrations
  private static let currentVersion = 1
  private static let schemaVersionKey = "schemaVersion"

  static func migrateIfNeeded() {
    let storedVersion = UserDefaults.standard.integer(forKey: schemaVersionKey)

    guard storedVersion < currentVersion else {
//      log.info("UserDefaults already at version \(storedVersion). Skipping migration...")
      return
    }

    if storedVersion < 1 {
      migrateFromOldBundleID()
      migrateFromNeedClick()
    }

    UserDefaults.standard.set(currentVersion, forKey: schemaVersionKey)

    log.info("Migrated UserDefaults to version \(currentVersion).")
  }

  private static func migrateFromOldBundleID() {
    let oldBundleID = "com.rouge41.middleClick"

    guard let oldDefaults = UserDefaults(suiteName: oldBundleID) else {
      log.info("No old UserDefaults found.")
      return
    }

    let oldKeys = [
      "NSStatusItem Visible Item-0",
      "fingers",
      "allowMoreFingers",
      "maxDistanceDelta",
      "maxTimeDelta",
      "needClick",
      "ignoredAppBundles",
    ]

    let oldData = oldDefaults.dictionaryRepresentation().filter { oldKeys.contains($0.key) }

    for (key, value) in oldData {
      let isDefined = oldDefaults.value(forKey: key) != nil
      guard isDefined else {
        log.info("Skipping UserDefault: \(key) - not defined.")
        continue
      }
      log.info("Migrating UserDefault: \(key) = \(value)")
      UserDefaults.standard.set(value, forKey: key)
    }

    oldDefaults.removePersistentDomain(forName: oldBundleID)

    log.info("Migrated UserDefaults from old bundle ID.")
  }

  private static func migrateFromNeedClick() {
    let key = "needClick"
    let newKey = "tapToClick"
    let isDefined = UserDefaults.standard.value(forKey: key) != nil
    guard isDefined else {
      log.info("Skipping migration \(key) -> \(newKey) - not defined.")
      return
    }
    let newValue = !UserDefaults.standard.bool(forKey: key)
    log.info("Migrating \(key) = \(!newValue) -> \(newKey) = \(newValue).")
    UserDefaults.standard.set(newValue, forKey: newKey)
  }
}
