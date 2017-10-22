Pod::Spec.new do |s|
  s.name         = 'SMBClient'
  s.version      = '0.1.0'
  s.summary      = 'Swift wrapper for libdsm for connecting to SMB shares.'
  s.description  = <<-DESC
SMBCLient is a Swift wrapper for libdsm. It allows browsing the local network
for SMB shares and allows authenticated or guest access.
                   DESC
  s.homepage     = 'https://github.com/filmicpro/SMBClient'
  s.license      = 'MIT'
  s.author       = { 'Seth Faxon' => 'seth.faxon@gmail.com' }
  s.platform     = :ios, '8.0'

  s.source       = { :git => 'https://github.com/filmicpro/SMBClient.git', :tag => s.version }
  
  s.source_files = 'Sources/**/*.swift', 'libdsm/include/**/*.h'
  s.public_header_files = 'Sources/Support Files/SMBClient.h'
  s.pod_target_xcconfig = { 'SWIFT_INCLUDE_PATHS' => '$(SRCROOT)/SMBClient/libdsm/include/**', 'LIBRARY_SEARCH_PATHS' => '$(SRCROOT)/SMBClient/Sources/'}
  s.preserve_paths = 'libdsm/module.modulemap'
  s.vendored_libraries = 'libdsm/libdsm.a', 'libdsm/libtasn1.a'
  s.library      = 'iconv'
end
