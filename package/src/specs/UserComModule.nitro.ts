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
  phoneNumber?: string
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
  /** Gate message display independently from the host application's event tracking. */
  setMessagingEnabled(pushEnabled: boolean, inAppEnabled: boolean): void
  /** The host owns Firebase and requests OS permission; this only binds its token. */
  registerPushToken(token: string): Promise<void>
  /** Detaches the stored token, retaining failed removals for the next attempt. */
  unregisterPushToken(): Promise<void>
  /** Forward FCM data. Background callers must pass foreground=false. */
  handleNotification(
    data: AnyMap,
    foreground: boolean,
    opened: boolean
  ): Promise<boolean>
  setNotificationLinkHandler(handler: ((url: string) => void) | undefined): void
  /** Android SDK notifications use their own launcher intent rather than RNFB's. */
  consumeInitialNotification(): AnyMap | undefined
  sendProductEvent(
    productId: string,
    eventType: UserComProductEventType,
    params?: AnyMap
  ): Promise<void>
  sendCustomEvent(eventName: string, data: AnyMap): Promise<void>
  sendScreenEvent(screenName: string): Promise<void>
}
