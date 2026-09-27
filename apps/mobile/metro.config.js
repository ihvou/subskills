const path = require("path");
const { getDefaultConfig } = require("expo/metro-config");

const projectRoot = __dirname;
const workspaceRoot = path.resolve(projectRoot, "../..");

const config = getDefaultConfig(projectRoot);

config.watchFolders = Array.from(new Set([...(config.watchFolders ?? []), workspaceRoot]));

config.resolver.nodeModulesPaths = [
  path.resolve(projectRoot, "node_modules"),
  path.resolve(workspaceRoot, "node_modules"),
];

// Force every `react` / `react-native` import in the bundle to resolve to the
// SAME on-disk path so we never end up with two React instances in memory.
// Without this, expo-router and other packages with nested node_modules can
// each see their own React copy, which trips "Invalid hook call / useMemo of
// null" at runtime in React 19.
//
// Hierarchical lookup stays on so that peer deps like @react-navigation/native
// (nested inside expo-router) still resolve correctly.
const reactCanonical = path.resolve(projectRoot, "node_modules/react");
const reactNativeCanonical = path.resolve(workspaceRoot, "node_modules/react-native");
// react-native-svg registers NATIVE views (RNSVGCircle, RNSVGPath, …). Two copies
// exist — 15.12.1 here (Expo SDK 54's pin) and 15.15.4 at the root, pulled in by
// lucide-react-native — and expo-doctor has long reported it as an accepted
// duplicate. It was harmless only while nothing imported the package directly:
// lucide's copy was the only one in the bundle. The moment app code imports
// `react-native-svg` itself, BOTH copies load and the app dies at startup with
// "Tried to register two views with the same name RNSVGCircle". Pin it here.
const reactNativeSvgCanonical = path.resolve(projectRoot, "node_modules/react-native-svg");
const singletonModules = new Map([
  ["react", reactCanonical],
  ["react-native", reactNativeCanonical],
  ["react-native-svg", reactNativeSvgCanonical],
]);

// Entry point per package: react/react-native resolve via index.js, but
// react-native-svg's main is lib/commonjs/index.js, so read it rather than assume.
function packageEntry(dir) {
  const pkg = require(path.join(dir, "package.json"));
  return path.resolve(dir, pkg["react-native"] || pkg.main || "index.js");
}

const previousResolveRequest = config.resolver.resolveRequest;
config.resolver.resolveRequest = (context, moduleName, platform) => {
  for (const [pkg, dir] of singletonModules) {
    if (moduleName === pkg) {
      return { type: "sourceFile", filePath: packageEntry(dir) };
    }
    if (moduleName.startsWith(`${pkg}/`)) {
      const sub = moduleName.slice(pkg.length + 1);
      const candidates = [
        path.resolve(dir, sub),
        path.resolve(dir, `${sub}.js`),
        path.resolve(dir, sub, "index.js"),
      ];
      for (const candidate of candidates) {
        try {
          require("fs").accessSync(candidate);
          return { type: "sourceFile", filePath: candidate };
        } catch {
          /* try next candidate */
        }
      }
    }
  }
  if (previousResolveRequest) return previousResolveRequest(context, moduleName, platform);
  return context.resolveRequest(context, moduleName, platform);
};

module.exports = config;
