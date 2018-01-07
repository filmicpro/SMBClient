#
# Be sure to run `pod lib lint SMBClient.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SMBClient'
  s.version          = '0.0.7'
  s.summary          = 'SMBClient is simple SMB client for iOS apps. It allows connecting to SMB devices.'

  s.homepage         = "https://github.com/filmicpro/SMBClient"
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Seth Faxon' => 'seth@filmicpro.com' }
  s.source           = { :git => "https://github.com/filmicpro/SMBClient.git", :tag => "#{s.version}" }

  s.ios.deployment_target = '10.0'

  s.source_files  = ["Sources/**/*.swift", "libdsm/**/*.h", "libdsm/**/*.modulemap"]
  # s.xcconfig = {
  #   'HEADER_SEARCH_PATHS' => '/Users/sfaxon/src/SMBClient/libdsm/include/bdsm',
  #   'SWIFT_INCLUDE_PATHS' => '/Users/sfaxon/src/SMBClient/libdsm'
  # }
  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/libdsm/include/bdsm',
    'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)/libdsm'
  }
  s.preserve_paths = 'libdsm/*'
  s.vendored_libraries = 'libdsm/libdsm.a', 'libdsm/libtasn1.a'
  s.library = 'iconv'

end
