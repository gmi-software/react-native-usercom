import type { AnyMap, HybridObject } from 'react-native-nitro-modules'

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

export enum UserComProductEventType {
  AddToCart,
  Purchase,
  Liking,
  AddToObservation,
  Order,
  Reservation,
  Return,
  View,
  Click,
  Detail,
  Add,
  Remove,
  Checkout,
  CheckoutOption,
  Refund,
  PromoClick,
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
  sendProductEvent(
    productId: string,
    eventType: UserComProductEventType,
    params?: AnyMap
  ): Promise<void>
  sendCustomEvent(eventName: string, data: AnyMap): Promise<void>
  sendScreenEvent(screenName: string): Promise<void>
}
