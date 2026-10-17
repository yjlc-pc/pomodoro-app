import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../audio/ambient_player.dart';
import '../layout/breakpoints.dart';

/// A play/pause toggle + current track label, rendered as a compact capsule
/// that fits in an [AppBar.action]. Tapping the capsule opens a popup menu
/// ([AudioPanelOverlay]) with the full track/volume controls.
class AudioMiniPlayer extends StatelessWidget {
  const AudioMiniPlayer({super.key});

  Future<void> _openPanel(BuildContext context) async {
    // A real modal rather than a menu. The panel holds a Slider and ChoiceChips,
    // which is more than a menu item can carry: the old implementation forced
    // it into `PopupMenuItem(enabled: false, height: 220)` positioned at a
    // hard-coded offset, which clipped on small windows and swallowed the
    // slider's drag gesture on some platforms.
    final isWide = MediaQuery.sizeOf(context).width >= kExpandedBreakpoint;
    if (isWide) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('背景音'),
          content: const SizedBox(width: 360, child: AudioPanelOverlay()),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: AudioPanelOverlay(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AmbientPlayer>();
    final scheme = Theme.of(context).colorScheme;

    if (!player.available) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Tooltip(
          message: '调控背景音',
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openPanel(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    player.track == null
                        ? Icons.graphic_eq
                        : Icons.music_note,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  if (player.track != null)
                    Text(
                      player.track!.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Popup menu content with the full ambient controls: current track label,
/// a play/pause + stop action, volume slider and track chips.
class AudioPanelOverlay extends StatelessWidget {
  const AudioPanelOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AmbientPlayer>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: player.playing ? '暂停' : '播放',
              icon: Icon(
                player.playing ? Icons.pause : Icons.play_arrow,
              ),
              onPressed: player.track == null ? null : () => _toggle(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                player.track?.label ?? '选择背景音',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: player.track == null
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : null,
                    ),
              ),
            ),
            IconButton(
              tooltip: '停止',
              icon: const Icon(Icons.stop),
              onPressed: player.track == null ? null : () => _stop(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.volume_down, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Slider(
                value: player.volume,
                onChanged: (v) => _setVolume(context, v),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.volume_up, size: 20),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final track in AmbientTrack.values)
              ChoiceChip(
                label: Text(track.label),
                selected: player.track == track,
                onSelected: (_) => _selectTrack(context, track),
              ),
          ],
        ),
      ],
    );
  }

  void _toggle(BuildContext context) {
    context.read<AmbientPlayer>().toggle();
  }

  Future<void> _selectTrack(BuildContext context, AmbientTrack track) {
    return context.read<AmbientPlayer>().playTrack(track);
  }

  Future<void> _stop(BuildContext context) {
    return context.read<AmbientPlayer>().stop();
  }

  Future<void> _setVolume(BuildContext context, double v) {
    return context.read<AmbientPlayer>().setVolume(v);
  }
}

class AudioControlBar extends StatelessWidget {
  const AudioControlBar({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<AmbientPlayer>();

    if (!player.available) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.music_off_outlined),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  player.lastError ?? '音频不可用',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AudioPanelOverlay(),
      ),
    );
  }
}
