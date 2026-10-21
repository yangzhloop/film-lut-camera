# UI and navigation baseline

The current direction is a minimalist dark camera interface with restrained monochrome controls and colorful, two-section filter labels. This is a design baseline that can evolve during development, not a pixel-locked specification.

## Concept artwork

The images below preserve the reviewed concepts. They still show the retired placeholder **STILL**. The current working name is **Lutli**, with a lowercase **lutli** wordmark; the old branding in the images is superseded.

These are static visual concepts. They do not demonstrate functional controls, camera processing, or an implemented application.

### Current camera navigation and app menu

![Camera with leading library button, app menu, and Your looks collection](assets/camera-navigation-concept.png)

This is the latest navigation reference. It supersedes the trailing `Looks` link visible in the earlier label-editor concept below.

### Filter identity and label editor

![Two-color filter labels, custom LUT collection, and label customization controls](assets/filter-label-concept.png)

Use this image for the label-editor layout and two-section label system. Use the latest navigation reference for the shooting-strip entry point. The numbered captions belong to the original concept board and are not route identifiers.

## Shooting screen

Keep the existing visual hierarchy:

1. Top toolbar with flash control, app wordmark, and the upper-right gear.
2. Large live camera preview, with supported lens choices near its lower edge.
3. Compact exposure and white-balance shortcuts showing current values, such as `EV +0.3` and `WB Auto`.
4. Horizontal look strip with a smaller library icon at its leading edge, followed by two-color filter labels.
5. Intensity slider for the current look.
6. Bottom row with last-capture preview, primary shutter, and camera switching.

The first small icon opens **Your looks**. It is a navigation control, not a neutral filter. The current interaction proposal keeps it fixed while the labels scroll horizontally beside it. The previous trailing `Looks` link is removed.

Tapping a filter label selects the look. Mark the selected label with a simple outline. The last-capture thumbnail may remain photographic; filter selectors use graphic labels instead of photographic thumbnails.

The implementation places Original immediately after the library button, with `ORIGINAL / RGB` on charcoal and cream.

## App menu

The upper-right gear opens a separate app menu. The current grouping is:

| Group | Entries |
| --- | --- |
| Settings | Camera & saving; App preferences |
| Support | Send feedback; About Lutli |
| Legal | Terms & conditions; Privacy policy |

The precise settings, destinations, and content remain to be designed. Exposure and white balance remain accessible from the camera screen. Filter management is reached through the leading library icon.

## Your looks

- Separate Built-in and My LUTs collections.
- Use the same two-section labels as the camera strip.
- Show the custom collection count; `3 of 5` in the concept illustrates the proposed five-slot limit.
- Provide an import action and per-look management actions for custom looks.
- Importing a compatible LUT leads to **Customize label** before the look is saved.
- Editing an existing custom label also opens **Customize label**.

Rename, replacement, deletion, full-capacity behavior, and selection behavior when returning to the camera require detailed interaction specifications.

## Customize label

Show a live preview of the label above two independent editing groups:

| Section | Editable properties |
| --- | --- |
| Top | Top text and a color selected from a predefined palette |
| Bottom | Bottom text and a color selected from a predefined palette |

Either text section accepts short words or numbers. Example text such as `DAYLIGHT / 400` does not set camera exposure or ISO.

Use a clear Save filter action and a cancel/back path. Saving should update the label wherever that look appears. Cancel behavior for unsaved changes still needs definition.

The implementation chooses black or white lettering using the stronger contrast. Both sections share an eight-color palette and accept 1–12 characters after trimming. Text is preserved as entered. See the [feature specification](feature-specification.md) for current validation rules.

## White balance and exposure

The proposed white-balance panel offers Auto, Lock, and Manual modes, followed by temperature and tint controls when supported. Selecting a manual value should have an explicit relationship to the active mode.

The implementation keeps white balance and exposure session-wide while intensity belongs to each look. Validate this behavior on real devices before release.

Exposure compensation belongs to the automatic-exposure workflow. Any later manual shutter/ISO mode needs its own coherent exposure interaction.

## Prototype checks

- Verify that the leading library icon is discoverable and reachable while browsing looks.
- Keep its visible icon small while providing at least a 44-point touch target.
- Check label readability, selection states, text scaling, contrast, and screen-reader naming.
- Check one-handed access, safe areas, compact displays, and the keyboard layout in the label editor.
- Confirm that cancel/back navigation preserves the appropriate camera state and existing filter data.
- Keep final label colors, spacing, and behavior adaptable as real-device testing reveals constraints.
