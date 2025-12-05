import { NitroModules } from 'react-native-nitro-modules'
import type { UserComModule as UserComModuleType } from './specs/UserComModule.nitro'

export const UserComModule =
  NitroModules.createHybridObject<UserComModuleType>('UserComModule')
