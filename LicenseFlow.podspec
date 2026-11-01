Pod::Spec.new do |s|
  s.name             = 'LicenseFlow'
  s.version          = '2.3.0'
  s.summary          = 'Official Swift & iOS SDK for LicenseFlow licensing, entitlements, and verification.'
  s.description      = <<-DESC
LicenseFlow is an API-first licensing and entitlement control plane for modern software,
AI agents, and offline sovereign deployments. This SDK provides hardware-bound licensing,
offline cryptographic token verification, and real-time usage metering for Apple platforms.
                       DESC

  s.homepage         = 'https://licenseflow.dev'
  s.license          = { :type => 'MIT', :file => 'README.md' }
  s.author           = { 'LicenseFlow' => 'support@licenseflow.dev' }
  s.source           = { :git => 'https://github.com/licenseflow/licenseflow-swift.git', :tag => "sdk-swift-v#{s.version}" }

  s.ios.deployment_target     = '15.0'
  s.osx.deployment_target     = '12.0'
  s.tvos.deployment_target    = '15.0'
  s.watchos.deployment_target = '8.0'

  s.swift_version    = '5.9'
  s.source_files     = 'Sources/LicenseFlow/**/*'
  s.frameworks       = 'Foundation'
end
