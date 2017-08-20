#
# Be sure to run `pod lib lint MoView.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |spec|
  spec.name             = 'MoView'
  spec.version          = '1.3.0'
  spec.license          = 'MIT'
  spec.homepage         = 'https://github.com/hyouuu/MoView'
  spec.authors          = { 'hyouuu' => 'hyouuu@gmail.com' }
  spec.summary          = 'MoView is a movable & resizable view for both iOS & macOS'
  spec.source           = { :git => 'https://github.com/hyouuu/MoView.git', :tag => spec.version.to_s }

  spec.ios.deployment_target = '9.0'
  spec.osx.deployment_target = '10.12'

  #spec.source_files = 'MoView/**/*.swift'
  spec.ios.source_files = 'MoView/ios/*.swift'
  spec.osx.source_files = 'MoView/osx/*.swift'

  spec.requires_arc = true
end
