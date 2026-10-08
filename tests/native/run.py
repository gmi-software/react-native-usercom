#!/usr/bin/env python3
"""Run native token/identity regression fixtures without Firebase or User.com network access."""
import argparse
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--platform", choices=("ios", "android", "all"), default="all")
parser.add_argument("--thread-sanitizer", action="store_true", help="Enable Swift Thread Sanitizer")
args = parser.parse_args()
repo = Path(__file__).resolve().parents[2]
fixtures = repo / "tests/native"
with tempfile.TemporaryDirectory(prefix="usercom-native-tests-") as directory:
    output = Path(directory)
    if args.platform in ("ios", "all"):
        command = ["xcrun", "swiftc", "-swift-version", "5", "-module-cache-path", str(output / "swift-cache")]
        if args.thread_sanitizer:
            command += ["-sanitize=thread"]
        binary = output / "push-ios-tests"
        command += [str(fixtures / "PushApiTests.swift"), str(repo / "package/ios/UserComPushApi.swift"), "-o", str(binary)]
        subprocess.run(command, check=True)
        subprocess.run([str(binary)], check=True)
    if args.platform in ("android", "all"):
        cache = Path(os.environ.get("GRADLE_USER_HOME", str(Path.home() / ".gradle"))) / "caches/modules-2/files-2.1"
        def binary_jars(group, artifact, version=None):
            folder = cache / group / artifact
            matches = list((folder / version).glob("*/*.jar")) if version else list(folder.glob("*/*/*.jar"))
            # Maven classifiers (sources, javadoc, tests) are not runtime libraries.
            return [path for path in matches if path.name == f"{artifact}-{path.parent.parent.name}.jar"]

        def jar(group, artifact, version=None):
            matches = binary_jars(group, artifact, version)
            if not matches:
                raise SystemExit(f"Missing cached {group}:{artifact}. Build the Android example first to populate Gradle dependencies.")
            return str(max(matches, key=lambda path: (tuple(int(n) for n in re.findall(r"\d+", path.parent.parent.name)), str(path))))
        compiler_jars = binary_jars("org.jetbrains.kotlin", "kotlin-compiler-embeddable")
        if not compiler_jars:
            raise SystemExit("Build the Android example first to cache the Kotlin compiler.")
        compiler_version = max(compiler_jars, key=lambda path: tuple(int(n) for n in re.findall(r"\d+", path.parent.parent.name))).parent.parent.name
        java_root = os.environ.get("JAVA_HOME")
        java = str(Path(java_root) / "bin/java") if java_root else shutil.which("java")
        compiler = [jar("org.jetbrains.kotlin", "kotlin-compiler-embeddable", compiler_version),
                    jar("org.jetbrains.kotlin", "kotlin-stdlib", compiler_version),
                    jar("org.jetbrains.kotlin", "kotlin-script-runtime", compiler_version),
                    jar("org.jetbrains.kotlin", "kotlin-reflect"),
                    jar("org.jetbrains.kotlin", "kotlin-daemon-embeddable", compiler_version),
                    jar("org.jetbrains.kotlinx", "kotlinx-coroutines-core-jvm"),
                    jar("org.jetbrains", "annotations")]
        trove = binary_jars("org.jetbrains.intellij.deps", "trove4j")
        if trove:
            compiler.append(jar("org.jetbrains.intellij.deps", "trove4j"))
        stdlib = jar("org.jetbrains.kotlin", "kotlin-stdlib", compiler_version)
        json = jar("org.json", "json")
        annotations = jar("org.jetbrains", "annotations")
        kotlin_output = output / "kotlin"
        sources = [str(path) for path in (fixtures / "android").glob("*.kt")]
        sources += [str(repo / "package/android/src/main/java/com/margelo/nitro/usercom/UserComPushApi.kt")]
        subprocess.run([java, "-cp", os.pathsep.join(compiler), "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler",
                        "-no-stdlib", "-no-reflect", "-jvm-target", "11", "-classpath",
                        os.pathsep.join((stdlib, json, annotations)), "-d", str(kotlin_output), *sources], check=True)
        subprocess.run([java, "-cp", os.pathsep.join((str(kotlin_output), stdlib, json)),
                        "com.margelo.nitro.usercom.PushApiTestsKt"], check=True)
        # Exercise real register/logout bodies with deterministic SDK/Task callbacks.
        module = (repo / "package/android/src/main/java/com/margelo/nitro/usercom/HybridUserComModule.kt").read_text()
        start = module.index("    override fun registerUser(")
        end = module.index("    override fun sendProductEvent(", start)
        bridge = output / "RegistrationBridgeTests.kt"
        bridge.write_text((fixtures / "RegistrationBridgeTests.kt.template").read_text().replace("// PRODUCTION_METHODS", module[start:end]))
        helpers = output / "PushFixtureSupport.kt"
        helpers.write_text((fixtures / "android/PushApiTests.kt").read_text().replace("fun main()", "private fun helperMain()"))
        bridge_sources = [str(fixtures / "android/Context.kt"), str(fixtures / "android/Log.kt"),
                          str(fixtures / "android/Handler.kt"), str(helpers), str(bridge),
                          str(repo / "package/android/src/main/java/com/margelo/nitro/usercom/UserComPushApi.kt")]
        bridge_output = output / "bridge"
        subprocess.run([java, "-cp", os.pathsep.join(compiler), "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler",
                        "-no-stdlib", "-no-reflect", "-jvm-target", "11", "-classpath",
                        os.pathsep.join((stdlib, json, annotations)), "-d", str(bridge_output), *bridge_sources], check=True)
        subprocess.run([java, "-cp", os.pathsep.join((str(bridge_output), stdlib, json)),
                        "com.margelo.nitro.usercom.RegistrationBridgeTestsKt"], check=True)
