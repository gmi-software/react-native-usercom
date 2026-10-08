import { NitroModules } from 'react-native-nitro-modules'
import type {
  UserComModule as UserComModuleType,
  UserComModuleUserData,
} from './specs/UserComModule.nitro'
import { UserComProductEventType } from './specs/UserComModule.nitro'

export type { UserComModuleUserData }
export type {
  UserComModule as UserComModuleType,
  UserComModuleConfig,
  UserComModuleRegisterUserResponse,
} from './specs/UserComModule.nitro'

export { UserComProductEventType }

export const UserComModule =
  NitroModules.createHybridObject<UserComModuleType>('UserComModule')
