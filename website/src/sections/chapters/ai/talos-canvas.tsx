"use client";

import { Suspense, useEffect, useMemo, useRef } from "react";
import { Canvas, useFrame, useLoader, useThree } from "@react-three/fiber";
import {
  Box3,
  Color,
  Mesh,
  MeshStandardMaterial,
  PMREMGenerator,
  Vector3,
  type DirectionalLight,
  type Group,
  type Object3D,
  type PointLight,
} from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { MeshoptDecoder } from "three/addons/libs/meshopt_decoder.module.js";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";
import { accentChannels, talosOrange, type TalosPose } from "./talos-pose";

export const talosModelUrl = "/models/talos.glb";

const modelHeight = 1.84;
const baseYaw = -Math.PI / 2;
const orange = accentChannels(talosOrange);

type AccentUniforms = {
  uAccent: { value: Color };
  uAccentMix: { value: number };
};

const accentUniforms = new WeakMap<Object3D, AccentUniforms>();

const accentShader = /* glsl */ `
  vec3 talosSrgb = pow(max(diffuseColor.rgb, vec3(0.0)), vec3(1.0 / 2.2));
  float talosMax = max(talosSrgb.r, max(talosSrgb.g, talosSrgb.b));
  float talosMin = min(talosSrgb.r, min(talosSrgb.g, talosSrgb.b));
  float talosSat = (talosMax - talosMin) / max(talosMax, 1e-4);
  float talosHue = talosMax == talosSrgb.r ? (talosSrgb.g - talosSrgb.b) / max(talosMax - talosMin, 1e-4) / 6.0 : 0.5;
  float talosMask = smoothstep(0.64, 0.82, talosSat) * smoothstep(0.24, 0.4, talosMax) * (1.0 - smoothstep(0.08, 0.13, abs(talosHue - 0.07)));
  float talosLum = dot(diffuseColor.rgb, vec3(0.2126, 0.7152, 0.0722));
  vec3 talosTarget = uAccent * clamp(talosLum / 0.316, 0.0, 1.6);
  diffuseColor.rgb = mix(diffuseColor.rgb, talosTarget, talosMask * uAccentMix);
`;

function configureLoader(loader: GLTFLoader) {
  loader.setMeshoptDecoder(MeshoptDecoder);
}

function patchMaterial(material: MeshStandardMaterial, uniforms: AccentUniforms) {
  material.onBeforeCompile = (shader) => {
    shader.uniforms.uAccent = uniforms.uAccent;
    shader.uniforms.uAccentMix = uniforms.uAccentMix;
    shader.fragmentShader = shader.fragmentShader
      .replace("#include <common>", "#include <common>\nuniform vec3 uAccent;\nuniform float uAccentMix;")
      .replace("#include <map_fragment>", `#include <map_fragment>\n${accentShader}`);
  };
  material.customProgramCacheKey = () => "talos-accent";
  material.needsUpdate = true;
}

function prepareModel(scene: Object3D) {
  const uniforms = accentUniforms.get(scene) ?? { uAccent: { value: new Color() }, uAccentMix: { value: 0 } };
  accentUniforms.set(scene, uniforms);
  scene.scale.setScalar(1);
  scene.position.set(0, 0, 0);
  scene.rotation.set(0, baseYaw, 0);
  scene.updateMatrixWorld(true);
  scene.traverse((child) => {
    if (child instanceof Mesh && child.material instanceof MeshStandardMaterial) {
      patchMaterial(child.material, uniforms);
    }
  });
  const bounds = new Box3().setFromObject(scene);
  const size = bounds.getSize(new Vector3());
  const center = bounds.getCenter(new Vector3());
  const scale = modelHeight / size.y;
  scene.scale.setScalar(scale);
  scene.position.set(-center.x * scale, -center.y * scale, -center.z * scale);
  return scene;
}

function StudioEnvironment({ pose }: { pose: TalosPose }) {
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
    state.scene.environmentIntensity = 0.08 * pose.light + 0.45 * pose.flash;
  });

  return <primitive object={environment} attach="environment" />;
}

function TalosModel({ pose, onReady }: { pose: TalosPose; onReady: () => void }) {
  const gltf = useLoader(GLTFLoader, talosModelUrl, configureLoader);
  const groupRef = useRef<Group>(null);
  const renderedRef = useRef(false);
  const model = useMemo(() => prepareModel(gltf.scene), [gltf.scene]);

  useFrame((state) => {
    const group = groupRef.current;
    const uniforms = accentUniforms.get(model);
    if (!group || !uniforms) return;
    const time = state.clock.elapsedTime;
    group.position.y = Math.sin(time * 0.85) * 0.045 * pose.float;
    group.rotation.y = pose.turn + pose.spin + Math.sin(time * 0.42) * 0.05 * pose.float;
    group.rotation.z = Math.sin(time * 0.6 + 1.2) * 0.012 * pose.float;
    uniforms.uAccent.value.setRGB(pose.accentR, pose.accentG, pose.accentB);
    const distance = Math.hypot(pose.accentR - orange.accentR, pose.accentG - orange.accentG, pose.accentB - orange.accentB);
    uniforms.uAccentMix.value = Math.min(1, distance * 4);
    if (!renderedRef.current) {
      renderedRef.current = true;
      requestAnimationFrame(onReady);
    }
  });

  return (
    <group ref={groupRef}>
      <primitive object={model} />
    </group>
  );
}

function TalosLights({ pose }: { pose: TalosPose }) {
  const keyRef = useRef<DirectionalLight>(null);
  const rimRef = useRef<DirectionalLight>(null);
  const fillRef = useRef<DirectionalLight>(null);
  const accentRef = useRef<PointLight>(null);
  const strobeRef = useRef<DirectionalLight>(null);

  useFrame(() => {
    if (keyRef.current) keyRef.current.intensity = 3.6 * pose.light;
    if (rimRef.current) rimRef.current.intensity = 8 * pose.light;
    if (fillRef.current) fillRef.current.intensity = 1.6 * pose.light;
    if (accentRef.current) {
      accentRef.current.intensity = 7 * pose.light;
      accentRef.current.color.setRGB(pose.accentR, pose.accentG, pose.accentB);
    }
    if (strobeRef.current) strobeRef.current.intensity = 4.2 * pose.flash;
  });

  return (
    <>
      <directionalLight ref={keyRef} position={[-4, 3.2, 1.6]} color="#fff0e0" />
      <directionalLight ref={rimRef} position={[3.2, 2.6, -2.6]} color="#8fc0ff" />
      <directionalLight ref={fillRef} position={[-2.8, 2, -3]} color="#a9c4ff" />
      <pointLight ref={accentRef} position={[2.4, -1, -0.2]} distance={6} decay={1.2} />
      <directionalLight ref={strobeRef} position={[0.4, 0.8, 5]} color="#ffffff" />
    </>
  );
}

function TalosScene({ pose, onReady }: { pose: TalosPose; onReady: () => void }) {
  return (
    <>
      <StudioEnvironment pose={pose} />
      <TalosLights pose={pose} />
      <Suspense fallback={null}>
        <TalosModel pose={pose} onReady={onReady} />
      </Suspense>
    </>
  );
}

export type TalosCanvasProps = {
  pose: TalosPose;
  active: boolean;
  onReady: () => void;
  className?: string;
};

export default function TalosCanvas({ pose, active, onReady, className }: TalosCanvasProps) {
  return (
    <Canvas
      className={className}
      resize={{ offsetSize: true, scroll: false }}
      frameloop={active ? "always" : "never"}
      dpr={[1, 1.75]}
      camera={{ fov: 20, position: [0, 0, 6.6], near: 0.1, far: 30 }}
      gl={{ alpha: true, antialias: true, powerPreference: "high-performance" }}
      aria-hidden="true"
    >
      <TalosScene pose={pose} onReady={onReady} />
    </Canvas>
  );
}
