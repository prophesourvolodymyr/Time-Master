"use client";

import { useEffect, useMemo, useRef, type RefObject } from "react";
import { useFrame, type ThreeEvent } from "@react-three/fiber";
import { RoundedBox } from "@react-three/drei";
import { CircleGeometry, type Group, type MeshBasicMaterial, type Texture } from "three";
import {
  createScreenState,
  disposeScreen,
  loadPoster,
  panel,
  setScreenPlaying,
  slab,
  type DeviceKit,
  type HandsetSpec,
  type ScreenSource,
  type ScreenState,
} from "./device-parts";

export type ScreenFrame = {
  phase: "off" | "logo" | "media";
  playing: boolean;
  brightness: number;
  open?: number;
};

export type Placement = (group: Group, time: number) => ScreenFrame;

export type ScreenCrop = { x: number; y: number; width: number; height: number };

type ScreenProps = {
  width: number;
  height: number;
  radius: number;
  source: ScreenSource;
  logo: Texture | null;
  crop?: ScreenCrop;
  kit: DeviceKit;
  frame: RefObject<ScreenFrame>;
};

function applyCrop(texture: Texture, crop: ScreenCrop | undefined) {
  if (!crop) return;
  texture.repeat.set(crop.width, crop.height);
  texture.offset.set(crop.x, crop.y);
}

function setMap(material: MeshBasicMaterial, map: Texture | null) {
  if (material.map === map) return;
  const swapsDefine = (material.map === null) !== (map === null);
  material.map = map;
  if (swapsDefine) material.needsUpdate = true;
}

function Screen({ width, height, radius, source, logo, crop, kit, frame }: ScreenProps) {
  const baseRef = useRef<MeshBasicMaterial>(null);
  const insetRef = useRef<MeshBasicMaterial>(null);
  const stateRef = useRef<ScreenState>(createScreenState());
  const posterRef = useRef<Texture | null>(null);
  const contain = !crop && Math.abs(source.aspect - width / height) > 0.15;
  const geometry = useMemo(() => {
    const surface = panel(width, height, radius);
    if (!contain) return { surface, inset: null };
    const insetHeight = height * 0.94;
    const insetWidth = Math.min(width * 0.94, insetHeight * source.aspect);
    return { surface, inset: panel(insetWidth, insetWidth / source.aspect, insetWidth * 0.12) };
  }, [width, height, radius, contain, source.aspect]);

  useEffect(() => {
    const state = stateRef.current;
    loadPoster(state, source, (texture) => {
      applyCrop(texture, crop);
      posterRef.current = texture;
    });
    return () => {
      disposeScreen(state);
      geometry.surface.dispose();
      geometry.inset?.dispose();
    };
  }, [source, crop, geometry]);

  useFrame(() => {
    const base = baseRef.current;
    const media = contain ? insetRef.current : baseRef.current;
    if (!base || !media) return;
    const state = stateRef.current;
    const current = frame.current;
    setScreenPlaying(state, source, current.phase === "media" && current.playing, (texture) => applyCrop(texture, crop));
    const mediaTexture = state.live ? state.videoTexture : posterRef.current;
    if (current.phase === "logo") {
      setMap(base, logo);
      if (media !== base) setMap(media, null);
    } else if (current.phase === "media") {
      if (media !== base) setMap(base, null);
      setMap(media, mediaTexture);
    } else {
      setMap(base, null);
      if (media !== base) setMap(media, null);
    }
    base.color.setScalar(base.map ? current.brightness : 0);
    if (media !== base) {
      media.visible = media.map !== null;
      media.color.setScalar(current.brightness);
    }
  });

  return (
    <>
      <mesh geometry={geometry.surface}>
        <meshBasicMaterial ref={baseRef} color="#000000" toneMapped={false} />
      </mesh>
      {geometry.inset ? (
        <mesh geometry={geometry.inset} position-z={0.0006}>
          <meshBasicMaterial ref={insetRef} color="#000000" toneMapped={false} />
        </mesh>
      ) : null}
      <mesh geometry={geometry.surface} material={kit.materials.glare} position-z={0.0012} />
    </>
  );
}

const offFrame: ScreenFrame = { phase: "off", playing: false, brightness: 0 };

type DeviceProps = {
  kit: DeviceKit;
  source: ScreenSource;
  logo?: Texture | null;
  place: Placement;
  onClick?: (event: ThreeEvent<MouseEvent>) => void;
};

const iPhoneButtons = [
  { side: -1, y: 0.62, length: 0.1 },
  { side: -1, y: 0.42, length: 0.17 },
  { side: -1, y: 0.2, length: 0.17 },
  { side: 1, y: 0.38, length: 0.26 },
  { side: 1, y: -0.36, length: 0.2 },
] as const;

const androidButtons = [
  { side: 1, y: 0.5, length: 0.32 },
  { side: 1, y: 0.06, length: 0.18 },
] as const;

export function Handset({ kit, source, logo = null, place, onClick, spec, kind }: DeviceProps & { spec: HandsetSpec; kind: "iphone" | "android" }) {
  const groupRef = useRef<Group>(null);
  const frame = useRef<ScreenFrame>(offFrame);
  const geometry = useMemo(
    () => ({
      body: slab(spec.width, spec.height, spec.depth, spec.radius, 0.026),
      glass: panel(spec.width - 0.024, spec.height - 0.024, spec.radius - 0.012),
      cutout: kind === "iphone" ? panel(0.33, 0.096, 0.048) : new CircleGeometry(0.036, 24),
    }),
    [spec, kind],
  );
  useEffect(
    () => () => {
      geometry.body.dispose();
      geometry.glass.dispose();
      geometry.cutout.dispose();
    },
    [geometry],
  );
  useFrame(({ clock }) => {
    const group = groupRef.current;
    if (group) frame.current = place(group, clock.elapsedTime);
  });

  const front = spec.depth / 2;
  const screenWidth = spec.width - spec.bezel * 2;
  const screenHeight = spec.height - spec.bezel * 2;
  const frameMaterial = kind === "iphone" ? kit.materials.titanium : kit.materials.obsidian;
  return (
    <group ref={groupRef} onClick={onClick}>
      <mesh geometry={geometry.body} material={frameMaterial} />
      <mesh geometry={geometry.glass} material={kit.materials.glass} position-z={front + 0.0012} />
      <group position-z={front + 0.0024}>
        <Screen width={screenWidth} height={screenHeight} radius={spec.radius - spec.bezel} source={source} logo={logo} kit={kit} frame={frame} />
      </group>
      <mesh geometry={geometry.cutout} material={kit.materials.black} position={[0, screenHeight / 2 - (kind === "iphone" ? 0.08 : 0.07), front + 0.004]} />
      {(kind === "iphone" ? iPhoneButtons : androidButtons).map((button) => (
        <mesh
          key={`${button.side}-${button.y}`}
          geometry={kit.geometry.button}
          material={frameMaterial}
          position={[button.side * (spec.width / 2 + 0.004), button.y, 0]}
          scale={[1, button.length, 1]}
        />
      ))}
    </group>
  );
}

const lidClosed = Math.PI / 2 - 0.04;
const lidOpen = -0.24;

export function Laptop({ kit, source, logo = null, place }: DeviceProps) {
  const groupRef = useRef<Group>(null);
  const lidRef = useRef<Group>(null);
  const frame = useRef<ScreenFrame>(offFrame);
  const geometry = useMemo(() => ({ keys: panel(2.3, 0.92, 0.05), pad: panel(1.02, 0.6, 0.06), bezel: panel(2.52, 1.64, 0.06), notch: panel(0.24, 0.06, 0.025) }), []);
  useEffect(
    () => () => {
      for (const shape of Object.values(geometry)) shape.dispose();
    },
    [geometry],
  );
  useFrame(({ clock }) => {
    const group = groupRef.current;
    const lid = lidRef.current;
    if (!group || !lid) return;
    const current = place(group, clock.elapsedTime);
    frame.current = current;
    lid.rotation.x = lidClosed + (lidOpen - lidClosed) * (current.open ?? 1);
  });
  return (
    <group ref={groupRef}>
      <RoundedBox args={[2.6, 0.06, 1.8]} radius={0.028} smoothness={4} material={kit.materials.aluminum} />
      <mesh geometry={geometry.keys} material={kit.materials.keys} position={[0, 0.031, -0.28]} rotation-x={-Math.PI / 2} />
      <mesh geometry={geometry.pad} material={kit.materials.keys} position={[0, 0.031, 0.5]} rotation-x={-Math.PI / 2} />
      <group ref={lidRef} position={[0, 0.03, -0.88]}>
        <group position={[0, 0.86, 0]}>
          <RoundedBox args={[2.6, 1.72, 0.045]} radius={0.02} smoothness={4} material={kit.materials.aluminum} />
          <mesh geometry={geometry.bezel} material={kit.materials.black} position-z={0.0235} />
          <group position={[0, -0.02, 0.0245]}>
            <Screen width={2.42} height={1.52} radius={0.04} source={source} logo={logo} kit={kit} frame={frame} />
          </group>
          <mesh geometry={geometry.notch} material={kit.materials.black} position={[0, 0.77, 0.027]} />
        </group>
      </group>
    </group>
  );
}

export function Monitor({ kit, source, logo = null, place }: DeviceProps) {
  const groupRef = useRef<Group>(null);
  const frame = useRef<ScreenFrame>(offFrame);
  const bezel = useMemo(() => panel(3.24, 1.89, 0.04), []);
  useEffect(() => () => bezel.dispose(), [bezel]);
  useFrame(({ clock }) => {
    const group = groupRef.current;
    if (group) frame.current = place(group, clock.elapsedTime);
  });
  return (
    <group ref={groupRef}>
      <RoundedBox args={[3.3, 1.95, 0.08]} radius={0.035} smoothness={4} material={kit.materials.aluminum} />
      <mesh geometry={bezel} material={kit.materials.black} position-z={0.041} />
      <group position-z={0.042}>
        <Screen width={3.14} height={1.77} radius={0.02} source={source} logo={logo} kit={kit} frame={frame} />
      </group>
      <RoundedBox args={[0.24, 0.72, 0.07]} radius={0.03} smoothness={4} material={kit.materials.aluminum} position={[0, -1.3, -0.12]} />
      <RoundedBox args={[1.25, 0.05, 0.62]} radius={0.024} smoothness={4} material={kit.materials.aluminum} position={[0, -1.66, -0.02]} />
    </group>
  );
}

export function Watch({ kit, source, logo = null, place, crop }: DeviceProps & { crop: ScreenCrop }) {
  const groupRef = useRef<Group>(null);
  const frame = useRef<ScreenFrame>(offFrame);
  const geometry = useMemo(() => ({ body: slab(0.46, 0.55, 0.11, 0.14, 0.02), glass: panel(0.44, 0.53, 0.13) }), []);
  useEffect(
    () => () => {
      geometry.body.dispose();
      geometry.glass.dispose();
    },
    [geometry],
  );
  useFrame(({ clock }) => {
    const group = groupRef.current;
    if (group) frame.current = place(group, clock.elapsedTime);
  });
  return (
    <group ref={groupRef}>
      <RoundedBox args={[0.36, 0.56, 0.05]} radius={0.022} smoothness={4} material={kit.materials.rubber} position={[0, 0.5, -0.015]} />
      <RoundedBox args={[0.36, 0.56, 0.05]} radius={0.022} smoothness={4} material={kit.materials.rubber} position={[0, -0.5, -0.015]} />
      <mesh geometry={geometry.body} material={kit.materials.aluminum} />
      <mesh geometry={geometry.glass} material={kit.materials.glass} position-z={0.0562} />
      <group position-z={0.0574}>
        <Screen width={0.39} height={0.48} radius={0.11} source={source} logo={logo} crop={crop} kit={kit} frame={frame} />
      </group>
      <mesh geometry={kit.geometry.crown} material={kit.materials.aluminum} position={[0.245, 0.08, 0]} rotation-z={Math.PI / 2} />
      <RoundedBox args={[0.02, 0.12, 0.05]} radius={0.008} smoothness={3} material={kit.materials.aluminum} position={[0.236, -0.1, 0]} />
    </group>
  );
}
