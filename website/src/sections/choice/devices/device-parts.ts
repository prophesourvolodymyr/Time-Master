import {
  AdditiveBlending,
  BoxGeometry,
  CanvasTexture,
  CylinderGeometry,
  ExtrudeGeometry,
  MeshBasicMaterial,
  MeshPhysicalMaterial,
  MeshStandardMaterial,
  Shape,
  ShapeGeometry,
  SRGBColorSpace,
  TextureLoader,
  VideoTexture,
  type Texture,
} from "three";

export type ScreenSource = {
  src: string;
  poster: string;
  aspect: number;
};

export type HandsetSpec = {
  width: number;
  height: number;
  depth: number;
  radius: number;
  bezel: number;
};

export const iPhoneSpec: HandsetSpec = { width: 1.15, height: 2.4, depth: 0.13, radius: 0.19, bezel: 0.045 };
export const androidSpec: HandsetSpec = { width: 1.12, height: 2.42, depth: 0.12, radius: 0.13, bezel: 0.04 };

export function roundedRect(width: number, height: number, radius: number) {
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

export function panel(width: number, height: number, radius: number) {
  const geometry = new ShapeGeometry(roundedRect(width, height, radius), 24);
  const uv = geometry.attributes.uv;
  const position = geometry.attributes.position;
  for (let index = 0; index < uv.count; index += 1) {
    uv.setXY(index, position.getX(index) / width + 0.5, position.getY(index) / height + 0.5);
  }
  return geometry;
}

export function slab(width: number, height: number, depth: number, radius: number, bevel: number) {
  const geometry = new ExtrudeGeometry(roundedRect(width - bevel * 2, height - bevel * 2, Math.max(0.001, radius - bevel)), {
    depth: depth - bevel * 2,
    bevelEnabled: true,
    bevelThickness: bevel,
    bevelSize: bevel,
    bevelSegments: 5,
    curveSegments: 24,
  });
  geometry.translate(0, 0, -(depth - bevel * 2) / 2);
  return geometry;
}

export type DeviceKit = {
  materials: {
    titanium: MeshPhysicalMaterial;
    obsidian: MeshPhysicalMaterial;
    aluminum: MeshPhysicalMaterial;
    glass: MeshPhysicalMaterial;
    black: MeshBasicMaterial;
    rubber: MeshStandardMaterial;
    keys: MeshStandardMaterial;
    glare: MeshStandardMaterial;
  };
  geometry: {
    button: BoxGeometry;
    crown: CylinderGeometry;
  };
  dispose: () => void;
};

export function createDeviceKit(): DeviceKit {
  const materials = {
    titanium: new MeshPhysicalMaterial({ color: "#34353a", metalness: 0.95, roughness: 0.3, clearcoat: 0.5, clearcoatRoughness: 0.15 }),
    obsidian: new MeshPhysicalMaterial({ color: "#1f2427", metalness: 0.6, roughness: 0.38, clearcoat: 0.8, clearcoatRoughness: 0.2 }),
    aluminum: new MeshPhysicalMaterial({ color: "#2c2d31", metalness: 0.9, roughness: 0.34, clearcoat: 0.3 }),
    glass: new MeshPhysicalMaterial({ color: "#030303", metalness: 0.1, roughness: 0.06, clearcoat: 1 }),
    black: new MeshBasicMaterial({ color: "#000000" }),
    rubber: new MeshStandardMaterial({ color: "#16171a", roughness: 0.85, metalness: 0 }),
    keys: new MeshStandardMaterial({ color: "#0b0b0d", roughness: 0.7, metalness: 0.1 }),
    glare: new MeshStandardMaterial({ color: "#000000", roughness: 0.2, metalness: 0, envMapIntensity: 0, transparent: true, opacity: 0.22, blending: AdditiveBlending, depthWrite: false }),
  };
  const geometry = {
    button: new BoxGeometry(0.014, 1, 0.05),
    crown: new CylinderGeometry(0.04, 0.04, 0.06, 24),
  };
  return {
    materials,
    geometry,
    dispose: () => {
      for (const material of Object.values(materials)) material.dispose();
      for (const shape of Object.values(geometry)) shape.dispose();
    },
  };
}

export function logoTexture(path: string, color: string, aspect: number) {
  const height = 512;
  const width = Math.round(height * aspect);
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext("2d");
  if (context) {
    context.fillStyle = "#000000";
    context.fillRect(0, 0, width, height);
    const size = Math.min(width, height) * 0.36;
    context.translate((width - size) / 2, (height - size) / 2);
    context.scale(size / 24, size / 24);
    context.shadowColor = color;
    context.shadowBlur = 18;
    context.fillStyle = color;
    context.fill(new Path2D(path));
  }
  const texture = new CanvasTexture(canvas);
  texture.colorSpace = SRGBColorSpace;
  return texture;
}

export type ScreenState = {
  video: HTMLVideoElement | null;
  videoTexture: VideoTexture | null;
  textures: Texture[];
  live: boolean;
  playing: boolean;
};

export function createScreenState(): ScreenState {
  return { video: null, videoTexture: null, textures: [], live: false, playing: false };
}

export function loadPoster(state: ScreenState, source: ScreenSource, onReady: (texture: Texture) => void) {
  new TextureLoader().load(source.poster, (texture) => {
    texture.colorSpace = SRGBColorSpace;
    state.textures.push(texture);
    onReady(texture);
  });
}

export function setScreenPlaying(state: ScreenState, source: ScreenSource, playing: boolean, onLive: (texture: VideoTexture) => void) {
  if (playing === state.playing) return;
  state.playing = playing;
  if (!playing) {
    state.video?.pause();
    return;
  }
  if (!state.video) {
    const video = document.createElement("video");
    video.muted = true;
    video.loop = true;
    video.playsInline = true;
    video.setAttribute("playsinline", "");
    video.crossOrigin = "anonymous";
    video.preload = "auto";
    video.src = source.src;
    const texture = new VideoTexture(video);
    texture.colorSpace = SRGBColorSpace;
    state.textures.push(texture);
    state.videoTexture = texture;
    video.addEventListener(
      "playing",
      () => {
        state.live = true;
        onLive(texture);
      },
      { once: true },
    );
    state.video = video;
  }
  state.video.play().catch(() => {
    state.playing = false;
  });
}

export function disposeScreen(state: ScreenState) {
  state.video?.pause();
  state.video?.removeAttribute("src");
  state.video?.load();
  for (const texture of state.textures) texture.dispose();
}

export function ease(value: number) {
  const clamped = Math.min(1, Math.max(0, value));
  return clamped * clamped * (3 - 2 * clamped);
}

export function stage(value: number, from: number, span: number) {
  return ease((value - from) / span);
}
