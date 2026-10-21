# Image naming

Keep images under `Explore/<Article>/`, using a stable descriptive name for the image’s role. Device-specific screenshots add the hardware model identifier and, when needed, the display state:

```text
<imageName>.<modelIdentifier>[.<displayState>].png
```

Use the model identifier already known to the app, such as `iPhone19,2`. Replace its comma with a hyphen in filenames: `iPhone19-2`. Keep the identifier’s original capitalization. The filename identifies the device shown in the screenshot.

| Image | Filename example |
| --- | --- |
| Screenshot from one iPhone model | `Explore/Widgets/widgetsEditor.iPhone19-2.png` |
| Screenshot from one iPad model | `Explore/Widgets/widgetsEditor.iPad17-1.png` |
| Duo outer display | `Explore/Widgets/widgetsEditor.iPhone19-4.closed.png` |
| Duo inner display | `Explore/Widgets/widgetsEditor.iPhone19-4.open.png` |
| Shared artwork or general fallback | `Explore/Collaboration/sharedWallpaper.png` |

Use `closed` and `open` only for distinct physical displays. Rotating an ordinary device keeps the same model identifier. Where separate orientation captures are useful, append `portrait` or `landscape`, after any display state: `widgetsEditor.iPhone19-4.open.landscape.png`.

Keep the same image name across device captures. Use a hardware identifier rather than a marketing name, screen dimensions, or a guessed device family. Device matching can use the app’s existing model-to-display information; numerical proximity between model identifiers does not describe visual similarity.

## Article references and delivery

Articles retain their stable logical reference:

```markdown
![The widget editor](asset:Explore/Widgets/widgetsEditor)
```

Register the actual PNG path in `manifest.json`, and add its pixel width and height to `imageSizes`. Commit the image and manifest changes together on `main`.

The current app resolves the standard image and the explicit `DuoClosed` and `DuoOpen` manifest aliases. Those aliases can point to files using this naming convention. For example:

```json
{
  "images": {
    "Explore/Widgets/widgetsEditor": "Explore/Widgets/widgetsEditor.iPhone19-2.png",
    "Explore/Widgets/widgetsEditorDuoClosed": "Explore/Widgets/widgetsEditor.iPhone19-4.closed.png",
    "Explore/Widgets/widgetsEditorDuoOpen": "Explore/Widgets/widgetsEditor.iPhone19-4.open.png"
  }
}
```

Model-based automatic selection needs a corresponding app resolver; filenames alone do not enable it. Existing published filenames remain valid. Apply this convention to new device-specific captures, retaining any older file still referenced by a published article or manifest.
