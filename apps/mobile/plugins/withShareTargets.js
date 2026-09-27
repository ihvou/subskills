const {
  AndroidConfig,
  withAndroidManifest,
  withEntitlementsPlist,
  withMainActivity,
  withDangerousMod,
  withXcodeProject,
} = require("@expo/config-plugins");
const fs = require("node:fs");
const path = require("node:path");

const PLUGIN_NAME = "withSubskillsShareTargets";
const SHARE_EXTENSION_NAME = "SubskillsShareExtension";
const SUPPORTED_HOSTS = [
  "youtube.com",
  "www.youtube.com",
  "m.youtube.com",
  "youtu.be",
  "tiktok.com",
  "www.tiktok.com",
  "vm.tiktok.com",
  "instagram.com",
  "www.instagram.com",
];

function hasAction(filter, actionName) {
  return (filter.action ?? []).some((action) => action.$?.["android:name"] === actionName);
}

function hasData(filter, expected) {
  return (filter.data ?? []).some((data) =>
    Object.entries(expected).every(([key, value]) => data.$?.[key] === value),
  );
}

function ensureIntentFilter(activity, filter) {
  activity["intent-filter"] = activity["intent-filter"] ?? [];
  const actionName = filter.action?.[0]?.$?.["android:name"];
  const expectedData = filter.data?.[0]?.$ ?? {};
  const exists = activity["intent-filter"].some((existing) =>
    actionName && hasAction(existing, actionName) && hasData(existing, expectedData),
  );
  if (!exists) activity["intent-filter"].push(filter);
}

function withAndroidShareManifest(config) {
  return withAndroidManifest(config, (modConfig) => {
    const mainActivity = AndroidConfig.Manifest.getMainActivityOrThrow(modConfig.modResults);
    ensureIntentFilter(mainActivity, {
      action: [{ $: { "android:name": "android.intent.action.SEND" } }],
      category: [{ $: { "android:name": "android.intent.category.DEFAULT" } }],
      data: [{ $: { "android:mimeType": "text/plain" } }],
    });
    for (const scheme of ["https", "http"]) {
      for (const host of SUPPORTED_HOSTS) {
        ensureIntentFilter(mainActivity, {
          action: [{ $: { "android:name": "android.intent.action.VIEW" } }],
          category: [
            { $: { "android:name": "android.intent.category.DEFAULT" } },
            { $: { "android:name": "android.intent.category.BROWSABLE" } },
          ],
          data: [{ $: { "android:scheme": scheme, "android:host": host } }],
        });
      }
    }
    return modConfig;
  });
}

function addKotlinImport(contents, importName) {
  if (contents.includes(`import ${importName}`)) return contents;
  const packageMatch = contents.match(/^package .+\n/m);
  if (!packageMatch) return `import ${importName}\n${contents}`;
  return contents.replace(packageMatch[0], `${packageMatch[0]}\nimport ${importName}\n`);
}

function withAndroidShareIntentNormalizer(config) {
  return withMainActivity(config, (modConfig) => {
    if (modConfig.modResults.language !== "kt") return modConfig;
    let contents = modConfig.modResults.contents;
    if (contents.includes("subskills.original_url")) return modConfig;

    contents = addKotlinImport(contents, "android.content.Intent");
    contents = addKotlinImport(contents, "android.net.Uri");
    const insertion = `
  override fun getIntent(): Intent {
    return normalizeSubskillsShareIntent(super.getIntent())
  }

  override fun onNewIntent(intent: Intent) {
    val normalized = normalizeSubskillsShareIntent(intent)
    super.onNewIntent(normalized)
    setIntent(normalized)
  }

  private fun normalizeSubskillsShareIntent(input: Intent): Intent {
    if (input.data?.scheme == "subskills") return input
    val candidate = when (input.action) {
      Intent.ACTION_SEND -> input.getStringExtra(Intent.EXTRA_TEXT)
      Intent.ACTION_VIEW -> input.dataString
      else -> null
    } ?: return input
    val sharedUrl = extractSubskillsShareUrl(candidate) ?: return input
    if (!isSupportedSubskillsShareUrl(sharedUrl)) return input
    return Intent(input).apply {
      action = Intent.ACTION_VIEW
      data = Uri.parse("subskills://suggest?url=" + Uri.encode(sharedUrl))
      putExtra("subskills.original_url", sharedUrl)
    }
  }

  private fun extractSubskillsShareUrl(value: String): String? {
    val match = Regex("https?://[^\\\\s<>\\\"']+").find(value) ?: return null
    return match.value.trimEnd('.', ',', ';', ')', ']', '}')
  }

  private fun isSupportedSubskillsShareUrl(value: String): Boolean {
    val host = Uri.parse(value).host?.removePrefix("www.")?.lowercase() ?: return false
    return host == "youtu.be" ||
      host == "youtube.com" ||
      host.endsWith(".youtube.com") ||
      host == "tiktok.com" ||
      host.endsWith(".tiktok.com") ||
      host == "instagram.com" ||
      host.endsWith(".instagram.com")
  }
`;
    contents = contents.replace(
      /\n  \/\*\*\n   \* Returns the name of the main component registered from JavaScript\./,
      `${insertion}\n  /**\n   * Returns the name of the main component registered from JavaScript.`,
    );
    modConfig.modResults.contents = contents;
    return modConfig;
  });
}


/**
 * The share-sheet form, generated with the build's Supabase config baked in.
 *
 * The extension is a separate process and cannot run the React Native bundle,
 * so this screen is native and is the one place in the project where a piece of
 * the Suggest form exists twice. It is kept deliberately small for that reason:
 * sport, skill, the two destination toggles, and nothing else. Level, public
 * note and fallback title stay in the app, where they can change without this
 * silently falling out of step.
 *
 * EXPO_PUBLIC_* values are not secrets: they are committed in eas.json and ship
 * inside the app bundle already. They are read from the build environment so
 * the extension talks to the same project the app does.
 */
function shareViewControllerSource(appGroup) {
  const supabaseUrl = (process.env.EXPO_PUBLIC_SUPABASE_URL ?? "").replace(/\/+$/, "");
  const anonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? "";
  if (!supabaseUrl || !anonKey) {
    // Failing loudly beats generating an extension that silently cannot load
    // its pickers on a real device.
    throw new Error(
      "withShareTargets: EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY " +
        "must be set when prebuilding; the share extension needs them to fetch sports and skills.",
    );
  }
  // Read from a real .swift file rather than an inline template literal.
  // Embedding Swift in a JS template literal silently ate one level of every
  // backslash: the keypath \.url arrived as .url and the regex "^www\\." as an
  // invalid escape, so the extension only failed at compile time, far from the
  // edit that caused it. A file has no such layer.
  return fs
    .readFileSync(path.join(__dirname, "ShareViewController.swift.template"), "utf8")
    .replace("__SUPABASE_URL__", supabaseUrl)
    .replace("__SUPABASE_ANON_KEY__", anonKey)
    .replace("__APP_GROUP__", appGroup);
}

/** The one channel a share extension and its app genuinely share. */
function appGroupFor(bundleIdentifier) {
  return `group.${bundleIdentifier}`;
}

function writeShareExtensionFiles(iosProjectRoot, bundleIdentifier) {
  const extensionRoot = path.join(iosProjectRoot, SHARE_EXTENSION_NAME);
  const appGroup = appGroupFor(bundleIdentifier);
  fs.mkdirSync(extensionRoot, { recursive: true });

  // The extension cannot launch the app (Apple restricts that to Today widgets,
  // and on iOS 18 the responder-chain workaround force-returns false), so the
  // App Group container is how the shared URL crosses the process boundary.
  // This is the same mechanism Telegram's share extension uses — it reads its
  // account out of `group.<bundleId>` and does the work in-process rather than
  // opening the app.
  fs.writeFileSync(
    path.join(extensionRoot, `${SHARE_EXTENSION_NAME}.entitlements`),
    `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>${appGroupFor(bundleIdentifier)}</string>
  </array>
</dict>
</plist>
`,
  );

  fs.writeFileSync(
    path.join(extensionRoot, `${SHARE_EXTENSION_NAME}-Info.plist`),
    `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>$(DEVELOPMENT_LANGUAGE)</string>
  <key>CFBundleDisplayName</key>
  <string>Subskills</string>
  <key>CFBundleExecutable</key>
  <string>$(EXECUTABLE_NAME)</string>
  <key>CFBundleIdentifier</key>
  <string>${bundleIdentifier}.share</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$(PRODUCT_NAME)</string>
  <key>CFBundlePackageType</key>
  <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
  <key>CFBundleShortVersionString</key>
  <string>$(MARKETING_VERSION)</string>
  <key>CFBundleVersion</key>
  <string>$(CURRENT_PROJECT_VERSION)</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionAttributes</key>
    <dict>
      <key>NSExtensionActivationRule</key>
      <dict>
        <key>NSExtensionActivationSupportsText</key>
        <true/>
        <key>NSExtensionActivationSupportsWebURLWithMaxCount</key>
        <integer>1</integer>
      </dict>
    </dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.share-services</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
  </dict>
</dict>
</plist>
`,
  );
  fs.writeFileSync(
    path.join(extensionRoot, "ShareViewController.swift"),
    shareViewControllerSource(appGroup),

  );
}

function nativeTargetByName(project, name) {
  const section = project.pbxNativeTargetSection();
  return Object.entries(section).find(([, target]) => target?.name === `"${name}"`)?.[0] ?? null;
}

function withIosShareExtensionFiles(config) {
  return withDangerousMod(config, [
    "ios",
    (modConfig) => {
      const bundleIdentifier = modConfig.ios?.bundleIdentifier ?? "xyz.subskills.app";
      writeShareExtensionFiles(modConfig.modRequest.platformProjectRoot, bundleIdentifier);
      return modConfig;
    },
  ]);
}

function withIosShareExtensionTarget(config) {
  return withXcodeProject(config, (modConfig) => {
    const project = modConfig.modResults;
    const bundleIdentifier = modConfig.ios?.bundleIdentifier ?? "xyz.subskills.app";
    const marketingVersion = modConfig.version ?? "1.0";
    // Single source of truth: app.json extra.appleTeamId. Also see
    // extra.eas.build.experimental.ios.appExtensions, which is what tells EAS to
    // provision a profile for this target — without it there are no credentials
    // for the extension's bundle id and the archive cannot be signed.
    const appleTeamId = modConfig.extra?.appleTeamId;
    if (nativeTargetByName(project, SHARE_EXTENSION_NAME)) return modConfig;

    const target = project.addTarget(
      SHARE_EXTENSION_NAME,
      "app_extension",
      SHARE_EXTENSION_NAME,
      `${bundleIdentifier}.share`,
    );
    project.addBuildPhase(
      [`${SHARE_EXTENSION_NAME}/ShareViewController.swift`],
      "PBXSourcesBuildPhase",
      "Sources",
      target.uuid,
    );

    const configs = project.pbxXCBuildConfigurationSection();
    for (const [key, buildConfig] of Object.entries(configs)) {
      if (!buildConfig || key.endsWith("_comment") || buildConfig.isa !== "XCBuildConfiguration") continue;
      const settings = buildConfig.buildSettings ?? {};
      if (settings.PRODUCT_BUNDLE_IDENTIFIER !== `"${bundleIdentifier}.share"`) continue;
      // A literal team, never "$(DEVELOPMENT_TEAM)". That placeholder expands to
      // an empty string on EAS — nothing there defines the variable — and the
      // archive dies with:
      //   error: Signing for "SubskillsShareExtension" requires a development team.
      // EAS reports that as XCODE_RESOURCE_BUNDLE_CODE_SIGNING_ERROR, which is a
      // misclassification: read the raw xcodebuild log, not the error code.
      //
      // Stored with embedded quotes to match PRODUCT_BUNDLE_IDENTIFIER above;
      // pbxproj is a property-list dialect and strips them on read.
      settings.DEVELOPMENT_TEAM = appleTeamId ? `"${appleTeamId}"` : settings.DEVELOPMENT_TEAM;
      settings.CODE_SIGN_ENTITLEMENTS = `"${SHARE_EXTENSION_NAME}/${SHARE_EXTENSION_NAME}.entitlements"`;
      settings.IPHONEOS_DEPLOYMENT_TARGET = settings.IPHONEOS_DEPLOYMENT_TARGET ?? "15.1";
      settings.SWIFT_VERSION = settings.SWIFT_VERSION ?? "5.0";
      settings.APPLICATION_EXTENSION_API_ONLY = "YES";
      settings.MARKETING_VERSION = settings.MARKETING_VERSION ?? marketingVersion;
      settings.CURRENT_PROJECT_VERSION = settings.CURRENT_PROJECT_VERSION ?? "1";
    }

    return modConfig;
  });
}

/**
 * Both sides of the App Group. The extension gets its entitlements file written
 * next to its source; the app needs the same group declared here, because a
 * container only exists where both processes claim it.
 */
function withIosAppGroup(config) {
  return withEntitlementsPlist(config, (modConfig) => {
    const bundleIdentifier = modConfig.ios?.bundleIdentifier ?? "xyz.subskills.app";
    const group = appGroupFor(bundleIdentifier);
    const key = "com.apple.security.application-groups";
    const existing = modConfig.modResults[key];
    const groups = Array.isArray(existing) ? existing : [];
    if (!groups.includes(group)) {
      modConfig.modResults[key] = [...groups, group];
    }
    return modConfig;
  });
}

function withSubskillsShareTargets(config) {
  config = withAndroidShareManifest(config);
  config = withAndroidShareIntentNormalizer(config);
  config = withIosAppGroup(config);
  config = withIosShareExtensionFiles(config);
  config = withIosShareExtensionTarget(config);
  return config;
}

module.exports = withSubskillsShareTargets;
module.exports.default = withSubskillsShareTargets;
module.exports.PLUGIN_NAME = PLUGIN_NAME;
