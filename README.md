# React Native UserCom

<div align="center">

A React Native bridge for [User.com](https://user.com) contact identity, event tracking, and optional push integration.

[![npm version](https://img.shields.io/npm/v/%40gmisoftware%2Freact-native-usercom.svg)](https://www.npmjs.com/package/@gmisoftware/react-native-usercom)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![TypeScript](https://img.shields.io/badge/TypeScript-Ready-blue.svg)](https://www.typescriptlang.org/)
[![Expo Compatible](https://img.shields.io/badge/Expo-Compatible-000020.svg)](https://expo.dev/)

Built with [Nitro Modules](https://nitro.margelo.com/) for high-performance native integration.

[Features](#features) • [Installation](#installation) • [Quick Start](#quick-start) • [Documentation](#documentation) • [API Reference](#api-reference)

</div>

---

## Features

- ✅ **Contact identity** - Register or update a User.com contact and reset it on logout; app authentication remains in the host app
- ✅ **Event tracking** - Send custom events, product events, and screen views
- ✅ **Android push receiver** - Bundled FCM service, registered by default for compatibility with 0.0.5; the host app must configure Firebase
- ✅ **Host-managed messaging** - Forward FCM messages, bind/unbind tokens, handle links, and gate push/in-app display independently from app events (0.0.7)
- ✅ **TypeScript API** - Typed methods and user data
- ✅ **iOS and Android** - One JavaScript API backed by native User.com SDKs
- ✅ **Nitro Modules** - Native bridge built with Nitro Modules
- ✅ **Expo config plugin** - Adds iOS UserSDK setup and controls Android FCM service registration

---

## Installation

### Step 1: Install React Native Nitro Modules

This package requires `react-native-nitro-modules` to work. Install it first:

```bash
npm install react-native-nitro-modules
# or
yarn add react-native-nitro-modules
# or
bun add react-native-nitro-modules
```

### Step 2: Install React Native UserCom

```bash
npm install @gmisoftware/react-native-usercom
# or
yarn add @gmisoftware/react-native-usercom
# or
bun add @gmisoftware/react-native-usercom
```

### Prerequisites

- React Native with New Architecture and `react-native-nitro-modules` 0.33.1+
- Expo development build (Expo Go does not include this native module)
- iOS 15.1+
- Android API level supported by the host app and native User.com SDK

---

## Quick Start

### Basic Example

Use the native module directly. This example initializes on mount. If your app requires consent, mount it only after consent or move `initializeUserCom()` behind your consent check:

```typescript
import React, { useEffect } from 'react'
import { View, Text, Button, Alert } from 'react-native'
import { 
  UserComModule,
  UserComModuleUserData, 
  UserComProductEventType 
} from '@gmisoftware/react-native-usercom'

function UserComExample() {
  // Initialize User.com SDK
  const initializeUserCom = async () => {
    try {
      await UserComModule.initialize({
        apiKey: 'your-mobile-sdk-key',
        integrationsApiKey: 'your-integrations-api-key',
        domain: 'your-domain.user.com',
        trackAllActivities: true,
        initTimeoutMs: 5000,
      })
      console.log('User.com initialized successfully')
    } catch (error) {
      console.error('Failed to initialize User.com:', error)
    }
  }

  // Register a user
  const registerUser = async () => {
    try {
      const userData: UserComModuleUserData = {
        id: 'user123',
        email: 'user@example.com',
        firstName: 'John',
        lastName: 'Doe',
        attributes: {
          plan: 'premium',
          signupDate: new Date().toISOString(),
        }
      }
      
      const result = await UserComModule.registerUser(userData)
      Alert.alert('Success', 'User registered successfully!')
    } catch (error) {
      Alert.alert('Error', 'Failed to register user')
      console.error('Registration error:', error)
    }
  }

  // Send a custom event
  const sendEvent = async () => {
    try {
      await UserComModule.sendCustomEvent('app_opened', {
        source: 'mobile_app',
        visit_count: 1
      })
      console.log('Event handed to the native SDK')
    } catch (error) {
      console.error('Failed to send event:', error)
    }
  }

  // Send a product event
  const sendProductEvent = async () => {
    try {
      await UserComModule.sendProductEvent(
        'product123',
        UserComProductEventType.View,
        { category: 'electronics', quantity: 1 }
      )
      console.log('Product event handed to the native SDK')
    } catch (error) {
      console.error('Failed to send product event:', error)
    }
  }

  // Send a screen event
  const sendScreenEvent = async () => {
    try {
      await UserComModule.sendScreenEvent('ProductDetailsScreen')
      console.log('Screen event handed to the native SDK')
    } catch (error) {
      console.error('Failed to send screen event:', error)
    }
  }

  // Logout user
  const logout = async () => {
    try {
      await UserComModule.logout()
      Alert.alert('Success', 'User logged out successfully!')
    } catch (error) {
      console.error('Failed to logout:', error)
    }
  }

  useEffect(() => {
    initializeUserCom()
  }, [])

  return (
    <View style={{ padding: 20 }}>
      <Text style={{ fontSize: 20, marginBottom: 20 }}>User.com Integration</Text>
      
      <Button title="Register User" onPress={registerUser} />
      <View style={{ height: 10 }} />
      
      <Button title="Send Custom Event" onPress={sendEvent} />
      <View style={{ height: 10 }} />
      
      <Button title="Send Product Event" onPress={sendProductEvent} />
      <View style={{ height: 10 }} />
      
      <Button title="Send Screen Event" onPress={sendScreenEvent} />
      <View style={{ height: 10 }} />
      
      <Button title="Logout" onPress={logout} />
    </View>
  )
}

export default UserComExample
```

### Using the Custom Hook

The repository includes an optional example hook at `example/hooks/useUserComHandler.ts`. It is not part of the published package API:

```typescript
import React, { useEffect } from 'react'
import { View, Button, Alert } from 'react-native'
import { useUserComHandler } from './hooks/useUserComHandler'
import { UserComProductEventType } from '@gmisoftware/react-native-usercom'

function UserComWithHook() {
  const { initialize, registerUser, sendCustomEvent, sendProductEvent, logout } = useUserComHandler()

  useEffect(() => {
    const initUserCom = async () => {
      await initialize(
        'your-api-key',
        'your-domain.user.com', 
        'your-integrations-api-key'
      )
    }
    initUserCom()
  }, [initialize])

  const handleRegisterUser = async () => {
    const result = await registerUser({
      id: 'user123',
      email: 'user@example.com',
      firstName: 'John',
      lastName: 'Doe'
    })
    if (result) {
      Alert.alert('Success', 'User registered!')
    }
  }

  return (
    <View style={{ padding: 20 }}>
      <Button title="Register User" onPress={handleRegisterUser} />
      <Button title="Send Event" onPress={() => sendCustomEvent('test_event', { key: 'value' })} />
      <Button title="Product View" onPress={() => sendProductEvent('prod123', UserComProductEventType.View)} />
      <Button title="Logout" onPress={logout} />
    </View>
  )
}
```

---

## Firebase Configuration

The package does not require `@react-native-firebase/messaging` for event tracking. On Android, User.com SDK 1.2.14 itself includes native Firebase dependencies and retrieves an FCM token during contact registration, so valid native Firebase configuration is still required for that registration path. The iOS SDK has no Firebase dependency for analytics. Configure the host's messaging stack if it needs User.com push notifications.

### 1. Create a Firebase project

Go to [Firebase Console](https://console.firebase.google.com/) and create a new project (or use existing one).

### 2. Add Firebase configuration files

Download the configuration files from Firebase Console:

- **iOS**: `GoogleService-Info.plist` - place it in your project root
- **Android**: `google-services.json` - place it in your project root

## Platform Setup

React Native Firebase is not a package peer dependency. The native User.com SDKs may bring their own Firebase dependencies; keep the iOS framework configuration shown below. To use FCM, install and configure Firebase in the host application.

### Expo Setup

Add the plugins to your `app.json`:

```json
{
  "expo": {
    "plugins": [
      [
        "expo-build-properties",
        {
          "ios": { "useFrameworks": "static", "deploymentTarget": "15.1" },
          "android": { "extraMavenRepos": ["https://android-sdk.user.com"] }
        }
      ],
      "@gmisoftware/react-native-usercom"
    ]
  }
}
```

Note (Android / Expo): if you're using Expo with `prebuild`, you must ensure the User.com Maven repository is present in the generated Android Gradle files. The recommended approach is to inject the repository using `expo-build-properties` (configure it in `app.json` / `app.config.js`) so it is added automatically during `prebuild`. If you don't use `expo-build-properties`, add the required `maven { url 'https://android-sdk.user.com' }` manually to the generated `android/build.gradle` after running `npx expo prebuild`.

Expo SDK 54 projects that hit the [upstream native build issue](https://github.com/expo/expo/issues/39607) may still need `buildReactNativeFromSource: true` in the iOS `expo-build-properties` options. Enable this workaround only when affected; it increases build time.

#### Plugin options

Add the options to the plugin entry inside `expo.plugins`:

```json
{
  "expo": {
    "plugins": [
      [
        "@gmisoftware/react-native-usercom",
        {
          "androidNotificationChannelName": "Notifications",
          "androidRegisterMessagingService": false
        }
      ]
    ]
  }
}
```

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `androidNotificationChannelName` | `string` | unset | Adds `user_com_channel_name` to Android strings. |
| `androidRegisterMessagingService` | `boolean` | `true` | Adds Firebase Messaging to the Android app and registers the package FCM service, as in 0.0.5. Set `false` when another FCM service handles messages or the app only needs event tracking. |

The package's Android module declares `com.user:android-sdk:1.2.14`; do not add it a second time to the app. The iOS plugin pins `UserSDK` to tag `1.1.1`. Static frameworks are required for this iOS integration. If your app uses React Native Firebase, configure its own Expo plugin according to its documentation.

Pass the User.com workspace host (such as `your-domain.user.com`) or its `https://` URL to `initialize`. The bridge normalizes this for the platform: the Android SDK receives a full URL ending in `/` and the iOS SDK receives a host.

Then run:

```bash
npx expo prebuild --clean
```

### Upgrading from 0.0.5

Version 0.0.6 keeps Android push registration enabled by default for existing applications. Set `androidRegisterMessagingService: false` and rebuild when another Firebase messaging service handles messages or the app only needs event tracking. Apps with another Firebase messaging service must forward User.com messages from that service as described below. Event tracking does not require React Native Firebase.

On Android, `registerUser({ attributes })` accepts integer, string, and boolean values. Fractional numbers now reject the registration call instead of being silently truncated to integers. The native Android User.com SDK documents only integer numeric event attributes; verify fractional event values on a User.com timeline before relying on them for cross-platform segments.

### Bare React Native

For bare React Native projects, ensure your `Podfile` includes:

```ruby
platform :ios, '15.1'
use_frameworks! :linkage => :static
pod 'UserSDK', :git => 'https://github.com/UserEngage/iOS-SDK.git', :tag => '1.1.1'
```

To customize the Android notification channel name, add to your `android/app/src/main/res/values/strings.xml`:

```xml
<string name="user_com_channel_name">Promotions</string>
```

For Android, add to your `android/build.gradle`:

```gradle
allprojects {
  repositories {
    // ...other repositories...
    maven { url 'https://android-sdk.user.com' }
  }
}
```

This repository is required so Gradle can resolve User.com artifacts (e.g. `com.user:android-sdk`).

The package's Android library already declares `com.user:android-sdk:1.2.14`. Do not duplicate it in the app unless the app's own native code calls User.com directly.

---

## Documentation

### Android: Firebase push notifications

The package includes `UserComMessagingService` and registers it by default for compatibility with 0.0.5. Firebase Messaging is optional for analytics-only applications: set `androidRegisterMessagingService: false` to omit it. If this service will be the app's sole FCM receiver:

1. Configure Firebase in the host app, including `google-services.json`. Expo apps can use `@react-native-firebase/app` for this setup.
2. Keep `androidRegisterMessagingService` enabled (the default) in the Expo plugin options. The plugin adds the Android Firebase Messaging runtime dependency and registers `com.margelo.nitro.usercom.UserComMessagingService`. In a bare app, add the runtime dependency yourself and register the same class with the `com.google.firebase.MESSAGING_EVENT` intent filter.
3. Test a User.com push on a device. The packaged service processes User.com messages only; apps needing their own message routing should use their existing FCM service instead.

If the app already has a `FirebaseMessagingService`, including one installed by `@react-native-firebase/messaging`, **do not register a competing service**. Forward messages from the existing service using `UserCom.getInstance().onNotification(applicationContext, remoteMessage)` and handle a message as the app normally does if that call returns `false`. The app's native module must add a direct `com.user:android-sdk:1.2.14` dependency for this call. See the [User.com Android notification guide](https://apidocs.user.com/mobilesdk/android/receiving-a-notification.html). On iOS, configure push permission, capabilities and Firebase in the host application according to the [User.com iOS guide](https://apidocs.user.com/mobilesdk/ios/receiving-a-notification.html). The bridge does not request notification permission.

The bundled Android messaging service can process a User.com message only after the SDK has been initialized. It currently drops messages received before `initialize()` runs, including some cold-start deliveries. Apps that need reliable Android push delivery must initialize the native SDK before FCM messages arrive or implement their own message handling. Choose the initialization point according to the host app's consent rules.

---

## API Reference

### Host-managed push and in-app messages (0.0.7)

The package does not request notification permission or choose your consent rules. The host owns authentication, Firebase configuration, OS permission, background handlers, and navigation. Analytics consent and messaging preference can be independent. Gate calls to `sendCustomEvent`, `sendScreenEvent`, and `sendProductEvent` in the host; disabling those calls does not suppress native SDK contact/device requests or its message view/click tracking.

A host may use one OS permission result to enable both push and in-app, or keep separate choices. That policy belongs to the host; the package retains independent `pushEnabled` and `inAppEnabled` flags.

When using React Native Firebase Messaging, set `androidRegisterMessagingService: false`. Keep one FCM receiver. Install matching versions of `@react-native-firebase/app` and `@react-native-firebase/messaging` in the host, not in this package. The iOS UserSDK 1.1.1 has no Firebase dependency. Android's upstream SDK includes native Firebase dependencies and automatically registers a token during `registerUser`.

After successful `initialize` and `registerUser`:

```ts
// Decide these values using the host's preferences and OS permission.
UserComModule.setMessagingEnabled(pushAllowed, inAppAllowed)
UserComModule.setNotificationLinkHandler(url => openValidatedLink(url))
await UserComModule.registerPushToken(fcmToken)

// Forward string-valued FCM data from foreground/background listeners.
// Preserve messageId as 'gcm.message_id' for iOS local notification taps.
await UserComModule.handleNotification(data, isForeground, false)

// For a tapped push, after auth and navigation are ready:
await UserComModule.handleNotification(data, true, true)
```

`handleNotification` returns whether the User.com message was handled. In-app messages are displayed only with `inAppAllowed` and `isForeground`; background callers must never pass `true`. If FCM/APNs already displayed a notification payload in the background, do not forward it for display again. Still forward its tap with `opened=true`. In-app links use the registered link handler. Validate URLs in the host before navigation.

On iOS, a resolved `handleNotification` promise confirms forwarding to the native SDK or scheduling local display, not that an in-app view or banner became visible. Verify actual push/in-app delivery and links on devices; successful compilation and token registration alone do not confirm campaign delivery.

For Android SDK-generated notifications, call `consumeInitialNotification()` after identity/navigation are ready and forward that data as an opened push. Warm launcher intents also invoke the link handler. RNFB handles iOS local taps when the original FCM message ID is forwarded; other push stacks must forward their notification-center responses. The iOS bridge preserves the host's notification delegate when showing its own local foreground banners.

On token rotation, call `registerPushToken` again. In a host using React Native Firebase Messaging, opt-out cleanup can use:

```ts
import { getMessaging, setAutoInitEnabled, deleteToken } from '@react-native-firebase/messaging'

UserComModule.setMessagingEnabled(false, false) // immediate display gate
const results = await Promise.allSettled([
  Promise.resolve().then(() => UserComModule.unregisterPushToken()),
  (async () => {
    try { await setAutoInitEnabled(getMessaging(), false) }
    finally { await deleteToken(getMessaging()) }
  })(),
])
const failure = results.find(result => result.status === 'rejected')
if (failure?.status === 'rejected') throw failure.reason
```

For logout, use `UserComModule.logout()` instead of `unregisterPushToken()` in that example to reset the SDK and clear the bridge's contact identity as well. With other Firebase stacks, implement equivalent cleanup: attempt Firebase invalidation even when User.com removal fails. Persist the opt-out so cold/background launches cannot enable messaging again.

Logout also clears queued links and the JS link callback; install the handler again after identifying the next contact. The host must retain its native notification-center delegate, as required by Apple's weak `delegate` property; the bridge forwards to it without taking over its lifetime.

`registerPushToken` and `unregisterPushToken` use the documented Mobile SDK `ping` and `delete-fcm-token` endpoints. A successful new binding is not rejected by an older removal failure. Pending removals retain their original contact/workspace and are retried; DELETE 404/410 counts as already removed, while authentication, throttling and network failures remain pending. Successful ping transfers the token to the current contact, so older removal records for that same workspace/token are discarded to avoid deleting the new binding. Logout clears the active bridge identity immediately while preserving old removal records. No privileged public REST API key is needed.

**Limits to test before release:** Android SDK 1.2.14 has no logout-completed callback: `logout()` waits for stored-token removal and dispatches the SDK reset, but cannot acknowledge the later anonymous registration. Verify logout/account changes on devices. In analytics-only mode Android SDK still obtains a token during contact registration: explicitly unbind it and invalidate it in Firebase. OS-displayed alert payloads cannot be canceled by a JS consent check that runs afterward. Rich iOS push images need a Notification Service Extension and are outside this bridge's text-push setup.

For iOS, enable the Push Notifications capability, `aps-environment` with a matching signing profile, and the `remote-notification` background mode. Upload APNs credentials to the host's Firebase project and its Firebase service-account credentials to User.com's SDK Admin. Keep service-account/APNs secrets out of app envs. See [UserSDK 1.1.1](https://github.com/UserEngage/iOS-SDK/blob/1.1.1/README.md), [Mobile SDK token endpoints](https://apidocs.user.com/mobilesdk/push-without-sdk.html), and [RNFB messaging](https://rnfirebase.io/messaging/usage).

| New method | Purpose |
| --- | --- |
| `setMessagingEnabled(pushEnabled, inAppEnabled): void` | Native display gates; does not request permission or change app event consent. |
| `registerPushToken(token): Promise<void>` | Bind the host's FCM token to the identified contact. |
| `unregisterPushToken(): Promise<void>` | Detach the stored token and retry pending removals. |
| `handleNotification(data, foreground, opened): Promise<boolean>` | Display a received message or record an opened push. |
| `setNotificationLinkHandler(handler \| undefined): void` | Route validated push/in-app URLs in the host. |
| `consumeInitialNotification(): AnyMap \| undefined` | Consume Android SDK launcher data; iOS returns `undefined`. |

### `UserComModule`

The main module for User.com SDK integration.

#### Methods

##### `initialize(config: UserComModuleConfig): Promise<void>`

Initializes the User.com SDK.

```typescript
await UserComModule.initialize({
  apiKey: 'your-api-key',
  integrationsApiKey: 'your-integrations-api-key',
  domain: 'your-domain.user.com',
  trackAllActivities: true,
  initTimeoutMs: 5000,
})
```

##### `registerUser(userData: UserComModuleUserData): Promise<UserComModuleRegisterUserResponse>`

Registers or updates a user in the User.com SDK.

```typescript
const result = await UserComModule.registerUser({
  id: 'user123',
  email: 'user@example.com',
  firstName: 'John',
  lastName: 'Doe',
  phoneNumber: '+15551234567',
  attributes: {
    plan: 'premium',
    signupDate: new Date().toISOString(),
  }
})
```

##### `sendCustomEvent(eventName: string, data: AnyMap): Promise<void>`

Sends a custom event to User.com.

```typescript
await UserComModule.sendCustomEvent('app_opened', {
  source: 'mobile_app',
  timestamp: Date.now()
})
```

##### `sendProductEvent(productId: string, eventType: UserComProductEventType, params?: AnyMap): Promise<void>`

Sends a product event to User.com.

```typescript
await UserComModule.sendProductEvent(
  'product123',
  UserComProductEventType.View,
  { category: 'electronics', quantity: 1 }
)
```

##### `sendScreenEvent(screenName: string): Promise<void>`

Sends a screen view event to User.com for tracking user navigation.

```typescript
await UserComModule.sendScreenEvent('HomeScreen')
```

##### `logout(): Promise<void>`

Logs out the current user from the User.com SDK.

```typescript
await UserComModule.logout()
```

---

### Types

#### `UserComModuleAttributeValue`

```ts
type UserComModuleAttributeValue = number | string | boolean
```

#### `UserComModuleUserData`

```ts
interface UserComModuleUserData {
  id: string
  email?: string
  firstName?: string
  lastName?: string
  phoneNumber?: string
  attributes?: Record<string, UserComModuleAttributeValue>
}
```

#### `UserComModuleConfig`

```ts
interface UserComModuleConfig {
  apiKey: string
  integrationsApiKey: string
  domain: string
  trackAllActivities?: boolean
  openLinksInChromeCustomTabs?: boolean
  initTimeoutMs?: number
  defaultCustomer?: UserComModuleUserData
}
```

#### `UserComProductEventType`

```ts
enum UserComProductEventType {
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
```

---

### Hook: `useUserComHandler`

The repository example hook provides a convenient interface for User.com operations. Copy and adapt it if needed; it is not exported by the package.

```typescript
import { useUserComHandler } from './hooks/useUserComHandler'

const {
  initialize,
  registerUser,
  sendCustomEvent,
  sendProductEvent,
  sendScreenEvent,
  logout
} = useUserComHandler()
```

#### Methods

- `initialize(apiKey: string, domain: string, integrationsApiKey: string): Promise<void>`
- `registerUser(userData: UserComModuleUserData): Promise<UserComModuleRegisterUserResponse | undefined>`
- `sendCustomEvent(eventName: string, data: Record<string, ValueType>): Promise<void>`
- `sendProductEvent(productId: string, eventType: UserComProductEventType, params?: Record<string, ValueType>): Promise<void>`
- `sendScreenEvent(screenName: string): Promise<void>`
- `logout(): Promise<void>`

---

## Requirements

- React Native with New Architecture and `react-native-nitro-modules` 0.33.1+
- Expo development build (Expo Go does not include this native module)
- iOS 15.1+
- Android API level supported by the host app and native User.com SDK

---

## Troubleshooting

### iOS Build Errors

If you encounter build errors related to `UserSDK` or `Gifu`, ensure:

1. `expo-build-properties` is configured with `useFrameworks: "static"` and `deploymentTarget: "15.1"`
2. Run `npx expo prebuild --clean` after making changes
3. Clear Xcode DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`

### Android Build Errors

If you encounter missing dependency errors:

1. Ensure the User.com maven repository is added to `android/build.gradle`
2. Rebuild the native app after changing the Maven repository or plugin options

---

## License

MIT
