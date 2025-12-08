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

## Usage

```typescript
import { UserComModule } from 'react-native-usercom'

// Initialize User.com SDK
UserComModule.initialize()
```

## API

### `UserComModule.initialize()`

Initializes the User.com SDK. Call this method early in your app lifecycle.

```typescript
import { UserComModule } from 'react-native-usercom'

UserComModule.initialize()
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
