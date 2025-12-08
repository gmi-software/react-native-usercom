import type { HybridObject } from 'react-native-nitro-modules'

export interface UserComCustomer {
  email: string
}

export interface UserComModuleConfig {
  apiKey: string
  integrationsApiKey: string
  domain: string
  trackAllActivities?: boolean
  openLinksInChromeCustomTabs?: boolean
  initTimeoutMs?: number
}
export interface UserComModule extends HybridObject<{
  android: 'kotlin'
  ios: 'swift'
}> {
  initialize(config: UserComModuleConfig): Promise<void>
}
