import {
  withProjectBuildGradle,
  withAppBuildGradle,
} from '@expo/config-plugins'
import type { ConfigPlugin } from '@expo/config-plugins'

const USERCOM_MAVEN_REPO = 'https://android-sdk.user.com'
const USERCOM_DEPENDENCY = 'com.user:android-sdk:1.2.8'

/**
 * Adds User.com Maven repository to android/build.gradle (allprojects.repositories)
 */
const withUserComMavenRepo: ConfigPlugin = (config) => {
  return withProjectBuildGradle(config, (modConfig) => {
    const contents = modConfig.modResults.contents

    if (contents.includes(USERCOM_MAVEN_REPO)) {
      return modConfig
    }

    const allProjectsRepoPattern = /allprojects\s*\{[\s\S]*?repositories\s*\{/

    if (allProjectsRepoPattern.test(contents)) {
      modConfig.modResults.contents = contents.replace(
        allProjectsRepoPattern,
        (match) => {
          return `${match}
    maven { url '${USERCOM_MAVEN_REPO}' }`
        }
      )
    }

    return modConfig
  })
}

/**
 * Adds User.com SDK dependency to app/build.gradle
 */
const withUserComDependency: ConfigPlugin = (config) => {
  return withAppBuildGradle(config, (modConfig) => {
    const contents = modConfig.modResults.contents

    if (contents.includes(USERCOM_DEPENDENCY)) {
      return modConfig
    }

    const dependenciesPattern = /dependencies\s*\{/

    if (dependenciesPattern.test(contents)) {
      modConfig.modResults.contents = contents.replace(
        dependenciesPattern,
        (match) => {
          return `${match}
    implementation("${USERCOM_DEPENDENCY}")`
        }
      )
    }

    return modConfig
  })
}

/**
 * Configures Android project with User.com SDK
 */
export const withAndroid: ConfigPlugin = (config) => {
  config = withUserComMavenRepo(config)
  config = withUserComDependency(config)
  return config
}
