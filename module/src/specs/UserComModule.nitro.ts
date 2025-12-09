import type { HybridObject } from 'react-native-nitro-modules'

export type UserComModuleAttributeValue = number | string | boolean
export type UserComModuleUserKey = string
// iOS API does not return UserKey
export type UserComModuleRegisterUserResponse = UserComModuleUserKey | null

export interface UserComModuleUserData {
  id: string
  email?: string
  firstName?: string
  lastName?: string
  attributes?: Record<string, UserComModuleAttributeValue>
}

export interface UserComModuleConfig {
  apiKey: string
  integrationsApiKey: string
  domain: string
  trackAllActivities?: boolean
  openLinksInChromeCustomTabs?: boolean
  initTimeoutMs?: number
  defaultCustomer?: UserComModuleUserData
  // TODO: Custom tabs are not supported yet
}

export interface UserComModule extends HybridObject<{
  android: 'kotlin'
  ios: 'swift'
}> {
  initialize(config: UserComModuleConfig): Promise<void>
  registerUser(
    userData: UserComModuleUserData
  ): Promise<UserComModuleRegisterUserResponse>
  logout(): Promise<void>
  // sendEvent(eventName: string, data: string): Promise<void>
}
