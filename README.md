# 番茄钟 (Pomodoro App)

一个使用 **Flutter** 构建、严格遵循 **Material Design 3 (M3)** 规范的番茄钟应用。
主目标平台为 Linux 桌面，同时提供 Android / macOS / Windows 脚手架。

## 功能

### 计时

- 专注 / 短休息 / 长休息三阶段循环，每 N 个专注后进入长休息（默认 4 个）
- **消耗式进度环**：从满环随时间排空，与环心倒计时同向；
  阶段重置（自然结束 / 跳过 / 重置）时先排空、停顿一拍再回满
- 进度环按阶段三段分色：专注 `primary`、短休息 `tertiary`、长休息 `secondary`
- 开始 / 暂停 / 重置 / 跳过控制，会话进度圆点
- 自动开始休息 / 自动开始专注选项
- **任务驱动计时**：开始专注前可关联一个待办，专注时显示「正在专注：〈待办〉」
- **阶段切换提示音**：由 SoLoud 振荡器实时合成，无需音频资源文件

### 待办

- **子任务**：每个待办可拆分为若干子项，行内可展开就地勾选，行尾显示「2/3」与进度条
- **优先级**：高 / 普通 / 低三档，以列表行左侧色条 + 文字标签双重呈现（颜色不是唯一通道）
- **详细描述**：详情面板内常驻多行输入，即时写穿
- **详情面板**：自适应内容高度，左上删除（带二次确认）、右上关闭
- **勾选动效**：勾选框先圆形扩散填满、再沿路径描出勾线
- 已完成待办缩小、淡化并折进归档区，不遮挡未完成的事
- 滑动删除（父行展开子任务时禁用，避免嵌套手势冲突）

### 统计与历史

- 持久化每次自然完成的专注，按日预聚合，超过 90 天自动清理
- 连续天数 streak（今天未完成不会中断连续记录）
- 每日柱状图 + 周 / 月汇总与上一周期对比
- 每日 / 每周 / 每月滚动明细
- 空数据时显示占位提示，而非空坐标系或全零卡片

### 其他

- **背景白噪音**：内置雨声 / 白噪音 / 氛围三首循环音频，支持播放 / 暂停 / 停止与音量调节
- **四页导航**：计时 / 待办 / 统计 / 历史；窄屏底部 NavigationBar，宽屏（≥840）左侧 NavigationRail
- 全局浮动胶囊在计时运行时叠加显示剩余时间与迷你进度环，点击跳回计时页
- 响应式布局：窄屏单列列表、宽屏多列网格
- 深浅色主题自动跟随系统

## Material 3 规范落实

- **颜色**：全部来自 `ColorScheme.fromSeed()`（番茄红种子色 + 青 / 玫瑰两个辅色），
  无任何硬编码色值；光 / 暗两套均由种子色派生
- **排版**：完整声明 M3 15 级 type scale（`AppTheme.typeScale`），组件只通过
  `Theme.of(context).textTheme.<role>` 取用，禁止裸写 `TextStyle(fontSize: ...)`
- **文字颜色**：按 M3 颜色角色钉死（display / headline / title / body → `onSurface`，
  label → `onSurfaceVariant`），不依赖环境 `DefaultTextStyle` 继承
- **等宽数字**：全局启用 `tabularFigures`，倒计时跳动时不左右抖动
- **强调**：一律使用 type scale 的 emphasized 变体，无手写字重
- **CJK**：中文界面由平台系统字体（Noto Sans CJK / PingFang SC）渲染，
  无逐组件 fontFamilyFallback hack

## 目录结构

```
lib/
  main.dart                     # 入口：Provider 装配 + 计时/音频接线
  src/
    layout/breakpoints.dart     # 窗口断点常量（kCompact / kExpanded）
    theme/app_theme.dart        # M3 主题：ColorScheme + 15 级 type scale
    format/date_formats.dart    # 中文日期格式化（intl locale 惰性初始化）
    timer/pomodoro_timer.dart   # 计时引擎（状态机 + onPhaseChanged seam）
    timer/pomodoro_settings.dart# 设置值对象（含 == / hashCode）
    settings/settings_controller.dart # 设置深模块，写穿持久化
    models/todo_item.dart       # 待办 / 子任务 / 优先级数据模型
    models/todo_store.dart      # 待办状态（ChangeNotifier + 持久化）
    models/focus_stats_store.dart # 专注统计（按日聚合 + streak/周月推导）
    audio/ambient_player.dart   # 白噪音播放器 + 合成提示音
    screens/main_shell.dart     # 四页导航壳（IndexedStack + 胶囊 + 淡入）
    screens/timer_screen.dart   # 计时页：进度环 + 控制 + 会话圆点
    screens/todo_screen.dart    # 待办页：列表/网格 + 新增 FAB
    screens/stats_screen.dart   # 统计页：streak + 柱状图 + 周月汇总
    screens/history_screen.dart # 历史页：每日/每周/每月滚动明细
    screens/settings_screen.dart# 设置页
    widgets/timer_ring.dart     # 消耗式进度环
    widgets/animated_check.dart # 两段式勾选动效
    widgets/todo_tile.dart      # 待办条目（列表 / 卡片双形态）
    widgets/todo_detail_sheet.dart # 待办详情面板
    widgets/active_timer_capsule.dart # 全局浮动胶囊（含迷你进度环）
    widgets/audio_control_bar.dart # 音频控制条与标准弹层
    widgets/focus_chart.dart    # fl_chart 每日柱状图
    widgets/stats_summary.dart  # 周/月汇总卡片与对比
test/
  golden_shots_test.dart        # 参考截图生成器（存档用，非回归门禁）
  golden_shots_test.dart → shots/  # 4 页 × 3 档宽度 × 明暗 = 24 张
```

## 开发

```bash
flutter pub get
flutter run        # 连接设备/模拟器
flutter test       # 运行测试
flutter analyze    # 静态分析
```

> 注意：若系统 `$HOME` 为只读挂载导致 flutter 遥测写入报错，
> 可执行 `flutter config --no-analytics` 或设置
> `export HOME=<可写目录>` 后运行。

### 参考截图

`test/shots/` 下是用于人工审阅的参考截图，按需重新生成：

```bash
GOLDEN_WRITE=1 flutter test test/golden_shots_test.dart --update-goldens
```

该测试刻意**不含** `matchesGoldenFile` 断言：PNG 光栅化结果随机器而异，
把它做成门禁只会在每次 Flutter 升级时产生大量误报。

> 已知局限：`flutter_tester` 不读系统字体，该测试会显式加载 MaterialIcons、
> 拉丁与中文字体；同时它绘制阴影时**不带模糊**，所有 elevation > 0 的表面
> （Card 1、FAB 6）会显示为硬边黑框。这套图只可信于布局、间距、颜色与排版。

## 打包（Linux / RPM）

```bash
flutter build linux --release
tar czf rpmbuild/SOURCES/pomodoro_app-<version>.tar.gz \
  --transform 's,^\.,pomodoro_app-<version>,' -C build/linux/x64/release/bundle .
rpmbuild --define "_topdir $(pwd)" -ba rpmbuild/SPECS/pomodoro_app.spec
sudo rpm -Uvh --oldpackage --replacepkgs \
  rpmbuild/RPMS/x86_64/pomodoro_app-<version>-1.fc44.x86_64.rpm
```

包内会一并安装 `flutter_soloud` 内置的 FLAC / Ogg / Opus / Vorbis
（它们以带版本号的 soname 链接，宿主系统未必提供），因此无需额外安装编解码包。

## 许可

[MIT](LICENSE)