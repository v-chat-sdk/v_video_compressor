import 'package:flutter/material.dart';
import 'package:v_video_compressor/v_video_compressor.dart';

/// Example showing how to configure and use the V Video Compressor logging system
class LoggingExampleWidget extends StatefulWidget {
  const LoggingExampleWidget({super.key});

  @override
  State<LoggingExampleWidget> createState() => _LoggingExampleWidgetState();
}

class _LoggingExampleWidgetState extends State<LoggingExampleWidget> {
  VVideoLogLevel _currentLogLevel = VVideoLogLevel.info;
  bool _loggingEnabled = true;
  bool _showProgress = true;
  bool _showParameters = false;
  bool _showSuccess = true;
  bool _useConsoleLog = false;

  final VVideoCompressor _compressor = VVideoCompressor();

  @override
  void initState() {
    super.initState();
    _configureLogging();
  }

  void _configureLogging() {
    final config = VVideoLogConfig(
      enabled: _loggingEnabled,
      level: _currentLogLevel,
      showProgress: _showProgress,
      showParameters: _showParameters,
      showSuccess: _showSuccess,
      useConsoleLog: _useConsoleLog,
    );

    VVideoCompressor.configureLogging(config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('V Video Compressor Logging'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLoggingControls(),
            const SizedBox(height: 24),
            _buildPresetButtons(),
            const SizedBox(height: 24),
            _buildTestButtons(),
            const SizedBox(height: 24),
            _buildCurrentConfig(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggingControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Logging Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Enable/Disable Logging
            SwitchListTile(
              title: const Text('Enable Logging'),
              subtitle: const Text('Turn logging on/off completely'),
              value: _loggingEnabled,
              onChanged: (value) {
                setState(() {
                  _loggingEnabled = value;
                  _configureLogging();
                });
              },
            ),

            // Log Level
            const Text(
              'Log Level:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            DropdownButton<VVideoLogLevel>(
              value: _currentLogLevel,
              isExpanded: true,
              items: VVideoLogLevel.values.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text('${level.name.toUpperCase()} (${level.level})'),
                );
              }).toList(),
              onChanged: _loggingEnabled
                  ? (level) {
                      if (level != null) {
                        setState(() {
                          _currentLogLevel = level;
                          _configureLogging();
                        });
                      }
                    }
                  : null,
            ),

            const SizedBox(height: 16),

            // Show Progress
            SwitchListTile(
              title: const Text('Show Progress'),
              subtitle: const Text('Log compression progress updates'),
              value: _showProgress,
              onChanged: _loggingEnabled
                  ? (value) {
                      setState(() {
                        _showProgress = value;
                        _configureLogging();
                      });
                    }
                  : null,
            ),

            // Show Parameters
            SwitchListTile(
              title: const Text('Show Parameters'),
              subtitle: const Text('Log method parameters'),
              value: _showParameters,
              onChanged: _loggingEnabled
                  ? (value) {
                      setState(() {
                        _showParameters = value;
                        _configureLogging();
                      });
                    }
                  : null,
            ),

            // Show Success
            SwitchListTile(
              title: const Text('Show Success'),
              subtitle: const Text('Log successful operations'),
              value: _showSuccess,
              onChanged: _loggingEnabled
                  ? (value) {
                      setState(() {
                        _showSuccess = value;
                        _configureLogging();
                      });
                    }
                  : null,
            ),

            // Use Console Log
            SwitchListTile(
              title: const Text('Use Console Log'),
              subtitle: const Text('Use print() instead of developer.log()'),
              value: _useConsoleLog,
              onChanged: _loggingEnabled
                  ? (value) {
                      setState(() {
                        _useConsoleLog = value;
                        _configureLogging();
                      });
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preset Configurations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () {
                    VVideoCompressor.configureLogging(
                      VVideoLogConfig.production(),
                    );
                    _updateStateFromConfig();
                  },
                  child: const Text('Production'),
                ),
                ElevatedButton(
                  onPressed: () {
                    VVideoCompressor.configureLogging(
                      VVideoLogConfig.development(),
                    );
                    _updateStateFromConfig();
                  },
                  child: const Text('Development'),
                ),
                ElevatedButton(
                  onPressed: () {
                    VVideoCompressor.configureLogging(VVideoLogConfig.debug());
                    _updateStateFromConfig();
                  },
                  child: const Text('Debug'),
                ),
                ElevatedButton(
                  onPressed: () {
                    VVideoCompressor.configureLogging(
                      VVideoLogConfig.disabled(),
                    );
                    _updateStateFromConfig();
                  },
                  child: const Text('Disabled'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Test Logging',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Test different log levels and operations:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _testGetPlatformVersion,
                  child: const Text('Test Platform Version'),
                ),
                ElevatedButton(
                  onPressed: _testGetVideoInfo,
                  child: const Text('Test Video Info'),
                ),
                ElevatedButton(
                  onPressed: _testCompression,
                  child: const Text('Test Compression'),
                ),
                ElevatedButton(
                  onPressed: _testThumbnail,
                  child: const Text('Test Thumbnail'),
                ),
                ElevatedButton(
                  onPressed: _testError,
                  child: const Text('Test Error'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentConfig() {
    final config = VVideoCompressor.loggingConfig;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Enabled: ${config.enabled}'),
            Text(
              'Level: ${config.level.name.toUpperCase()} (${config.level.level})',
            ),
            Text('Show Progress: ${config.showProgress}'),
            Text('Show Parameters: ${config.showParameters}'),
            Text('Show Success: ${config.showSuccess}'),
            Text('Show Stack Trace: ${config.showStackTrace}'),
            Text('Use Console Log: ${config.useConsoleLog}'),
            if (config.customPrefix != null)
              Text('Custom Prefix: ${config.customPrefix}'),
          ],
        ),
      ),
    );
  }

  void _updateStateFromConfig() {
    final config = VVideoCompressor.loggingConfig;
    setState(() {
      _loggingEnabled = config.enabled;
      _currentLogLevel = config.level;
      _showProgress = config.showProgress;
      _showParameters = config.showParameters;
      _showSuccess = config.showSuccess;
      _useConsoleLog = config.useConsoleLog;
    });
  }

  Future<void> _testGetPlatformVersion() async {
    try {
      final version = await _compressor.getPlatformVersion();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Platform version: $version')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _testGetVideoInfo() async {
    try {
      // This will likely fail since it's a test path, but will show logging
      final info = await _compressor.getVideoInfo('/test/video/path.mp4');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video info: ${info?.name ?? "Not found"}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _testCompression() async {
    try {
      // This will likely fail since it's a test path, but will show logging
      final result = await _compressor.compressVideo(
        '/test/video/path.mp4',
        const VVideoCompressionConfig.medium(),
        onProgress: (progress) {
          // Progress will be logged if enabled
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Compression result: ${result?.compressedFilePath ?? "Failed"}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _testThumbnail() async {
    try {
      // This will likely fail since it's a test path, but will show logging
      final result = await _compressor.getVideoThumbnail(
        '/test/video/path.mp4',
        const VVideoThumbnailConfig.defaults(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Thumbnail result: ${result?.thumbnailPath ?? "Failed"}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _testError() async {
    try {
      // Test with empty path to trigger warning/error logs
      await _compressor.getVideoInfo('');
      await _compressor.compressVideo(
        '',
        const VVideoCompressionConfig.medium(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error test completed - check logs')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
