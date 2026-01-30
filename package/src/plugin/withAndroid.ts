import {
  withAppBuildGradle,
  withStringsXml,
  withAndroidManifest,
  AndroidConfig,
} from '@expo/config-plugins'
import type { ConfigPlugin } from '@expo/config-plugins'
import type { UserComPluginOptions } from './index'

type ManifestService = NonNullable<
  AndroidConfig.Manifest.ManifestApplication['service']
>[number]

const USERCOM_DEPENDENCY = 'com.user:android-sdk:1.2.8'

/**
 * Adds User.com SDK dependency to app/build.gradle
 */
const withUserComDependency: ConfigPlugin = (config) => {
  return withAppBuildGradle(config, (modConfig) => {
    const contents = modConfig.modResults.contents

    if (contents.includes(USERCOM_DEPENDENCY)) {
      return modConfig
    }

    const dependenciesPattern = /dependencies\s*\{/

    if (dependenciesPattern.test(contents)) {
      modConfig.modResults.contents = contents.replace(
        dependenciesPattern,
        (match) => {
          return `${match}
    implementation("${USERCOM_DEPENDENCY}")`
        }
      )
    } else {
        console.warn(
            '[UserCom] Could not find dependencies block in build.gradle. SDK dependency was not added.'
        );
    }

    return modConfig
  })
}

/**
 * Adds custom notification channel name to strings.xml according to https://apidocs.user.com/mobilesdk/android/receiving-a-notification.html
 */
const withNotificationChannelName: ConfigPlugin<UserComPluginOptions> = (
  config,
  options
) => {
  if (!options.androidNotificationChannelName) {
    return config
  }

  return withStringsXml(config, (modConfig) => {
    const strings = modConfig.modResults.resources.string || []

    const filtered = strings.filter(
      (item: { $: { name: string } }) => item.$.name !== 'user_com_channel_name'
    )

    filtered.push({
      $: { name: 'user_com_channel_name' },
      _: options.androidNotificationChannelName!,
    })

    modConfig.modResults.resources.string = filtered
    return modConfig
  })
}

/**
 * Registers UserComMessagingService in AndroidManifest.xml if class is provided.
 */
const withUserComMessagingService: ConfigPlugin = (config) => {
  // Always register the static UserComMessagingService class

  return withAndroidManifest(config, (modConfig) => {
    const mainApplication = AndroidConfig.Manifest.getMainApplicationOrThrow(
      modConfig.modResults
    )

    const services = mainApplication.service || []
    const serviceExists = services.some(
      (service: { $: { 'android:name': string } }) =>
        service.$['android:name'] ===
        'com.margelo.nitro.usercom.UserComMessagingService'
    )

    if (serviceExists) return modConfig

    const newService: ManifestService = {
      '$': {
        'android:name': 'com.margelo.nitro.usercom.UserComMessagingService',
        'android:exported': 'false',
      },
      'intent-filter': [
        {
          action: [
            {
              $: {
                'android:name': 'com.google.firebase.MESSAGING_EVENT',
              },
            },
          ],
        },
      ],
    }
    services.push(newService)

    mainApplication.service = services

    return modConfig
  })
}

/**
 * Configures Android project with User.com SDK
 */
export const withAndroid: ConfigPlugin<UserComPluginOptions> = (
  config,
  options
) => {
  config = withUserComDependency(config)
  config = withNotificationChannelName(config, options)
  config = withUserComMessagingService(config)
  return config
}
