# Lutli product plan

Status: planning baseline, not a finalized release specification.

## Product goal

Let people choose a film-inspired look, see it while composing a photograph, adjust the camera when needed, and capture the result. Built-in looks are implemented with developer-provided LUTs. Users can import a limited number of their own LUTs.

The initial inspiration includes the color and tone associated with Kodak and Fujifilm film stocks. Exact preset names, artwork, and the released look collection remain undecided.

## Confirmed direction

| Area | Decision |
| --- | --- |
| Working name | Lutli; use lowercase `lutli` as the wordmark. The user selected the name provisionally. |
| Platforms | iOS first, Android in a later phase. |
| Framework | Undecided; do not assume native Swift/Kotlin, Flutter, or React Native has been selected. |
| Core camera experience | Live LUT-based film looks, bundled presets, limited custom LUT imports. |
| Capture adjustments | Automatic white balance / white-balance adjustment and exposure compensation. Filter intensity is represented in the accepted visual baseline. |
| Visual direction | Minimalist dark interface, with the current camera-control placement as the starting point. |
| Filter identity | Two stacked solid-color sections replace photographic filter thumbnails. |
| Custom labels | Independently choose top and bottom colors from predefined palettes and enter text in both sections. Either section can contain words or numbers. |
| App navigation | The upper-right gear opens the app menu: detailed app settings, feedback, About, and terms/legal information. |
| Look navigation | A smaller leading icon in the horizontal filter strip opens Your looks; importing or editing a look leads to Customize label. |
| Design flexibility | Refine the interface during implementation and when new features require it. |

## Proposed first-release scope

These are planning assumptions from the discussion, not individually finalized requirements.

| Area | Current proposal | Decision still needed |
| --- | --- | --- |
| Capture scope | Still photographs first. | Confirm the first-release scope before implementation. |
| Bundled collection | Approximately 6–8 distinct looks and a neutral/original option. | Exact count, names, LUT assets, and visual targets. |
| Custom collection | Five replaceable slots, shown in the mockups. | Final cap and behavior when full. |
| LUT import | Import compatible 3D `.cube` files through the system file picker, preview, then save. | Supported sizes, input/output color spaces, file limits, validation, and storage. |
| Look controls | Intensity adjustment and remembered intensity per look. | Range, defaults, persistence, and reset behavior. |
| White balance | Auto, Lock, and Manual modes, with temperature/tint where supported. | Device coverage, lock behavior, and control ranges. |
| Exposure | Automatic exposure with exposure compensation. | Supported ranges and exposure/focus lock behavior. |
| Camera controls | Tap to focus, available camera/lens switching, grid, and timer. | Which controls belong in the first release. |
| Output | Filtered HEIF/JPEG, with optional unfiltered original. | Formats, quality, storage behavior, and saving permissions. |
| Photo review | Last-capture preview and system sharing. | Exact review and comparison interactions. |
| Persistence | Keep exposure/WB consistent during a session; remember selected look. | Startup/reset behavior and what survives relaunch. |
| Offline use | Capture and apply installed looks without a network connection. | Confirm as a release requirement. |

An unfiltered original means a normal processed photograph without the creative look; it does not imply RAW support. A label such as `WARM / 400` is a filter identity, not a camera ISO setting.

## Functional expectations

- Applying a look should visibly affect the preview, and the saved photograph should closely match that look. Matching must be validated on supported devices rather than inferred from a mockup.
- Validate imported LUT structure and supported dimensions. A structurally valid LUT can still be unsuitable for the camera's color space; preview and compatibility guidance are needed. Do not assume all Log/HDR LUTs are compatible or reliably identifiable from the file alone.
- Custom labels should appear consistently in the shooting strip, collection, and editor.
- LUT import, replacement, and deletion should have clear outcomes and preserve the user's existing collection when an operation fails.
- Camera permissions, saving failures, unsupported controls, and interrupted capture need defined behavior before implementation is considered complete.

## Recommended later scope

Video, RAW/ProRAW, manual shutter/ISO, editing existing photos, saved recipes, advanced grain/halation effects, and Android implementation are proposed later milestones. These boundaries require confirmation before release planning.

LUTs control color and tone. Grain, halation, and similar textures require separate processing, even if they are presented together as one look.

## Open product decisions

1. Confirm the first-release scope and device/iOS support range.
2. Select the implementation framework and camera/rendering approach.
3. Specify LUT compatibility, the bundled look pipeline, and import limits.
4. Finalize label palettes, text limits, and readable contrast behavior.
5. Define capture output, permissions, original-copy storage, and settings persistence.
6. Establish device-based quality and performance acceptance criteria.
7. Finalize app-menu settings, feedback destination, About content, and legal content.

Commercial model, accounts, cloud synchronization, and social features have not been selected.
