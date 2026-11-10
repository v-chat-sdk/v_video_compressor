import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:v_video_compressor/v_video_compressor.dart';

class AdvancedCompressionPage extends StatefulWidget {
  final String videoPath;
  final VVideoInfo videoInfo;
  final Function(VVideoCompressionConfig) onCompress;

  const AdvancedCompressionPage({
    super.key,
    required this.videoPath,
    required this.videoInfo,
    required this.onCompress,
  });

  @override
  State<AdvancedCompressionPage> createState() =>
      _AdvancedCompressionPageState();
}

class _AdvancedCompressionPageState extends State<AdvancedCompressionPage> {
  // Basic Settings
  VVideoCompressQuality _selectedQuality = VVideoCompressQuality.medium;
  bool _deleteOriginal = false;

  // Advanced Settings
  final TextEditingController _videoBitrateController = TextEditingController();
  final TextEditingController _audioBitrateController = TextEditingController();
  final TextEditingController _customWidthController = TextEditingController();
  final TextEditingController _customHeightController = TextEditingController();
  final TextEditingController _frameRateController = TextEditingController();
  final TextEditingController _crfController = TextEditingController();
  final TextEditingController _trimStartController = TextEditingController();
  final TextEditingController _trimEndController = TextEditingController();
  final TextEditingController _cropLeftController = TextEditingController();
  final TextEditingController _cropTopController = TextEditingController();
  final TextEditingController _cropRightController = TextEditingController();
  final TextEditingController _cropBottomController = TextEditingController();
  final TextEditingController _audioSampleRateController =
      TextEditingController();
  final TextEditingController _audioChannelsController =
      TextEditingController();
  final TextEditingController _brightnessController = TextEditingController();
  final TextEditingController _contrastController = TextEditingController();
  final TextEditingController _saturationController = TextEditingController();
  final TextEditingController _keyframeIntervalController =
      TextEditingController();
  final TextEditingController _bFramesController = TextEditingController();
  final TextEditingController _reducedFrameRateController =
      TextEditingController();

  // Dropdown selections
  VVideoCodec? _selectedVideoCodec;
  VAudioCodec? _selectedAudioCodec;
  VEncodingSpeed? _selectedEncodingSpeed;
  int _selectedRotation = 0;

  // Boolean settings
  bool _twoPassEncoding = false;
  bool _hardwareAcceleration = true;
  bool _removeAudio = false;
  bool _variableBitrate = true;
  bool _aggressiveCompression = false;
  bool _noiseReduction = false;
  bool _monoAudio = false;
  bool _cropEnabled = false;

  // Validation
  String? _validationError;

  // Expanded sections
  bool _videoSettingsExpanded = true;
  bool _audioSettingsExpanded = false;
  bool _advancedSettingsExpanded = false;
  bool _colorSettingsExpanded = false;
  bool _trimSettingsExpanded = false;
  bool _cropSettingsExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadDefaultValues();
  }

  @override
  void dispose() {
    _videoBitrateController.dispose();
    _audioBitrateController.dispose();
    _customWidthController.dispose();
    _customHeightController.dispose();
    _frameRateController.dispose();
    _crfController.dispose();
    _trimStartController.dispose();
    _trimEndController.dispose();
    _cropLeftController.dispose();
    _cropTopController.dispose();
    _cropRightController.dispose();
    _cropBottomController.dispose();
    _audioSampleRateController.dispose();
    _audioChannelsController.dispose();
    _brightnessController.dispose();
    _contrastController.dispose();
    _saturationController.dispose();
    _keyframeIntervalController.dispose();
    _bFramesController.dispose();
    _reducedFrameRateController.dispose();
    super.dispose();
  }

  void _loadDefaultValues() {
    // Set reasonable defaults based on original video
    _customWidthController.text = widget.videoInfo.width.toString();
    _customHeightController.text = widget.videoInfo.height.toString();
    _frameRateController.text = '30.0';
    _crfController.text = '23';
    _audioSampleRateController.text = '44100';
    _audioChannelsController.text = '2';
    _brightnessController.text = '0.0';
    _contrastController.text = '0.0';
    _saturationController.text = '0.0';
    _keyframeIntervalController.text = '2';
    _bFramesController.text = '2';
    _reducedFrameRateController.text = '30.0';
    _resetCropFields();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Compression Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: _applyPreset,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'maximum',
                child: Text('Maximum Compression'),
              ),
              const PopupMenuItem(value: 'social', child: Text('Social Media')),
              const PopupMenuItem(
                value: 'mobile',
                child: Text('Mobile Optimized'),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Text('Reset to Defaults'),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.settings_suggest),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_validationError != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _validationError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _validationError = null),
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildVideoInfoCard(),
                  const SizedBox(height: 16),
                  _buildBasicSettingsCard(),
                  const SizedBox(height: 16),
                  _buildVideoSettingsCard(),
                  const SizedBox(height: 16),
                  _buildAudioSettingsCard(),
                  const SizedBox(height: 16),
                  _buildAdvancedSettingsCard(),
                  const SizedBox(height: 16),
                  _buildColorSettingsCard(),
                  const SizedBox(height: 16),
                  _buildTrimSettingsCard(),
                  const SizedBox(height: 16),
                  _buildCropSettingsCard(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, -2),
              blurRadius: 8,
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _validateAndShowEstimate,
                  icon: const Icon(Icons.analytics),
                  label: const Text('Estimate Size'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _validateAndCompress,
                  icon: const Icon(Icons.compress),
                  label: const Text('Compress Video'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Original Video Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Resolution',
              '${widget.videoInfo.width} × ${widget.videoInfo.height}',
            ),
            _buildInfoRow('Duration', widget.videoInfo.durationFormatted),
            _buildInfoRow('File Size', widget.videoInfo.fileSizeFormatted),
            _buildInfoRow(
              'Format',
              widget.videoInfo.name.split('.').last.toUpperCase(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildQualityDropdown(),
            const SizedBox(height: 16),

            _buildSwitchTile(
              'Delete Original File',
              _deleteOriginal,
              (value) => setState(() => _deleteOriginal = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSettingsCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Video Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            trailing: Icon(
              _videoSettingsExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () => setState(
              () => _videoSettingsExpanded = !_videoSettingsExpanded,
            ),
          ),
          if (_videoSettingsExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildNumberField(
                    'Video Bitrate (bps)',
                    _videoBitrateController,
                    'e.g., 1000000 for 1 Mbps',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumberField(
                          'Custom Width',
                          _customWidthController,
                          'Must be even',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildNumberField(
                          'Custom Height',
                          _customHeightController,
                          'Must be even',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    'Frame Rate (FPS)',
                    _frameRateController,
                    'e.g., 30.0',
                    allowDecimal: true,
                  ),
                  const SizedBox(height: 16),
                  _buildCodecDropdown(),
                  const SizedBox(height: 16),
                  _buildEncodingSpeedDropdown(),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    'CRF (Constant Rate Factor)',
                    _crfController,
                    '0-51, lower = better quality',
                  ),
                  const SizedBox(height: 16),
                  _buildRotationDropdown(),
                  const SizedBox(height: 16),
                  _buildSwitchTile(
                    'Two-Pass Encoding',
                    _twoPassEncoding,
                    (value) => setState(() => _twoPassEncoding = value),
                    subtitle: 'Better quality, slower encoding',
                  ),
                  _buildSwitchTile(
                    'Hardware Acceleration',
                    _hardwareAcceleration,
                    (value) => setState(() => _hardwareAcceleration = value),
                    subtitle: 'Faster encoding when available',
                  ),
                  _buildSwitchTile(
                    'Variable Bitrate',
                    _variableBitrate,
                    (value) => setState(() => _variableBitrate = value),
                    subtitle: 'Better compression efficiency',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioSettingsCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Audio Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            trailing: Icon(
              _audioSettingsExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () => setState(
              () => _audioSettingsExpanded = !_audioSettingsExpanded,
            ),
          ),
          if (_audioSettingsExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSwitchTile(
                    'Remove Audio Track',
                    _removeAudio,
                    (value) => setState(() => _removeAudio = value),
                    subtitle: 'Completely remove audio for smaller file',
                  ),
                  if (!_removeAudio) ...[
                    const SizedBox(height: 16),
                    _buildNumberField(
                      'Audio Bitrate (bps)',
                      _audioBitrateController,
                      'e.g., 128000 for 128 kbps',
                    ),
                    const SizedBox(height: 16),
                    _buildAudioCodecDropdown(),
                    const SizedBox(height: 16),
                    _buildNumberField(
                      'Sample Rate (Hz)',
                      _audioSampleRateController,
                      'e.g., 44100, 48000',
                    ),
                    const SizedBox(height: 16),
                    _buildNumberField(
                      'Audio Channels',
                      _audioChannelsController,
                      '1 = mono, 2 = stereo',
                    ),
                    const SizedBox(height: 16),
                    _buildSwitchTile(
                      'Convert to Mono',
                      _monoAudio,
                      (value) => setState(() => _monoAudio = value),
                      subtitle: 'Smaller file size',
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettingsCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Advanced Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            trailing: Icon(
              _advancedSettingsExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () => setState(
              () => _advancedSettingsExpanded = !_advancedSettingsExpanded,
            ),
          ),
          if (_advancedSettingsExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildNumberField(
                    'Keyframe Interval (seconds)',
                    _keyframeIntervalController,
                    '1-30, larger = better compression',
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    'B-Frames',
                    _bFramesController,
                    '0-16, more = better compression',
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    'Reduced Frame Rate (FPS)',
                    _reducedFrameRateController,
                    'Lower FPS for smaller files',
                    allowDecimal: true,
                  ),
                  const SizedBox(height: 16),
                  _buildSwitchTile(
                    'Aggressive Compression',
                    _aggressiveCompression,
                    (value) => setState(() => _aggressiveCompression = value),
                    subtitle: 'Enable all compression optimizations',
                  ),
                  _buildSwitchTile(
                    'Noise Reduction',
                    _noiseReduction,
                    (value) => setState(() => _noiseReduction = value),
                    subtitle: 'Remove noise for better compression',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildColorSettingsCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Color Adjustments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            trailing: Icon(
              _colorSettingsExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () => setState(
              () => _colorSettingsExpanded = !_colorSettingsExpanded,
            ),
          ),
          if (_colorSettingsExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildNumberField(
                    'Brightness',
                    _brightnessController,
                    '-1.0 to 1.0 (0.0 = no change)',
                    allowDecimal: true,
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    'Contrast',
                    _contrastController,
                    '-1.0 to 1.0 (0.0 = no change)',
                    allowDecimal: true,
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    'Saturation',
                    _saturationController,
                    '-1.0 to 1.0 (0.0 = no change)',
                    allowDecimal: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrimSettingsCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Trim Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            trailing: Icon(
              _trimSettingsExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () =>
                setState(() => _trimSettingsExpanded = !_trimSettingsExpanded),
          ),
          if (_trimSettingsExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Original Duration: ${widget.videoInfo.durationFormatted}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    'Trim Start (milliseconds)',
                    _trimStartController,
                    'Start time in ms (optional)',
                  ),
                  const SizedBox(height: 16),
                  _buildNumberField(
                    'Trim End (milliseconds)',
                    _trimEndController,
                    'End time in ms (optional)',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCropSettingsCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Normalized Crop',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Coordinates use the displayed frame after rotation',
            ),
            trailing: Icon(
              _cropSettingsExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () =>
                setState(() => _cropSettingsExpanded = !_cropSettingsExpanded),
          ),
          if (_cropSettingsExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSwitchTile(
                    'Enable crop coordinates',
                    _cropEnabled,
                    (value) => setState(() => _cropEnabled = value),
                    subtitle:
                        'Use values from 0.0 to 1.0; full frame is a no-op',
                  ),
                  if (_cropEnabled) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberField(
                            'Left',
                            _cropLeftController,
                            '0.0',
                            allowDecimal: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNumberField(
                            'Top',
                            _cropTopController,
                            '0.0',
                            allowDecimal: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNumberField(
                            'Right',
                            _cropRightController,
                            '1.0',
                            allowDecimal: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNumberField(
                            'Bottom',
                            _cropBottomController,
                            '1.0',
                            allowDecimal: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => setState(_resetCropFields),
                        icon: const Icon(Icons.crop_free),
                        label: const Text('Reset to full frame'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildQualityDropdown() {
    return DropdownButtonFormField<VVideoCompressQuality>(
      initialValue: _selectedQuality,
      decoration: const InputDecoration(
        labelText: 'Base Quality Preset',
        border: OutlineInputBorder(),
      ),
      items: VVideoCompressQuality.values.map((quality) {
        return DropdownMenuItem(
          value: quality,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(quality.displayName),
              Text(
                quality.description,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedQuality = value);
        }
      },
    );
  }

  Widget _buildCodecDropdown() {
    return DropdownButtonFormField<VVideoCodec?>(
      initialValue: _selectedVideoCodec,
      decoration: const InputDecoration(
        labelText: 'Video Codec',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Auto (Default)')),
        ...VVideoCodec.values.map((codec) {
          return DropdownMenuItem(
            value: codec,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(codec.displayName),
                Text(
                  codec.description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }),
      ],
      onChanged: (value) => setState(() => _selectedVideoCodec = value),
    );
  }

  Widget _buildAudioCodecDropdown() {
    return DropdownButtonFormField<VAudioCodec?>(
      initialValue: _selectedAudioCodec,
      decoration: const InputDecoration(
        labelText: 'Audio Codec',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Auto (Default)')),
        ...VAudioCodec.values.map((codec) {
          return DropdownMenuItem(
            value: codec,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(codec.displayName),
                Text(
                  codec.description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }),
      ],
      onChanged: (value) => setState(() => _selectedAudioCodec = value),
    );
  }

  Widget _buildEncodingSpeedDropdown() {
    return DropdownButtonFormField<VEncodingSpeed?>(
      initialValue: _selectedEncodingSpeed,
      decoration: const InputDecoration(
        labelText: 'Encoding Speed',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Auto (Default)')),
        ...VEncodingSpeed.values.map((speed) {
          return DropdownMenuItem(
            value: speed,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(speed.displayName),
                Text(
                  speed.description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }),
      ],
      onChanged: (value) => setState(() => _selectedEncodingSpeed = value),
    );
  }

  Widget _buildRotationDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedRotation,
      decoration: const InputDecoration(
        labelText: 'Rotation',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 0, child: Text('No Rotation (0°)')),
        DropdownMenuItem(value: 90, child: Text('90° Clockwise')),
        DropdownMenuItem(value: 180, child: Text('180° (Upside Down)')),
        DropdownMenuItem(value: 270, child: Text('270° Clockwise')),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedRotation = value);
        }
      },
    );
  }

  Widget _buildNumberField(
    String label,
    TextEditingController controller,
    String hint, {
    bool allowDecimal = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      keyboardType: allowDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: allowDecimal
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : [FilteringTextInputFormatter.digitsOnly],
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    String? subtitle,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  void _applyPreset(String preset) {
    switch (preset) {
      case 'maximum':
        _applyMaximumCompressionPreset();
        break;
      case 'social':
        _applySocialMediaPreset();
        break;
      case 'mobile':
        _applyMobileOptimizedPreset();
        break;
      case 'reset':
        _resetToDefaults();
        break;
    }
  }

  void _applyMaximumCompressionPreset() {
    setState(() {
      _selectedQuality = VVideoCompressQuality.veryLow;
      _selectedVideoCodec = VVideoCodec.h265;
      _videoBitrateController.text = '300000';
      _audioBitrateController.text = '64000';
      _crfController.text = '28';
      _twoPassEncoding = true;
      _hardwareAcceleration = true;
      _variableBitrate = true;
      _keyframeIntervalController.text = '10';
      _bFramesController.text = '3';
      _reducedFrameRateController.text = '24.0';
      _aggressiveCompression = true;
      _noiseReduction = true;
      _monoAudio = true;
      _audioSampleRateController.text = '22050';
      _audioChannelsController.text = '1';
    });
    _showPresetAppliedSnackBar('Maximum Compression preset applied');
  }

  void _applySocialMediaPreset() {
    setState(() {
      _selectedQuality = VVideoCompressQuality.medium;
      _selectedVideoCodec = VVideoCodec.h265;
      _videoBitrateController.text = '800000';
      _audioBitrateController.text = '96000';
      _crfController.text = '25';
      _variableBitrate = true;
      _keyframeIntervalController.text = '5';
      _bFramesController.text = '2';
      _reducedFrameRateController.text = '30.0';
      _aggressiveCompression = true;
      _audioSampleRateController.text = '44100';
      _audioChannelsController.text = '2';
    });
    _showPresetAppliedSnackBar('Social Media preset applied');
  }

  void _applyMobileOptimizedPreset() {
    setState(() {
      _selectedQuality = VVideoCompressQuality.medium;
      _selectedVideoCodec = VVideoCodec.h264;
      _videoBitrateController.text = '1500000';
      _audioBitrateController.text = '128000';
      _crfController.text = '23';
      _hardwareAcceleration = true;
      _variableBitrate = true;
      _keyframeIntervalController.text = '3';
      _bFramesController.text = '1';
      _reducedFrameRateController.text = '30.0';
      _audioSampleRateController.text = '44100';
      _audioChannelsController.text = '2';
    });
    _showPresetAppliedSnackBar('Mobile Optimized preset applied');
  }

  void _resetToDefaults() {
    setState(() {
      _selectedQuality = VVideoCompressQuality.medium;
      _selectedVideoCodec = null;
      _selectedAudioCodec = null;
      _selectedEncodingSpeed = null;
      _selectedRotation = 0;
      _twoPassEncoding = false;
      _hardwareAcceleration = true;
      _removeAudio = false;
      _variableBitrate = true;
      _aggressiveCompression = false;
      _noiseReduction = false;
      _monoAudio = false;
      _cropEnabled = false;

      _deleteOriginal = false;
    });

    // Clear all text controllers
    _videoBitrateController.clear();
    _audioBitrateController.clear();
    _frameRateController.text = '30.0';
    _crfController.text = '23';
    _trimStartController.clear();
    _trimEndController.clear();
    _resetCropFields();
    _audioSampleRateController.text = '44100';
    _audioChannelsController.text = '2';
    _brightnessController.text = '0.0';
    _contrastController.text = '0.0';
    _saturationController.text = '0.0';
    _keyframeIntervalController.text = '2';
    _bFramesController.text = '2';
    _reducedFrameRateController.text = '30.0';

    _loadDefaultValues();
    _showPresetAppliedSnackBar('Settings reset to defaults');
  }

  void _showPresetAppliedSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _validateSettings() {
    setState(() => _validationError = null);

    // Validate resolution
    if (_customWidthController.text.isNotEmpty &&
        _customHeightController.text.isNotEmpty) {
      final width = int.tryParse(_customWidthController.text);
      final height = int.tryParse(_customHeightController.text);

      if (width == null || height == null || width <= 0 || height <= 0) {
        setState(() => _validationError = 'Invalid resolution values');
        return false;
      }

      if (width % 2 != 0 || height % 2 != 0) {
        setState(
          () => _validationError = 'Width and height must be even numbers',
        );
        return false;
      }
    }

    // Validate CRF
    if (_crfController.text.isNotEmpty) {
      final crf = int.tryParse(_crfController.text);
      if (crf == null || crf < 0 || crf > 51) {
        setState(() => _validationError = 'CRF must be between 0 and 51');
        return false;
      }
    }

    // Validate trim times
    if (_trimStartController.text.isNotEmpty &&
        _trimEndController.text.isNotEmpty) {
      final start = int.tryParse(_trimStartController.text);
      final end = int.tryParse(_trimEndController.text);

      if (start != null && end != null && start >= end) {
        setState(
          () => _validationError = 'Trim start time must be less than end time',
        );
        return false;
      }
    }

    if (_cropEnabled) {
      final cropRect = _readCropRect();
      if (cropRect == null || !cropRect.isValid()) {
        setState(
          () => _validationError = 'Crop requires finite values with 0 ≤ left < right ≤ 1 and 0 ≤ top < bottom ≤ 1',
        );
        return false;
      }
    }

    // Validate color adjustments
    for (final controller in [
      _brightnessController,
      _contrastController,
      _saturationController,
    ]) {
      if (controller.text.isNotEmpty) {
        final value = double.tryParse(controller.text);
        if (value == null || value < -1.0 || value > 1.0) {
          setState(
            () => _validationError =
                'Color adjustment values must be between -1.0 and 1.0',
          );
          return false;
        }
      }
    }

    return true;
  }

  VVideoAdvancedConfig _buildAdvancedConfig() {
    return VVideoAdvancedConfig(
      videoBitrate: _videoBitrateController.text.isNotEmpty
          ? int.tryParse(_videoBitrateController.text)
          : null,
      audioBitrate: _audioBitrateController.text.isNotEmpty
          ? int.tryParse(_audioBitrateController.text)
          : null,
      customWidth: _customWidthController.text.isNotEmpty
          ? int.tryParse(_customWidthController.text)
          : null,
      customHeight: _customHeightController.text.isNotEmpty
          ? int.tryParse(_customHeightController.text)
          : null,
      frameRate: _frameRateController.text.isNotEmpty
          ? double.tryParse(_frameRateController.text)
          : null,
      videoCodec: _selectedVideoCodec,
      audioCodec: _selectedAudioCodec,
      encodingSpeed: _selectedEncodingSpeed,
      crf: _crfController.text.isNotEmpty
          ? int.tryParse(_crfController.text)
          : null,
      twoPassEncoding: _twoPassEncoding,
      hardwareAcceleration: _hardwareAcceleration,
      trimStartMs: _trimStartController.text.isNotEmpty
          ? int.tryParse(_trimStartController.text)
          : null,
      trimEndMs: _trimEndController.text.isNotEmpty
          ? int.tryParse(_trimEndController.text)
          : null,
      rotation: _selectedRotation != 0 ? _selectedRotation : null,
      cropRect: _cropEnabled ? _readCropRect() : null,
      audioSampleRate: _audioSampleRateController.text.isNotEmpty
          ? int.tryParse(_audioSampleRateController.text)
          : null,
      audioChannels: _audioChannelsController.text.isNotEmpty
          ? int.tryParse(_audioChannelsController.text)
          : null,
      removeAudio: _removeAudio,
      brightness: _brightnessController.text.isNotEmpty
          ? double.tryParse(_brightnessController.text)
          : null,
      contrast: _contrastController.text.isNotEmpty
          ? double.tryParse(_contrastController.text)
          : null,
      saturation: _saturationController.text.isNotEmpty
          ? double.tryParse(_saturationController.text)
          : null,
      variableBitrate: _variableBitrate,
      keyframeInterval: _keyframeIntervalController.text.isNotEmpty
          ? int.tryParse(_keyframeIntervalController.text)
          : null,
      bFrames: _bFramesController.text.isNotEmpty
          ? int.tryParse(_bFramesController.text)
          : null,
      reducedFrameRate: _reducedFrameRateController.text.isNotEmpty
          ? double.tryParse(_reducedFrameRateController.text)
          : null,
      aggressiveCompression: _aggressiveCompression,
      noiseReduction: _noiseReduction,
      monoAudio: _monoAudio,
    );
  }

  VVideoCropRect? _readCropRect() {
    final left = double.tryParse(_cropLeftController.text);
    final top = double.tryParse(_cropTopController.text);
    final right = double.tryParse(_cropRightController.text);
    final bottom = double.tryParse(_cropBottomController.text);
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    return VVideoCropRect(left: left, top: top, right: right, bottom: bottom);
  }

  void _resetCropFields() {
    _cropLeftController.text = '0.0';
    _cropTopController.text = '0.0';
    _cropRightController.text = '1.0';
    _cropBottomController.text = '1.0';
  }

  void _validateAndCompress() {
    if (!_validateSettings()) {
      return;
    }

    final config = VVideoCompressionConfig(
      quality: _selectedQuality,

      deleteOriginal: _deleteOriginal,
      advanced: _buildAdvancedConfig(),
    );

    widget.onCompress(config);
    Navigator.of(context).pop();
  }

  void _validateAndShowEstimate() {
    if (!_validateSettings()) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compression Estimate'),
        content: const Text(
          'Advanced compression estimation is complex and depends on many factors. '
          'The actual result may vary significantly based on video content, '
          'selected settings, and device capabilities.\n\n'
          'For accurate results, we recommend running a test compression.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
