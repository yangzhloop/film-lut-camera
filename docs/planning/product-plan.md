# Lutli product plan

Status: implementation baseline. The detailed behavior and acceptance checks are in the [feature specification](feature-specification.md); sequencing and verification gates are in the [roadmap](roadmap.md).

## Product goal

Choose a film-inspired look, see it while composing a photograph, adjust the camera when needed, and capture the result. Lutli ships with developer-created LUT looks and lets users import a small collection of their own.

## User-approved direction

- The working name is **Lutli**, with lowercase **lutli** as its wordmark.
- Start with iOS; develop Android later. The user selected native iOS with SwiftUI.
- Use a minimalist dark interface with the accepted camera-control placement. Refine the design as implementation and new features require it.
- Include live film looks, bundled LUTs, limited custom LUT imports, white balance, exposure compensation, and look intensity.
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
| White balance | Auto, Lock, and Manual temperature/tint, subject to actual camera capabilities. |
| Exposure | Automatic exposure with exposure compensation within device-supported limits. |
| Persistence | Remember the look and user preferences; exposure and WB remain session controls and reset for a fresh camera session. |
| Output | Filtered JPEG; optional clean JPEG from the same capture. HEIF is a later format decision. |
| Privacy and storage | Process images and keep custom LUTs on device; no account, analytics, upload, or backend is needed for the initial camera workflow. |
| Navigation | Keep the smaller library entry visible while look labels scroll beside it. |

The original mockups used **STILL**. That branding is superseded by **Lutli**; see [UI and navigation](ui-ux.md) for the preserved concept artwork.

## Experience and quality priorities

1. **Trust the preview.** Apply the same creative LUT and intensity to preview and output, while explicitly validating differences caused by camera capture processing.
2. **Keep shooting immediate.** Looks, EV, WB, and the shutter remain reachable from the camera. Collection management and app settings are separate destinations.
3. **Protect the user's collection.** Invalid imports, canceled edits, failed saves, and replacements must not silently remove a working look.
4. **Keep custom identity simple.** A live label preview, two text fields, and two palette choices are sufficient. Label numbers such as `400` are decorative text, not actual ISO settings.
5. **Be honest about capability.** Hide or disable unsupported lens, flash, WB, or exposure controls. A simulator/sample preview is not a functional camera.

## First-version boundary

The first implementation covers camera capture and LUT rendering, local look management, the accepted UI/navigation, white balance/exposure controls, basic saving preferences, and app information screens. A clean original is a processed photograph without the creative look; it is not RAW.

Video, RAW/ProRAW, manual shutter/ISO, grain, halation, saved recipes, editing existing photos, commercial features, accounts, cloud synchronization, and Android are later milestones. LUTs control color and tone; film texture effects require additional processing.

## Decisions that still require external input or validation

- iOS 17 is the initial deployment target. The supported device matrix and release-level compatibility still require Apple-platform validation.
- Final bundled grades need photographic review across skin tones, lighting, and supported devices.
- Camera throughput, capture latency, thermal behavior, output color consistency, and accessibility require Apple-platform and physical-device verification.
- Feedback destination, publisher identity, production legal copy, signing, distribution, and release metadata are not invented by the implementation.
- Any change to the five-slot limit, supported LUT types, or deferred features should update the feature specification and acceptance checks together.
