#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint gvl_comments.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'gvl_comments'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'https://goodvibeslab.cloud'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'GoodVibesLab' => 'contact@goodvibeslab.app' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'gvl_comments_privacy' => ['Resources/PrivacyInfo.xcprivacy']}

  s.frameworks = 'Security'

end

#
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint gvl_comments.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'gvl_comments'
  s.version          = '0.9.5'
  s.summary          = 'Native bridge for GoodVibesLab Comments (install binding & metadata).'
  s.description      = <<-DESC
Provides the iOS native bridge used by the gvl_comments Flutter package.

It exposes a stable install binding (bundle id + Team ID when available) to help
backend validation and prevent API key reuse across unrelated apps.
DESC

  s.homepage         = 'https://goodvibeslab.cloud'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'GoodVibesLab' => 'contact@goodvibeslab.app' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*.{h,m,swift}'
  s.dependency       'Flutter'
  s.platform         = :ios, '13.0'

  # Flutter.framework does not contain an i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }

  s.swift_version = '5.0'

  # Include the privacy manifest in the built pod bundle.
  s.resource_bundles = { 'gvl_comments_privacy' => ['Resources/PrivacyInfo.xcprivacy'] }

  # Used by the Team ID best-effort probe.
  s.frameworks = 'Security'
end