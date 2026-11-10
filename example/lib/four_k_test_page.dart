import 'package:flutter/material.dart';
import 'package:v_video_compressor/v_video_compressor.dart';
import 'package:image_picker/image_picker.dart';

class FourKTestPage extends StatefulWidget {
  const FourKTestPage({super.key});

  @override
  State<FourKTestPage> createState() => _FourKTestPageState();
}

class _FourKTestPageState extends State<FourKTestPage> {
  final VVideoCompressor _compressor = VVideoCompressor();

  String? _selectedVideoPath;
  VVideoInfo? _videoInfo;
  double _compressionProgress = 0.0;
  bool _isCompressing = false;
  VVideoCompressionResult? _result;
  String _logOutput = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('4K Compression Test'),
        backgroundColor: Colors.red.shade100,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              color: Colors.orange,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '4K Compression Test',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This page tests the 4K compression fixes. Select a 4K video (3840x2160 or higher) to test the enhanced compression logic.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Video Selection
            ElevatedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library),
              label: const Text('Pick 4K Video for Testing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            if (_videoInfo != null) ...[
              // Video Info Card
              Card(
                color: _is4KVideo() ? Colors.red.shade50 : Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _is4KVideo() ? Icons.warning : Icons.check_circle,
                            color: _is4KVideo() ? Colors.red : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _is4KVideo()
                                ? '4K Video Detected'
                                : 'Standard Video',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _is4KVideo() ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Resolution: ${_videoInfo!.width}x${_videoInfo!.height}',
                      ),
                      Text('Duration: ${_videoInfo!.durationFormatted}'),
                      Text('Size: ${_videoInfo!.fileSizeFormatted}'),
                      if (_is4KVideo()) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'This is a 4K video. The plugin will automatically apply 4K-specific optimizations.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedVideoPath != null) ...[
              // 4K-Specific Compression Options
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '4K-Optimized Compression Tests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'These tests use 4K-specific optimizations:',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      // Conservative Test (Recommended for Galaxy A40)
                      ElevatedButton(
                        onPressed: () => _testConservative4K(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Conservative 4K (Recommended)'),
                      ),
                      const Text(
                        'MEDIUM quality, H.264 codec, 3.2 Mbps bitrate',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),

                      // Balanced Test
                      ElevatedButton(
                        onPressed: () => _testBalanced4K(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Balanced 4K'),
                      ),
                      const Text(
                        'HIGH quality with automatic device capability detection',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),

                      // Custom Test
                      ElevatedButton(
                        onPressed: () => _testCustom4K(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Custom 4K Settings'),
                      ),
                      const Text(
                        'H.265 codec with custom bitrate (may fail on some devices)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_isCompressing) ...[
              // Progress
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Compressing 4K Video...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _compressionProgress),
                      Text('${(_compressionProgress * 100).toInt()}%'),
                      const SizedBox(height: 8),
                      const Text(
                        'Watch the console for "4K FIX" messages to see what optimizations are being applied.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _cancelCompression,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_result != null) ...[
              // Result
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            '4K Compression Successful!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Original Size: ${_result!.originalSizeFormatted}'),
                      Text(
                        'Compressed Size: ${_result!.compressedSizeFormatted}',
                      ),
                      Text(
                        'Saved: ${_result!.spaceSavedFormatted} (${_result!.compressionPercentage}%)',
                      ),
                      Text('Time: ${_result!.timeTakenFormatted}'),
                      Text('Quality: ${_result!.quality.displayName}'),
                      const SizedBox(height: 8),
                      const Text(
                        'Success! The 4K compression fixes are working correctly.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Log Output
            if (_logOutput.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Debug Log',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 200,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            _logOutput,
                            style: const TextStyle(
                              color: Colors.green,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _is4KVideo() {
    return _videoInfo != null &&
        (_videoInfo!.width >= 3840 || _videoInfo!.height >= 2160);
  }

  Future<void> _pickVideo() async {
    try {
      final pickedVideo = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
      );
      if (pickedVideo == null) return;

      final path = pickedVideo.path;
      final info = await _compressor.getVideoInfo(path);

      if (info == null) throw Exception('Invalid video');

      setState(() {
        _selectedVideoPath = path;
        _videoInfo = info;
        _result = null;
        _compressionProgress = 0.0;
        _isCompressing = false;
        _logOutput = '';
      });

      _addLog('Video selected: ${info.width}x${info.height}');
      if (_is4KVideo()) {
        _addLog('4K video detected - 4K optimizations will be applied');
      }
    } catch (e) {
      _addLog('Error picking video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error picking video: $e')));
      }
    }
  }

  Future<void> _testConservative4K() async {
    _addLog('Starting Conservative 4K Test...');
    _addLog('Settings: MEDIUM quality, H.264 codec, 3.2 Mbps');

    final config = VVideoCompressionConfig(
      quality: VVideoCompressQuality.medium,
      advanced: VVideoAdvancedConfig(
        videoCodec: VVideoCodec.h264,
        videoBitrate: 3200000, // 3.2 Mbps
        hardwareAcceleration: true,
      ),
    );

    await _compressVideo(config, 'Conservative 4K');
  }

  Future<void> _testBalanced4K() async {
    _addLog('Starting Balanced 4K Test...');
    _addLog('Settings: HIGH quality with automatic device detection');

    final config = VVideoCompressionConfig(
      quality: VVideoCompressQuality.high,
      advanced: VVideoAdvancedConfig(hardwareAcceleration: true),
    );

    await _compressVideo(config, 'Balanced 4K');
  }

  Future<void> _testCustom4K() async {
    _addLog('Starting Custom 4K Test...');
    _addLog('Settings: H.265 codec, custom bitrate (experimental)');

    final config = VVideoCompressionConfig(
      quality: VVideoCompressQuality.medium,
      advanced: VVideoAdvancedConfig(
        videoCodec: VVideoCodec.h265,
        videoBitrate: 4800000, // 4.8 Mbps
        hardwareAcceleration: true,
      ),
    );

    await _compressVideo(config, 'Custom 4K');
  }

  Future<void> _compressVideo(
    VVideoCompressionConfig config,
    String testName,
  ) async {
    if (_selectedVideoPath == null) return;

    setState(() {
      _isCompressing = true;
      _compressionProgress = 0.0;
      _result = null;
    });

    _addLog('$testName compression started...');

    try {
      final result = await _compressor.compressVideo(
        _selectedVideoPath!,
        config,
        onProgress: (progress) {
          setState(() => _compressionProgress = progress);
          if (progress > 0.02 && progress < 0.05) {
            _addLog(
              'Progress: ${(progress * 100).toInt()}% - Past critical 2.7% mark!',
            );
          }
        },
      );

      setState(() {
        _isCompressing = false;
        _result = result;
      });

      if (result != null) {
        _addLog('$testName compression successful!');
        _addLog('Original: ${result.originalSizeFormatted}');
        _addLog('Compressed: ${result.compressedSizeFormatted}');
        _addLog('Saved: ${result.spaceSavedFormatted}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$testName compression successful!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isCompressing = false);
      _addLog('$testName compression failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$testName compression failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelCompression() async {
    await _compressor.cancelCompression();
    setState(() {
      _isCompressing = false;
      _compressionProgress = 0.0;
    });
    _addLog('Compression cancelled');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compression cancelled'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logOutput += '[$timestamp] $message\n';
    });
  }
}
