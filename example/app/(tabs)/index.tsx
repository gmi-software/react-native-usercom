import { Image } from "expo-image";
import { Button, StyleSheet } from "react-native";

import ParallaxScrollView from "@/components/parallax-scroll-view";
import { ThemedView } from "@/components/themed-view";
import { useUserComHandler } from "@/hooks/useUserComHandler";
import { UserComProductEventType } from "@gmisoftware/react-native-usercom";

export default function HomeScreen() {
  const {
    initialize,
    registerUser,
    sendCustomEvent,
    sendProductEvent,
    logout,
  } = useUserComHandler();

  return (
    <ParallaxScrollView
      headerBackgroundColor={{ light: "#A1CEDC", dark: "#1D3D47" }}
      headerImage={
        <Image
          source={require("@/assets/images/partial-react-logo.png")}
          style={styles.reactLogo}
        />
      }
    >
      <ThemedView style={styles.stepContainer}>
        <Button
          title="Init UserCom SDK"
          onPress={() =>
            initialize(
              "randomApiKey",
              "https://com.lszpanelewski.example.user.com/",
              "randomIntApiKey"
            )
          }
        />
        <Button
          title="Register user"
          onPress={() => registerUser({ id: "react-native-usercom-test", firstName: "Test user!" })}
        />
        <Button
          title="Send custom event"
          onPress={() =>
            sendCustomEvent("generic", { json: JSON.stringify({hello: 'world'}) })
          }
        />
        <Button
          title="Send product event"
          onPress={() =>
            sendProductEvent(
              "product_id",
              UserComProductEventType.CheckoutOption,
              { price: 9.99 }
            )
          }
        />
        <Button title="Logout" onPress={() => logout()} />
      </ThemedView>
    </ParallaxScrollView>
  );
}

const styles = StyleSheet.create({
  titleContainer: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  stepContainer: {
    gap: 8,
    marginBottom: 8,
  },
  reactLogo: {
    height: 178,
    width: 290,
    bottom: 0,
    left: 0,
    position: "absolute",
  },
});
