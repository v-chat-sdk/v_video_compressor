import 'package:flutter/material.dart';
import 'package:v_video_compressor/v_video_compressor.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gal/gal.dart';

import 'crop_compression_page.dart';
import 'four_k_test_page.dart';

void main() {
  // Configure logging for development
  VVideoCompressor.configureLogging(VVideoLogConfig.development());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'V Video Compressor Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'V Video Compressor Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final VVideoCompressor _compressor = VVideoCompressor();

  String? _selectedVideoPath;
  double _compressionProgress = 0.0;
  bool _isCompressing = false;
  VVideoInfo? _videoInfo;
  VVideoCompressionResult? _result;
  bool _saveToGallery = false;
  String? _thumbnailPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FourKTestPage()),
              );
            },
            icon: const Icon(Icons.science),
            tooltip: '4K Compression Test',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'V Video Compressor Example',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'For 4K video compression testing, tap the test tube icon above.',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FourKTestPage(),
                          ),
                        );
                      },
                      child: const Text('4K Test'),
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
              label: const Text('Pick Video from Gallery'),
            ),
            const SizedBox(height: 16),

            if (_videoInfo != null) ...[
              // Video Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Video Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('Path: $_selectedVideoPath'),
                      Text('Duration: ${_videoInfo!.durationFormatted}'),
                      Text('Size: ${_videoInfo!.fileSizeFormatted}'),
                      Text(
                        'Resolution: ${_videoInfo!.width}x${_videoInfo!.height}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedVideoPath != null) ...[
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.crop,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Crop export example',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose normalized coordinates, trim times, and a '
                        'rotation, then export everything in one native pass.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('openCropExampleButton'),
                        onPressed: _videoInfo == null ? null : _openCropExample,
                        icon: const Icon(Icons.crop_rotate),
                        label: const Text('Crop, trim & rotate'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Compression Options
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Compress Video',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: VVideoCompressQuality.values.map((quality) {
                          return ElevatedButton(
                            onPressed: () => _compressVideo(quality),
                            child: Text(quality.name.toUpperCase()),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Save to Gallery after Compression'),
                        value: _saveToGallery,
                        onChanged: (value) =>
                            setState(() => _saveToGallery = value),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Thumbnail Generation
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Generate Thumbnail',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _generateThumbnail,
                        child: const Text('Generate Thumbnail at 5s'),
                      ),
                      if (_thumbnailPath != null) ...[
                        const SizedBox(height: 8),
                        Text('Thumbnail saved at: $_thumbnailPath'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _saveThumbnailToGallery,
                          child: const Text('Save Thumbnail to Gallery'),
                        ),
                      ],
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
                        'Compressing...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      LinearProgressIndicator(value: _compressionProgress),
                      Text('${(_compressionProgress * 100).toInt()}%'),
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
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Compression Result',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('Original Size: ${_result!.originalSizeFormatted}'),
                      Text(
                        'Compressed Size: ${_result!.compressedSizeFormatted}',
                      ),
                      Text(
                        'Saved: ${_result!.spaceSavedFormatted} (${_result!.compressionPercentage}%)',
                      ),
                      Text('Time: ${_result!.timeTakenFormatted}'),
                      Text('Path: ${_result!.compressedFilePath}'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _saveCompressedToGallery(
                          _result!.compressedFilePath,
                        ),
                        child: const Text('Save Compressed Video to Gallery'),
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
        _thumbnailPath = null;
        _compressionProgress = 0.0;
        _isCompressing = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error picking video: $e')));
      }
    }
  }

  Future<void> _compressVideo(VVideoCompressQuality quality) async {
    await _compressWithConfig(VVideoCompressionConfig(quality: quality));
  }

  void _openCropExample() {
    final videoPath = _selectedVideoPath;
    final videoInfo = _videoInfo;
    if (videoPath == null || videoInfo == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CropCompressionPage(
          videoPath: videoPath,
          videoInfo: videoInfo,
          onCompress: _compressWithConfig,
        ),
      ),
    );
  }

  Future<void> _compressWithConfig(VVideoCompressionConfig config) async {
    if (_selectedVideoPath == null) return;

    setState(() {
      _isCompressing = true;
      _compressionProgress = 0.0;
      _result = null;
    });

    try {
      final result = await _compressor.compressVideo(
        _selectedVideoPath!,
        config,
        onProgress: (progress) =>
            setState(() => _compressionProgress = progress),
      );

      setState(() {
        _isCompressing = false;
        _result = result;
      });

      if (result != null) {
        if (_saveToGallery) {
          await _saveCompressedToGallery(result.compressedFilePath);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Compression successful!')),
          );
        }
      }
    } catch (e) {
      setState(() => _isCompressing = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Compression failed: $e')));
      }
    }
  }

  Future<void> _generateThumbnail() async {
    if (_selectedVideoPath == null) return;

    try {
      final config = VVideoThumbnailConfig(
        timeMs: 5000,
        maxWidth: 300,
        maxHeight: 200,
        format: VThumbnailFormat.jpeg,
        quality: 85,
      );

      final thumbnail = await _compressor.getVideoThumbnail(
        _selectedVideoPath!,
        config,
      );

      setState(() {
        _thumbnailPath = thumbnail?.thumbnailPath;
      });

      if (thumbnail != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Thumbnail generated!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Thumbnail failed: $e')));
      }
    }
  }

  Future<void> _saveThumbnailToGallery() async {
    if (_thumbnailPath == null) return;

    try {
      await Gal.putImage(_thumbnailPath!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thumbnail saved to gallery!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save thumbnail: $e')));
      }
    }
  }

  Future<void> _saveCompressedToGallery(String path) async {
    try {
      await Gal.putVideo(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compressed video saved to gallery!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save video: $e')));
      }
    }
  }

  Future<void> _cancelCompression() async {
    await _compressor.cancelCompression();
    setState(() {
      _isCompressing = false;
      _compressionProgress = 0.0;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compression cancelled'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
