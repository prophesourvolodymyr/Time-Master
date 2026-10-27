function loadOrder(count: number) {
  const order: number[] = [];
  const seen = new Set<number>();
  for (const stride of [count, 24, 12, 6, 3, 1]) {
    for (let index = 0; index < count; index += stride) {
      if (!seen.has(index)) {
        seen.add(index);
        order.push(index);
      }
    }
  }
  return order;
}

export class FrameSequence {
  private readonly frames: (HTMLImageElement | undefined)[];

  constructor(private readonly urls: readonly string[]) {
    this.frames = new Array(urls.length);
  }

  load(signal: AbortSignal, onFrame: (index: number) => void, workers = 6) {
    const order = loadOrder(this.urls.length);
    let cursor = 0;
    const work = async () => {
      while (cursor < order.length && !signal.aborted) {
        const index = order[cursor];
        cursor += 1;
        const image = new Image();
        image.decoding = "async";
        image.src = this.urls[index];
        try {
          await image.decode();
        } catch {
          continue;
        }
        if (signal.aborted) return;
        this.frames[index] = image;
        onFrame(index);
      }
    };
    for (let worker = 0; worker < workers; worker += 1) void work();
  }

  nearest(index: number) {
    if (this.frames[index]) return index;
    for (let distance = 1; distance < this.frames.length; distance += 1) {
      if (this.frames[index - distance]) return index - distance;
      if (this.frames[index + distance]) return index + distance;
    }
    return -1;
  }

  frame(index: number) {
    return this.frames[index];
  }
}
