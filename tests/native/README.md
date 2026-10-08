# Native messaging regression tests

Run from the repository root:

```sh
python3 tests/native/run.py --platform ios --thread-sanitizer
python3 tests/native/run.py --platform android
```

The iOS fixture needs macOS/Xcode. Android needs a JDK and the Kotlin compiler/runtime, annotations, coroutines and JSON jars in the Gradle cache; build the Android example first to populate it. Set `JAVA_HOME` or `GRADLE_USER_HOME` when needed. Compilation outputs are created in a temporary directory and removed automatically. Tests use in-memory preferences and fake HTTP connections; they do not contact Firebase/User.com or write app credentials.

- Swift: 10 cases against the production `UserComPushApi`, including concurrent identity changes with Thread Sanitizer.
- Kotlin: 11 cases against the production `UserComPushApi`, including preserving automatically bound SDK token metadata after messaging opt-out.
- Kotlin registration bridge: 7 cases replay the production `registerUser` and `logout` method bodies with deterministic SDK/Firebase callbacks. They cover successful registration, optional follow-up token retrieval failures, storage failures, synchronous SDK failures and late callbacks after logout.

Both helpers test old deletion failures (404/410/401/429/503), new binding rejection, token transfer without a later stale deletion, retained original deletion credentials and cancellation during identity changes. The generated bridge harness uses minimal Nitro/Android/SDK types; it does not replace compiling the actual native module. Full native builds and manual campaign/link tests on devices are separate verification steps. Test files are outside `package/` and are not included in the published npm package.
