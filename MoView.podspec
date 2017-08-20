#
# Be sure to run `pod lib lint MoView.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "MoView"
  s.version          = "1.2.1"
  s.summary          = "MoView is a movable & resizable view for both iOS & macOS"

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!
  s.description      = <<-DESC
  MoView is a movable & resizable view for both iOS & macOS
  DESC

  s.homepage         = "https://github.com/hyouuu/MoView"
  s.license          = 'MIT'
  s.author           = { "hyouuu" => "hyouuu@gmail.com" }
  s.source           = { :git => "https://github.com/hyouuu/MoView.git", :tag => s.version.to_s }

  s.ios.platform = :ios, "8.0"
  s.osx.platform = :osx, "10.12"
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'
end
