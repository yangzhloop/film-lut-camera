# Feature specification

This is the actionable first-version specification for Lutli. It expands the approved concept with working defaults needed for implementation. Native iOS uses SwiftUI, AVFoundation, and Core Image with an iOS 17 deployment target. Domain logic lives in the portable `LutliCore` Swift package. Requirements describe intended behavior; they do not claim that code has been implemented or validated. See the [roadmap](roadmap.md) for evidence gates.

F01–F09 describe the initial implementation baseline. **F10 now has source implementations for its model, controls and rendering.** The portable suite passes 45 tests, including diffusion model checks; new Apple rendering/UI results and physical-device acceptance remain outstanding. The [latest UI concept](ui-ux.md) shows the approved interaction, and the [implementation plan](diffusion-implementation.md) records the development sequence. See the [validation record](../validation.md) for executed evidence rather than inferring completion from these requirements.

## F01 — Camera and session lifecycle

- Open on the camera screen with the `lutli` wordmark, gear/menu entry, live preview, shooting controls, look strip, intensity, shutter, and last-capture entry.
- Request camera access through the system permission flow. If denied or restricted, explain the state and offer system settings when useful; never pretend sample imagery is a live camera.
- Represent initializing, permission-required, ready, switching, interrupted, unavailable, and capture-in-progress states. The shutter is enabled only when capture can proceed.
- Start with the available rear camera; offer front/rear switching and available physical lens choices. Do not advertise a lens that the device lacks.
- Tap-to-focus and flash modes operate only where supported. Show the active flash mode clearly.
- Pause camera work when backgrounded, and recover from interruption without discarding looks or preferences. Preserve the selected look when visiting an in-app menu.

Acceptance:

- Denial, missing camera, interruption, and session-configuration failure show distinct recoverable states without an enabled nonfunctional shutter.
- A supported iPhone can start the session, switch camera, focus, capture, background, and resume.
- Repeated shutter taps cannot start overlapping unbounded processing work.

## F02 — Bundled looks and rendering

- Include Original plus six original developer color/tone looks. The first implementation uses procedural starter LUTs; photographic tuning and approval remain a release gate. Initial identities are Warm 400, Soft 200, Chrome 100, Fade 400, Night 800, and Mono 800; the final assets may be tuned without changing stable look identifiers.
- Built-in looks are available offline, cannot consume custom slots, and cannot be deleted or overwritten by imported files.
- Place Original first among selectable looks, after the separate leading library button. Original bypasses the creative LUT. With F10, it does not disable a separately selected diffusion effect.
- Select a look by tapping its two-section label. Use a visible outline and an accessible selected state; do not duplicate labels with photographic thumbnails.
- Provide an intensity control from 0–100%. At 0%, the creative LUT has no effect. Remember intensity by look identifier. F10 labels this control **Look intensity** to distinguish it from diffusion **Filter strength**.
- Use a consistent standard SDR sRGB color contract for preview and photo rendering. Configure image orientation and camera output deliberately; do not treat an arbitrary incoming pixel buffer as already compatible.
- Use the same LUT and blend strength for preview and capture. Keep rendering work off the UI thread, reuse resources, and discard obsolete preview frames instead of accumulating latency.

Acceptance:

- An identity LUT preserves representative colors within defined numerical tolerances; nonidentity fixtures change the expected channels.
- Changing one look's intensity does not alter another look's remembered value.
- Original and 0% Look intensity bypass the creative LUT. With F10, a separately active diffusion effect still applies; a fully untreated creative output requires diffusion Off or 0% as well.
- The saved look and preview are compared on actual supported devices; a pure parser test does not validate this behavior.

## F03 — Exposure and white balance

- Keep EV and WB shortcuts visible below the preview, including their current values/modes. F10 adds Filters alongside them without removing these shortcuts while its tray is open.
- EV adjusts automatic exposure within the device's reported bounds. Clamp requests before applying them and display the accepted value.
- WB offers Auto, Lock, and Manual when supported. Lock freezes the current measured balance; Manual offers temperature and tint controls clamped to valid device gains.
- Moving a manual WB control selects Manual mode. Auto returns control to the camera. Unsupported adjustments are disabled with a concise explanation.
- EV and WB apply across looks during the same camera session; selecting a look does not silently reset them. A fresh session defaults to EV 0 and Auto WB.

Acceptance:

- Switching looks changes only creative rendering, not the session's EV/WB selection.
- Device limits are respected, including on camera switching.
- Lock/Auto/Manual transitions and manual values are verified with live camera hardware.

## F04 — Capture, saving, and review

- Capture a full-resolution still supported by the current camera, using the look and intensity selected at the instant of capture. F10 extends that immutable recipe to the diffusion type, strength and HDF glow color.
- Render a filtered JPEG. When Save clean original is enabled, generate a second JPEG from that same capture before applying the creative look. With F10, the clean copy excludes both the LUT grade and diffusion/halation while retaining the camera's exposure and white balance; it is not RAW.
- Request Photos add permission when needed. Do not request broad library read access just to save or review the app's most recent capture.
- Keep the recent capture available for review/share while the app owns its temporary output. Clearly distinguish a rendered image from a successful Photos save.
- Update the thumbnail only with a successfully generated result. Provide a visible confirmation when saved and an actionable error if rendering, permissions, storage, or saving fails.
- Prevent an in-progress render from silently changing its selected look when the user browses to another look.
- Provide the system share sheet from the last-shot review. Images and LUTs do not upload automatically.

Acceptance:

- One shutter action produces the expected filtered photo, plus one clean copy only when requested.
- Changing looks after pressing the shutter cannot change the in-flight photograph's look. With F10, later diffusion adjustments cannot change that photograph's effect either.
- Denied Photos access and a failed save do not display a false success message.
- Orientation, front-camera mirroring, crop, and color are checked on device, with any preview/capture differences recorded.

## F05 — LUT import and validation

- Import through the system file picker. Read the selected file under the platform's permitted access scope, validate it, then copy its data into app-managed storage on a successful save.
- Support UTF-8 3D `.cube` files with `LUT_3D_SIZE` of 17 or 33. Entries follow the standard red-fastest ordering and contain exactly size-cubed RGB rows.
- Permit an optional title, comments, whitespace, and normalized domain declarations. Require `DOMAIN_MIN` of 0,0,0 and `DOMAIN_MAX` of 1,1,1 when present.
- Reject 1D LUTs, unsupported sizes/directives, missing or duplicate required declarations, incorrect row counts, malformed/nonfinite values, nonnormalized domains, and output components outside 0–1. Reject source files larger than 8 MiB before fully reading/parsing them.
- A valid LUT is not necessarily suitable for an sRGB camera image. Import guidance must state the supported SDR sRGB contract; do not promise automatic detection of every Log/HDR mismatch.
- After validation, open Customize label. Canceling this flow leaves the existing collection unchanged and does not occupy a slot.
- Errors identify the issue in ordinary language. An inaccessible file and an invalid LUT are different error states.

Acceptance:

- Existing fixtures cover a valid identity LUT, a nonidentity transform, comments/title, and the supported sizes.
- Negative cases cover truncation, excess rows, bad size, invalid domains, unsupported 1D input, NaN/infinity, invalid numeric rows, and oversized input.
- An invalid import or canceled editor leaves the collection and selected look unchanged.
- Imported looks remain usable after the original external file is moved or deleted.

## F06 — Collection, capacity, and persistence

- Your looks has Built-in and My LUTs tabs. Show the custom count as `n of 5 slots used` and the remaining capacity.
- Keep five custom looks at most. At capacity, explain that a look must be replaced or deleted before a new one can be added; do not silently evict a look.
- Each custom item has actions to edit its label, replace its LUT, and delete it. Built-in items do not expose destructive custom-library actions.
- Editing a label preserves the look identifier, LUT, and intensity. Replacing a LUT preserves the item/label identity and slot count; a failed replacement preserves the previous LUT.
- Confirm destructive deletion. If the selected custom look is deleted, select Original and persist that safe fallback.
- Persist versioned look metadata, validated LUT contents, per-look intensity, selected look preference, and app preferences. Validate restored data and recover with built-ins if a custom record is unavailable.
- Make collection writes atomic enough that a failed write cannot replace a previously valid library with a partial one. Surface errors without falsely showing a saved state.

Acceptance:

- Adding a sixth custom look is rejected without changing the first five.
- Edit, replace, delete, relaunch, and missing/corrupt-storage recovery have coverage.
- Deleting the selected look falls back to Original; editing or replacing it preserves its stable identity.
- Restarting restores valid custom looks and intensity values without referencing the original import location.

## F07 — Two-section label editor

- Show a live preview above Top text/Top color and Bottom text/Bottom color controls.
- Both text fields accept 1–12 user-perceived characters after trimming leading/trailing whitespace; text must be single-line and is preserved as entered. Neither field is an ISO control.
- Both color pickers use the same fixed palette: indigo, yellow, green, cream, red, violet, slate, and charcoal. Final hexadecimal values may be adjusted for visual quality without altering the selection model.
- Choose black or white text independently for each section using the higher contrast against its background.
- Saving a new look commits the validated LUT and label together. Saving edits updates the label wherever the look appears.
- Disallow saving invalid text, explain the issue, and preserve the draft during correction. Cancel discards the draft, with confirmation if there are unsaved changes.

Acceptance:

- Top/bottom colors and text are independent and immediately reflected in the preview.
- Empty, multiline, and over-limit text cannot be committed.
- Label editing updates the collection and camera strip without duplicating the look.
- A small visible icon still has an adequate touch target; long labels remain readable without changing the saved text.

## F08 — Navigation and accessibility

- The gear opens App menu. The smaller stacked-label icon is fixed at the leading edge of the strip while look cards scroll beside it; remove the previous trailing Looks link.
- Your looks leads to import/edit and Customize label. Returning from management preserves the camera's look and session state unless the selected look was explicitly deleted.
- Navigation controls have at least 44-point touch targets. The library entry has an accessible name such as Your looks; filter labels announce both texts and selection state.
- Support meaningful screen-reader labels, text scaling, high-contrast text, and a usable keyboard layout in the editor.
- Maintain the approved hierarchy and dark appearance while adapting spacing to smaller supported screens and safe areas.

Acceptance:

- Camera → Menu → Camera and Camera → Your looks → Customize label → Your looks → Camera are complete paths.
- Keyboard presentation never obscures both the edited field and the save/cancel route.
- Accessibility review can identify the selected look and distinguish the library button from a filter.

## F09 — App menu and preferences

| Group | Entries and first-version behavior |
| --- | --- |
| Settings | Camera & saving: Save clean original (off), grid (off), timer (off/3/10 seconds). App preferences: remember last look (on), shutter haptics (on where supported). |
| Support | Send feedback: compose a user-initiated message through an available system share/composer flow; do not submit automatically or invent a destination. About Lutli: app purpose, version supplied by the build, and acknowledgments. |
| Legal | Terms & conditions and Privacy policy routes exist. Development copy must clearly identify unfinalized release content; production publisher/contact/legal text remains a release gate. |

- Persist preferences and apply changes on returning to the camera.
- If remember-last-look is off, select Original on the next fresh session. This does not delete saved looks or their intensities.
- Remember-last-look applies to LUT selection only. F10 starts each fresh app launch with diffusion Off; this preference must not silently restore diffusion settings across launches.
- A timer shows a visible countdown and can be canceled. Camera switching, leaving the camera, or interruption cancels a pending countdown.
- No account or network service is required for the initial capture and custom-look workflow.

Acceptance:

- Preferences survive relaunch and control the corresponding behavior.
- Feedback cannot be reported as sent before the user completes the system flow.
- Legal routes do not pretend that placeholder development content is finalized policy.

## F10 — Diffusion filters and halation

**Status: model, controls and renderer implemented in source; Apple-platform and physical-device validation pending.** The portable model is covered by the passing 45-test core suite. This feature extends the LUT camera with spatial light effects. The approved mockup is an interaction reference, not a calibrated example of the rendering algorithm.

### Effect selection and controls

- Add **Filters** as the third shooting-toolbar control beside EV and WB. The collapsed control initially shows **Filters Off**. An active effect shows its type and amount, such as **HDF 35%** with a small glow-color indicator, or **Mist 20%**.
- Tapping Filters opens a compact overlay tray at the lower edge of the preview. Its first row contains horizontally arranged **Off**, **HDF**, and **Black Mist** choices plus a close control. When Off is selected, show this chooser alone; reopening an active effect opens its controls directly beneath the chooser. More choices may scroll horizontally if needed on compact layouts.
- Selecting HDF or Black Mist applies that effect and expands the same tray upward to reveal its controls. Preserve the preview's bounds and framing and the positions of EV/WB, the LUT strip, Look intensity, and the shutter. The tray may temporarily cover the preview's lower portion; it must not push shooting controls off screen.
- Keep one diffusion effect active at a time. Each effect works alongside any built-in or custom LUT, including Original, and does not consume a custom LUT slot.

| Mode | Intended appearance | Exposed controls |
| --- | --- | --- |
| Off | No diffusion or halation; the selected LUT still applies | No effect adjustments |
| HDF | Highlight diffusion with optional colored halation localized around bright sources and edges | Filter strength, 0–100%; Glow color: Neutral, Amber, Rose, Red, or custom color |
| Black Mist | Neutral highlight bloom and gentle contrast softening, retaining useful shadow and subject detail | Filter strength, 0–100%; no HDF glow-color controls |

- HDF means highlight diffusion in this product. Its colored halation is a creative treatment; do not promise an exact physical-filter or film-stock simulation. Color selection changes highlight glow, not the entire photograph's tint.
- Present a continuous strength slider with its current percentage. Percentages describe creative effect amount, not an equivalence to physical filter densities such as 1/8 or 1/4. At 0%, bypass the effect while preserving the selected LUT and remembered settings.
- Glow-color swatches include a selection ring/checkmark and an accessible color name. **Neutral** adds no halo tint and follows the highlight's color after the selected LUT grade. A **+** swatch opens the system color picker for a custom color. Color choices are opaque and strength controls the effect amount, so this picker has no separate opacity control. This palette is independent of the Top/Bottom label-color palette.
- Custom-color changes preview immediately. Dismissing the color picker retains the current color; dismissing it without an edit preserves the prior selection.
- The illustrated HDF 35% with Amber and Black Mist 20% are presentation examples. The initial implementation uses **HDF 35% with Neutral** and **Black Mist 20%** when first selected. These development defaults, preset colors, bloom shape and tonal response require photographic tuning; they are not calibrated rendering defaults.
- Controls update the live result immediately. Closing the tray or tapping outside it preserves the selected effect and settings; choosing Off disables diffusion. A closed tray must not look equivalent to a disabled effect.
- Keep touch targets at least 44 points, readable values, and accessible selected states. Touches within the tray must not also trigger focus on the image beneath it. Opening EV, WB or another destination closes the diffusion tray while preserving its settings. Hide lens controls when the tray would cover them and restore them on close.

### State and capture behavior

- Start each fresh app launch with diffusion **Off**. Keep each effect's most recent strength and HDF color in memory during the current app session, including after closing the tray, choosing Off, selecting another effect, opening a menu, or backgrounding and resuming the app.
- Diffusion is session-wide, independent of per-look intensity. Switching LUTs, choosing Original, editing a label, or switching camera/lens does not reset the active effect or its settings. Relaunch restoration of diffusion and saved effect recipes are outside this addition.
- Keep **Look intensity** and **Filter strength** independent. Neither control overwrites the other. Selecting a different diffusion effect replaces the active effect while retaining the inactive effect's settings for reselection.
- Snapshot the selected LUT, Look intensity, diffusion type, Filter strength, and glow color together at the shutter action. A later edit must not change an in-flight capture.
- Apply the same effect definition and settings to live preview and the captured still. Normalize the spatial glow size to image dimensions so preview and full-resolution output have comparable appearance. Preserve the existing color-profile, orientation and output contract.
- Generate the optional clean original from the same capture without either LUT grading or diffusion/halation. Review/share and Photos save states continue to follow F04.

### Rendering and acceptance checks

The implementation adds a spatial rendering stage beyond the LUT. Highlight extraction uses the ungraded source, while the glow is composited after LUT grading so custom/preset tint is not subsequently changed by that LUT. Neutral HDF and Black Mist derive light color from the graded photograph. Soft glow/contrast layers are limited to a 640-pixel long edge; the base image retains its full capture resolution. Blur radii scale relative to image dimensions, and the result is cropped back to the original extent. Off and 0% follow the unchanged LUT-only path. The full recipe is frozen at shutter time, and the clean copy branches before both creative stages.

These are initial artistic algorithm choices that still require Apple image tests and photographic comparison. Keep processing off the UI thread and retain bounded preview delivery. The following acceptance checks distinguish the passing portable model tests from Apple/UI/device evidence still to be recorded:

- **UI:** open Filters, select HDF, adjust amount and color, select Black Mist, close and reopen, and choose Off. The toolbar and shutter stay reachable; Black Mist exposes no HDF-only controls. Check small screens, large text, VoiceOver, focus hit testing and tray dismissal.
- **State:** only one effect is active; closing and Off/reselection preserve settings within the app session. LUT/camera changes and background/resume preserve them. A fresh launch starts Off regardless of remember-last-look.
- **Bypass:** Off and 0% produce the same creative output as the selected LUT alone. Original and 0% Look intensity preserve independently active diffusion. Use numerical tolerances appropriate to the renderer rather than visual guesses.
- **Image behavior:** HDF color changes are localized to highlight glow; Black Mist remains neutral. Compare bright point sources, skin, deep shadows, clipped highlights and mixed lighting, including at the strength endpoints.
- **Capture:** changing effect, strength or color after the shutter cannot alter the captured recipe. Compare equivalent preview/full-resolution framing and relative halo size. Verify that the optional clean copy excludes both creative stages.
- **Performance and recovery:** profile latency, memory and thermal behavior on the supported device matrix. Exercise repeated adjustments, camera switching and interruptions without unbounded frame accumulation or false save-success states.

## External release gates

The following are required before a release-ready claim, regardless of unit-test results: an Apple-platform build, device camera/rendering tests, supported-device and iOS-version selection, permissions/error-path testing, accessibility review, photographic review of all built-in looks, final feedback/legal/publisher details, signing, and distribution configuration. Linux-only checks and static mockups cannot satisfy these gates.
