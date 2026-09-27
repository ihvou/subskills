import ExpoModulesCore

/**
 * Reads what the share extension left in the App Group container.
 *
 * A share extension cannot launch its containing app — Apple allows that only
 * for Today widgets, and since iOS 18 the responder-chain workaround
 * force-returns false. So `ShareViewController` appends the shared URL to
 * `pending_shared_urls` in the group's UserDefaults and completes immediately,
 * and the app collects it the next time it comes to the foreground. Telegram's
 * share extension crosses the same boundary the same way.
 *
 * JavaScript cannot reach a suite-scoped UserDefaults on its own, which is the
 * only reason this module exists. It is deliberately one function.
 */
public class SharedInboxModule: Module {
  // Must match appGroupFor() in plugins/withShareTargets.js and the entitlements
  // written for both targets. A mismatch is silent: the suite simply resolves to
  // nil and every share disappears with no error anywhere.
  private static let appGroup = "group.xyz.subskills.app"
  // Complete requests written by the share sheet form: url, category, skill and
  // the two destination toggles. The app sends them as-is.
  private static let pendingKey = "pending_shared_requests"
  // Bare URLs from the pre-form extension. A build 12/13 user can have one
  // queued at the moment they upgrade, and dropping it would lose a share they
  // already made.
  private static let legacyKey = "pending_shared_urls"

  public func definition() -> ModuleDefinition {
    Name("SharedInbox")

    /**
     * Both functions return everything queued and clear it in the same call.
     *
     * Read-and-clear rather than read-then-clear-later: the caller is JS, and
     * anything that can interleave between two bridge calls eventually will.
     * The cost is that an item is lost if the app dies between the clear and
     * the send — the right trade, because the server dedupes on dedupe_key, so
     * a retry collapses to duplicate:true while a share that silently
     * reappears days later would not.
     */

    /// Complete requests written by the share-sheet form, as JSON strings.
    Function("drainPendingSharedRequests") { () -> [String] in
      guard let defaults = UserDefaults(suiteName: Self.appGroup) else {
        log.warn("SharedInbox: no App Group container for \(Self.appGroup)")
        return []
      }
      let pending = defaults.stringArray(forKey: Self.pendingKey) ?? []
      if !pending.isEmpty { defaults.removeObject(forKey: Self.pendingKey) }
      return pending
    }

    /// Bare URLs left by the pre-form extension, drained once on upgrade.
    Function("drainPendingSharedUrls") { () -> [String] in
      guard let defaults = UserDefaults(suiteName: Self.appGroup) else {
        // Only happens when the entitlement is missing or the group id does not
        // match the one in the portal, which is a build problem, not a runtime
        // one — so say so rather than returning an empty array that reads as
        // "nothing was shared".
        log.warn("SharedInbox: no App Group container for \(Self.appGroup)")
        return []
      }
      let pending = defaults.stringArray(forKey: Self.legacyKey) ?? []
      if !pending.isEmpty {
        defaults.removeObject(forKey: Self.legacyKey)
      }
      return pending
    }
  }
}
