import { NitroModules } from 'react-native-nitro-modules'
import type { UserComModule } from './specs/UserComModule.nitro'

export const userComModule =
  NitroModules.createHybridObject<UserComModule>('UserComModule')
