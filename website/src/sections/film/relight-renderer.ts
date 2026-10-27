const vertexSource = `
attribute vec2 aCorner;
uniform vec2 uCanvas;
varying vec2 vPixel;
void main() {
  vPixel = aCorner * uCanvas;
  gl_Position = vec4(aCorner.x * 2.0 - 1.0, 1.0 - aCorner.y * 2.0, 0.0, 1.0);
}`;

const fragmentSource = `
precision highp float;
uniform sampler2D uColor;
uniform sampler2D uDepth;
uniform vec2 uFrameOrigin;
uniform vec2 uFrameSize;
uniform vec2 uDepthTexel;
uniform vec3 uLight;
uniform float uRadius;
uniform float uAmbient;
uniform float uIntensity;
uniform float uRelief;
varying vec2 vPixel;

float depthAt(vec2 uv) {
  return texture2D(uDepth, uv).r;
}

void main() {
  vec2 uv = (vPixel - uFrameOrigin) / uFrameSize;
  if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
    gl_FragColor = vec4(0.0);
    return;
  }
  vec4 color = texture2D(uColor, uv);
  float dx = depthAt(uv + vec2(uDepthTexel.x, 0.0)) - depthAt(uv - vec2(uDepthTexel.x, 0.0));
  float dy = depthAt(uv + vec2(0.0, uDepthTexel.y)) - depthAt(uv - vec2(0.0, uDepthTexel.y));
  vec3 normal = normalize(vec3(-dx * uRelief, -dy * uRelief, 1.0));
  vec3 toLight = uLight - vec3(vPixel, depthAt(uv) * uRadius * 0.35);
  vec3 direction = normalize(toLight);
  float distance = length(toLight.xy) / uRadius;
  float falloff = 1.0 / (1.0 + distance * distance * 2.2);
  float diffuse = max(dot(normal, direction), 0.0);
  vec3 halfway = normalize(direction + vec3(0.0, 0.0, 1.0));
  float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
  float gloss = pow(max(dot(normal, halfway), 0.0), 36.0) * smoothstep(0.03, 0.25, luma) * 0.28;
  vec3 lit = color.rgb * (uAmbient + uIntensity * diffuse * falloff) + vec3(gloss * falloff) * color.a;
  gl_FragColor = vec4(min(lit, vec3(color.a)), color.a);
}`;

export type RelightView = {
  width: number;
  height: number;
  ratio: number;
  frameX: number;
  frameY: number;
  frameWidth: number;
  frameHeight: number;
};

export type RelightLight = {
  x: number;
  y: number;
  height: number;
  radius: number;
  ambient: number;
  intensity: number;
  relief: number;
};

function compile(gl: WebGLRenderingContext, type: number, source: string) {
  const shader = gl.createShader(type);
  if (!shader) throw new Error("shader allocation failed");
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader) ?? "shader compile failed");
  return shader;
}

function texture(gl: WebGLRenderingContext) {
  const handle = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, handle);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  return handle;
}

export class RelightRenderer {
  private readonly gl: WebGLRenderingContext;
  private readonly program: WebGLProgram;
  private readonly buffer: WebGLBuffer | null;
  private readonly colorTexture: WebGLTexture | null;
  private readonly depthTexture: WebGLTexture | null;
  private readonly uniforms: Record<string, WebGLUniformLocation | null>;
  private colorSource: TexImageSource | null = null;
  private depthSource: TexImageSource | null = null;
  private depthSize = { width: 1, height: 1 };

  static create(canvas: HTMLCanvasElement) {
    const gl = canvas.getContext("webgl", { premultipliedAlpha: true, alpha: true, antialias: false });
    if (!gl) return null;
    try {
      return new RelightRenderer(gl);
    } catch {
      return null;
    }
  }

  private constructor(gl: WebGLRenderingContext) {
    this.gl = gl;
    const program = gl.createProgram();
    if (!program) throw new Error("program allocation failed");
    gl.attachShader(program, compile(gl, gl.VERTEX_SHADER, vertexSource));
    gl.attachShader(program, compile(gl, gl.FRAGMENT_SHADER, fragmentSource));
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program) ?? "program link failed");
    this.program = program;
    gl.useProgram(program);

    this.buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, this.buffer);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0, 0, 1, 0, 0, 1, 1, 1]), gl.STATIC_DRAW);
    const corner = gl.getAttribLocation(program, "aCorner");
    gl.enableVertexAttribArray(corner);
    gl.vertexAttribPointer(corner, 2, gl.FLOAT, false, 0, 0);

    gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, true);
    gl.activeTexture(gl.TEXTURE0);
    this.colorTexture = texture(gl);
    gl.activeTexture(gl.TEXTURE1);
    this.depthTexture = texture(gl);

    const names = ["uCanvas", "uColor", "uDepth", "uFrameOrigin", "uFrameSize", "uDepthTexel", "uLight", "uRadius", "uAmbient", "uIntensity", "uRelief"];
    this.uniforms = Object.fromEntries(names.map((name) => [name, gl.getUniformLocation(program, name)]));
    gl.uniform1i(this.uniforms.uColor, 0);
    gl.uniform1i(this.uniforms.uDepth, 1);
  }

  setFrame(color: HTMLImageElement, depth: HTMLImageElement | undefined) {
    const { gl } = this;
    if (color !== this.colorSource) {
      gl.activeTexture(gl.TEXTURE0);
      gl.bindTexture(gl.TEXTURE_2D, this.colorTexture);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, color);
      this.colorSource = color;
    }
    if (depth && depth !== this.depthSource) {
      gl.activeTexture(gl.TEXTURE1);
      gl.bindTexture(gl.TEXTURE_2D, this.depthTexture);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, depth);
      this.depthSource = depth;
      this.depthSize = { width: depth.naturalWidth, height: depth.naturalHeight };
    }
  }

  render(view: RelightView, light: RelightLight) {
    const { gl, uniforms } = this;
    gl.viewport(0, 0, Math.round(view.width * view.ratio), Math.round(view.height * view.ratio));
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.uniform2f(uniforms.uCanvas, view.width, view.height);
    gl.uniform2f(uniforms.uFrameOrigin, view.frameX, view.frameY);
    gl.uniform2f(uniforms.uFrameSize, view.frameWidth, view.frameHeight);
    gl.uniform2f(uniforms.uDepthTexel, 1 / this.depthSize.width, 1 / this.depthSize.height);
    gl.uniform3f(uniforms.uLight, light.x, light.y, light.height);
    gl.uniform1f(uniforms.uRadius, light.radius);
    gl.uniform1f(uniforms.uAmbient, light.ambient);
    gl.uniform1f(uniforms.uIntensity, light.intensity);
    gl.uniform1f(uniforms.uRelief, light.relief);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  }

  dispose() {
    const { gl } = this;
    gl.deleteTexture(this.colorTexture);
    gl.deleteTexture(this.depthTexture);
    gl.deleteBuffer(this.buffer);
    gl.deleteProgram(this.program);
  }
}
