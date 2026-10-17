/// Window-class boundaries shared by every screen and widget.
///
/// These used to live in `screens/main_shell.dart` next to the navigation code
/// that happens to consult them, which forced widgets to import a screen for a
/// single constant — the wrong dependency direction, and it made the two look
/// coupled when they are not.
library;

/// Compact/Medium boundary: below this a screen uses compact margins and a
/// single pane; at or above it switches to medium margins and, where
/// applicable, a second pane.
const double kCompactBreakpoint = 600;

/// Expanded boundary: at or above this the shell swaps the bottom
/// [NavigationBar] for a labelled [NavigationRail].
const double kExpandedBreakpoint = 840;