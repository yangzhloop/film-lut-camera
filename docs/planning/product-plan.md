# Lutli product plan

Status: existing native implementation baseline plus an approved diffusion-filter addition. The detailed behavior and acceptance checks are in the [feature specification](feature-specification.md); sequencing and verification gates are in the [roadmap](roadmap.md). The latest Filters/HDF/Black Mist UI is approved design work and is not yet implemented.

## Product goal

Choose a film-inspired look, see it while composing a photograph, adjust the camera when needed, and capture the result. Lutli ships with developer-created LUT looks and lets users import a small collection of their own.

## User-approved direction

- The working name is **Lutli**, with lowercase **lutli** as its wordmark.
- Start with iOS; develop Android later. The user selected native iOS with SwiftUI.
- Use a minimalist dark interface with the accepted camera-control placement. Refine the design as implementation and new features require it.
- Include live film looks, bundled LUTs, limited custom LUT imports, white balance, exposure compensation, and look intensity.
- Add a Filters control beside EV and WB, with horizontally arranged Off, HDF and Black Mist choices. HDF expands to strength and glow color; Black Mist expands to strength. This addition is specified in F10 and remains pending implementation.
- Represent each look with two stacked color sections, not a photographic thumbnail. Custom looks have independently editable top/bottom text and predefined colors.
- The upper-right gear opens an app menu with detailed settings, feedback, About, and legal information.
- A smaller leading icon in the horizontal filter strip opens Your looks. Importing or editing a look leads to Customize label.

## Working implementation decisions

The following choices resolve the earlier open proposals so implementation can proceed. They are defaults for the first version, rather than claims that the user separately selected every numerical limit or behavior.

| Area | First-version decision |
| --- | --- |
| Platform and architecture | iOS 17+ as the working minimum; SwiftUI, AVFoundation, and Core Image, with portable domain logic in the `LutliCore` Swift package. |
| Capture | Still photographs; portrait-oriented camera interface. |
| Bundled collection | Six original developer looks plus Original. The first implementation uses procedural starter LUTs that require photographic tuning before release; they are not exact named-film emulations. |
| Custom collection | Five replaceable slots stored locally. |
| LUT compatibility | 3D `.cube`, size 17 or 33, at most 8 MiB, standard SDR sRGB input/output, normalized domain. |
| Label design | Two editable single-line sections, each with 1–12 characters and a shared predefined color palette. |
| Look controls | Intensity from 0–100%, remembered independently for each look. |
| Diffusion addition — pending | One effect at a time, combined with any LUT. HDF offers 0–100% strength and Neutral/Amber/Rose/Red/custom glow color; Black Mist offers 0–100% strength with neutral diffusion. |
| Diffusion state — pending | Start each fresh app launch Off; retain effect settings during the app session across LUT/camera changes, tray closure and background/resume. Remember-last-look continues to govern LUT selection only. |
| White balance | Auto, Lock, and Manual temperature/tint, subject to actual camera capabilities. |
| Exposure | Automatic exposure with exposure compensation within device-supported limits. |
| Persistence | Remember the look and user preferences; exposure and WB remain session controls and reset for a fresh camera session. |
| Output | Filtered JPEG; optional clean JPEG from the same capture. HEIF is a later format decision. |
| Privacy and storage | Process images and keep custom LUTs on device; no account, analytics, upload, or backend is needed for the initial camera workflow. |
| Navigation | Keep the smaller library entry visible while look labels scroll beside it. |

The latest [UI and navigation reference](ui-ux.md) uses **lutli** and adds diffusion controls. Earlier mockups retain the retired **STILL** wordmark and remain historical references for the menu, library and label editor.

## Experience and quality priorities

1. **Trust the preview.** Apply the same creative LUT and intensity to preview and output. F10 must also preserve diffusion settings and relative glow size between preview and full-resolution photos. Validate differences caused by camera capture processing.
2. **Keep shooting immediate.** Looks, EV, WB, Filters and the shutter remain reachable from the camera. The approved diffusion tray expands upward over the preview while keeping the existing toolbar and lower controls stationary. Collection management and app settings are separate destinations.
3. **Protect the user's collection.** Invalid imports, canceled edits, failed saves, and replacements must not silently remove a working look.
4. **Keep custom identity simple.** A live label preview, two text fields, and two palette choices are sufficient. Label numbers such as `400` are decorative text, not actual ISO settings.
5. **Be honest about capability.** Hide or disable unsupported lens, flash, WB, or exposure controls. A simulator/sample preview is not a functional camera.

## First-version boundary

The existing implementation covers camera capture and LUT rendering, local look management, the initial UI/navigation, white balance/exposure controls, basic saving preferences, and app information screens. A clean original is a processed photograph without the creative look; it is not RAW.

The approved next addition is **F10: diffusion filters and colored halation**. It combines the selected LUT with either HDF or Black Mist, keeping Look intensity separate from Filter strength. HDF's optional color applies to highlight glow; Black Mist provides neutral bloom and gentle contrast softening. A spatial rendering stage, immutable capture settings and preview/photo consistency are required. The clean-original option must exclude both the LUT and diffusion/halation. The concept's HDF 35% Amber and Black Mist 20% illustrate interaction states, not calibrated defaults.

Video, RAW/ProRAW, manual shutter/ISO, grain, effect stacking, saved recipes, editing existing photos, commercial features, accounts, cloud synchronization, and Android remain later milestones. The HDF/Black Mist scope above is now approved; other film texture effects still require separate decisions.

## Decisions that still require external input or validation

- iOS 17 is the initial deployment target. The supported device matrix and release-level compatibility still require Apple-platform validation.
- Final bundled grades need photographic review across skin tones, lighting, and supported devices.
- HDF and Black Mist need algorithm selection, LUT/effect ordering, first-use strengths, glow-color tuning, normalized bloom sizing, and image/performance validation before implementation can be called complete. The mockup does not establish these results.
- Camera throughput, capture latency, thermal behavior, output color consistency, and accessibility require Apple-platform and physical-device verification.
- Feedback destination, publisher identity, production legal copy, signing, distribution, and release metadata are not invented by the implementation.
- Any change to the five-slot limit, supported LUT types, or deferred features should update the feature specification and acceptance checks together.
