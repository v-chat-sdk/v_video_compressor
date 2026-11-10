#
# V Video Compressor Plugin
# Efficient video compression for Flutter applications
#
Pod::Spec.new do |s|
  s.name             = 'v_video_compressor'
  s.version          = '3.0.1'
  s.summary          = 'Efficient video compression plugin for Flutter'
  s.description      = <<-DESC
A focused Flutter plugin for efficient video compression with real-time progress tracking,
advanced configuration options, and high-quality output.
                       DESC
  s.homepage         = 'https://github.com/v-chat-sdk/v_video_compressor'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'V Chat SDK Team' => 'support@v-chat-sdk.com' }
  s.source           = { :path => '.' }
  s.source_files = 'v_video_compressor/Sources/v_video_compressor/**/*.swift'
  
  # Dependencies
  s.dependency 'Flutter'
  
  # Platform requirements
  s.platform = :ios, '12.0'
  s.ios.deployment_target = '12.0'

  # Compiler settings
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'SWIFT_VERSION' => '5.0',
    'OTHER_SWIFT_FLAGS' => '-Xfrontend -warn-long-function-bodies=100 -Xfrontend -warn-long-expression-type-checking=100'
  }
  s.swift_version = '5.0'
  
  # Framework dependencies
  s.frameworks = 'AVFoundation', 'UIKit', 'Foundation'

  # Privacy manifest for App Store compliance
  s.resource_bundles = {
    'v_video_compressor_privacy' => [
      'v_video_compressor/Sources/v_video_compressor/PrivacyInfo.xcprivacy'
    ]
  }
end
