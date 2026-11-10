import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:v_video_compressor/v_video_compressor.dart';
import 'package:video_trimmer/video_trimmer.dart';

import 'crop_preview_painter.dart';

class CropCompressionPage extends StatefulWidget {
  const CropCompressionPage({
    super.key,
    required this.videoPath,
    required this.videoInfo,
    required this.onCompress,
  });

  final String videoPath;
  final VVideoInfo videoInfo;
  final ValueChanged<VVideoCompressionConfig> onCompress;

  @override
  State<CropCompressionPage> createState() => _CropCompressionPageState();
}

class _CropCompressionPageState extends State<CropCompressionPage> {
  final _leftController = TextEditingController(text: '0.0');
  final _topController = TextEditingController(text: '0.0');
  final _rightController = TextEditingController(text: '1.0');
  final _bottomController = TextEditingController(text: '1.0');
  final Trimmer _trimmer = Trimmer();

  VVideoCompressQuality _quality = VVideoCompressQuality.medium;
  int _rotation = 0;
  bool _includeAudio = true;
  bool _videoLoaded = false;
  bool _isPlaying = false;
  late double _sourceDurationMs;
  late double _trimStartMs;
  late double _trimEndMs;
  String? _videoLoadError;
  String? _validationError;

  VVideoCropRect? get _cropRect {
    final left = double.tryParse(_leftController.text);
    final top = double.tryParse(_topController.text);
    final right = double.tryParse(_rightController.text);
    final bottom = double.tryParse(_bottomController.text);
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    return VVideoCropRect(left: left, top: top, right: right, bottom: bottom);
  }

  @override
  void initState() {
    super.initState();
    _sourceDurationMs = widget.videoInfo.durationMillis.toDouble();
    _trimStartMs = 0;
    _trimEndMs = _sourceDurationMs;
    _loadVideo();
  }

  @override
  void dispose() {
    _leftController.dispose();
    _topController.dispose();
    _rightController.dispose();
    _bottomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cropRect = _cropRect;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop, trim & rotate'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIntroCard(),
          const SizedBox(height: 16),
          _buildTrimmerCard(cropRect),
          const SizedBox(height: 16),
          _buildCropControls(),
          const SizedBox(height: 16),
          _buildEditControls(),
          if (_validationError != null) ...[
            const SizedBox(height: 16),
            _buildValidationError(),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('exportCropButton'),
            onPressed: _export,
            icon: const Icon(Icons.crop),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Export crop'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTrimmerCard(VVideoCropRect? cropRect) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Interactive trim',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${_formatTime(_trimStartMs)} – ${_formatTime(_trimEndMs)}',
                  key: const Key('trimSelectionLabel'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_videoLoadError != null)
              Text(
                _videoLoadError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (!_videoLoaded)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              _buildSynchronizedPreview(cropRect),
              const SizedBox(height: 16),
              TrimViewer(
                trimmer: _trimmer,
                viewerHeight: 64,
                viewerWidth: MediaQuery.sizeOf(context).width - 64,
                maxVideoLength: Duration(
                  milliseconds: _sourceDurationMs.round(),
                ),
                onChangeStart: (value) {
                  setState(() {
                    _trimStartMs = value;
                    _validationError = null;
                  });
                },
                onChangeEnd: (value) {
                  setState(() {
                    _trimEndMs = value;
                    _validationError = null;
                  });
                },
                onChangePlaybackState: (value) {
                  setState(() => _isPlaying = value);
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: IconButton.filledTonal(
                  key: const Key('trimPlaybackButton'),
                  tooltip: _isPlaying ? 'Pause selection' : 'Play selection',
                  onPressed: _togglePlayback,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _cropDescription(cropRect),
              key: const Key('cropPreviewDescription'),
            ),
            const SizedBox(height: 8),
            const Text(
              'The video, crop overlay, playback range, and timeline stay '
              'synchronized through video_trimmer. The example does not call '
              'saveTrimmedVideo; it sends the selected milliseconds and crop '
              'coordinates to v_video_compressor for one final export.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Normalized displayed-frame coordinates',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a rectangle from 0.0 to 1.0. Source orientation is '
              'applied first, then rotation, crop, sizing, and encoding run '
              'together in one native export.',
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.videoInfo.width} × ${widget.videoInfo.height}  •  '
              '${widget.videoInfo.durationFormatted}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSynchronizedPreview(VVideoCropRect? cropRect) {
    final validRect = cropRect?.isValid() == true
        ? cropRect!
        : const VVideoCropRect(left: 0, top: 0, right: 1, bottom: 1);
    final controllerAspectRatio =
        _trimmer.videoPlayerController?.value.aspectRatio;
    final fallbackAspectRatio =
        widget.videoInfo.width > 0 && widget.videoInfo.height > 0
        ? widget.videoInfo.width / widget.videoInfo.height
        : 16 / 9;
    final sourceAspectRatio =
        controllerAspectRatio != null && controllerAspectRatio.isFinite
        ? controllerAspectRatio
        : fallbackAspectRatio;
    final rotated = _rotation == 90 || _rotation == 270;
    final orientedAspectRatio = rotated
        ? 1 / sourceAspectRatio
        : sourceAspectRatio;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: AspectRatio(
          aspectRatio: orientedAspectRatio,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                RotatedBox(
                  key: const Key('rotatedTrimmerPreview'),
                  quarterTurns: _rotation ~/ 90,
                  child: VideoViewer(trimmer: _trimmer),
                ),
                IgnorePointer(
                  child: CustomPaint(
                    key: const Key('cropPreview'),
                    painter: CropPreviewPainter(
                      cropRect: validRect,
                      colorScheme: Theme.of(context).colorScheme,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _cropDescription(VVideoCropRect? cropRect) {
    if (cropRect == null || !cropRect.isValid()) {
      return 'Enter a valid crop rectangle to update the video overlay.';
    }
    if (cropRect.isFullFrame()) {
      return 'Full frame — crop is a no-op';
    }
    return 'Selected ${(cropRect.right - cropRect.left) * 100 ~/ 1}% '
        '× ${(cropRect.bottom - cropRect.top) * 100 ~/ 1}% '
        'of the rotated video preview';
  }

  Widget _buildCropControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Crop rectangle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _presetButton('Full', 0, 0, 1, 1),
                _presetButton('Top left', 0, 0, 0.5, 0.5),
                _presetButton('Top right', 0.5, 0, 1, 0.5),
                _presetButton('Bottom left', 0, 0.5, 0.5, 1),
                _presetButton('Bottom right', 0.5, 0.5, 1, 1),
                _presetButton('Center', 0.25, 0.25, 0.75, 0.75),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _coordinateField(
                    key: const Key('cropLeftField'),
                    label: 'Left',
                    controller: _leftController,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _coordinateField(
                    key: const Key('cropTopField'),
                    label: 'Top',
                    controller: _topController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _coordinateField(
                    key: const Key('cropRightField'),
                    label: 'Right',
                    controller: _rightController,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _coordinateField(
                    key: const Key('cropBottomField'),
                    label: 'Bottom',
                    controller: _bottomController,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export settings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<VVideoCompressQuality>(
              initialValue: _quality,
              decoration: const InputDecoration(
                labelText: 'Quality',
                border: OutlineInputBorder(),
              ),
              items: VVideoCompressQuality.values
                  .map(
                    (quality) => DropdownMenuItem(
                      value: quality,
                      child: Text(quality.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _quality = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: const Key('rotationField'),
              initialValue: _rotation,
              decoration: const InputDecoration(
                labelText: 'Rotation',
                border: OutlineInputBorder(),
              ),
              items: const [0, 90, 180, 270]
                  .map(
                    (rotation) => DropdownMenuItem(
                      value: rotation,
                      child: Text('$rotation°'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _rotation = value;
                    _validationError = null;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep audio'),
              subtitle: const Text('Disable to export video-only output'),
              value: _includeAudio,
              onChanged: (value) => setState(() => _includeAudio = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationError() {
    return Material(
      key: const Key('cropValidationError'),
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _validationError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coordinateField({
    required Key key,
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
      decoration: InputDecoration(
        labelText: label,
        hintText: '0.0–1.0',
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() => _validationError = null),
    );
  }

  Widget _presetButton(
    String label,
    double left,
    double top,
    double right,
    double bottom,
  ) {
    return OutlinedButton(
      onPressed: () => _setCrop(left, top, right, bottom),
      child: Text(label),
    );
  }

  void _setCrop(double left, double top, double right, double bottom) {
    setState(() {
      _leftController.text = left.toString();
      _topController.text = top.toString();
      _rightController.text = right.toString();
      _bottomController.text = bottom.toString();
      _validationError = null;
    });
  }

  void _export() {
    final cropRect = _cropRect;
    if (cropRect == null || !cropRect.isValid()) {
      setState(() {
        _validationError =
            'Use finite values satisfying 0 ≤ left < right ≤ 1 and '
            '0 ≤ top < bottom ≤ 1.';
      });
      return;
    }

    final selectedStart = _trimStartMs.round();
    final selectedEnd = _trimEndMs.round();
    if (selectedStart >= selectedEnd) {
      setState(() => _validationError = 'Trim start must be before trim end.');
      return;
    }
    if (selectedEnd > _sourceDurationMs.round() + 1) {
      setState(() {
        _validationError =
            'Trim end exceeds the ${_sourceDurationMs.round()} ms video.';
      });
      return;
    }
    final fullRange =
        selectedStart <= 1 && selectedEnd >= _sourceDurationMs.round() - 1;
    final trimStart = fullRange ? null : selectedStart;
    final trimEnd = fullRange ? null : selectedEnd;

    widget.onCompress(
      VVideoCompressionConfig(
        quality: _quality,
        fallbackToOriginalIfNotSmaller: false,
        includeAudio: _includeAudio,
        advanced: VVideoAdvancedConfig(
          trimStartMs: trimStart,
          trimEndMs: trimEnd,
          rotation: _rotation,
          cropRect: cropRect,
          removeAudio: !_includeAudio,
          videoCodec: VVideoCodec.h264,
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _loadVideo() async {
    try {
      await _trimmer.loadVideo(videoPath: widget.videoPath);
      if (!mounted) return;
      final loadedDuration =
          _trimmer.videoPlayerController?.value.duration.inMilliseconds;
      setState(() {
        if (loadedDuration != null && loadedDuration > 0) {
          _sourceDurationMs = loadedDuration.toDouble();
          _trimStartMs = 0;
          _trimEndMs = _sourceDurationMs;
        }
        _videoLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _videoLoadError = 'Unable to load the trim preview: $error';
      });
    }
  }

  Future<void> _togglePlayback() async {
    final playing = await _trimmer.videoPlaybackControl(
      startValue: _trimStartMs,
      endValue: _trimEndMs,
    );
    if (mounted) setState(() => _isPlaying = playing);
  }

  String _formatTime(double milliseconds) {
    final duration = Duration(milliseconds: milliseconds.round());
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final tenths = duration.inMilliseconds.remainder(1000) ~/ 100;
    return '$minutes:${seconds.toString().padLeft(2, '0')}.$tenths';
  }
}
