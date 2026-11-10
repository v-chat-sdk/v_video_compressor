/// Global stream manager for V Video Compressor progress events
library;

import 'dart:async';

import 'package:flutter/services.dart';

import 'v_video_models.dart';
import 'v_video_logger.dart';

/// Global stream manager for video compression progress events
class VVideoStreamManager {
  static VVideoStreamManager? _instance;
  static VVideoStreamManager get instance =>
      _instance ??= VVideoStreamManager._();

  VVideoStreamManager._();

  /// The event channel for progress updates
  static const EventChannel _eventChannel = EventChannel(
    'v_video_compressor/progress',
  );

  /// Global progress stream controller
  static StreamController<VVideoProgressEvent>? _progressController;

  /// Global progress stream subscription
  static StreamSubscription<dynamic>? _progressSubscription;

  /// Global progress stream - accessible from anywhere
  static Stream<VVideoProgressEvent> get progressStream {
    _ensureStreamInitialized();
    return _progressController!.stream;
  }

  /// Initialize the global stream if not already initialized
  static void _ensureStreamInitialized() {
    if (_progressController != null && !_progressController!.isClosed) {
      return; // Already initialized
    }

    VVideoLogger.debug('Initializing global progress stream');

    // Create broadcast stream controller
    _progressController = StreamController<VVideoProgressEvent>.broadcast(
      onListen: _onStreamListen,
      onCancel: _onStreamCancel,
    );
  }

  /// Called when someone starts listening to the progress stream
  static void _onStreamListen() {
    if (_progressSubscription != null) {
      return; // Already listening
    }

    VVideoLogger.debug('Starting progress stream listener');

    _progressSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        try {
          // Since we only have progress events, we can directly parse them
          final progressEvent = VVideoProgressEvent.fromMap(
            Map<String, dynamic>.from(event as Map),
          );

          VVideoLogger.progress(
            'Global Stream',
            progressEvent.progress,
            progressEvent.isBatchOperation
                ? progressEvent.batchProgressDescription
                : progressEvent.videoPath,
          );

          // Emit to global stream
          _progressController?.add(progressEvent);
        } catch (error, stackTrace) {
          VVideoLogger.error('Error parsing progress event', error, stackTrace);

          // Try to extract basic progress as fallback
          if (event is Map && event.containsKey('progress')) {
            final fallbackEvent = VVideoProgressEvent(
              progress: (event['progress'] as num).toDouble(),
            );
            _progressController?.add(fallbackEvent);
          }
        }
      },
      onError: (error, stackTrace) {
        VVideoLogger.error('Progress stream error', error, stackTrace);
        _progressController?.addError(error, stackTrace);
      },
    );
  }

  /// Called when no one is listening to the progress stream
  static void _onStreamCancel() {
    VVideoLogger.debug('Cancelling progress stream listener');
    _progressSubscription?.cancel();
    _progressSubscription = null;
  }

  /// Manually dispose the global stream (usually not needed)
  static void dispose() {
    VVideoLogger.debug('Disposing global progress stream');
    _progressSubscription?.cancel();
    _progressSubscription = null;
    _progressController?.close();
    _progressController = null;
    _instance = null;
  }

  /// Check if the global stream is active
  static bool get isActive =>
      _progressController != null && !_progressController!.isClosed;

  /// Check if someone is listening to the stream
  static bool get hasListeners => _progressController?.hasListener ?? false;

  /// Get the current number of listeners
  static int get listenerCount =>
      _progressController?.hasListener == true ? 1 : 0;

  /// Convenience method to listen to progress with typed callback
  static StreamSubscription<VVideoProgressEvent> listen(
    void Function(VVideoProgressEvent event) onProgress, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return progressStream.listen(
      onProgress,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// Convenience method to listen to progress with simple callback
  static StreamSubscription<VVideoProgressEvent> listenToProgress(
    void Function(double progress) onProgress, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return progressStream.listen(
      (event) => onProgress(event.progress),
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// Convenience method to listen to batch progress
  static StreamSubscription<VVideoProgressEvent> listenToBatchProgress(
    void Function(double progress, int currentIndex, int total) onProgress, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return progressStream
        .where((event) => event.isBatchOperation)
        .listen(
          (event) =>
              onProgress(event.progress, event.currentIndex!, event.total!),
          onError: onError,
          onDone: onDone,
          cancelOnError: cancelOnError,
        );
  }

  /// Get the latest progress event (if any)
  static VVideoProgressEvent? get lastProgressEvent {
    // Since this is a broadcast stream, we can't get the last event directly
    // This would require maintaining state, which we'll skip for simplicity
    return null;
  }
}
