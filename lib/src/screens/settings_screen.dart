import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../settings/settings_controller.dart';
import '../layout/breakpoints.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Compact margin 16, medium and up margin 24 in a 720dp column.
            final wide = constraints.maxWidth >= kCompactBreakpoint;
            final side = wide ? 24.0 : 16.0;
            final body = ListView(
              padding: EdgeInsets.fromLTRB(side, 8, side, 32),
              children: _buildSections(context),
            );
            if (!wide) return body;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: body,
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    return [
      const _SectionHeader('时长'),
      _DurationSetting(
        title: '专注时长',
        subtitle: '每个专注周期的长度',
        valueKey: 'focus',
        min: 1,
        max: 120,
        unit: ' 分钟',
      ),
      _DurationSetting(
        title: '短休息',
        subtitle: '专注之间的休息',
        valueKey: 'shortBreak',
        min: 1,
        max: 60,
        unit: ' 分钟',
      ),
      _DurationSetting(
        title: '长休息',
        subtitle: '完成一轮后的休息',
        valueKey: 'longBreak',
        min: 5,
        max: 90,
        unit: ' 分钟',
      ),
      const Divider(),
      const _SectionHeader('节奏'),
      _DurationSetting(
        title: '长休息间隔',
        subtitle: '每多少个专注后进入长休息',
        valueKey: 'sessions',
        min: 2,
        max: 8,
        unit: '',
      ),
      _SwitchSetting(
        title: '自动开始休息',
        subtitle: '专注结束后自动开始休息',
        valueKey: 'autoBreaks',
      ),
      _SwitchSetting(
        title: '自动开始专注',
        subtitle: '休息结束后自动开始下一个专注',
        valueKey: 'autoFocus',
      ),
      const Divider(),
      const _SectionHeader('其他'),
      _SwitchSetting(
        title: '提示音',
        subtitle: '阶段切换时播放提示音',
        valueKey: 'sound',
      ),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Indent 16 inside the list padding so the header aligns with the
      // ListTile titles below it.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _DurationSetting extends StatefulWidget {
  const _DurationSetting({
    required this.title,
    required this.subtitle,
    required this.valueKey,
    required this.min,
    required this.max,
    required this.unit,
  });

  final String title;
  final String subtitle;
  final String valueKey;
  final int min;
  final int max;
  final String unit;

  @override
  State<_DurationSetting> createState() => _DurationSettingState();
}

class _DurationSettingState extends State<_DurationSetting> {
  late int _value;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>().settings;
    switch (widget.valueKey) {
      case 'focus':
        _value = settings.focusMinutes;
      case 'shortBreak':
        _value = settings.shortBreakMinutes;
      case 'longBreak':
        _value = settings.longBreakMinutes;
      case 'sessions':
        _value = settings.sessionsBeforeLongBreak;
      default:
        _value = widget.min;
    }
  }

  /// Publishes the slider value to the shared settings, which persists it and
  /// forwards it to the running timer. The page stays open so the user can
  /// keep adjusting.
  void _save() {
    final controller = context.read<SettingsController>();
    final s = controller.settings;
    controller.update(s.copyWith(
      focusMinutes: widget.valueKey == 'focus' ? _value : s.focusMinutes,
      shortBreakMinutes: widget.valueKey == 'shortBreak' ? _value : s.shortBreakMinutes,
      longBreakMinutes: widget.valueKey == 'longBreak' ? _value : s.longBreakMinutes,
      sessionsBeforeLongBreak: widget.valueKey == 'sessions' ? _value : s.sessionsBeforeLongBreak,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(widget.title),
          subtitle: Text(widget.subtitle),
          trailing: Text(
            '$_value${widget.unit}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        Slider(
          value: _value.toDouble(),
          min: widget.min.toDouble(),
          max: widget.max.toDouble(),
          divisions: widget.max - widget.min,
          label: '$_value${widget.unit}',
          onChanged: (v) {
            setState(() => _value = v.round());
            _save();
          },
        ),
      ],
    );
  }
}

class _SwitchSetting extends StatefulWidget {
  const _SwitchSetting({
    required this.title,
    required this.subtitle,
    required this.valueKey,
  });

  final String title;
  final String subtitle;
  final String valueKey;

  @override
  State<_SwitchSetting> createState() => _SwitchSettingState();
}

class _SwitchSettingState extends State<_SwitchSetting> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>().settings;
    switch (widget.valueKey) {
      case 'autoBreaks':
        _value = settings.autoStartBreaks;
      case 'autoFocus':
        _value = settings.autoStartFocus;
      case 'sound':
        _value = settings.soundEnabled;
      default:
        _value = false;
    }
  }

  /// Publishes the toggle to the shared settings, which persists it. The
  /// timer re-reads its own copy through the controller listener.
  void _save() {
    final controller = context.read<SettingsController>();
    final s = controller.settings;
    controller.update(s.copyWith(
      autoStartBreaks: widget.valueKey == 'autoBreaks' ? _value : s.autoStartBreaks,
      autoStartFocus: widget.valueKey == 'autoFocus' ? _value : s.autoStartFocus,
      soundEnabled: widget.valueKey == 'sound' ? _value : s.soundEnabled,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(widget.title),
      subtitle: Text(widget.subtitle),
      value: _value,
      onChanged: (v) {
        setState(() => _value = v);
        _save();
      },
    );
  }
}
