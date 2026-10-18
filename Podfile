platform :ios, '16.0'
use_frameworks!
inhibit_all_warnings!

target 'ZendeskAIAgents' do
  # Zendesk Messaging SDK
  pod 'ZendeskSDKMessaging', '~> 2.25'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings['EXPANDED_CODE_SIGN_IDENTITY'] = ""
      config.build_settings['CODE_SIGNING_REQUIRED'] = "NO"
      config.build_settings['CODE_SIGNING_ALLOWED'] = "NO"
    end
  end
end
