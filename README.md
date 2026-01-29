# React Native UserCom

<div align="center">

A powerful React Native module for [User.com](https://user.com) SDK integration, enabling user tracking, engagement, and push notifications.

[![npm version](https://img.shields.io/npm/v/react-native-usercom.svg)](https://www.npmjs.com/package/react-native-usercom)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![TypeScript](https://img.shields.io/badge/TypeScript-Ready-blue.svg)](https://www.typescriptlang.org/)
[![Expo Compatible](https://img.shields.io/badge/Expo-Compatible-000020.svg)](https://expo.dev/)

Built with [Nitro Modules](https://nitro.margelo.com/) for high-performance native integration.

[Features](#features) • [Installation](#installation) • [Quick Start](#quick-start) • [Documentation](#documentation) • [API Reference](#api-reference)

</div>

---

## Features

- ✅ **User Management** - Complete user registration, login, and profile management
- ✅ **Event Tracking** - Track custom events and product interactions
- ✅ **Push Notifications** - Firebase-powered push notification system
- ✅ **Type-Safe** - Full TypeScript support with comprehensive type definitions
- ✅ **Cross-Platform** - Single API for iOS and Android platforms
- ✅ **Modern Architecture** - Built with Nitro Modules for optimal performance
- ✅ **Firebase Integration** - Seamless Firebase messaging integration
- ✅ **Expo Compatible** - Config plugins for seamless Expo integration
- ✅ **Production Ready** - Battle-tested user engagement platform

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
npm install react-native-usercom @react-native-firebase/app
# or
yarn add react-native-usercom @react-native-firebase/app
# or
bun add react-native-usercom @react-native-firebase/app
```

### Prerequisites

- React Native 0.76+
- React Native Nitro Modules (required)
- Expo SDK 52+ (if using Expo)
- iOS 15.1+
- Android API 21+

---

## Quick Start

### Basic Example with Hook (Recommended)

The easiest way to integrate User.com - one hook handles everything:

```typescript
import React, { useEffect } from 'react'
import { View, Text, Button, Alert } from 'react-native'
import { 
  UserComModule,
  UserComModuleUserData, 
  UserComProductEventType 
} from 'react-native-usercom'

function UserComExample() {
  // Initialize User.com SDK
  const initializeUserCom = async () => {
    try {
      await UserComModule.initialize({
        apiKey: 'your-api-key',
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
        timestamp: Date.now()
      })
      console.log('Event sent successfully')
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
        { category: 'electronics', price: 299.99 }
      )
      console.log('Product event sent successfully')
    } catch (error) {
      console.error('Failed to send product event:', error)
    }
  }

  // Send a screen event
  const sendScreenEvent = async () => {
    try {
      await UserComModule.sendScreenEvent('ProductDetailsScreen')
      console.log('Screen event sent successfully')
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

For a more structured approach, use the provided hook:

```typescript
import React, { useEffect } from 'react'
import { View, Button, Alert } from 'react-native'
import { useUserComHandler } from './hooks/useUserComHandler'
import { UserComProductEventType } from 'react-native-usercom'

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

User.com SDK requires Firebase for push notifications. You need to configure Firebase in your project:

### 1. Create a Firebase project

Go to [Firebase Console](https://console.firebase.google.com/) and create a new project (or use existing one).

### 2. Add Firebase configuration files

Download the configuration files from Firebase Console:

- **iOS**: `GoogleService-Info.plist` - place it in your project root
- **Android**: `google-services.json` - place it in your project root

## Platform Setup

### Expo Setup

Add the plugins to your `app.json`:

**Please note**\
*Regarding Expo 54*\
[Expo Issue `#39607`](https://github.com/expo/expo/issues/39607#issuecomment-3337284928) \
`buildReactNativeFromSource` is required for Expo 54 (this is a workaround and will give you longer build-times (no longer than in the previous Expo SDKs though)\
`"forceStaticLinking": ["RNFBApp"]` might be sufficient but was not tested


```json
{
  "expo": {
    "ios": {
      "googleServicesFile": "./GoogleService-Info.plist"
    },
    "android": {
      "googleServicesFile": "./google-services.json"
    },
    "plugins": [
      "@react-native-firebase/app",
      [
        "expo-build-properties",
        {
          "ios": {
            "useFrameworks": "static",
            "buildReactNativeFromSource": true // Regarding Expo 54 (read note above)
          }
        }
      ],
      "react-native-usercom"
    ]
  }
}
```

Note (Android / Expo): if you're using Expo with `prebuild`, you must ensure the User.com Maven repository is present in the generated Android Gradle files. The recommended approach is to inject the repository using `expo-build-properties` (configure it in `app.json` / `app.config.js`) so it is added automatically during `prebuild`. If you don't use `expo-build-properties`, add the required `maven { url 'https://android-sdk.user.com' }` manually to the generated `android/build.gradle` after running `npx expo prebuild`.

#### Plugin Options

The `react-native-usercom` plugin accepts configuration options:

```json
{
  "plugins": [
    [
      "react-native-usercom",
      {
        "androidNotificationChannelName": "Notifications"
      }
    ]
  ]
}
```

| Option                           | Type     | Default           | Description                                      |
| -------------------------------- | -------- | ----------------- | ------------------------------------------------ |
| `androidNotificationChannelName` | `string` | `"Notifications"` | Custom name for the Android notification channel |

The plugin will automatically register the static service `com.margelo.nitro.usercom.UserComMessagingService` in your AndroidManifest.xml. You do not need to provide a class name option.

> **⚠️ Important (iOS):** The `expo-build-properties` plugin with `"useFrameworks": "static"` is **required** for iOS. The User.com SDK (UserSDK) depends on Firebase, which requires static frameworks to work correctly with CocoaPods.

> **⚠️ Important:** The `@react-native-firebase/app` plugin must be added **before** `expo-build-properties` in the plugins array.

Then run:

```bash
npx expo prebuild --clean
```

### Bare React Native

For bare React Native projects, ensure your `Podfile` includes:

```ruby
platform :ios, '15.1'
use_frameworks! :linkage => :static
pod 'UserSDK', :git => 'https://github.com/UserEngage/iOS-SDK'
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

And in `android/app/build.gradle`:

```gradle
dependencies {
  implementation 'com.user:android-sdk:1.2.8'
}
```

---

## Documentation

### Android: Integrating with push notifications (UserComMessagingService)

To handle User.com notifications alongside React Native Firebase:

1. Ensure you have `@react-native-firebase/messaging` installed in your app (see example `package.json`).

2. For **Expo projects** (with prebuild): The plugin automatically registers the `UserComMessagingService` in your `AndroidManifest.xml`. However, you must copy the `UserComMessagingService.kt` file from the module to your app's Android source directory (e.g., `android/app/src/main/java/com/yourpackage/`) to ensure it is compiled into your APK.

   > **Note:** The service implementation is provided by the module. Simply copy `module/android/src/main/java/com/margelo/nitro/usercom/UserComMessagingService.kt` to your app's source directory.

3. For **Bare React Native projects**: Manually add the service entry to your `AndroidManifest.xml` and ensure the `UserComMessagingService.kt` is in your app's source.

   ```xml
   <service
     android:name=".UserComMessagingService"
     android:exported="false">
     <intent-filter>
       <action android:name="com.google.firebase.MESSAGING_EVENT" />
     </intent-filter>
   </service>
   ```

---

## Android: Implementing UserComMessagingService

The `UserComMessagingService.kt` extends `FirebaseMessagingService` to integrate User.com SDK with Firebase messaging.

It forwards incoming notifications to the User.com SDK and then to React Native Firebase for JavaScript handling.

---

## API Reference

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
  { category: 'electronics', price: 299.99 }
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

A custom hook that provides a convenient interface for User.com operations.

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

- React Native 0.76+
- Expo SDK 52+ (for Expo projects)
- iOS 15.1+
- Android API 21+

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
2. Run `cd android && ./gradlew clean`

---

## License

MIT
