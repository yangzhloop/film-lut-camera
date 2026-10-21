(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const renderer = window.LutliRenderer;
  const palette = [
    ['Indigo', '#4349cc'], ['Yellow', '#f4da47'], ['Green', '#416b52'], ['Cream', '#eee8d5'],
    ['Red', '#bb5147'], ['Violet', '#897198'], ['Slate', '#687681'], ['Charcoal', '#292c2d']
  ];
  const builtins = [
    { id: 'original', top: 'ORIGINAL', bottom: 'RGB', topColor: '#292c2d', bottomColor: '#eee8d5' },
    { id: 'warm400', top: 'WARM', bottom: '400', topColor: '#4349cc', bottomColor: '#f4da47' },
    { id: 'soft200', top: 'SOFT', bottom: '200', topColor: '#416b52', bottomColor: '#eee8d5' },
    { id: 'chrome100', top: 'CHROME', bottom: '100', topColor: '#bb5147', bottomColor: '#eee8d5' },
    { id: 'fade400', top: 'FADE', bottom: '400', topColor: '#897198', bottomColor: '#eee8d5' },
    { id: 'night800', top: 'NIGHT', bottom: '800', topColor: '#687681', bottomColor: '#f4da47' },
    { id: 'mono800', top: 'MONO', bottom: '800', topColor: '#292c2d', bottomColor: '#eee8d5' }
  ];
  const glowColors = { neutral: null, amber: '#ff9e47', rose: '#ff738c', red: '#ff3829' };
  const effectNames = { off: 'Off', hdf: 'HDF', blackMist: 'Black Mist' };
  const initialPreferences = () => ({ grid: false, saveOriginal: false, rememberLook: true, haptics: true, timer: 0 });
  const state = {
    screen: 'shoot', tray: null, tab: 'builtin', selection: 'original', custom: [], intensities: {},
    effect: 'off', strengths: { hdf: 35, blackMist: 20 }, glow: 'neutral', customGlow: '#ffae62',
    ev: 0, wb: 'auto', temperature: 5500, tint: 0, zoom: 1, mirrored: false, flash: 'off',
    preferences: initialPreferences(), draft: null, draftBaseline: '', replaceID: null,
    image: null, capture: null, pendingCapture: null, countdown: 0
  };
  let frameRequested = false;
  let toastTimeout;
  let focusTimeout;
  let countdownInterval;
  let imageObjectURL;
  let importRevision = 0;
  let imageRevision = 0;
  let confirmation = null;
  const openers = {};
  const emptyThumbnail = [...$('review-open').childNodes].map((node) => node.cloneNode(true));

  function make(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  }
  function button(text, className, action) {
    const node = make('button', className, text);
    node.type = 'button';
    node.addEventListener('click', action);
    return node;
  }
  function setSelected(node, selected) {
    node.classList.toggle('is-selected', selected);
    node.setAttribute('aria-pressed', String(selected));
  }
  function toast(message) {
    clearTimeout(toastTimeout);
    $('toast').textContent = message;
    $('toast').hidden = false;
    toastTimeout = setTimeout(() => { $('toast').hidden = true; }, 3400);
  }
  function contrast(hex) {
    const values = hex.replace('#', '').match(/.{2}/g).map((v) => parseInt(v, 16) / 255);
    const linear = values.map((v) => v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
    const luminance = linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722;
    return (luminance + 0.05) / 0.05 > 1.05 / (luminance + 0.05) ? '#101111' : '#ffffff';
  }
  function colorSection(node, text, color) {
    node.textContent = text;
    node.style.backgroundColor = color;
    node.style.color = contrast(color);
  }
  function filmLabel(look) {
    const label = make('span', 'film-label');
    const top = make('span', 'label-top');
    const bottom = make('span', 'label-bottom');
    colorSection(top, look.top, look.topColor);
    colorSection(bottom, look.bottom, look.bottomColor);
    label.append(top, bottom);
    return label;
  }
  function selectedLook() {
    return [...builtins, ...state.custom].find((look) => look.id === state.selection) || builtins[0];
  }
  function intensity() { return state.intensities[state.selection] ?? 100; }
  function currentGlow() { return state.glow === 'custom' ? state.customGlow : glowColors[state.glow]; }
  function glowName() { return state.glow[0].toUpperCase() + state.glow.slice(1); }
  function renderOptions() {
    const look = selectedLook();
    return {
      look: look.cube ? 'original' : look.id, cube: look.cube, intensity: intensity() / 100,
      ev: state.ev, temperature: state.wb === 'auto' ? 5500 : state.temperature,
      tint: state.wb === 'auto' ? 0 : state.tint, effect: state.effect,
      strength: state.effect === 'off' ? 0 : state.strengths[state.effect] / 100,
      glow: currentGlow(), zoom: state.zoom, mirrored: state.mirrored
    };
  }
  function fitCanvas() {
    const bounds = $('scene-area').getBoundingClientRect();
    if (bounds.width < 1 || bounds.height < 1) return;
    const scale = 720 / Math.max(bounds.width, bounds.height);
    const width = Math.max(1, Math.round(bounds.width * scale));
    const height = Math.max(1, Math.round(bounds.height * scale));
    if ($('scene-canvas').width !== width || $('scene-canvas').height !== height) {
      $('scene-canvas').width = width;
      $('scene-canvas').height = height;
    }
  }
  function renderNow() {
    if (!state.image || !renderer) return;
    fitCanvas();
    try {
      renderer.render($('scene-canvas'), state.image, renderOptions());
      $('scene-loading').hidden = true;
      $('shutter').disabled = false;
    } catch (error) {
      $('scene-loading').hidden = false;
      $('scene-loading').textContent = 'This image could not be rendered. Try another photo.';
      $('shutter').disabled = true;
      console.error('Lutli prototype render:', error);
    }
  }
  function requestRender() {
    if (frameRequested) return;
    frameRequested = true;
    requestAnimationFrame(() => { frameRequested = false; renderNow(); });
  }

  function syncControls() {
    const evText = `${state.ev >= 0 ? '+' : ''}${state.ev.toFixed(1)}`;
    $('ev-summary').textContent = evText;
    $('ev-value').textContent = `${evText} EV`;
    $('ev-slider').value = state.ev;
    $('wb-summary').textContent = state.wb === 'auto' ? 'Auto' : state.wb === 'locked' ? 'Lock' : `${state.temperature}K`;
    $('temperature').value = state.temperature;
    $('temperature-value').textContent = `${state.temperature.toLocaleString()} K`;
    $('tint').value = state.tint;
    $('tint-value').textContent = `${state.tint > 0 ? '+' : ''}${state.tint}`;
    $('wb-manual').hidden = state.wb !== 'manual';
    $$('[data-wb]').forEach((node) => setSelected(node, node.dataset.wb === state.wb));
    const active = state.effect !== 'off';
    const amount = active ? state.strengths[state.effect] : 0;
    $('filter-summary').textContent = active ? `${state.effect === 'hdf' ? 'HDF' : 'Mist'} ${amount}%` : 'Filters Off';
    $('filters-toggle').setAttribute('aria-label', `Diffusion filters: ${active ? `${effectNames[state.effect]}, ${amount}%${state.effect === 'hdf' ? `, ${glowName()}` : ''}` : 'Off'}`);
    $('filter-dot').hidden = state.effect !== 'hdf';
    $('filter-dot').style.backgroundColor = currentGlow() || '#eee8d5';
    $('effect-details').hidden = !active;
    $('effect-strength').value = amount;
    $('effect-strength').setAttribute('aria-label', `${effectNames[state.effect]} filter strength`);
    $('effect-strength-value').textContent = `${amount}%`;
    $('glow-controls').hidden = state.effect !== 'hdf';
    $('glow-name').textContent = glowName();
    $('custom-glow').value = state.customGlow;
    $('custom-glow').setAttribute('aria-label', `Custom glow color${state.glow === 'custom' ? ', selected' : ''}`);
    $('custom-glow').classList.toggle('is-selected', state.glow === 'custom');
    $('custom-glow').parentElement.classList.toggle('is-selected', state.glow === 'custom');
    $$('button[data-effect]').forEach((node) => setSelected(node, node.dataset.effect === state.effect));
    $$('[data-glow]').forEach((node) => setSelected(node, node.dataset.glow === state.glow));
    $$('[data-zoom]').forEach((node) => setSelected(node, Number(node.dataset.zoom) === state.zoom));
    $('look-intensity').value = intensity();
    $('look-intensity').disabled = state.selection === 'original';
    $('look-intensity-value').textContent = `${intensity()}%`;
    $('grid-overlay').hidden = !state.preferences.grid;
    $('flash-toggle').setAttribute('aria-label', `Flash ${state.flash}. Demo setting`);
    $('flash-toggle').classList.toggle('is-selected', state.flash !== 'off');
    $('flash-toggle').dataset.mode = state.flash;
    $('camera-switch').setAttribute('aria-label', state.mirrored ? 'Return to rear demo view' : 'Switch to mirrored front demo view');
    ['diffusion', 'ev', 'wb'].forEach((name) => { $(`${name}-tray`).hidden = state.tray !== name; });
    $('lens-row').hidden = state.tray !== null;
    $('filters-toggle').setAttribute('aria-expanded', String(state.tray === 'diffusion'));
    $('ev-toggle').setAttribute('aria-expanded', String(state.tray === 'ev'));
    $('wb-toggle').setAttribute('aria-expanded', String(state.tray === 'wb'));
    $('phone-screen').dataset.effect = state.effect;
  }
  function showTray(name) {
    state.tray = state.tray === name ? null : name;
    syncControls();
  }
  function closeTray(restoreFocus = false) {
    const previous = state.tray;
    state.tray = null;
    syncControls();
    if (restoreFocus && previous) $(previous === 'diffusion' ? 'filters-toggle' : `${previous}-toggle`).focus();
  }
  function showScreen(name, restoreFocus = false) {
    cancelCountdown();
    closeTray();
    const previous = state.screen;
    if (name !== 'shoot' && name !== previous) openers[name] = document.activeElement;
    state.screen = name;
    ['library', 'editor', 'menu', 'review', 'info'].forEach((screen) => {
      const node = $(`${screen}-screen`);
      node.hidden = screen !== name;
      node.inert = screen !== name;
      node.removeAttribute('aria-modal');
    });
    $('shoot-screen').inert = name !== 'shoot';
    $('phone-screen').dataset.screen = name;
    if (name === 'library') renderLibrary();
    if (name === 'review') renderReview();
    requestAnimationFrame(() => {
      if (restoreFocus && openers[previous]?.isConnected && !openers[previous].closest('[hidden], [inert]')) {
        openers[previous].focus({ preventScroll: true });
      } else {
        const screen = $(`${name}-screen`);
        const target = screen.querySelector('button:not(:disabled), input:not(:disabled), [tabindex="0"]');
        target?.focus({ preventScroll: true });
      }
      requestRender();
    });
  }
  function ask(title, description, accept = 'Continue') {
    if (confirmation) return Promise.resolve(false);
    $('confirm-title').textContent = title;
    $('confirm-description').textContent = description;
    $('confirm-accept').textContent = accept;
    $('confirm-cancel').textContent = title === 'Discard label changes?' ? 'Keep editing' : 'Cancel';
    $('confirm-dialog').showModal();
    $('confirm-cancel').focus();
    return new Promise((resolve) => { confirmation = resolve; });
  }
  function finishConfirmation(result) {
    const resolve = confirmation;
    confirmation = null;
    $('confirm-dialog').close();
    resolve?.(result);
  }

  function renderLookStrip() {
    const strip = $('look-strip');
    const scroll = strip.scrollLeft;
    strip.replaceChildren();
    [...builtins, ...state.custom].forEach((look) => {
      const node = button('', 'look-button', () => selectLook(look.id));
      node.dataset.look = look.id;
      node.setAttribute('aria-label', `${look.top} ${look.bottom}`);
      setSelected(node, state.selection === look.id);
      node.append(filmLabel(look));
      strip.append(node);
    });
    strip.scrollLeft = scroll;
  }
  function selectLook(id, returnToCamera = false) {
    if (![...builtins, ...state.custom].some((look) => look.id === id)) return;
    const restoreLookFocus = $('look-strip').contains(document.activeElement)
      && document.activeElement.dataset.look === id;
    state.selection = id;
    renderLookStrip();
    syncControls();
    requestRender();
    if (returnToCamera) showScreen('shoot', true);
    const selected = $$('[data-look]', $('look-strip')).find((node) => node.dataset.look === id);
    if (restoreLookFocus && !returnToCamera) selected?.focus({ preventScroll: true });
    selected?.scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth', block: 'nearest', inline: 'nearest' });
  }
  function renderLibrary() {
    const count = state.custom.length;
    $('slot-count').textContent = `${count} of 5 slots used`;
    $('import-lut').disabled = count >= 5;
    $('demo-look').disabled = count >= 5;
    $('library-help').textContent = count >= 5
      ? 'Your five slots are full. Replace or delete a custom look to make room.'
      : 'Import an SDR sRGB .cube (17 or 33), up to 8 MiB. Your files stay in this browser session.';
    $$('[data-library-tab]').forEach((node) => {
      setSelected(node, node.dataset.libraryTab === state.tab);
      node.setAttribute('aria-selected', String(node.dataset.libraryTab === state.tab));
    });
    const looks = state.tab === 'builtin' ? builtins : state.custom;
    $('library-empty').hidden = looks.length > 0;
    $('library-grid').replaceChildren();
    looks.forEach((look) => {
      const card = make('article', 'library-card');
      const choose = button('', 'library-look', () => selectLook(look.id, true));
      choose.setAttribute('aria-label', `Use ${look.top} ${look.bottom}`);
      setSelected(choose, state.selection === look.id);
      choose.append(filmLabel(look));
      card.append(choose);
      if (look.cube) {
        const actions = make('div', 'card-actions');
        const edit = button('Edit', 'text-button', () => openEditor(look));
        edit.setAttribute('aria-label', `Edit ${look.top} label`);
        const replace = button('Replace', 'text-button', () => {
          state.replaceID = look.id;
          $('lut-file').value = '';
          $('lut-file').click();
        });
        replace.setAttribute('aria-label', `Replace ${look.top} LUT`);
        const remove = button('Delete', 'text-button destructive', async () => {
          if (!await ask('Delete this look?', `${look.top} ${look.bottom} will be removed from this prototype session.`, 'Delete look')) return;
          state.custom = state.custom.filter((item) => item.id !== look.id);
          delete state.intensities[look.id];
          if (state.selection === look.id) state.selection = 'original';
          renderLibrary(); renderLookStrip(); syncControls(); requestRender();
          toast('Custom look deleted.');
        });
        remove.setAttribute('aria-label', `Delete ${look.top}`);
        actions.append(edit, replace, remove);
        card.append(actions);
      }
      $('library-grid').append(card);
    });
  }
  function libraryError(message = '') {
    $('library-error').textContent = message;
    $('library-error').hidden = !message;
  }
  function openLibrary(tab = state.tab) {
    state.tab = tab;
    libraryError();
    showScreen('library');
  }
  function labelSnapshot(draft) {
    return JSON.stringify([draft.top, draft.bottom, draft.topColor, draft.bottomColor]);
  }
  function openEditor(look, isNew = false) {
    state.draft = { ...look, isNew };
    state.draftBaseline = labelSnapshot(state.draft);
    $('editor-title').textContent = isNew ? 'Customize label' : 'Edit label';
    $('top-text').value = look.top;
    $('bottom-text').value = look.bottom;
    $('editor-error').hidden = true;
    $('editor-error').textContent = '';
    renderPalettes(); updateLabelPreview(); showScreen('editor');
  }
  function newDemoLook() {
    if (state.custom.length >= 5) { openLibrary('custom'); libraryError('All five slots are full. Replace or delete a look first.'); return; }
    const cube = renderer.makeDemoLUT();
    openEditor({ id: newID(), top: 'DAYLIGHT', bottom: '400', topColor: '#4349cc', bottomColor: '#f4da47', cube }, true);
  }
  function newID() {
    return `custom-${globalThis.crypto?.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(16).slice(2)}`}`;
  }
  function renderPalettes() {
    ['top', 'bottom'].forEach((section) => {
      const container = $(`${section}-palette`);
      container.replaceChildren();
      palette.forEach(([name, color]) => {
        const swatch = button('', 'palette-swatch', () => {
          state.draft[`${section}Color`] = color;
          renderPalettes(); updateLabelPreview();
          $$('button', container).find((node) => node.dataset.color === color)?.focus({ preventScroll: true });
        });
        swatch.style.setProperty('--swatch', color);
        swatch.style.color = contrast(color);
        swatch.dataset.color = color;
        swatch.setAttribute('aria-label', `${section === 'top' ? 'Top' : 'Bottom'} color: ${name}`);
        setSelected(swatch, state.draft[`${section}Color`] === color);
        container.append(swatch);
      });
    });
  }
  function updateLabelPreview() {
    if (!state.draft) return;
    colorSection($('preview-top'), state.draft.top.trim() || 'YOUR LOOK', state.draft.topColor);
    colorSection($('preview-bottom'), state.draft.bottom.trim() || '400', state.draft.bottomColor);
  }
  function graphemeLength(text) {
    return typeof Intl.Segmenter === 'function'
      ? [...new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(text)].length
      : Array.from(text).length;
  }
  function saveLabel() {
    if (!state.draft) return;
    const top = state.draft.top.trim();
    const bottom = state.draft.bottom.trim();
    if ([top, bottom].some((text) => !text || graphemeLength(text) > 12 || /[\r\n\u2028\u2029]/.test(text))) {
      $('editor-error').textContent = 'Use 1–12 characters on each line. Both sections need a name or number.';
      $('editor-error').hidden = false;
      (!top || graphemeLength(top) > 12 ? $('top-text') : $('bottom-text')).focus();
      return;
    }
    const { isNew, ...look } = state.draft;
    look.top = top; look.bottom = bottom;
    if (isNew) {
      if (state.custom.length >= 5) { $('editor-error').hidden = false; $('editor-error').textContent = 'All five custom slots are full.'; return; }
      state.custom.push(look);
    } else {
      const index = state.custom.findIndex((item) => item.id === look.id);
      if (index < 0) return;
      state.custom[index] = look;
    }
    state.draft = null;
    state.tab = 'custom';
    renderLookStrip(); syncControls(); requestRender(); showScreen('library', true);
    toast(isNew ? 'Your new look is ready to use.' : 'Label updated everywhere.');
  }
  async function cancelEditor() {
    if (state.draft && labelSnapshot(state.draft) !== state.draftBaseline) {
      if (!await ask('Discard label changes?', 'Your existing look will stay unchanged.', 'Discard changes')) return false;
    }
    state.draft = null;
    state.tab = 'custom';
    showScreen('library', true);
    return true;
  }
  async function importLUT(file) {
    if (!file) { state.replaceID = null; return; }
    const revision = ++importRevision;
    const replacement = state.replaceID;
    state.replaceID = null;
    libraryError();
    try {
      if (!/\.cube$/i.test(file.name)) throw new Error('Choose a .cube LUT file.');
      if (file.size > 8 * 1024 * 1024) throw new Error('Choose a .cube file smaller than 8 MiB.');
      if (!replacement && state.custom.length >= 5) throw new Error('All five slots are full. Replace or delete a look first.');
      const text = new TextDecoder('utf-8', { fatal: true }).decode(await file.arrayBuffer());
      const cube = renderer.parseCube(text);
      if (revision !== importRevision) return;
      if (replacement) {
        const look = state.custom.find((item) => item.id === replacement);
        if (!look) throw new Error('This look is no longer in your collection.');
        look.cube = cube;
        renderLibrary(); requestRender();
        toast('LUT replaced. Your label and intensity are unchanged.');
      } else {
        const rawName = file.name.replace(/\.cube$/i, '').replace(/[_-]+/g, ' ').trim();
        const name = Array.from(rawName || 'MY LOOK').slice(0, 12).join('');
        openEditor({ id: newID(), top: name, bottom: 'CUSTOM', topColor: '#416b52', bottomColor: '#eee8d5', cube }, true);
      }
    } catch (error) {
      if (revision !== importRevision) return;
      if (state.screen !== 'library') openLibrary('custom');
      libraryError(error instanceof TypeError ? 'The file is not readable UTF-8 text. Choose a supported .cube LUT.' : error.message);
    } finally { $('lut-file').value = ''; }
  }

  function paragraph(text) { return make('p', 'body-copy', text); }
  function settingToggle(title, description, key) {
    const row = make('label', 'settings-row');
    const copy = make('span', 'settings-copy');
    copy.append(make('strong', '', title), make('small', '', description));
    const control = make('input', 'switch');
    control.type = 'checkbox'; control.checked = state.preferences[key];
    control.setAttribute('aria-label', title);
    control.addEventListener('change', () => { state.preferences[key] = control.checked; syncControls(); });
    row.append(copy, control);
    return row;
  }
  function showInfo(kind) {
    const body = $('info-body');
    body.replaceChildren();
    const titles = { camera: 'Camera & saving', preferences: 'App preferences', feedback: 'Send feedback', about: 'About lutli', terms: 'Terms & conditions', privacy: 'Privacy' };
    $('info-title').textContent = titles[kind] || 'About lutli';
    if (kind === 'camera') {
      body.append(
        settingToggle('Save clean original', 'Keep a copy without the LUT or diffusion.', 'saveOriginal'),
        settingToggle('Grid', 'A quiet guide for your composition.', 'grid')
      );
      const row = make('div', 'settings-row');
      const copy = make('span', 'settings-copy');
      copy.append(make('strong', '', 'Shutter timer'), make('small', '', 'Tap the shutter again to cancel.'));
      const choices = make('div', 'segmented');
      [0, 3, 10].forEach((value) => {
        const choice = button(value ? `${value}s` : 'Off', '', () => {
          state.preferences.timer = value;
          $$('button', choices).forEach((node) => setSelected(node, Number(node.dataset.timer) === value));
        });
        choice.dataset.timer = value;
        setSelected(choice, state.preferences.timer === value);
        choices.append(choice);
      });
      row.append(copy, choices); body.append(row);
      body.append(paragraph('In this prototype, captures download as sample JPEGs. Nothing is saved to your Photos library automatically.'));
    } else if (kind === 'preferences') {
      body.append(
        settingToggle('Remember last look', 'Native-app preference; this demo resets on reload.', 'rememberLook'),
        settingToggle('Shutter haptics', 'Native-app preference; no browser vibration is requested.', 'haptics'),
        paragraph('Prototype preferences and custom looks last for this open session. Reloading starts fresh; diffusion always starts Off.')
      );
    } else if (kind === 'feedback') {
      body.append(paragraph('What felt right? What would you change? Write a note to keep with your prototype review.'));
      const label = make('label', 'field-label', 'Your feedback');
      const note = make('textarea', 'text-input');
      note.id = 'feedback-note'; note.rows = 6; note.placeholder = 'I would like…';
      label.htmlFor = note.id;
      const save = button('Download feedback note', 'primary-button', () => {
        if (!note.value.trim()) { note.focus(); toast('Write a note first.'); return; }
        downloadBlob(new Blob([note.value.trim()], { type: 'text/plain;charset=utf-8' }), 'lutli-feedback.txt');
        toast('Feedback note downloaded locally. Nothing was sent.');
      });
      body.append(label, note, save, paragraph('This is a local note, not a submitted support message.'));
    } else if (kind === 'terms') {
      body.append(paragraph('Interactive design prototype'), paragraph('This preview is for exploring Lutli’s interface. It is not an app release, a camera service, or a calibrated film simulation. Production terms and publisher details are still being prepared.'));
    } else if (kind === 'privacy') {
      body.append(paragraph('Local by design'), paragraph('This standalone preview makes no network requests. Photos and LUTs you choose are read locally in this open browser tab. Custom looks and captures are held in memory and disappear when you reload or close it.'), paragraph('Download buttons save only the file you choose. No camera access, analytics, accounts, or automatic uploads are used.'));
    } else {
      body.append(make('p', 'about-wordmark', 'lutli'), paragraph('A little light. A look of your own.'), paragraph('Film-inspired LUT looks, a personal label collection, and soft highlight diffusion. Designed first for native iOS.'), paragraph('Interactive browser prototype · 0.1'), paragraph('The sample scene and browser effects illustrate the experience. Real camera controls, photographic tuning, and Apple rendering are part of the iOS app.'));
    }
    showScreen('info');
  }

  function makeCapture() {
    renderNow();
    const canvas = $('scene-canvas');
    const look = selectedLook();
    const options = renderOptions();
    const description = `${look.top} ${look.bottom} · ${intensity()}% look${state.effect === 'off' ? ' · Filters Off' : ` · ${effectNames[state.effect]} ${state.strengths[state.effect]}%${state.effect === 'hdf' ? ` · ${glowName()}` : ''}`}`;
    let original = null;
    if (state.preferences.saveOriginal) {
      const clean = document.createElement('canvas'); clean.width = canvas.width; clean.height = canvas.height;
      renderer.render(clean, state.image, { ...options, look: 'original', cube: undefined, intensity: 0, effect: 'off', strength: 0 });
      original = clean.toDataURL('image/jpeg', 0.95);
    }
    return { image: canvas.toDataURL('image/jpeg', 0.95), original, description, time: new Date().toISOString() };
  }
  function finishCapture(capture) {
    state.capture = capture;
    $('review-open').disabled = false;
    const image = make('img', 'last-capture'); image.src = capture.image; image.alt = '';
    $('review-open').replaceChildren(image);
    $('capture-flash').hidden = false;
    $('capture-flash').classList.add('capture-ready');
    setTimeout(() => { $('capture-flash').hidden = true; $('capture-flash').classList.remove('capture-ready'); }, 160);
    toast('Sample captured. Tap the thumbnail to review.');
  }
  function cancelCountdown() {
    clearInterval(countdownInterval);
    state.pendingCapture = null; state.countdown = 0;
    $('countdown').hidden = true;
    $('shutter').setAttribute('aria-label', 'Capture sample photo');
    $('shutter').classList.remove('is-counting');
  }
  function capture() {
    if (state.pendingCapture) { cancelCountdown(); toast('Timer canceled.'); return; }
    if (!state.image) return;
    let frozen;
    try { frozen = makeCapture(); } catch { toast('The photo could not be captured. Try another image.'); return; }
    if (!state.preferences.timer) { finishCapture(frozen); return; }
    state.pendingCapture = frozen;
    state.countdown = state.preferences.timer;
    $('countdown').textContent = state.countdown; $('countdown').hidden = false;
    $('shutter').setAttribute('aria-label', 'Cancel timer'); $('shutter').classList.add('is-counting');
    countdownInterval = setInterval(() => {
      state.countdown -= 1;
      if (state.countdown <= 0) {
        const result = state.pendingCapture;
        cancelCountdown();
        if (result) finishCapture(result);
      } else { $('countdown').textContent = state.countdown; }
    }, 1000);
  }
  function renderReview() {
    const exists = Boolean(state.capture);
    $('review-empty').hidden = exists;
    $('capture-image').hidden = !exists;
    $('download-photo').disabled = !exists;
    $('download-original').hidden = !state.capture?.original;
    if (exists) {
      $('capture-image').src = state.capture.image;
      $('capture-recipe').textContent = state.capture.description;
    }
  }
  function downloadDataURL(url, filename) {
    const link = make('a'); link.href = url; link.download = filename;
    document.body.append(link); link.click(); link.remove();
  }
  function downloadBlob(blob, filename) {
    const url = URL.createObjectURL(blob);
    downloadDataURL(url, filename);
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  async function loadScene(file) {
    if (!file) return;
    if (!file.type.startsWith('image/') || file.size > 20 * 1024 * 1024) {
      toast('Choose a photo smaller than 20 MiB.'); return;
    }
    const revision = ++imageRevision;
    const url = URL.createObjectURL(file);
    const image = new Image();
    try {
      image.src = url;
      await image.decode();
      if (revision !== imageRevision) { URL.revokeObjectURL(url); return; }
      if (image.naturalWidth * image.naturalHeight > 40_000_000) throw new Error('Photo too large');
      if (imageObjectURL) URL.revokeObjectURL(imageObjectURL);
      imageObjectURL = url;
      state.image = image;
      cancelCountdown(); requestRender();
      toast('Your photo is loaded locally. Nothing was uploaded.');
    } catch {
      URL.revokeObjectURL(url);
      if (revision === imageRevision) toast('This photo could not be opened. Try a JPEG, PNG, or WebP.');
    } finally { $('scene-file').value = ''; }
  }
  async function resetDemo() {
    if ((state.custom.length || state.draft) && !await ask('Start a fresh demo?', 'This removes custom looks and captures from this browser session.', 'Reset demo')) return;
    importRevision += 1; imageRevision += 1;
    cancelCountdown();
    if (imageObjectURL) URL.revokeObjectURL(imageObjectURL);
    imageObjectURL = null;
    Object.assign(state, {
      selection: 'original', custom: [], intensities: {}, effect: 'off', strengths: { hdf: 35, blackMist: 20 },
      glow: 'neutral', customGlow: '#ffae62', ev: 0, wb: 'auto', temperature: 5500, tint: 0,
      zoom: 1, mirrored: false, flash: 'off', preferences: initialPreferences(), draft: null, capture: null,
      image: $('scene-source'), tab: 'builtin'
    });
    $('review-open').disabled = true;
    $('review-open').replaceChildren(...emptyThumbnail.map((node) => node.cloneNode(true)));
    showScreen('shoot'); renderLookStrip(); syncControls(); requestRender();
    toast('A fresh roll. All demo settings reset.');
  }

  $('filters-toggle').addEventListener('click', () => showTray('diffusion'));
  $('ev-toggle').addEventListener('click', () => showTray('ev'));
  $('wb-toggle').addEventListener('click', () => showTray('wb'));
  $$('[data-close-tray]').forEach((node) => node.addEventListener('click', () => closeTray(true)));
  $$('button[data-effect]').forEach((node) => node.addEventListener('click', () => {
    state.effect = node.dataset.effect; syncControls(); requestRender();
  }));
  $('effect-strength').addEventListener('input', (event) => {
    if (state.effect === 'off') return;
    state.strengths[state.effect] = Number(event.target.value); syncControls(); requestRender();
  });
  $$('[data-glow]').forEach((node) => node.addEventListener('click', () => {
    state.glow = node.dataset.glow; syncControls(); requestRender();
  }));
  $('custom-glow').addEventListener('input', (event) => {
    state.customGlow = event.target.value; state.glow = 'custom'; syncControls(); requestRender();
  });
  $('ev-slider').addEventListener('input', (event) => { state.ev = Number(event.target.value); syncControls(); requestRender(); });
  $('ev-reset').addEventListener('click', () => { state.ev = 0; syncControls(); requestRender(); });
  $$('[data-wb]').forEach((node) => node.addEventListener('click', () => {
    if (node.dataset.wb === 'locked' && state.wb === 'auto') { state.temperature = 5500; state.tint = 0; }
    state.wb = node.dataset.wb; syncControls(); requestRender();
  }));
  $('temperature').addEventListener('input', (event) => { state.wb = 'manual'; state.temperature = Number(event.target.value); syncControls(); requestRender(); });
  $('tint').addEventListener('input', (event) => { state.wb = 'manual'; state.tint = Number(event.target.value); syncControls(); requestRender(); });
  $$('[data-zoom]').forEach((node) => node.addEventListener('click', () => { state.zoom = Number(node.dataset.zoom); syncControls(); requestRender(); }));
  $('look-intensity').addEventListener('input', (event) => { state.intensities[state.selection] = Number(event.target.value); syncControls(); requestRender(); });
  $('look-strip').addEventListener('wheel', (event) => {
    const strip = $('look-strip');
    if (event.ctrlKey || Math.abs(event.deltaY) <= Math.abs(event.deltaX)
        || strip.scrollWidth <= strip.clientWidth) return;
    const multiplier = event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? strip.clientWidth : 1;
    const previous = strip.scrollLeft;
    strip.scrollLeft += event.deltaY * multiplier;
    if (strip.scrollLeft !== previous) event.preventDefault();
  }, { passive: false });
  $('look-strip').addEventListener('keydown', (event) => {
    if (!['ArrowLeft', 'ArrowRight'].includes(event.key) || event.altKey || event.ctrlKey || event.metaKey) return;
    const strip = $('look-strip');
    const focused = event.target.closest('button[data-look]');
    if (!focused || !strip.contains(focused)) return;
    const choices = $$('button[data-look]', strip);
    const next = choices[choices.indexOf(focused) + (event.key === 'ArrowRight' ? 1 : -1)];
    if (!next) return;
    event.preventDefault();
    const id = next.dataset.look;
    selectLook(id);
    $$('button[data-look]', strip).find((node) => node.dataset.look === id)?.focus({ preventScroll: true });
  });
  $('scene-area').addEventListener('click', (event) => {
    if (event.target.closest('.control-tray, #diffusion-tray, #ev-tray, #wb-tray, #lens-row')) return;
    if (state.tray) { closeTray(); return; }
    const bounds = $('scene-area').getBoundingClientRect();
    $('focus-ring').style.left = `${event.clientX - bounds.left}px`;
    $('focus-ring').style.top = `${event.clientY - bounds.top}px`;
    $('focus-ring').hidden = false;
    clearTimeout(focusTimeout); focusTimeout = setTimeout(() => { $('focus-ring').hidden = true; }, 1000);
  });
  $('flash-toggle').addEventListener('click', () => {
    const modes = ['off', 'auto', 'on']; state.flash = modes[(modes.indexOf(state.flash) + 1) % modes.length];
    syncControls(); toast(`Flash ${state.flash} · demo setting; no camera flash.`);
  });
  $('camera-switch').addEventListener('click', () => {
    state.mirrored = !state.mirrored; syncControls(); requestRender();
    toast(state.mirrored ? 'Mirrored demo view · no live camera.' : 'Rear demo view restored.');
  });
  $('library-open').addEventListener('click', () => openLibrary());
  $('menu-open').addEventListener('click', () => showScreen('menu'));
  $$('[data-library-tab]').forEach((node) => node.addEventListener('click', () => { state.tab = node.dataset.libraryTab; libraryError(); renderLibrary(); }));
  $('demo-look').addEventListener('click', newDemoLook);
  $('import-lut').addEventListener('click', () => { state.replaceID = null; $('lut-file').value = ''; $('lut-file').click(); });
  $('lut-file').addEventListener('change', (event) => importLUT(event.target.files[0]));
  $('top-text').addEventListener('input', (event) => { if (state.draft) { state.draft.top = event.target.value; updateLabelPreview(); } });
  $('bottom-text').addEventListener('input', (event) => { if (state.draft) { state.draft.bottom = event.target.value; updateLabelPreview(); } });
  // Validation counts grapheme clusters, so HTML's UTF-16 maxlength must not
  // reject a valid short emoji label before the editor can validate it.
  $('top-text').removeAttribute('maxlength'); $('bottom-text').removeAttribute('maxlength');
  $('save-label').addEventListener('click', saveLabel);
  $('cancel-label').addEventListener('click', cancelEditor);
  $$('[data-info]').forEach((node) => node.addEventListener('click', () => showInfo(node.dataset.info)));
  $$('[data-back]').forEach((node) => node.addEventListener('click', () => {
    if (state.screen === 'editor') { cancelEditor(); return; }
    showScreen(node.dataset.back === 'camera' ? 'shoot' : node.dataset.back, true);
  }));
  $('review-open').addEventListener('click', () => showScreen('review'));
  $('shutter').addEventListener('click', capture);
  $('download-photo').addEventListener('click', () => { if (state.capture) downloadDataURL(state.capture.image, 'lutli-sample.jpg'); });
  $('download-original').addEventListener('click', () => { if (state.capture?.original) downloadDataURL(state.capture.original, 'lutli-clean-sample.jpg'); });
  $('confirm-cancel').addEventListener('click', () => finishConfirmation(false));
  $('confirm-accept').addEventListener('click', () => finishConfirmation(true));
  $('confirm-dialog').addEventListener('cancel', (event) => { event.preventDefault(); finishConfirmation(false); });
  $('reset-demo').addEventListener('click', resetDemo);
  $('load-scene').addEventListener('click', () => { $('scene-file').value = ''; $('scene-file').click(); });
  $('scene-file').addEventListener('change', (event) => loadScene(event.target.files[0]));
  $$('[data-tour]').forEach((node) => node.addEventListener('click', async () => {
    if (state.screen === 'editor' && !await cancelEditor()) return;
    if (node.dataset.tour === 'diffusion') { showScreen('shoot'); state.effect = 'hdf'; state.tray = 'diffusion'; syncControls(); requestRender(); }
    if (node.dataset.tour === 'looks') openLibrary('custom');
    if (node.dataset.tour === 'label') newDemoLook();
  }));
  document.addEventListener('keydown', (event) => {
    if ($('confirm-dialog').open) return;
    if (event.key === 'Escape') {
      if (state.tray) { event.preventDefault(); closeTray(true); }
      else if (state.screen === 'editor') { event.preventDefault(); cancelEditor(); }
      else if (state.screen === 'info') showScreen('menu', true);
      else if (state.screen !== 'shoot') showScreen('shoot', true);
    }
    if (event.key === 'Tab' && state.screen !== 'shoot') {
      const focusable = $$('button:not(:disabled), input:not(:disabled), textarea, select, a[href], [tabindex="0"]', $(`${state.screen}-screen`))
        .filter((node) => !node.closest('[hidden], [inert]') && node.getClientRects().length);
      const first = focusable[0], last = focusable.at(-1);
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
    }
  });
  document.addEventListener('visibilitychange', () => { if (document.hidden) { cancelCountdown(); closeTray(); } });
  if (typeof ResizeObserver === 'function') new ResizeObserver(requestRender).observe($('scene-area'));
  window.addEventListener('resize', requestRender);

  $('capture-flash').hidden = true;
  renderLookStrip(); syncControls(); renderLibrary();
  $('shutter').disabled = true;
  const sample = $('scene-source');
  function sampleReady() { if (!state.image && sample.naturalWidth) { state.image = sample; requestRender(); } }
  sample.addEventListener('load', sampleReady);
  sample.addEventListener('error', () => { $('scene-loading').textContent = 'Choose a photo to start exploring.'; });
  if (sample.complete) sampleReady();
})();
