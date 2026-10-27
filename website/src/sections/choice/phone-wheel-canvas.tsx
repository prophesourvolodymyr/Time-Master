"use client";

import { useEffect, useMemo, useRef } from "react";
import { Canvas, useFrame, useThree } from "@react-three/fiber";
import {
  BoxGeometry,
  ExtrudeGeometry,
  MeshBasicMaterial,
  MeshPhysicalMaterial,
  PMREMGenerator,
  Shape,
  ShapeGeometry,
  SRGBColorSpace,
  TextureLoader,
  VideoTexture,
  type Group,
  type Texture,
} from "three";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";
import { focusWeight, type WheelState } from "./wheel";

export type PhoneScreen = {
  src: string;
  poster: string;
};

export type PhoneWheelCanvasProps = {
  screens: readonly PhoneScreen[];
  wheel: WheelState;
  active: boolean;
  onPick: (index: number) => void;
  className?: string;
};

const bodyWidth = 1.15;
const bodyHeight = 2.4;
const bodyDepth = 0.13;
const cornerRadius = 0.19;
const bevel = 0.026;
const bezel = 0.045;
const screenWidth = bodyWidth - bezel * 2;
const screenHeight = bodyHeight - bezel * 2;
const front = bodyDepth / 2;
const arcStep = 0.6;
const arcRadius = 3.5;
const playRange = 1.25;
const visibleRange = 3.4;

const buttons = [
  { side: -1, y: 0.62, length: 0.1 },
  { side: -1, y: 0.42, length: 0.17 },
  { side: -1, y: 0.2, length: 0.17 },
  { side: 1, y: 0.38, length: 0.26 },
  { side: 1, y: -0.36, length: 0.2 },
] as const;

function roundedRect(width: number, height: number, radius: number) {
  const shape = new Shape();
  const x = -width / 2;
  const y = -height / 2;
  shape.moveTo(x + radius, y);
  shape.lineTo(x + width - radius, y);
  shape.quadraticCurveTo(x + width, y, x + width, y + radius);
  shape.lineTo(x + width, y + height - radius);
  shape.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
  shape.lineTo(x + radius, y + height);
  shape.quadraticCurveTo(x, y + height, x, y + height - radius);
  shape.lineTo(x, y + radius);
  shape.quadraticCurveTo(x, y, x + radius, y);
  return shape;
}

function panel(width: number, height: number, radius: number) {
  const geometry = new ShapeGeometry(roundedRect(width, height, radius), 24);
  const uv = geometry.attributes.uv;
  const position = geometry.attributes.position;
  for (let index = 0; index < uv.count; index += 1) {
    uv.setXY(index, position.getX(index) / width + 0.5, position.getY(index) / height + 0.5);
  }
  return geometry;
}

type PhoneParts = {
  geometry: {
    body: ExtrudeGeometry;
    glass: ShapeGeometry;
    display: ShapeGeometry;
    island: ShapeGeometry;
    button: BoxGeometry;
  };
  material: {
    titanium: MeshPhysicalMaterial;
    glass: MeshPhysicalMaterial;
    island: MeshBasicMaterial;
  };
};

function createParts(): PhoneParts {
  const body = new ExtrudeGeometry(roundedRect(bodyWidth - bevel * 2, bodyHeight - bevel * 2, cornerRadius - bevel), {
    depth: bodyDepth - bevel * 2,
    bevelEnabled: true,
    bevelThickness: bevel,
    bevelSize: bevel,
    bevelSegments: 5,
    curveSegments: 24,
  });
  body.translate(0, 0, -(bodyDepth - bevel * 2) / 2);
  return {
    geometry: {
      body,
      glass: panel(bodyWidth - 0.024, bodyHeight - 0.024, cornerRadius - 0.012),
      display: panel(screenWidth, screenHeight, cornerRadius - bezel),
      island: panel(0.33, 0.096, 0.048),
      button: new BoxGeometry(0.014, 1, 0.05),
    },
    material: {
      titanium: new MeshPhysicalMaterial({ color: "#34353a", metalness: 0.95, roughness: 0.3, clearcoat: 0.5, clearcoatRoughness: 0.15 }),
      glass: new MeshPhysicalMaterial({ color: "#030303", metalness: 0.1, roughness: 0.06, clearcoat: 1 }),
      island: new MeshBasicMaterial({ color: "#000000" }),
    },
  };
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
    state.scene.environmentIntensity = 0.55;
  });

  return (
    <>
      <primitive object={environment} attach="environment" />
      <ambientLight intensity={0.25} />
      <directionalLight position={[-3, 4, 6]} intensity={1.6} />
      <directionalLight position={[4, -1, -3]} intensity={2.4} color="#ffb27a" />
    </>
  );
}

type PhoneProps = {
  index: number;
  screen: PhoneScreen;
  parts: PhoneParts;
  wheel: WheelState;
  active: boolean;
  onPick: (index: number) => void;
};

type ScreenMedia = {
  video: HTMLVideoElement | null;
  textures: Texture[];
  live: boolean;
  playing: boolean;
};

function Phone({ index, screen, parts, wheel, active, onPick }: PhoneProps) {
  const groupRef = useRef<Group>(null);
  const displayRef = useRef<MeshBasicMaterial>(null);
  const mediaRef = useRef<ScreenMedia>({ video: null, textures: [], live: false, playing: false });

  useEffect(() => {
    const media = mediaRef.current;
    let disposed = false;
    new TextureLoader().load(screen.poster, (texture) => {
      texture.colorSpace = SRGBColorSpace;
      media.textures.push(texture);
      const display = displayRef.current;
      if (disposed || media.live || !display) return;
      display.map = texture;
      display.needsUpdate = true;
    });
    return () => {
      disposed = true;
      media.video?.pause();
      media.video?.removeAttribute("src");
      media.video?.load();
      for (const texture of media.textures) texture.dispose();
    };
  }, [screen.poster]);

  const startVideo = () => {
    const media = mediaRef.current;
    if (!media.video) {
      const video = document.createElement("video");
      video.muted = true;
      video.loop = true;
      video.playsInline = true;
      video.setAttribute("playsinline", "");
      video.crossOrigin = "anonymous";
      video.preload = "auto";
      video.src = screen.src;
      const texture = new VideoTexture(video);
      texture.colorSpace = SRGBColorSpace;
      media.textures.push(texture);
      video.addEventListener(
        "playing",
        () => {
          media.live = true;
          const display = displayRef.current;
          if (!display) return;
          display.map = texture;
          display.needsUpdate = true;
        },
        { once: true },
      );
      media.video = video;
    }
    media.video.play().catch(() => {
      media.playing = false;
    });
  };

  useFrame(({ clock }) => {
    const group = groupRef.current;
    const display = displayRef.current;
    if (!group || !display) return;
    const media = mediaRef.current;
    const offset = index - wheel.current;
    const distance = Math.abs(offset);
    const weight = focusWeight(offset);
    const angle = offset * arcStep;
    const time = clock.elapsedTime;
    group.visible = distance < visibleRange;
    group.position.set(Math.sin(angle) * arcRadius, Math.sin(time * 1.2 + index) * 0.025 * weight, (Math.cos(angle) - 1) * arcRadius + weight * 0.9);
    group.rotation.set(Math.sin(time * 0.8 + index) * 0.03 * weight, angle * 0.9, 0);
    group.scale.setScalar(0.66 + 0.34 * weight);
    display.color.setScalar(display.map ? 1 - (0.62 * Math.min(distance, 2.5)) / 2.5 : 0);

    const shouldPlay = active && distance <= playRange;
    if (shouldPlay !== media.playing) {
      media.playing = shouldPlay;
      if (shouldPlay) startVideo();
      else media.video?.pause();
    }
  });

  const { geometry, material } = parts;
  return (
    <group
      ref={groupRef}
      onClick={(event) => {
        event.stopPropagation();
        onPick(index);
      }}
      onPointerOver={() => {
        document.body.style.cursor = "pointer";
      }}
      onPointerOut={() => {
        document.body.style.cursor = "";
      }}
    >
      <mesh geometry={geometry.body} material={material.titanium} />
      <mesh geometry={geometry.glass} material={material.glass} position={[0, 0, front + 0.0012]} />
      <mesh geometry={geometry.display} position={[0, 0, front + 0.0024]}>
        <meshBasicMaterial ref={displayRef} color="#000000" toneMapped={false} />
      </mesh>
      <mesh geometry={geometry.island} material={material.island} position={[0, screenHeight / 2 - 0.08, front + 0.0036]} />
      {buttons.map((button) => (
        <mesh
          key={`${button.side}-${button.y}`}
          geometry={geometry.button}
          material={material.titanium}
          position={[button.side * (bodyWidth / 2 + 0.004), button.y, 0]}
          scale={[1, button.length, 1]}
        />
      ))}
    </group>
  );
}

function PhoneWheel({ screens, wheel, active, onPick }: Omit<PhoneWheelCanvasProps, "className">) {
  const parts = useMemo(() => createParts(), []);
  useEffect(
    () => () => {
      for (const geometry of Object.values(parts.geometry)) geometry.dispose();
      for (const material of Object.values(parts.material)) material.dispose();
      document.body.style.cursor = "";
    },
    [parts],
  );
  return (
    <>
      {screens.map((screen, index) => (
        <Phone key={screen.src + index} index={index} screen={screen} parts={parts} wheel={wheel} active={active} onPick={onPick} />
      ))}
    </>
  );
}

export default function PhoneWheelCanvas({ screens, wheel, active, onPick, className }: PhoneWheelCanvasProps) {
  return (
    <Canvas
      className={className}
      resize={{ offsetSize: true, scroll: false }}
      frameloop={active ? "always" : "never"}
      dpr={[1, 1.75]}
      camera={{ fov: 22, position: [0, 0, 7.6], near: 0.1, far: 40 }}
      gl={{ alpha: true, antialias: true, powerPreference: "high-performance" }}
      aria-hidden="true"
    >
      <Studio />
      <PhoneWheel screens={screens} wheel={wheel} active={active} onPick={onPick} />
    </Canvas>
  );
}
