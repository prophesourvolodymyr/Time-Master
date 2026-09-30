#!/usr/bin/env python3
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
NATIVE = ROOT / "routing/native"
ENGINE = ROOT / "TimeMaster/Resources/OfflineRouting/engine.json"


def run(*arguments, cwd=None):
    subprocess.run([str(argument) for argument in arguments], cwd=cwd, check=True)


def main():
    parser = argparse.ArgumentParser(description="Build the pinned, network-free iOS routing XCFramework.")
    parser.add_argument("--source", type=Path, required=True, help="Valhalla checkout with recursive submodules")
    parser.add_argument("--vcpkg", type=Path, required=True, help="vcpkg checkout")
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "routing/TimeMasterRouting/TimeMasterRouting.xcframework")
    parser.add_argument("--jobs", type=int, default=4)
    args = parser.parse_args()
    args.source = args.source.resolve()
    args.vcpkg = args.vcpkg.resolve()
    args.work = args.work.resolve()
    args.output = args.output.resolve()
    engine = json.loads(ENGINE.read_text())
    revision = subprocess.check_output(["git", "-C", str(args.source), "rev-parse", "HEAD"], text=True).strip()
    if revision != engine["sourceRevision"]:
        parser.error("Valhalla checkout does not match the engine revision")
    if args.output.exists():
        parser.error("Output already exists; choose a new output rather than overwriting a framework")
    args.work.mkdir(parents=True, exist_ok=True)
    source = args.work / "source"
    if not source.exists():
        shutil.copytree(args.source, source, ignore=shutil.ignore_patterns(".git"))
        run("patch", "-d", source, "-p1", "-i", NATIVE / "terrain-goals.patch")
        run("patch", "-d", source, "-p1", "-i", NATIVE / "ios16-formatting.patch")
    if "timemaster_terrain_goal" not in (source / "proto/options.proto").read_text():
        raise RuntimeError("The copied native source is missing the terrain-goal patch")
    if "fmt/chrono.h" not in (source / "src/midgard/logging.cc").read_text():
        raise RuntimeError("The copied native source is missing the iOS 16 formatting patch")
    os.environ["VCPKG_MAX_CONCURRENCY"] = str(max(1, args.jobs))
    frameworks = []
    for triplet, sdk in [("arm64-ios-simulator", "iphonesimulator"), ("arm64-ios", "iphoneos")]:
        dependencies = args.work / ("deps-" + triplet)
        run(args.vcpkg / "vcpkg", "install", "--triplet", triplet,
            "--host-triplet", "arm64-osx-release", "--overlay-triplets=" + str(NATIVE / "triplets"),
            "--x-install-root=" + str(dependencies), "--clean-after-build", "--disable-metrics", cwd=NATIVE)
        build = args.work / triplet
        run("cmake", "-S", NATIVE, "-B", build, "-G", "Ninja",
            "-DVALHALLA_SOURCE=" + str(source),
            "-DCMAKE_TOOLCHAIN_FILE=" + str(args.vcpkg / "scripts/buildsystems/vcpkg.cmake"),
            "-DVCPKG_TARGET_TRIPLET=" + triplet, "-DVCPKG_HOST_TRIPLET=arm64-osx-release",
            "-DVCPKG_OVERLAY_TRIPLETS=" + str(NATIVE / "triplets"),
            "-DVCPKG_INSTALLED_DIR=" + str(dependencies), "-DVCPKG_MANIFEST_MODE=OFF",
            "-DCMAKE_SYSTEM_NAME=iOS", "-DCMAKE_OSX_SYSROOT=" + sdk,
            "-DCMAKE_OSX_ARCHITECTURES=arm64", "-DCMAKE_OSX_DEPLOYMENT_TARGET=16.0",
            "-DCMAKE_BUILD_TYPE=Release", "-DBUILD_SHARED_LIBS=OFF")
        run("cmake", "--build", build, "--target", "TMNativeRouting", "--parallel", max(1, args.jobs))
        frameworks.append(build / "TimeMasterRouting.framework")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    run("xcodebuild", "-create-xcframework", "-framework", frameworks[0], "-framework", frameworks[1], "-output", args.output)
    print("Prepared native iOS routing:", args.output)


if __name__ == "__main__":
    main()
