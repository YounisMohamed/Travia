import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import 'audio_recorder_io.dart';

// State class to hold all relevant recorder state
class RecorderState {
  final int recordDuration;
  final RecordState recordState;
  final Amplitude? amplitude;

  RecorderState({
    this.recordDuration = 0,
    this.recordState = RecordState.stop,
    this.amplitude,
  });

  RecorderState copyWith({
    int? recordDuration,
    RecordState? recordState,
    Amplitude? amplitude,
  }) {
    return RecorderState(
      recordDuration: recordDuration ?? this.recordDuration,
      recordState: recordState ?? this.recordState,
      amplitude: amplitude ?? this.amplitude,
    );
  }
}

// Provider for the recorder
final recorderProvider = StateNotifierProvider<RecorderNotifier, RecorderState>(
  (ref) => RecorderNotifier(),
);

// Recorder controller that manages the state
class RecorderNotifier extends StateNotifier<RecorderState> with AudioRecorderMixin {
  RecorderNotifier() : super(RecorderState()) {
    _initialize();
  }

  Timer? _timer;
  late final AudioRecorder _audioRecorder;
  StreamSubscription<RecordState>? _recordSub;
  StreamSubscription<Amplitude>? _amplitudeSub;

  void _initialize() {
    _audioRecorder = AudioRecorder();

    _recordSub = _audioRecorder.onStateChanged().listen((recordState) {
      _updateRecordState(recordState);
    });

    _amplitudeSub = _audioRecorder.onAmplitudeChanged(const Duration(milliseconds: 300)).listen((amp) {
      state = state.copyWith(amplitude: amp);
    });
  }

  Future<void> start() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        const encoder = AudioEncoder.aacLc;

        if (!await _isEncoderSupported(encoder)) {
          return;
        }

        final devs = await _audioRecorder.listInputDevices();
        debugPrint(devs.toString());

        const config = RecordConfig(encoder: encoder, numChannels: 1);

        // Record to file
        await recordFile(_audioRecorder, config);

        // Reset duration and start timer
        state = state.copyWith(recordDuration: 0);
        _startTimer();
      }
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<String?> stop() async {
    final path = await _audioRecorder.stop();
    return path;
  }

  Future<void> pause() => _audioRecorder.pause();

  Future<void> resume() => _audioRecorder.resume();

  void _updateRecordState(RecordState recordState) {
    state = state.copyWith(recordState: recordState);

    switch (recordState) {
      case RecordState.pause:
        _timer?.cancel();
        break;
      case RecordState.record:
        _startTimer();
        break;
      case RecordState.stop:
        _timer?.cancel();
        state = state.copyWith(recordDuration: 0);
        break;
    }
  }

  Future<bool> _isEncoderSupported(AudioEncoder encoder) async {
    final isSupported = await _audioRecorder.isEncoderSupported(encoder);

    if (!isSupported) {
      debugPrint('${encoder.name} is not supported on this platform.');
      debugPrint('Supported encoders are:');

      for (final e in AudioEncoder.values) {
        if (await _audioRecorder.isEncoderSupported(e)) {
          debugPrint('- ${e.name}');
        }
      }
    }

    return isSupported;
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      state = state.copyWith(recordDuration: state.recordDuration + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recordSub?.cancel();
    _amplitudeSub?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}

// The ConsumerWidget implementation
class Recorder extends ConsumerWidget {
  final void Function(String path) onStop;

  const Recorder({super.key, required this.onStop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recorderState = ref.watch(recorderProvider);
    final recorderNotifier = ref.read(recorderProvider.notifier);

    return MaterialApp(
      home: Scaffold(
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _buildRecordStopControl(context, recorderState, recorderNotifier),
                const SizedBox(width: 20),
                _buildPauseResumeControl(context, recorderState, recorderNotifier),
                const SizedBox(width: 20),
                _buildTimer(recorderState),
              ],
            ),
            if (recorderState.amplitude != null) ...[
              const SizedBox(height: 40),
              Text('Current: ${recorderState.amplitude?.current ?? 0.0}'),
              Text('Max: ${recorderState.amplitude?.max ?? 0.0}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordStopControl(BuildContext context, RecorderState state, RecorderNotifier notifier) {
    late Icon icon;
    late Color color;

    if (state.recordState != RecordState.stop) {
      icon = const Icon(Icons.stop, color: Colors.red, size: 30);
      color = Colors.red.withOpacity(0.1);
    } else {
      final theme = Theme.of(context);
      icon = Icon(Icons.mic, color: theme.primaryColor, size: 30);
      color = theme.primaryColor.withOpacity(0.1);
    }

    return ClipOval(
      child: Material(
        color: color,
        child: InkWell(
          child: SizedBox(width: 56, height: 56, child: icon),
          onTap: () async {
            if (state.recordState != RecordState.stop) {
              final path = await notifier.stop();
              if (path != null) {
                onStop(path);
              }
            } else {
              notifier.start();
            }
          },
        ),
      ),
    );
  }

  Widget _buildPauseResumeControl(BuildContext context, RecorderState state, RecorderNotifier notifier) {
    if (state.recordState == RecordState.stop) {
      return const SizedBox.shrink();
    }

    late Icon icon;
    late Color color;

    if (state.recordState == RecordState.record) {
      icon = const Icon(Icons.pause, color: Colors.red, size: 30);
      color = Colors.red.withOpacity(0.1);
    } else {
      final theme = Theme.of(context);
      icon = const Icon(Icons.play_arrow, color: Colors.red, size: 30);
      color = theme.primaryColor.withOpacity(0.1);
    }

    return ClipOval(
      child: Material(
        color: color,
        child: InkWell(
          child: SizedBox(width: 56, height: 56, child: icon),
          onTap: () {
            (state.recordState == RecordState.pause) ? notifier.resume() : notifier.pause();
          },
        ),
      ),
    );
  }

  Widget _buildTimer(RecorderState state) {
    final String minutes = _formatNumber(state.recordDuration ~/ 60);
    final String seconds = _formatNumber(state.recordDuration % 60);

    return Text(
      '$minutes : $seconds',
      style: const TextStyle(color: Colors.red),
    );
  }

  String _formatNumber(int number) {
    String numberStr = number.toString();
    if (number < 10) {
      numberStr = '0$numberStr';
    }

    return numberStr;
  }
}
