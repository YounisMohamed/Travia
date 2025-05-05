import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioPlayerState {
  final Duration? position;
  final Duration? duration;
  final ap.PlayerState playerState;

  AudioPlayerState({
    this.position,
    this.duration,
    this.playerState = ap.PlayerState.stopped,
  });

  AudioPlayerState copyWith({
    Duration? position,
    Duration? duration,
    ap.PlayerState? playerState,
  }) {
    return AudioPlayerState(
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playerState: playerState ?? this.playerState,
    );
  }
}

// Provider for the AudioPlayerNotifier
final audioPlayerProvider = StateNotifierProvider.family<AudioPlayerNotifier, AudioPlayerState, String>(
  (ref, source) => AudioPlayerNotifier(source),
);

// Audio player controller that manages the state
class AudioPlayerNotifier extends StateNotifier<AudioPlayerState> {
  final String source;
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer()..setReleaseMode(ap.ReleaseMode.stop);
  late StreamSubscription<void> _playerStateChangedSubscription;
  late StreamSubscription<Duration?> _durationChangedSubscription;
  late StreamSubscription<Duration> _positionChangedSubscription;

  AudioPlayerNotifier(this.source) : super(AudioPlayerState()) {
    _initializePlayer();
  }

  void _initializePlayer() {
    _playerStateChangedSubscription = _audioPlayer.onPlayerComplete.listen((_) async {
      await stop();
    });

    _positionChangedSubscription = _audioPlayer.onPositionChanged.listen(
      (position) => state = state.copyWith(position: position),
    );

    _durationChangedSubscription = _audioPlayer.onDurationChanged.listen(
      (duration) => state = state.copyWith(duration: duration),
    );

    _audioPlayer.onPlayerStateChanged.listen(
      (playerState) => state = state.copyWith(playerState: playerState),
    );

    _audioPlayer.setSource(ap.DeviceFileSource(source));
  }

  Future<void> play() async {
    await _audioPlayer.play(ap.DeviceFileSource(source));
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  @override
  void dispose() {
    _playerStateChangedSubscription.cancel();
    _positionChangedSubscription.cancel();
    _durationChangedSubscription.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

// The actual widget is now a ConsumerWidget
class AudioPlayer extends ConsumerWidget {
  /// Path from where to play recorded audio
  final String source;

  /// Callback when audio file should be removed
  /// Setting this to null hides the delete button
  final VoidCallback onDelete;

  static const double _controlSize = 56;
  static const double _deleteBtnSize = 24;

  const AudioPlayer({
    super.key,
    required this.source,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioState = ref.watch(audioPlayerProvider(source));
    final audioNotifier = ref.read(audioPlayerProvider(source).notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _buildControl(context, audioState, audioNotifier),
                _buildSlider(context, constraints.maxWidth, audioState, audioNotifier),
                IconButton(
                  icon: const Icon(Icons.delete, color: Color(0xFF73748D), size: _deleteBtnSize),
                  onPressed: () async {
                    if (audioState.playerState == ap.PlayerState.playing) {
                      await audioNotifier.stop();
                    }
                    onDelete();
                  },
                ),
              ],
            ),
            Text('${audioState.duration ?? 0.0}'),
          ],
        );
      },
    );
  }

  Widget _buildControl(BuildContext context, AudioPlayerState audioState, AudioPlayerNotifier audioNotifier) {
    Icon icon;
    Color color;

    if (audioState.playerState == ap.PlayerState.playing) {
      icon = const Icon(Icons.pause, color: Colors.red, size: 30);
      color = Colors.red.withOpacity(0.1);
    } else {
      final theme = Theme.of(context);
      icon = Icon(Icons.play_arrow, color: theme.primaryColor, size: 30);
      color = theme.primaryColor.withOpacity(0.1);
    }

    return ClipOval(
      child: Material(
        color: color,
        child: InkWell(
          child: SizedBox(width: _controlSize, height: _controlSize, child: icon),
          onTap: () {
            if (audioState.playerState == ap.PlayerState.playing) {
              audioNotifier.pause();
            } else {
              audioNotifier.play();
            }
          },
        ),
      ),
    );
  }

  Widget _buildSlider(BuildContext context, double widgetWidth, AudioPlayerState audioState, AudioPlayerNotifier audioNotifier) {
    bool canSetValue = false;
    final duration = audioState.duration;
    final position = audioState.position;

    if (duration != null && position != null) {
      canSetValue = position.inMilliseconds > 0;
      canSetValue &= position.inMilliseconds < duration.inMilliseconds;
    }

    double width = widgetWidth - _controlSize - _deleteBtnSize;
    width -= _deleteBtnSize;

    return SizedBox(
      width: width,
      child: Slider(
        activeColor: Theme.of(context).primaryColor,
        inactiveColor: Theme.of(context).colorScheme.secondary,
        onChanged: (v) {
          if (duration != null) {
            final position = v * duration.inMilliseconds;
            audioNotifier.seek(Duration(milliseconds: position.round()));
          }
        },
        value: canSetValue && duration != null && position != null ? position.inMilliseconds / duration.inMilliseconds : 0.0,
      ),
    );
  }
}
