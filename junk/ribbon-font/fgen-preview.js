(() => {
  const panel = document.getElementById('fgen-panel');
  const composer = document.getElementById('fgen-word-hub');
  const controls = document.getElementById('fgen-controls');
  const input = document.getElementById('fgen-input');
  const word = document.getElementById('fgen-live-word');
  const stage = document.getElementById('fgen-stage');
  const line = stage.querySelector('.stage-line');
  const message = document.getElementById('fgen-message');
  const empty = document.getElementById('fgen-empty');
  const status = document.getElementById('fgen-status');
  const size = document.getElementById('fgen-size');
  const tracking = document.getElementById('fgen-tracking');
  const tabs = Array.from(document.querySelectorAll('[role="tab"]'));
  const presets = Array.from(panel.querySelectorAll('[data-fgen-word]'));
  const initialMessage = message.textContent;
  const unitsPerEm = 1000;
  const capHeight = 560;
  const xHeight = 406;
  const glyphs = {
    M: { src: '../../genesis/REFERENCE/ribbon-font/individual-m/master-M-reference.png', canvasWidth: 1024, canvasHeight: 1024, left: 72, top: 232, right: 952, bottom: 792 },
    A: { src: '../../genesis/REFERENCE/ribbon-font/fgen-five-original-M/uppercase-A.png', canvasWidth: 1254, canvasHeight: 1254, left: 176, top: 278, right: 1057, bottom: 981 },
    B: { src: '../../genesis/REFERENCE/ribbon-font/fgen-five-original-M/uppercase-B.png', canvasWidth: 1254, canvasHeight: 1254, left: 155, top: 249, right: 976, bottom: 983 },
    C: { src: '../../genesis/REFERENCE/ribbon-font/fgen-next-ten-original-M/uppercase-C.png', canvasWidth: 1254, canvasHeight: 1254, left: 203, top: 211, right: 1060, bottom: 1054 },
    D: { src: '../../genesis/REFERENCE/ribbon-font/fgen-next-ten-original-M/uppercase-D.png', canvasWidth: 1254, canvasHeight: 1254, left: 241, top: 261, right: 1013, bottom: 987 },
    E: { src: '../../genesis/REFERENCE/ribbon-font/fgen-next-ten-original-M/uppercase-E.png', canvasWidth: 1254, canvasHeight: 1254, left: 149, top: 167, right: 1094, bottom: 1048 },
    F: { src: '../../genesis/REFERENCE/ribbon-font/fgen-next-ten-original-M/uppercase-F.png', canvasWidth: 1254, canvasHeight: 1254, left: 114, top: 191, right: 1139, bottom: 1062 },
    G: { src: '../../genesis/REFERENCE/ribbon-font/fgen-next-ten-original-M/uppercase-G.png', canvasWidth: 1254, canvasHeight: 1254, left: 207, top: 221, right: 1038, bottom: 1044 },
    H: { src: '../../genesis/REFERENCE/ribbon-font/fgen-next-ten-original-M/uppercase-H.png', canvasWidth: 1254, canvasHeight: 1254, left: 164, top: 229, right: 1090, bottom: 1010 },
    I: { src: '../../genesis/REFERENCE/ribbon-font/fgen-i-refinement-original-M/uppercase-I-v2.png', canvasWidth: 1254, canvasHeight: 1254, left: 345, top: 255, right: 833, bottom: 1006 },
    J: { src: '../../genesis/REFERENCE/ribbon-font/fgen-next-ten-original-M/uppercase-J.png', canvasWidth: 1254, canvasHeight: 1254, left: 252, top: 267, right: 985, bottom: 992 },
    K: { src: '../../genesis/REFERENCE/ribbon-font/fgen-next-ten-original-M/uppercase-K.png', canvasWidth: 1254, canvasHeight: 1254, left: 130, top: 219, right: 1091, bottom: 1044 },
    L: { src: '../../genesis/REFERENCE/ribbon-font/fgen-next-ten-original-M/uppercase-L-v2.png', canvasWidth: 1254, canvasHeight: 1254, left: 276, top: 263, right: 978, bottom: 996 },
    N: { src: '../../genesis/REFERENCE/ribbon-font/fgen-third-ten-original-M/uppercase-N.png', canvasWidth: 1254, canvasHeight: 1254, left: 149, top: 268, right: 1068, bottom: 979 },
    O: { src: '../../genesis/REFERENCE/ribbon-font/fgen-third-ten-original-M/uppercase-O.png', canvasWidth: 1254, canvasHeight: 1254, left: 274, top: 223, right: 975, bottom: 1033 },
    P: { src: '../../genesis/REFERENCE/ribbon-font/fgen-third-ten-original-M/uppercase-P.png', canvasWidth: 1254, canvasHeight: 1254, left: 207, top: 208, right: 1051, bottom: 1045 },
    Q: { src: '../../genesis/REFERENCE/ribbon-font/fgen-third-ten-original-M/uppercase-Q.png', canvasWidth: 1254, canvasHeight: 1254, left: 305, top: 273, right: 1001, bottom: 979, baseline: 935 },
    R: { src: '../../genesis/REFERENCE/ribbon-font/fgen-third-ten-original-M/uppercase-R.png', canvasWidth: 1254, canvasHeight: 1254, left: 140, top: 260, right: 1111, bottom: 1019 },
    S: { src: '../../genesis/REFERENCE/ribbon-font/fgen-five-original-M/uppercase-S.png', canvasWidth: 1254, canvasHeight: 1254, left: 321, top: 220, right: 941, bottom: 1026 },
    T: { src: '../../genesis/REFERENCE/ribbon-font/fgen-third-ten-original-M/uppercase-T.png', canvasWidth: 1254, canvasHeight: 1254, left: 194, top: 280, right: 1061, bottom: 987 },
    U: { src: '../../genesis/REFERENCE/ribbon-font/fgen-third-ten-original-M/uppercase-U.png', canvasWidth: 1254, canvasHeight: 1254, left: 201, top: 206, right: 1082, bottom: 1075 },
    V: { src: '../../genesis/REFERENCE/ribbon-font/fgen-third-ten-original-M/uppercase-V.png', canvasWidth: 1254, canvasHeight: 1254, left: 225, top: 277, right: 1053, bottom: 977 },
    W: { src: '../../genesis/REFERENCE/ribbon-font/fgen-third-ten-original-M/uppercase-W.png', canvasWidth: 1254, canvasHeight: 1254, left: 66, top: 285, right: 1181, bottom: 959 },
    X: { src: '../../genesis/REFERENCE/ribbon-font/fgen-third-ten-original-M/uppercase-X.png', canvasWidth: 1254, canvasHeight: 1254, left: 202, top: 251, right: 1050, bottom: 1015 },
    Y: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/uppercase-Y.png', canvasWidth: 1254, canvasHeight: 1254, left: 297, top: 240, right: 994, bottom: 1011 },
    Z: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/uppercase-Z.png', canvasWidth: 1254, canvasHeight: 1254, left: 209, top: 235, right: 1044, bottom: 1016 },
    a: { src: '../../genesis/REFERENCE/ribbon-font/fgen-five-original-M/lowercase-a.png', canvasWidth: 1254, canvasHeight: 1254, left: 299, top: 366, right: 992, bottom: 895 },
    b: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-b.png', canvasWidth: 1254, canvasHeight: 1254, left: 310, top: 188, right: 944, bottom: 1066, xTop: 527 },
    c: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-c.png', canvasWidth: 1254, canvasHeight: 1254, left: 344, top: 340, right: 918, bottom: 934 },
    d: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-d.png', canvasWidth: 1254, canvasHeight: 1254, left: 271, top: 200, right: 1015, bottom: 1050, xTop: 539 },
    e: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-e.png', canvasWidth: 1254, canvasHeight: 1254, left: 308, top: 303, right: 961, bottom: 944 },
    f: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-f.png', canvasWidth: 1254, canvasHeight: 1254, left: 382, top: 205, right: 865, bottom: 1041, xTop: 535 },
    g: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-g.png', canvasWidth: 1254, canvasHeight: 1254, left: 333, top: 301, right: 930, bottom: 1033, baseline: 755 },
    h: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-h.png', canvasWidth: 1254, canvasHeight: 1254, left: 164, top: 169, right: 1090, bottom: 1085, xTop: 493 },
    i: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-i.png', canvasWidth: 1254, canvasHeight: 1254, left: 440, top: 269, right: 734, bottom: 985, xTop: 496 },
    j: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-j.png', canvasWidth: 1254, canvasHeight: 1254, left: 400, top: 232, right: 787, bottom: 1032, xTop: 424, baseline: 830 },
    k: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-k.png', canvasWidth: 1254, canvasHeight: 1254, left: 221, top: 210, right: 1023, bottom: 1056, xTop: 473 },
    l: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-l.png', canvasWidth: 1254, canvasHeight: 1254, left: 437, top: 183, right: 810, bottom: 1069, xTop: 507 },
    m: { src: '../../genesis/REFERENCE/ribbon-font/fgen-five-original-M/lowercase-m.png', canvasWidth: 1254, canvasHeight: 1254, left: 86, top: 358, right: 1168, bottom: 881 },
    n: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-n.png', canvasWidth: 1254, canvasHeight: 1254, left: 215, top: 319, right: 1038, bottom: 953 },
    o: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-o.png', canvasWidth: 1254, canvasHeight: 1254, left: 290, top: 322, right: 957, bottom: 937 },
    p: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-p.png', canvasWidth: 1254, canvasHeight: 1254, left: 352, top: 331, right: 891, bottom: 972, baseline: 730 },
    q: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-q.png', canvasWidth: 1254, canvasHeight: 1254, left: 286, top: 278, right: 1016, bottom: 995, baseline: 825 },
    r: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-r.png', canvasWidth: 1254, canvasHeight: 1254, left: 331, top: 343, right: 917, bottom: 903 },
    s: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-s.png', canvasWidth: 1254, canvasHeight: 1254, left: 394, top: 345, right: 860, bottom: 910 },
    t: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-t.png', canvasWidth: 1254, canvasHeight: 1254, left: 327, top: 245, right: 884, bottom: 1012, xTop: 478 },
    u: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-u-v3.png', canvasWidth: 1254, canvasHeight: 1254, left: 281, top: 331, right: 989, bottom: 950 },
    v: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-v.png', canvasWidth: 1254, canvasHeight: 1254, left: 268, top: 355, right: 1012, bottom: 943 },
    w: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-w.png', canvasWidth: 1254, canvasHeight: 1254, left: 79, top: 432, right: 1176, bottom: 878 },
    x: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-x-v2.png', canvasWidth: 1254, canvasHeight: 1254, left: 316, top: 345, right: 933, bottom: 925 },
    y: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-y.png', canvasWidth: 1254, canvasHeight: 1254, left: 323, top: 290, right: 951, bottom: 1026, baseline: 690 },
    z: { src: '../../genesis/REFERENCE/ribbon-font/fgen-complete-alphabet-original-M/lowercase-z.png', canvasWidth: 1254, canvasHeight: 1254, left: 319, top: 302, right: 935, bottom: 952 },
  };
  const availableLetters = Object.keys(glyphs).sort().join(', ');
  const templates = new Map();
  const baseline = document.createElement('span');
  baseline.className = 'baseline-marker';
  baseline.setAttribute('aria-hidden', 'true');
  let automaticFit = true;
  let previewText = '';

  function createGlyph(letter, glyph) {
    const glyphBaseline = glyph.baseline ?? glyph.bottom;
    const uppercase = letter === letter.toUpperCase();
    const bodyTop = uppercase ? glyph.top : (glyph.xTop ?? glyph.top);
    const scale = (uppercase ? capHeight : xHeight) / (glyphBaseline - bodyTop);
    const left = Math.max(0, glyph.left - 8);
    const top = Math.max(0, glyph.top - 8);
    const right = Math.min(glyph.canvasWidth, glyph.right + 8);
    const bottom = Math.min(glyph.canvasHeight, glyph.bottom + 8);
    const em = value => `${value * scale / unitsPerEm}em`;
    const wrapper = document.createElement('span');
    wrapper.className = 'fgen-glyph';
    wrapper.dataset.fgenGlyph = letter;
    wrapper.setAttribute('aria-hidden', 'true');
    Object.assign(wrapper.style, { width: em(right - left), height: em(bottom - top), verticalAlign: em(glyphBaseline - bottom) });
    const image = document.createElement('img');
    image.src = glyph.src;
    image.alt = '';
    image.draggable = false;
    Object.assign(image.style, { width: em(glyph.canvasWidth), height: em(glyph.canvasHeight), left: em(-left), top: em(-top) });
    wrapper.append(image);
    return wrapper;
  }

  for (const [letter, glyph] of Object.entries(glyphs)) {
    templates.set(letter, createGlyph(letter, glyph));
  }

  function updateGuides() {
    if (!stage.clientWidth) return;
    const baselineY = baseline.getBoundingClientRect().top - line.getBoundingClientRect().top;
    const scale = Number(size.value) / capHeight;
    composer.style.setProperty('--study-cap-line', `${baselineY - capHeight * scale}px`);
    composer.style.setProperty('--study-x-line', `${baselineY - xHeight * scale}px`);
    composer.style.setProperty('--study-baseline', `${baselineY}px`);
  }

  function updateSize(value) {
    size.value = String(value);
    composer.style.setProperty('--study-size', `${size.value}px`);
    document.getElementById('fgen-size-value').textContent = `${size.value} px`;
    size.setAttribute('aria-valuetext', `${size.value} pixels capital height`);
    updateGuides();
  }

  function fitWord() {
    if (!previewText.trim() || stage.clientWidth <= 24) return;
    const width = word.getBoundingClientRect().width;
    updateSize(Math.max(Number(size.min), Math.min(Number(size.max), Math.floor(Number(size.value) * (stage.clientWidth - 24) / Math.max(width, 1)))));
  }

  function renderWord() {
    const fragment = document.createDocumentFragment();
    for (const letter of previewText) {
      if (letter === ' ') {
        const space = document.createElement('span');
        space.className = 'fgen-space';
        space.setAttribute('aria-hidden', 'true');
        fragment.append(space);
      } else {
        fragment.append(templates.get(letter).cloneNode(true));
      }
    }
    fragment.append(baseline);
    word.replaceChildren(fragment);
    word.setAttribute('aria-label', previewText.trim() ? `Fgen letter combination: ${previewText}` : 'No Fgen preview text');
    empty.hidden = Boolean(previewText.trim());
    if (automaticFit) fitWord();
    updateGuides();
  }

  function updateWord() {
    const unsupported = [...new Set([...input.value].filter(letter => letter !== ' ' && !templates.has(letter)))];
    input.setAttribute('aria-invalid', String(unsupported.length > 0));
    message.classList.toggle('error', unsupported.length > 0);
    if (unsupported.length) {
      message.textContent = `Not generated in this sample: ${unsupported.join(' ')}. Available: ${availableLetters} and spaces. Showing your last supported text.`;
      return;
    }
    previewText = input.value;
    renderWord();
    message.textContent = initialMessage;
    presets.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.fgenWord === previewText)));
  }

  function selectSource(source, updateUrl = false) {
    for (const tab of tabs) {
      const selected = tab.dataset.source === source;
      tab.setAttribute('aria-selected', String(selected));
      tab.tabIndex = selected ? 0 : -1;
      document.getElementById(tab.getAttribute('aria-controls')).hidden = !selected;
    }
    if (updateUrl) history.replaceState(null, '', source === 'fgen' ? '#fgen' : '#vector');
    if (source === 'fgen' && !controls.disabled) requestAnimationFrame(() => { if (automaticFit) fitWord(); updateGuides(); });
  }

  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => selectSource(tab.dataset.source, true));
    tab.addEventListener('keydown', event => {
      let next;
      if (event.key === 'ArrowRight') next = (index + 1) % tabs.length;
      else if (event.key === 'ArrowLeft') next = (index + tabs.length - 1) % tabs.length;
      else if (event.key === 'Home') next = 0;
      else if (event.key === 'End') next = tabs.length - 1;
      else return;
      event.preventDefault();
      tabs[next].focus();
      selectSource(tabs[next].dataset.source, true);
    });
  });
  window.addEventListener('hashchange', () => {
    selectSource(location.hash === '#fgen' ? 'fgen' : 'vector');
    if (location.hash === '#word-hub' || location.hash === '#uppercase-heading') requestAnimationFrame(() => document.querySelector(location.hash).scrollIntoView());
  });
  selectSource(location.hash === '#fgen' ? 'fgen' : 'vector');

  input.addEventListener('input', updateWord);
  size.addEventListener('input', () => { automaticFit = false; updateSize(size.value); });
  tracking.addEventListener('input', () => {
    composer.style.setProperty('--study-tracking', `${tracking.value}em`);
    document.getElementById('fgen-tracking-value').textContent = `${Number(tracking.value).toFixed(3)} em`;
    tracking.setAttribute('aria-valuetext', `${tracking.value} em`);
    if (automaticFit) fitWord();
  });
  document.getElementById('fgen-fit').addEventListener('click', () => { automaticFit = true; fitWord(); stage.scrollLeft = 0; });
  document.getElementById('fgen-guides').addEventListener('click', event => event.currentTarget.setAttribute('aria-pressed', String(stage.classList.toggle('guides'))));
  presets.forEach(button => button.addEventListener('click', () => { input.value = button.dataset.fgenWord; automaticFit = true; updateWord(); stage.scrollLeft = 0; }));
  new ResizeObserver(() => { if (!controls.disabled && automaticFit) fitWord(); }).observe(stage);

  composer.style.setProperty('--study-font-scale', unitsPerEm / capHeight);
  composer.style.setProperty('--study-line-height', '.88em');
  Promise.all([...templates.values()].map(template => new Promise((resolve, reject) => {
    const image = template.querySelector('img');
    image.onload = resolve;
    image.onerror = reject;
    if (image.complete) image.naturalWidth ? resolve() : reject();
  }))).then(() => {
    controls.disabled = false;
    composer.classList.add('font-ready');
    composer.setAttribute('aria-busy', 'false');
    status.textContent = `${templates.size - 1} Fgen letters + original M / PNG preview`;
    empty.textContent = 'Type a word below';
    updateWord();
  }).catch(() => {
    composer.setAttribute('aria-busy', 'false');
    status.textContent = 'Fgen samples unavailable';
    empty.textContent = 'The generated letter images could not load';
    message.textContent = 'Keep the original sample image folders beside this website, then reopen it. The raw PNG links below remain available.';
    message.classList.add('error');
  });
})();
