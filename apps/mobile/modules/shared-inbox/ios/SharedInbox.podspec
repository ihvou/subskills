Pod::Spec.new do |s|
  s.name           = 'SharedInbox'
  s.version        = '1.0.0'
  s.summary        = 'Reads URLs the share extension left in the App Group container.'
  s.description    = 'Local Expo module. JavaScript cannot reach a suite-scoped UserDefaults, which is the only reason this exists.'
  s.author         = 'Subskills'
  s.homepage       = 'https://subskills.xyz'
  s.platforms      = { :ios => '15.1' }
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule',
  }

  s.source_files = '**/*.{h,m,mm,swift,hpp,cpp}'
end
