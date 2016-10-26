#
# Be sure to run `pod lib lint MoView.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = "MoView"
  s.version          = "1.0.3"
  s.summary          = "MoView is a movable, resizable view, with special attention to be used with UIImage, thus providing Save, Copy and Delete menu options."

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!  
  s.description      = <<-DESC
  MoView by hyouuu, made for Pendo, based on SPUserResizableView.

  It is a movable, resizable view, with special attention to be used with UIImage, thus providing Save, Copy and Delete menu options.
                       DESC

  s.homepage         = "https://github.com/hyouuu/MoView"
  s.license          = 'MIT'
  s.author           = { "hyouuu" => "hyouuu@gmail.com" }
  s.source           = { :git => "https://github.com/hyouuu/MoView.git", :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.platform     = :ios, '8.0'
  s.requires_arc = true

  s.source_files = 'Pod/Classes/**/*'

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
