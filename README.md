# 番茄钟 (Pomodoro App)

一个使用 **Flutter** 构建、严格遵循 **Material Design 3 (M3)** 规范的番茄钟应用。

## 功能

- 专注 / 短休息 / 长休息三阶段循环，每 N 个专注后进入长休息（默认 4 个）
- 圆形进度环倒计时，实时显示剩余时间与阶段
- 开始 / 暂停 / 重置 / 跳过控制，会话进度圆点
- 自动开始休息 / 自动开始专注选项
- 时长、节奏等设置持久化（shared_preferences）
- **待办列表**：独立待办页增删 / 勾选待办，持久化（shared_preferences）
- **任务驱动计时**：开始专注前可选择关联一个待办，专注时显示「正在专注：〈待办〉」
- **统计洞察**：持久化每次自然完成的专注，每日柱状图 + 连续天数 streak + 周/月汇总与上一周期对比（保留最近 90 天自动清理）
- **三页导航**：计时 / 待办 / 统计；窄屏底部 NavigationBar、宽屏（≥840）左侧 NavigationRail，
  全局浮动胶囊在专注运行时叠加显示剩余时间，点击跳回计时页
- **背景白噪音**：内置雨声 / 白噪音 / 氛围三首循环音频（[flutter_soloud](https://pub.dev/packages/flutter_soloud)，
  **全平台含 Linux/macOS/Windows 桌面**），支持播放/暂停/停止、音量调节，偏好持久化
- **响应式布局**：待办窄屏列表 / 桌面宽屏多列密集网格，充分利用窗口宽度
- 深浅色主题自动跟随系统

## Material 3 规范落实

- **颜色**：全部来自 \`ColorScheme.fromSeed()\`（番茄红种子色），无硬编码颜色；
  光/暗两套主题均由种子色派生
- **排版**：完整声明 M3 15 级 type scale（\`AppTheme.typeScale\`），
  组件只通过 \`Theme.of(context).textTheme.<role>\` 取用并搭配颜色角色，
  禁止裸写 \`TextStyle(fontSize: ...)\`
- **组件**：\`FilledButton\`、\`SwitchListTile\`、\`NavigationBar\` 等 M3 组件，
  卡片用容器色调（\`surfaceContainerLow\`）分层而非阴影
- **CJK**：中文界面由平台系统字体（Noto Sans CJK / PingFang SC）渲染，
  无逐组件 fontFamilyFallback hack

## 目录结构

\`\`\`
lib/
  main.dart                     # 入口，Provider 装配
  src/
    theme/app_theme.dart        # M3 主题：ColorScheme + 15 级 type scale + 组件主题
    timer/pomodoro_timer.dart   # 核心计时引擎（状态机 + ChangeNotifier）
    timer/pomodoro_settings.dart# 设置模型
    settings/settings_store.dart# 设置持久化（shared_preferences）
    models/todo_item.dart       # 待办数据模型
    models/todo_store.dart      # 待办状态（ChangeNotifier + shared_preferences）
    models/focus_stats_store.dart # 专注统计（按日预聚合 + 90 天清理 + streak/周/月推导）
    audio/ambient_player.dart   # 白噪音播放器（flutter_soloud 封装 + 状态机）
    screens/main_shell.dart     # 三页导航壳（IndexedStack + NavigationBar/NavigationRail）
    screens/timer_screen.dart   # 计时页：进度环 + 控制 + 会话圆点 + 音频
    screens/todo_screen.dart    # 待办页：列表/网格 + 新增 FAB
    screens/stats_screen.dart   # 统计页：streak + 柱状图 + 周/月汇总
    screens/settings_screen.dart# 设置界面（从 AppBar 推入）
    widgets/timer_ring.dart     # 圆形进度环
    widgets/audio_control_bar.dart # 音频控制条（曲目 / 播放 / 音量）
    widgets/todo_panel.dart     # 待办 sliver（窄屏列表 / 宽屏网格）
    widgets/todo_tile.dart      # 待办条目（ListTile / Card 双形态 + 滑动删除）
    widgets/active_timer_capsule.dart # 全局浮动胶囊（运行时显示剩余时间）
    widgets/start_todo_sheet.dart     # 开始前待办选择 bottom sheet
    widgets/focus_chart.dart    # fl_chart 每日柱状图
    widgets/stats_summary.dart  # 周/月汇总卡片与对比
assets/
  audio/                        # 内置循环白噪音（rain / focus / lofi）
test/
  pomodoro_timer_test.dart      # 计时引擎单元测试（含 onFocusCompleted）
  theme_test.dart               # M3 type scale / 配色规范测试
  home_screen_widget_test.dart  # 计时页组件测试（拆分迁移自原首页测试）
  todo_store_test.dart          # 待办状态 / 持久化单元测试
  todo_widget_test.dart         # 待办页交互与响应式布局组件测试
  focus_stats_store_test.dart   # 统计持久化 / 90 天清理 / streak / 周月对比
  start_todo_sheet_test.dart    # 开始前待办选择弹层测试
  active_timer_capsule_test.dart# 全局浮动胶囊测试
  ambient_player_test.dart      # 播放器状态机 + 音频偏好持久化测试
  audio_control_bar_widget_test.dart # 音频控制条组件测试
\`\`\`

## 运行

\`\`\`bash
flutter pub get
flutter run        # 连接设备/模拟器
flutter test       # 运行测试
flutter analyze    # 静态分析
\`\`\`

> 注意：若系统 \`\$HOME\` 为只读挂载导致 flutter 遥测写入报错，
> 可执行 \`flutter config --no-analytics\` 或设置
> \`export HOME=<可写目录>\` 后运行。
