# 番茄钟 M3 重塑 + 设置模块深化 — 设计

2026-09-23 · architecture-review 候选 1 + 用户「太丑了，按 Material Design 3 / 官方布局重做」。

## A. 架构（grilling 已定，直接落实）

1. **深化「设置」为深模块 `SettingsController extends ChangeNotifier`**（新增 `lib/src/settings/settings_controller.dart`）
   - 拥有 `PomodoroSettings` 活值 + 写穿持久化（SharedPreferences 直连，暂不掏 adapter）。
   - 唯一入口 `Future<void> update(PomodoroSettings next)`：更新活值 → notifyListeners → 持久化。
   - `load()` 启动读回。删除 `SettingsStore`（PomodoroSettings 持久化并入 controller；AudioPrefs 迁 audio 域）。
2. **main() 接线，双方互不知晓**
   ```dart
   settingsController.addListener(() => timer.applySettings(settingsController.settings));
   timer.onPhaseChanged = (_) { if (settingsController.settings.soundEnabled) ambientPlayer.playChime(); };
   ```
3. **实现提示音**：`PomodoroTimer` 新增 `onPhaseChanged` seam（与 `onFocusCompleted` 平行），`_switchPhase` 末尾触发（覆盖完成/跳过/自动续接）。
   - `soundEnabled` 从假 seam 变真消费；`alwaysOnScreen` 死字段删除（无 UI 无消费）。
   - 音效：flutter_soloud `loadWaveform(WaveForm.sine, false, scale, 0)` 合成短「叮」，播放后 ~200ms 停止 + disposeSource，无需资源文件。
4. **AudioPrefs 搬进 audio 域**：`AmbientPlayer` 成为深模块，持有 `SharedPreferences? _prefs`，
   `playTrack/stop/toggle/setVolume` 内部写穿；新增 `restore(prefs)` 读回快照。UI 三处「读回拼接快照」胶水全删。

## B. 主题（根治「太丑」）— AppTheme 集中组件化

- 种子保持 `#C62828`（番茄）、secondary `#006A6A`、tertiary `#7D5260` → `ColorScheme.fromSeed`，**零手调 hex**。
- **组件主题**（light + dark 同构）：
  - Card：`surfaceContainerLow`、elevation 0、radius 12（去阴影）
  - Dialog：`surfaceContainerHigh`、elevation 6、radius 28
  - BottomSheet：`surfaceContainerLow`、顶角 28
  - Menu：radius 4；Snackbar：`inverseSurface`、radius 4
  - TextField：顶角 4；Chip：radius 8；FAB：radius 16、elevation 6（静止态）
  - FilledButton / TonalButton / TextButton / IconButton：full 胶囊（IconButton 补 48 命中区）
  - NavigationBar/Rail：surfaceContainer 底、`secondaryContainer` indicator、elevation 0
  - AppBar：surface、elevation 0、scrolledUnderElevation 0
- 排版：启用到 typeScale 角色；强调只用 emphasized 变体；删 `window_title_bar` 的 `w600` 手作字重。

## C. 逐屏布局（canonical）

| 屏 | 改动 |
|---|---|
| 计时 hero | 圆环置于 `surfaceContainerLow` 面板（28 圆角、padding 32）；进度色按阶段映射（focus=primary、shortBreak=tertiary、longBreak=secondary），TimerRing 增加 `progressColor` 参数；倒计时 displayMedium + emphasized；`_LinkedTodoBanner` 改 tonal 容器 |
| 导航 | **断点修复**：<600 底部 NavigationBar；≥600 NavigationRail（Medium 收起/标签 none）；≥840 展开标签（`kRailBreakpoint=600`，`kExpandedBreakpoint=840` 语义保留为「标签展开」） |
| 统计 | `🔥` → `Icons.local_fire_department` + tertiaryContainer 徽章（颜色非唯一通道）；数字 displaySmall/Medium；卡片 tonal（Card 主题统一） |
| 待办 | 卡片 12 圆角（Card 主题统一）；FAB 16；删除背景 errorContainer 已有 |
| 设置 | 改用 SettingsController；分组标题 titleSmall；删 alwaysOnScreen 行 |
| 窗口标题栏 | 删 w600；labelLarge + onSurfaceVariant；命中区 48 |

## D. 测试

- 新增 `test/settings_controller_test.dart`（load 默认值、update 写穿、round-trip）。
- `pomodoro_timer_test.dart`：新增 `onPhaseChanged` 组（完成/跳过/自动续接触发；reset 不触发）。
- `ambient_player_test.dart`：改 AudioPrefs→AmbientPlayer 写穿 API；新增 chime 用例 + restore 用例。
- 更新 `settings_screen_test.dart`、`audio_control_bar_widget_test.dart`、`audio_mini_player_test.dart`、`home_screen_widget_test.dart`（移出 SettingsStore/prefs 提供者）。
- 收尾 `flutter analyze` + `flutter test` 全绿。

## 涉及文件
新增：`lib/src/settings/settings_controller.dart`、`docs/superpowers/specs/2026-09-23-m3-redesign-settings-module-design.md`、对应测试
删除：`lib/src/settings/settings_store.dart`
改：`lib/main.dart`、`pomodoro_settings.dart`、`pomodoro_timer.dart`、`ambient_player.dart`、`app_theme.dart`、`main_shell.dart`、`timer_screen.dart`、`stats_screen.dart`、`settings_screen.dart`、`timer_ring.dart`、`audio_control_bar.dart`、`window_title_bar.dart` + 5 个测试文件