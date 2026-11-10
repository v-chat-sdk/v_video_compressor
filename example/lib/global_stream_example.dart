/// Example demonstrating the improved global stream with proper typing
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:v_video_compressor/v_video_compressor.dart';

class GlobalStreamExample extends StatefulWidget {
  const GlobalStreamExample({super.key});

  @override
  State<GlobalStreamExample> createState() => _GlobalStreamExampleState();
}

class _GlobalStreamExampleState extends State<GlobalStreamExample> {
  StreamSubscription<VVideoProgressEvent>? _progressSubscription;
  VVideoProgressEvent? _currentProgress;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _setupGlobalProgressListener();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  /// Setup global progress listener - accessible from anywhere in the app
  void _setupGlobalProgressListener() {
    // Method 1: Listen to the global stream directly
    _progressSubscription = VVideoCompressor.progressStream.listen(
      (event) {
        setState(() {
          _currentProgress = event;
          _status = event.isBatchOperation
              ? 'Batch: ${event.batchProgressDescription}'
              : 'Progress: ${event.progressFormatted}';
        });
      },
      onError: (error) {
        setState(() {
          _status = 'Error: $error';
        });
      },
    );

    // Method 2: Use convenience methods
    // VVideoCompressor.listenToProgress((progress) {
    //   print('Simple progress: ${(progress * 100).toInt()}%');
    // });

    // Method 3: Listen to batch progress only
    // VVideoCompressor.listenToBatchProgress((progress, currentIndex, total) {
    //   print('Batch: Video ${currentIndex + 1}/$total - ${(progress * 100).toInt()}%');
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Global Stream Example')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Global Progress Stream',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Status display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    if (_currentProgress != null) ...[
                      Text('Progress: ${_currentProgress!.progressFormatted}'),
                      if (_currentProgress!.videoPath != null)
                        Text('Video: ${_currentProgress!.videoPath}'),
                      if (_currentProgress!.isBatchOperation)
                        Text(
                          'Batch: ${_currentProgress!.currentIndex! + 1}/${_currentProgress!.total!}',
                        ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Progress indicator
            if (_currentProgress != null)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _currentProgress!.progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _currentProgress!.isBatchOperation
                          ? Colors.blue
                          : Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentProgress!.isBatchOperation
                        ? _currentProgress!.batchProgressDescription
                        : _currentProgress!.progressFormatted,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Code example
            const Text(
              'Code Example:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('''// Listen to global progress from anywhere
VVideoCompressor.progressStream.listen((event) {
  print('Progress: \${event.progressFormatted}');
  if (event.isBatchOperation) {
    print('Batch: \${event.batchProgressDescription}');
  }
});

// Or use convenience methods
VVideoCompressor.listenToProgress((progress) {
  print('Progress: \${(progress * 100).toInt()}%');
});''', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),

            const SizedBox(height: 16),

            // Benefits
            const Text(
              'Benefits:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✅ Fully typed - no more Map checking'),
                Text('✅ Global access - listen from anywhere'),
                Text('✅ Automatic stream management'),
                Text('✅ Convenience methods for different use cases'),
                Text('✅ Batch operation support'),
                Text('✅ Comprehensive progress information'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Example of using the global stream in a service/controller
class VideoCompressionService {
  static StreamSubscription<VVideoProgressEvent>? _subscription;

  /// Start listening to global progress
  static void startListening() {
    _subscription = VVideoCompressor.progressStream.listen((event) {
      // Handle progress updates - service receives progress updates
      // You can emit to other streams, update state management, etc.
    });
  }

  /// Stop listening
  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}

/// Example of using in a state management solution
class VideoCompressionNotifier extends ChangeNotifier {
  StreamSubscription<VVideoProgressEvent>? _subscription;
  VVideoProgressEvent? _currentProgress;

  VVideoProgressEvent? get currentProgress => _currentProgress;

  void startListening() {
    _subscription = VVideoCompressor.progressStream.listen((event) {
      _currentProgress = event;
      notifyListeners(); // Notify UI to rebuild
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
