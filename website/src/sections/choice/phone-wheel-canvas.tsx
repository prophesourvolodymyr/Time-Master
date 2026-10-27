"use client";

import { useEffect, useMemo, useRef } from "react";
import { Canvas, useFrame, useThree } from "@react-three/fiber";
import { PMREMGenerator, type Group, type PointLight } from "three";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";
import { siAndroid, siApple, siLinux } from "simple-icons";
import { familyLayouts, logoSequence, revealStart, type FamilyMember, type LogoClock, type Slot } from "./devices/crossplatform";
import { androidSpec, createDeviceKit, ease, iPhoneSpec, logoTexture, stage, type ScreenSource } from "./devices/device-parts";
import { Handset, Laptop, Monitor, Watch, type ScreenCrop, type ScreenFrame } from "./devices/devices";
import { focusWeight, type WheelState } from "./wheel";

export type FamilySources = Record<Exclude<FamilyMember, "iphone">, ScreenSource>;

export type PhoneWheelCanvasProps = {
  screens: readonly ScreenSource[];
  family: FamilySources;
  familyIndex: number;
  wheel: WheelState;
  active: boolean;
  onPick: (index: number) => void;
  className?: string;
};

const spacing = 1.5;
const playRange = 1.25;
const visibleRange = 4;
const watchCrop: ScreenCrop = { x: 0.1, y: 0.25, width: 0.8, height: 0.4527 };

function lerp(from: number, to: number, amount: number) {
  return from + (to - from) * amount;
}

function Studio() {
  const gl = useThree((state) => state.gl);
  const environment = useMemo(() => {
    const generator = new PMREMGenerator(gl);
    const room = new RoomEnvironment();
    const texture = generator.fromScene(room, 0.04).texture;
    room.dispose();
    generator.dispose();
    return texture;
  }, [gl]);

  useEffect(() => () => environment.dispose(), [environment]);

  useFrame((state) => {
    state.scene.environmentIntensity = 0.5;
  });

  return (
    <>
      <primitive object={environment} attach="environment" />
      <ambientLight intensity={0.2} />
      <directionalLight position={[-3, 4, 6]} intensity={1.1} />
      <directionalLight position={[4, -1, -3]} intensity={2.4} color="#ffb27a" />
    </>
  );
}

function PointerLight() {
  const lightRef = useRef<PointLight>(null);
  const targetRef = useRef({ x: 0.3, y: 0.4, pointer: false });
  const gl = useThree((state) => state.gl);

  useEffect(() => {
    const canvas = gl.domElement;
    const target = targetRef.current;
    const follow = (event: PointerEvent) => {
      if (event.pointerType === "touch") return;
      const rect = canvas.getBoundingClientRect();
      target.x = Math.max(-1.4, Math.min(1.4, ((event.clientX - rect.left) / rect.width) * 2 - 1));
      target.y = Math.max(-1.4, Math.min(1.4, 1 - ((event.clientY - rect.top) / rect.height) * 2));
      target.pointer = true;
    };
    window.addEventListener("pointermove", follow, { passive: true });
    return () => window.removeEventListener("pointermove", follow);
  }, [gl]);

  useFrame(({ clock, viewport }, delta) => {
    const light = lightRef.current;
    if (!light) return;
    const target = targetRef.current;
    const time = clock.elapsedTime;
    const x = target.pointer ? target.x : Math.sin(time * 0.35) * 0.6;
    const y = target.pointer ? target.y : 0.3 + Math.cos(time * 0.27) * 0.35;
    const follow = 1 - Math.exp(-delta * 2.4);
    light.position.x += ((x * viewport.width) / 2 - light.position.x) * follow;
    light.position.y += ((y * viewport.height) / 2 - light.position.y) * follow;
  });

  return <pointLight ref={lightRef} position={[1, 1, 4]} intensity={16} decay={2} distance={0} color="#ffe6cc" />;
}

function rowPose(group: Group, offset: number, time: number, index: number) {
  const weight = focusWeight(offset);
  group.position.set(offset * spacing, Math.sin(time * 1.2 + index) * 0.025 * weight, weight * 0.6);
  group.rotation.set(Math.sin(time * 0.8 + index) * 0.03 * weight, -Math.tanh(offset * 1.4) * 0.24 + Math.sin(time * 0.6 + index) * 0.05 * weight, 0);
  group.scale.setScalar(0.66 + 0.34 * weight);
}

function placeInFamily(group: Group, slot: Slot, reveal: number, time: number, phase: number) {
  const settled = ease(reveal);
  group.visible = reveal > 0.005;
  group.position.set(slot.x, slot.y - (1 - settled) * 0.5 + Math.sin(time * 0.9 + phase) * 0.02 * settled, slot.z);
  group.rotation.set(slot.tiltX, slot.turnY + Math.sin(time * 0.5 + phase) * 0.03 * settled, 0);
  group.scale.setScalar(slot.scale * (0.72 + 0.28 * settled));
}

function Scene({ screens, family, familyIndex, wheel, active, onPick }: Omit<PhoneWheelCanvasProps, "className">) {
  const kit = useMemo(() => createDeviceKit(), []);
  const logos = useMemo(
    () => ({
      laptop: logoTexture(siApple.path, "#ffffff", 2.42 / 1.52),
      monitor: logoTexture(siLinux.path, "#ffffff", 3.14 / 1.77),
      android: logoTexture(siAndroid.path, `#${siAndroid.hex}`, (androidSpec.width - androidSpec.bezel * 2) / (androidSpec.height - androidSpec.bezel * 2)),
      watch: logoTexture(siApple.path, "#ffffff", 0.39 / 0.48),
    }),
    [],
  );
  useEffect(
    () => () => {
      kit.dispose();
      for (const texture of Object.values(logos)) texture.dispose();
    },
    [kit, logos],
  );

  const activeRef = useRef(active);
  useEffect(() => {
    activeRef.current = active;
  }, [active]);
  const clocksRef = useRef<Record<Exclude<FamilyMember, "iphone">, LogoClock>>({
    laptop: { start: null },
    monitor: { start: null },
    android: { start: null },
    watch: { start: null },
  });

  const size = useThree((state) => state.size);
  const layout = familyLayouts[size.width / Math.max(1, size.height) < 1.1 ? "compact" : "wide"];

  const placeRow = (index: number, group: Group, time: number): ScreenFrame => {
    const offset = index - wheel.current;
    const distance = Math.abs(offset);
    const cross = focusWeight(familyIndex - wheel.current);
    rowPose(group, offset, time, index);
    let brightness = 1 - (0.62 * Math.min(distance, 2.5)) / 2.5;
    if (index === familyIndex) {
      const blend = ease(cross);
      const slot = layout.iphone;
      group.position.set(lerp(group.position.x, slot.x, blend), lerp(group.position.y, slot.y, blend), lerp(group.position.z, slot.z, blend));
      group.rotation.y = lerp(group.rotation.y, slot.turnY, blend);
      group.scale.setScalar(lerp(group.scale.x, slot.scale, blend));
    } else {
      group.position.x -= 3.2 * ease(cross);
      brightness *= 1 - 0.75 * cross;
    }
    group.visible = distance < visibleRange;
    return { phase: "media", playing: activeRef.current && distance <= playRange, brightness };
  };

  const placeMember = (member: Exclude<FamilyMember, "iphone">, phase: number, group: Group, time: number): ScreenFrame => {
    const start = revealStart[member];
    const reveal = stage(focusWeight(familyIndex - wheel.current), start, 1 - start);
    placeInFamily(group, layout[member], reveal, time, phase);
    const frame = logoSequence(clocksRef.current[member], reveal, time, activeRef.current);
    return member === "laptop" ? { ...frame, open: reveal } : frame;
  };

  return (
    <>
      {screens.map((source, index) => (
        <Handset
          key={`${source.src}-${index}`}
          spec={iPhoneSpec}
          kind="iphone"
          kit={kit}
          source={source}
          place={(group, time) => placeRow(index, group, time)}
          onClick={(event) => {
            event.stopPropagation();
            onPick(index);
          }}
        />
      ))}
      <Monitor kit={kit} source={family.monitor} logo={logos.monitor} place={(group, time) => placeMember("monitor", 1.3, group, time)} />
      <Laptop kit={kit} source={family.laptop} logo={logos.laptop} place={(group, time) => placeMember("laptop", 0.4, group, time)} />
      <Handset spec={androidSpec} kind="android" kit={kit} source={family.android} logo={logos.android} place={(group, time) => placeMember("android", 2.1, group, time)} />
      <Watch kit={kit} source={family.watch} logo={logos.watch} crop={watchCrop} place={(group, time) => placeMember("watch", 2.9, group, time)} />
    </>
  );
}

export default function PhoneWheelCanvas({ className, ...props }: PhoneWheelCanvasProps) {
  return (
    <Canvas
      className={className}
      resize={{ offsetSize: true, scroll: false }}
      frameloop={props.active ? "always" : "never"}
      dpr={[1, 1.75]}
      camera={{ fov: 22, position: [0, 0, 7.6], near: 0.1, far: 40 }}
      gl={{ alpha: true, antialias: true, powerPreference: "high-performance" }}
      aria-hidden="true"
    >
      <Studio />
      <PointerLight />
      <Scene {...props} />
    </Canvas>
  );
}
