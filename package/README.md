# react-native-usercom

React Native module for [User.com](https://user.com) SDK integration using [Nitro Modules](https://nitro.margelo.com/).

## Installation

```bash
npm install react-native-usercom @react-native-firebase/app
# or
yarn add react-native-usercom @react-native-firebase/app
# or
bun add react-native-usercom @react-native-firebase/app
```

## Firebase Configuration

User.com SDK requires Firebase for push notifications. You need to configure Firebase in your project:

### 1. Create a Firebase project

Go to [Firebase Console](https://console.firebase.google.com/) and create a new project (or use existing one).  

### 2. Add Firebase configuration files

Download the configuration files from Firebase Console:

- **iOS**: `GoogleService-Info.plist` - place it in your project root
- **Android**: `google-services.json` - place it in your project root

## Configuration

### Expo

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

## Android: Integrating with push notifications (UserComMessagingService)

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

If you need custom behavior, you can modify the copied `UserComMessagingService.kt` in your app's source directory.

## Usage

### Initialization (JS/TS)

You must initialize the User.com SDK from JavaScript/TypeScript using a config object. The initialization is asynchronous and returns a Promise:

## API Reference

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
}
```

### Methods

#### `initialize(config: UserComModuleConfig): Promise<void>`

Initializes the User.com SDK.

#### `registerUser(userData: UserComModuleUserData): Promise<UserComModuleRegisterUserResponse>`

Registers or updates a user in the User.com SDK.

#### `logout(): Promise<void>`

Logs out the current user from the User.com SDK.

#### `sendProductEvent(productId: string, eventType: UserComProductEventType, params?: AnyMap): Promise<void>`

Sends a product event to User.com.

#### `sendCustomEvent(eventName: string, data: AnyMap): Promise<void>`

Sends a custom event to User.com.

### `UserComModule.logout(): Promise<void>`

Logs out the current user from the User.com SDK.

```typescript
await UserComModule.logout()
````

## Requirements

- React Native 0.76+
- Expo SDK 52+ (for Expo projects)
- iOS 15.1+
- Android API 21+

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

## License

MIT
