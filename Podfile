# Podfile
platform :ios, '17.0'

target 'SommLens' do
  use_frameworks!

  pod 'GoogleMLKit/TextRecognition'
end

post_install do |installer|
  # 1️⃣ individual pod targets
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |c|
      c.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      c.build_settings['IPHONEOS_DEPLOYMENT_TARGET']    = '17.0'
      c.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      c.build_settings['GCC_TREAT_WARNINGS_AS_ERRORS']                 = 'NO'
    end
  end

  # 2️⃣ the aggregate “Pods-SommLens” targets Xcode adds
  installer.aggregate_targets.each do |agg|
    agg.user_project.build_configurations.each do |c|
      c.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      c.build_settings['IPHONEOS_DEPLOYMENT_TARGET']    = '17.0'
      c.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
      c.build_settings['GCC_TREAT_WARNINGS_AS_ERRORS']                 = 'NO'
    end
  end
end
