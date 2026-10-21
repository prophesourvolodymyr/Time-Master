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
    a: { src: '../../genesis/REFERENCE/ribbon-font/fgen-five-original-M/lowercase-a.png', canvasWidth: 1254, canvasHeight: 1254, left: 299, top: 366, right: 992, bottom: 895 },
    m: { src: '../../genesis/REFERENCE/ribbon-font/fgen-five-original-M/lowercase-m.png', canvasWidth: 1254, canvasHeight: 1254, left: 86, top: 358, right: 1168, bottom: 881 },
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
    const scale = (letter === letter.toUpperCase() ? capHeight : xHeight) / (glyphBaseline - glyph.top);
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
