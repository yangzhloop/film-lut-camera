/* Lutli interaction prototype: local Canvas rendering, not native camera processing.
 * Starter look formulas mirror the app's intent; Canvas blur, color management,
 * preview dimensions and approximate EV/WB differ from the iOS Core Image path.
 * Imported .cube samples use standard red-fastest RGB ordering and trilinear
 * interpolation. Nothing is uploaded and no hardware camera values are changed.
 */
(() => {
  'use strict';

  const LIMIT = 8 * 1024 * 1024;
  const NUMBER = /^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/;
  const buffers = new WeakMap();
  const clamp = (n, lo = 0, hi = 1) => Math.min(hi, Math.max(lo, n));
  const number = (n, fallback) => Number.isFinite(Number(n)) ? Number(n) : fallback;

  function commentless(line) {
    let quoted = false;
    for (let i = 0; i < line.length; i++) {
      if (line[i] === '"') quoted = !quoted;
      if (line[i] === '#' && !quoted) return line.slice(0, i);
    }
    return line;
  }

  function parseCube(text) {
    if (typeof text !== 'string' || text.includes('\uFFFD')) {
      throw new Error('Choose a UTF-8 text .cube file.');
    }
    if (text.length > LIMIT || new TextEncoder().encode(text).length > LIMIT) {
      throw new Error('Choose a .cube file no larger than 8 MiB.');
    }
    const lines = text.replace(/^\uFEFF/, '').split(/\r\n|\n|\r/);
    const seen = new Set();
    let size = 0, title = '', count = 0, values = null;
    const validNumber = token => NUMBER.test(token) && Number.isFinite(Number(token));
    for (let i = 0; i < lines.length; i++) {
      const line = commentless(lines[i]).trim();
      if (!line) continue;
      const parts = line.split(/\s+/);
      const head = parts[0];
      const lineNumber = i + 1;
      if (head === 'LUT_1D_SIZE') throw new Error('1D LUTs are not supported. Choose a 3D .cube LUT.');
      if (['TITLE', 'LUT_3D_SIZE', 'DOMAIN_MIN', 'DOMAIN_MAX'].includes(head)) {
        if (count) throw new Error(`Move LUT headers before sample data (line ${lineNumber}).`);
        if (seen.has(head)) throw new Error(`The file repeats its ${head} header.`);
        seen.add(head);
        if (head === 'TITLE') {
          const match = /^TITLE\s+"([^"\r\n]*)"\s*$/.exec(line);
          if (!match) throw new Error(`The TITLE header on line ${lineNumber} must contain quoted text.`);
          title = match[1];
        } else if (head === 'LUT_3D_SIZE') {
          if (parts.length !== 2 || !/^\d+$/.test(parts[1])) {
            throw new Error(`The LUT_3D_SIZE header on line ${lineNumber} is invalid.`);
          }
          size = Number(parts[1]);
          if (size !== 17 && size !== 33) throw new Error('Lutli supports 17- and 33-point 3D LUTs.');
          values = new Float32Array(size ** 3 * 3);
        } else {
          if (parts.length !== 4 || !parts.slice(1).every(validNumber)) {
            throw new Error(`The ${head} header on line ${lineNumber} is invalid.`);
          }
          const expected = head === 'DOMAIN_MIN' ? 0 : 1;
          if (!parts.slice(1).every(value => Number(value) === expected)) {
            throw new Error('Use a standard SDR RGB LUT with DOMAIN_MIN 0 0 0 and DOMAIN_MAX 1 1 1.');
          }
        }
        continue;
      }
      if (!validNumber(head)) throw new Error(`Unsupported header or invalid number on line ${lineNumber}.`);
      if (!size) throw new Error('Add a LUT_3D_SIZE header before the RGB samples.');
      if (parts.length !== 3 || !parts.every(value => validNumber(value) && Number(value) >= 0 && Number(value) <= 1)) {
        throw new Error(`RGB values on line ${lineNumber} must be numbers from 0 to 1.`);
      }
      if (count >= size ** 3) throw new Error(`This ${size}-point LUT has too many RGB samples.`);
      const offset = count * 3;
      values[offset] = Number(parts[0]);
      values[offset + 1] = Number(parts[1]);
      values[offset + 2] = Number(parts[2]);
      count++;
    }
    if (!size) throw new Error('The file is missing its LUT_3D_SIZE header.');
    if (count !== size ** 3) throw new Error(`This LUT needs ${size ** 3} RGB samples but contains ${count}.`);
    return { size, values, title };
  }

  function grade(r, g, b, look, result) {
    const luma = .2126 * r + .7152 * g + .0722 * b;
    const channel = (v, saturation, contrast, lift = 0) => clamp((luma + (v - luma) * saturation - .5) * contrast + .5 + lift);
    switch (look) {
      case 'warm400':
        result[0] = channel(r, .94, .92, .035); result[1] = channel(g, .94, .92, .009); result[2] = channel(b, .94, .92, -.025); break;
      case 'soft200':
        result[0] = channel(r, .80, .83, .018); result[1] = channel(g, .84, .87, .015); result[2] = channel(b, .80, .86, .005); break;
      case 'chrome100':
        result[0] = channel(r, 1.14, 1.08); result[1] = channel(g, 1.10, 1.08); result[2] = channel(b, 1.12, 1.08, -.01); break;
      case 'fade400':
        result[0] = channel(r, .72, .80, .018); result[1] = channel(g, .72, .80, .009); result[2] = channel(b, .72, .80, .002); break;
      case 'night800':
        result[0] = channel(r, .87, 1.08, -.018); result[1] = channel(g, .87, 1.04, .003); result[2] = channel(b, .91, 1.03, .035); break;
      case 'mono800':
        result.fill(clamp((luma - .5) * 1.10 + .515)); break;
      default: result[0] = r; result[1] = g; result[2] = b;
    }
  }

  function sample(cube, r, g, b, result) {
    const s = cube.size;
    const rr = r * (s - 1), gg = g * (s - 1), bb = b * (s - 1);
    const r0 = Math.floor(rr), g0 = Math.floor(gg), b0 = Math.floor(bb);
    const r1 = Math.min(r0 + 1, s - 1), g1 = Math.min(g0 + 1, s - 1), b1 = Math.min(b0 + 1, s - 1);
    const rf = rr - r0, gf = gg - g0, bf = bb - b0;
    const v = cube.values;
    for (let c = 0; c < 3; c++) {
      const v000 = v[((b0 * s + g0) * s + r0) * 3 + c];
      const v100 = v[((b0 * s + g0) * s + r1) * 3 + c];
      const v010 = v[((b0 * s + g1) * s + r0) * 3 + c];
      const v110 = v[((b0 * s + g1) * s + r1) * 3 + c];
      const v001 = v[((b1 * s + g0) * s + r0) * 3 + c];
      const v101 = v[((b1 * s + g0) * s + r1) * 3 + c];
      const v011 = v[((b1 * s + g1) * s + r0) * 3 + c];
      const v111 = v[((b1 * s + g1) * s + r1) * 3 + c];
      const lower = (v000 + (v100 - v000) * rf) * (1 - gf) + (v010 + (v110 - v010) * rf) * gf;
      const upper = (v001 + (v101 - v001) * rf) * (1 - gf) + (v011 + (v111 - v011) * rf) * gf;
      result[c] = lower + (upper - lower) * bf;
    }
  }

  function makeDemoLUT() {
    const size = 17;
    const values = new Float32Array(size ** 3 * 3);
    const result = [0, 0, 0];
    let i = 0;
    for (let b = 0; b < size; b++) {
      for (let g = 0; g < size; g++) {
        for (let r = 0; r < size; r++) {
          grade(r / (size - 1), g / (size - 1), b / (size - 1), 'warm400', result);
          values[i++] = result[0]; values[i++] = result[1]; values[i++] = result[2];
        }
      }
    }
    return { size, values, title: 'Daylight demo' };
  }

  function buffer(width, height) {
    const canvas = document.createElement('canvas');
    canvas.width = width; canvas.height = height;
    return { canvas, context: canvas.getContext('2d', { willReadFrequently: true }) };
  }

  function tintColor(value) {
    if (typeof value !== 'string') return null;
    const hex = value.replace(/^#/, '');
    if (!/^[0-9a-f]{6}$/i.test(hex)) return null;
    return [parseInt(hex.slice(0, 2), 16) / 255, parseInt(hex.slice(2, 4), 16) / 255, parseInt(hex.slice(4, 6), 16) / 255];
  }

  function render(canvas, image, options = {}) {
    if (!canvas || !image) throw new Error('A canvas and sample image are needed for the preview.');
    const outputWidth = canvas.width, outputHeight = canvas.height;
    if (!outputWidth || !outputHeight) return;
    const ratio = Math.min(1, 720 / Math.max(outputWidth, outputHeight));
    const width = Math.max(1, Math.round(outputWidth * ratio));
    const height = Math.max(1, Math.round(outputHeight * ratio));
    let pool = buffers.get(canvas);
    if (!pool || pool.width !== width || pool.height !== height) {
      pool = { width, height, base: buffer(width, height), lights: buffer(width, height), close: buffer(width, height), wide: buffer(width, height), bloom: buffer(width, height) };
      buffers.set(canvas, pool);
    }
    const ctx = pool.base.context;
    const imageWidth = image.naturalWidth || image.videoWidth || image.width;
    const imageHeight = image.naturalHeight || image.videoHeight || image.height;
    if (!imageWidth || !imageHeight) throw new Error('The sample image has not finished loading.');
    const zoom = clamp(number(options.zoom, 1), 1, 4);
    const scale = Math.max(width / imageWidth, height / imageHeight) * zoom;
    const sourceWidth = width / scale, sourceHeight = height / scale;
    ctx.save();
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, width, height);
    if (options.mirrored) { ctx.translate(width, 0); ctx.scale(-1, 1); }
    ctx.drawImage(image, (imageWidth - sourceWidth) / 2, (imageHeight - sourceHeight) / 2, sourceWidth, sourceHeight, 0, 0, width, height);
    ctx.restore();

    const frame = ctx.getImageData(0, 0, width, height);
    const pixels = frame.data;
    const intensity = clamp(number(options.intensity, 1));
    const exposure = 2 ** clamp(number(options.ev, 0), -3, 3);
    const warmth = clamp((number(options.temperature, 5500) - 5500) / 4500, -1, 1);
    const tint = clamp(number(options.tint, 0) / 100, -1, 1);
    const redGain = exposure * (1 + warmth * .22 + tint * .05);
    const greenGain = exposure * (1 - tint * .13);
    const blueGain = exposure * (1 - warmth * .28 + tint * .05);
    const strength = clamp(number(options.strength, 0));
    const effect = options.effect;
    const enabled = (effect === 'hdf' || effect === 'blackMist') && strength > 0;
    const glow = effect === 'hdf' ? tintColor(options.glow) : null;
    const threshold = effect === 'hdf' ? .65 : .55;
    const lightFrame = enabled ? pool.lights.context.createImageData(width, height) : null;
    const lights = lightFrame && lightFrame.data;
    const cube = options.cube;
    if (cube && (![17, 33].includes(cube.size) || !cube.values || cube.values.length !== cube.size ** 3 * 3)) {
      throw new Error('This imported LUT is incomplete. Please import it again.');
    }
    const graded = [0, 0, 0];
    for (let i = 0; i < pixels.length; i += 4) {
      const r = clamp(pixels[i] / 255 * redGain);
      const g = clamp(pixels[i + 1] / 255 * greenGain);
      const b = clamp(pixels[i + 2] / 255 * blueGain);
      if (cube) sample(cube, r, g, b, graded);
      else grade(r, g, b, options.look, graded);
      const outR = r + (graded[0] - r) * intensity;
      const outG = g + (graded[1] - g) * intensity;
      const outB = b + (graded[2] - b) * intensity;
      pixels[i] = outR * 255; pixels[i + 1] = outG * 255; pixels[i + 2] = outB * 255;
      if (enabled) {
        const mask = clamp((Math.max(r, g, b) - threshold) / (1 - threshold));
        lights[i] = (glow ? glow[0] : outR) * 255;
        lights[i + 1] = (glow ? glow[1] : outG) * 255;
        lights[i + 2] = (glow ? glow[2] : outB) * 255;
        lights[i + 3] = mask * pixels[i + 3];
      }
    }
    ctx.putImageData(frame, 0, 0);

    if (enabled) {
      pool.lights.context.putImageData(lightFrame, 0, 0);
      const edge = Math.max(width, height);
      const hdf = effect === 'hdf';
      const blur = (target, source, radius) => {
        target.context.clearRect(0, 0, width, height);
        target.context.filter = `blur(${radius}px)`;
        target.context.drawImage(source, 0, 0);
        target.context.filter = 'none';
      };
      blur(pool.close, pool.lights.canvas, edge * (hdf ? .012 : .020));
      blur(pool.wide, pool.lights.canvas, edge * (hdf ? .028 : .045));
      const bloom = pool.bloom.context;
      bloom.clearRect(0, 0, width, height);
      bloom.save();
      bloom.globalCompositeOperation = 'lighter';
      bloom.globalAlpha = hdf ? .70 : .75;
      bloom.drawImage(pool.close.canvas, 0, 0);
      bloom.globalAlpha = hdf ? .30 : .25;
      bloom.drawImage(pool.wide.canvas, 0, 0);
      bloom.restore();
      if (!hdf) {
        blur(pool.close, pool.base.canvas, edge * .003);
        ctx.save(); ctx.globalAlpha = strength * .10;
        ctx.drawImage(pool.close.canvas, 0, 0); ctx.restore();
      }
      ctx.save();
      ctx.globalCompositeOperation = 'screen';
      ctx.globalAlpha = strength * (hdf ? .85 : .60);
      ctx.drawImage(pool.bloom.canvas, 0, 0);
      ctx.restore();
    }
    const output = canvas.getContext('2d');
    output.save();
    output.setTransform(1, 0, 0, 1, 0, 0);
    output.globalAlpha = 1;
    output.globalCompositeOperation = 'source-over';
    output.filter = 'none';
    output.clearRect(0, 0, outputWidth, outputHeight);
    output.drawImage(pool.base.canvas, 0, 0, outputWidth, outputHeight);
    output.restore();
  }

  window.LutliRenderer = Object.freeze({ render, parseCube, makeDemoLUT });
})();
