# Diffusion implementation plan

This implements the approved [F10 specification](feature-specification.md#f10--diffusion-filters-and-halation) and [shooting UI](ui-ux.md#filters-interaction). It extends the existing native iOS camera on `planning/lutli`.

## Scope and sequence

1. **Portable state and render settings.** Add Off/HDF/Black Mist selection, independent remembered strengths, named/custom opaque glow colors and an immutable settings value. Start each new app session Off. Use HDF 35% with Neutral glow and Black Mist 20% as initial development values; they require photographic tuning.
2. **Spatial rendering.** Extend the locked renderer recipe to include diffusion. Preserve the effect when the LUT changes and preserve the LUT when the effect changes. Add localized highlight diffusion, colored HDF glow, and neutral Black Mist softening. Normalize spatial size across preview and capture, crop to the original extent, and retain an exact bypass when Off or strength is zero.
3. **Shooting interface.** Add Filters beside EV/WB. Overlay a horizontal chooser and expanding detail controls on the lower preview. Preserve the look strip and shutter positions. Add live strength, HDF presets/custom color, selected-state feedback, accessible controls and scrolling for larger text.
4. **Capture and lifecycle integration.** Forward settings through the existing camera controller/service. Snapshot the full recipe at shutter time. Keep the clean original free of both creative stages. Preserve session settings through look changes, navigation and backgrounding without writing diffusion preferences to disk.
5. **Verification and handoff.** Run portable tests, compile and execute Apple renderer tests, and exercise the tray through simulator UI tests. Update the validation record with actual results. Keep physical-camera comparisons, accessibility review and performance/thermal measurements as explicit device checks.

## Focused verification

| Layer | Evidence required |
| --- | --- |
| Core | Finite/clamped colors and strengths; one active effect; independent remembered settings; Off/reselection; fresh-launch Off; immutable snapshots |
| Renderer | Off/0% equivalence; highlight locality and tint; neutral Black Mist; proportional glow size; unchanged in-flight recipes; clean-copy exclusion |
| UI | Open/select/adjust/close/reopen; effect switching; separate look intensity; no layout movement of the shutter; fresh launch resets to Off |
| Device | Preview/photo appearance, skin and shadow detail, mixed lighting, capture timing, memory, thermal behavior and touch/accessibility review |

The core model, renderer and interface can be implemented independently against the shared settings contract. Camera forwarding, generated project configuration and CI integrate those pieces. Tests must execute before their results are marked as passed in the [validation record](../validation.md).

## Implementation result

The model, renderer, camera forwarding and overlay are implemented. The [validation record](../validation.md) records **45 passing portable tests, 16 passing Apple renderer tests and 3 passing simulator UI tests**, with the successful run tied to application commit `3497cf8`. The shared render recipe preserves settings through independent LUT/effect updates and snapshots both at shutter time.

Device photographic tuning and performance remain the next gate. Manual custom-color-picker interaction, VoiceOver, Reduce Motion, compact-device reachability, real camera/lens transitions and background recovery still require review. Automated simulator results do not close those checks.

## Boundaries

Only one diffusion effect is active at a time. This work does not add physical optical-filter equivalence, effect stacking, saved effect recipes, grain, RAW, video or Android. It does not infer final image quality or device performance from a mockup or successful simulator test.
