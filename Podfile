project 'MusicalCaneGame.xcodeproj/'

# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

# Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

target 'MusicalCaneGame' do
  pod 'SQLite.swift', '~> 0.11.5'
  pod 'MetaWear'
  pod 'MBProgressHUD'
  pod 'StaticDataTableViewController'
  pod 'PRTween', '~> 0.1'
  pod 'FlexColorPicker'
end


  # Pods for MusicalCaneGame

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "15.0"
    end
  end
end
