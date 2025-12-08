import type { ConfigPlugin } from '@expo/config-plugins'
import { withAndroid } from './withAndroid'
import { withIos } from './withIos'

/**
 * Main config plugin for react-native-usercom
 * Configures Android and iOS projects with User.com SDK and required settings
 */
const withUserCom: ConfigPlugin = (config) => {
  config = withAndroid(config)
  config = withIos(config)
  return config
}

export default withUserCom
