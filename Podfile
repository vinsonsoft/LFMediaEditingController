project './LFMediaEditingController/LFMediaEditingController.xcodeproj'

source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '13.0'

inhibit_all_warnings!

target 'LFMediaEditingController' do
use_frameworks!
pod 'LFFilterSuite'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'No'
      
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 13.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      end
      
    end
  end
end

end
