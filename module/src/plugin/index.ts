import type { ConfigPlugin } from '@expo/config-plugins'
import { withAndroid } from './withAndroid'
import { withIos } from './withIos'

export interface UserComPluginOptions {
  /**
   * Custom notification channel name for Android
   * @default "Notifications"
   */
  androidNotificationChannelName?: string
  apiKey: string
  integrationsApiKey: string
  domain: string
}

/**
 * Configures Android and iOS projects with User.com SDK and required settings
 */
const withUserCom: ConfigPlugin<UserComPluginOptions> = (config, options) => {
  config = withAndroid(config, options)
  config = withIos(config)
  return config
}

export default withUserCom
