#
# Be sure to run `pod lib lint MoView.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "MoView"
  s.version          = "1.3.0"

  s.license          = 'MIT'
  s.homepage         = "https://github.com/hyouuu/MoView"
  s.authors          = { "hyouuu" => "hyouuu@gmail.com" }
  s.summary          = "MoView is a movable & resizable view for both iOS & macOS"
  s.source           = { :git => "https://github.com/hyouuu/MoView.git", :tag => s.version.to_s }

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.12"

  s.ios.source_files = 'ios/*.swift'
  s.osx.source_files = 'osx/*.swift'

  s.requires_arc = true
end
