#include <jni.h>
#include "NitroUsercomOnLoad.hpp"

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  return margelo::nitro::usercom::initialize(vm);
}
