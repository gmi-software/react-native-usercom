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

### 3. Configure app.json (Expo)

Add the Firebase configuration files to your `app.json`:

```json
{
  "expo": {
    "ios": {
      "googleServicesFile": "./GoogleService-Info.plist"
    },
    "android": {
      "googleServicesFile": "./google-services.json"
    }
  }
}
```

## Configuration

### Expo

Add the plugins to your `app.json`:

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
            "useFrameworks": "static"
          }
        }
      ],
      "react-native-usercom"
    ]
  }
}
```

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

pod 'UserSDK', :git => 'https://github.com/UserEngage/iOS-SDK'
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
    maven { url 'https://android-sdk.user.com' }
  }
}
```

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

```typescript
import { UserComModule } from 'react-native-usercom'

await UserComModule.initialize({
  apiKey: 'YOUR_API_KEY',
  integrationsApiKey: 'YOUR_INTEGRATIONS_API_KEY',
  domain: 'https://yourdomain.user.com/',
  // Optional:
  trackAllActivities: true,
  openLinksInChromeCustomTabs: false,
  initTimeoutMs: 2000,
})
```

If initialization fails (e.g. registration error, timeout), the Promise will reject with an error.

See the [example app](<../example/app/(tabs)/index.tsx>) for a usage pattern.

## API

### `UserComModule.initialize()`

Initializes the User.com SDK. Call this method early in your app lifecycle. Returns a Promise that resolves when the SDK is ready, or rejects on error.

```typescript
import { UserComModule } from 'react-native-usercom'

await UserComModule.initialize({
  apiKey: 'YOUR_API_KEY',
  integrationsApiKey: 'YOUR_INTEGRATIONS_API_KEY',
  domain: 'https://yourdomain.user.com/',
})
```

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
