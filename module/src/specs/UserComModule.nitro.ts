import type { HybridObject } from 'react-native-nitro-modules'

export interface UserComModule extends HybridObject<{
  android: 'kotlin'
  ios: 'swift'
}> {
  initialize(): void
}
