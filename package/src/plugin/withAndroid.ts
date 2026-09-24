import {
  AndroidConfig,
  withAndroidManifest,
  withAppBuildGradle,
  withStringsXml,
} from '@expo/config-plugins'
import type { ConfigPlugin } from '@expo/config-plugins'
import type { UserComPluginOptions } from './index'

const SERVICE_NAME = 'com.margelo.nitro.usercom.UserComMessagingService'

export const withAndroid: ConfigPlugin<UserComPluginOptions> = (
  config,
  options = {}
) => {
  if (options.androidNotificationChannelName) {
    config = withStringsXml(config, (modConfig) => {
      const strings = modConfig.modResults.resources.string || []
      modConfig.modResults.resources.string = strings.filter(
        (item) => item.$.name !== 'user_com_channel_name'
      )
      modConfig.modResults.resources.string.push({
        $: { name: 'user_com_channel_name' },
        _: options.androidNotificationChannelName!,
      })
      return modConfig
    })
  }

  if (options.androidRegisterMessagingService !== false) {
    config = withAppBuildGradle(config, (modConfig) => {
      const contents = modConfig.modResults.contents
      if (!contents.includes('com.google.firebase:firebase-messaging')) {
        if (!/dependencies\s*\{/.test(contents)) {
          throw new Error('[UserCom] Android app/build.gradle has no dependencies block')
        }
        modConfig.modResults.contents = contents.replace(
          /dependencies\s*\{/,
          (match) =>
            `${match}\n    implementation platform("com.google.firebase:firebase-bom:34.15.0")\n    implementation("com.google.firebase:firebase-messaging")`
        )
      }
      return modConfig
    })

    config = withAndroidManifest(config, (modConfig) => {
      const application = AndroidConfig.Manifest.getMainApplicationOrThrow(
        modConfig.modResults
      )
      const services = application.service || []
      if (!services.some((service) => service.$['android:name'] === SERVICE_NAME)) {
        services.push({
          $: {
            'android:name': SERVICE_NAME,
            'android:exported': 'false',
          },
          'intent-filter': [
            {
              action: [{ $: { 'android:name': 'com.google.firebase.MESSAGING_EVENT' } }],
            },
          ],
        })
      }
      application.service = services
      return modConfig
    })
  }

  return config
}
