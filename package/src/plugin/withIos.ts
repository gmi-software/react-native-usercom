import { withPodfile } from '@expo/config-plugins'
import type { ConfigPlugin } from '@expo/config-plugins'

const USERCOM_IOS_POD =
  "pod 'UserSDK', :git => 'https://github.com/UserEngage/iOS-SDK.git', :tag => '1.1.1'"

const LEGACY_POST_INSTALL_PATCH = `
  # Patch UserSDK deployment target (ios13.0 -> ios15.1)
  # This is a workaround for UserSDK XCFramework having incorrect deployment target
  installer.pods_project.targets.each do |target|
    if target.name == 'UserSDK'
      user_sdk_path = installer.sandbox.pod_dir('UserSDK')
      Dir.glob("#{user_sdk_path}/**/*.swiftinterface").each do |file|
        content = File.read(file)
        if content.include?('ios13.0')
          puts "[react-native-usercom] Patching #{File.basename(file)} deployment target"
          content.gsub!('ios13.0', 'ios15.1')
          File.write(file, content)
        end
      end
    end
  end`

/**
 * Adds User.com SDK pod to Podfile (iOS)
 */
export const withIos: ConfigPlugin = (config) => {
  return withPodfile(config, (modConfig) => {
    let contents = modConfig.modResults.contents

    const existingPod = /^\s*pod ['"]UserSDK['"].*$/m
    if (existingPod.test(contents)) {
      contents = contents.replace(existingPod, `  ${USERCOM_IOS_POD}`)
    } else {
      // Find target block and add pod after use_expo_modules!
      const targetPattern = /(use_expo_modules!)/

      if (targetPattern.test(contents)) {
        contents = contents.replace(targetPattern, (match) => {
          return `${match}\n\n  # User.com SDK\n  ${USERCOM_IOS_POD}`
        })
      } else {
          console.warn(
              '[UserCom] Could not find use_expo_modules! in Podfile. UserSDK pod was not added automatically.'
          )
      }
    }

    contents = contents.replace(LEGACY_POST_INSTALL_PATCH, '')

    modConfig.modResults.contents = contents
    return modConfig
  })
}
