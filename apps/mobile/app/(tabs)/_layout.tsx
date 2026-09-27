import { Tabs } from "expo-router";
import { BookOpen, Compass, UserRound } from "lucide-react-native";
import { colors } from "@/lib/theme";

/**
 * Two-tab root.
 *  Each tab is a route group containing its own Stack so we can push
 *  Category and Skill screens while the tab bar stays visible.
 */

/**
 * Only `(home)` is a route GROUP, so it owns "/". Library and Account are real path
 * segments ("/library", "/account").
 *
 * They used to be groups too — and since groups contribute no path segment, all three
 * index routes resolved to "/", which expo-router settled alphabetically onto
 * `(account)`. That is why the app opened on the Account tab, and why neither
 * `unstable_settings.initialRouteName` nor the `<Tabs initialRouteName>` prop fixed it:
 * the tab was not chosen by initial-route order, it was chosen by path resolution.
 */
export const unstable_settings = {
  initialRouteName: "(home)",
};

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: colors.ink,
        tabBarInactiveTintColor: colors.muted,
        headerShown: false,
        tabBarStyle: {
          borderTopColor: colors.divider,
          backgroundColor: colors.surface,
        },
        tabBarLabelStyle: {
          fontSize: 11,
          fontWeight: "600",
        },
      }}
    >
      <Tabs.Screen
        name="(home)"
        options={{
          title: "Discover",
          tabBarIcon: ({ color, size }) => <Compass color={color} size={size} />,
        }}
      />
      <Tabs.Screen
        name="library"
        options={{
          title: "Library",
          tabBarIcon: ({ color, size }) => <BookOpen color={color} size={size} />,
        }}
      />
      <Tabs.Screen
        name="account"
        options={{
          title: "Account",
          tabBarIcon: ({ color, size }) => <UserRound color={color} size={size} />,
        }}
      />
    </Tabs>
  );
}
