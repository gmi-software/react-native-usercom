import { useCallback } from "react";
import { ValueType } from "react-native-nitro-modules";
import {
  UserComModule,
  UserComModuleUserData,
  UserComProductEventType,
} from "@gmisoftware/react-native-usercom";

export const useUserComHandler = () => {
  const initialize = useCallback(
    async (apiKey: string, domain: string, integrationsApiKey: string) => {
      try {
        return await UserComModule.initialize({
          apiKey,
          domain,
          integrationsApiKey,
          initTimeoutMs: 2000,
        });
      } catch (error) {
        console.error("JS:UserCom:init:error", error);
      }
    },
    []
  );

  const registerUser = useCallback(async (userData: UserComModuleUserData) => {
    try {
      console.log("JS:UserCom:registerUser start");
      return await UserComModule.registerUser(userData);
    } catch (error) {
      console.error("JS:UserCom:registerUser:error", error);
    }
  }, []);

  const sendCustomEvent = useCallback(
    async (eventName: string, data: Record<string, ValueType>) => {
      try {
        console.log("JS:UserCom:sendCustomEvent start");
        await UserComModule.sendCustomEvent(eventName, data);
        console.log("JS:UserCom:sendCustomEvent done");
      } catch (error) {
        console.error("JS:UserCom:sendCustomEvent:error", error);
      }
    },
    []
  );

  const sendProductEvent = useCallback(
    async (
      productId: string,
      eventType: UserComProductEventType,
      params?: Record<string, ValueType>
    ) => {
      try {
        console.log("JS:UserCom:sendProductEvent start");
        await UserComModule.sendProductEvent(productId, eventType, params);
        console.log("JS:UserCom:sendProductEvent done");
      } catch (error) {
        console.error("JS:UserCom:sendProductEvent:error", error);
      }
    },
    []
  );

  const sendScreenEvent = useCallback(async (screenName: string) => {
    try {
      console.log("JS:UserCom:sendScreenEvent start");
      await UserComModule.sendScreenEvent(screenName);
      console.log("JS:UserCom:sendScreenEvent done");
    } catch (error) {
      console.error("JS:UserCom:sendScreenEvent:error", error);
    }
  }, []);

  const logout = useCallback(async () => {
    console.log("JS:UserCom:logout");
    try {
      await UserComModule.logout();
      console.log("JS:UserCom:logout:done");
    } catch (error) {
      console.error("JS:UserCom:logout:error", error);
    }
  }, []);

  return {
    initialize,
    registerUser,
    sendCustomEvent,
    sendProductEvent,
    sendScreenEvent,
    logout,
  };
};
