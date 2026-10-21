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

The logical name’s entry in `images` supplies the general fallback. Register additional device captures with a matching model suffix in their keys. The app reads the model and display state from each registered PNG’s filename:

```json
{
  "images": {
    "Explore/Widgets/widgetsEditor": "Explore/Widgets/widgetsEditor.iPhone19-2.png",
    "Explore/Widgets/widgetsEditor.iPhone19-4.closed": "Explore/Widgets/widgetsEditor.iPhone19-4.closed.png",
    "Explore/Widgets/widgetsEditor.iPhone19-4.open": "Explore/Widgets/widgetsEditor.iPhone19-4.open.png"
  }
}
```

Every registered PNG needs a corresponding `imageSizes` entry, keyed by its complete file path. Keep device captures beside one another under the logical image’s article folder. An unregistered file is not part of the published inventory.

## Selection

The app uses its known hardware model identifier and screen profiles:

1. Choose a capture for the exact model and physical display state.
2. Otherwise choose the closest known model in the same family and physical display state. Compare portrait-normalized screen proportions first, then pixel area. These are device-screen dimensions from the app’s model profiles, rather than the framed PNG’s dimensions.
3. Otherwise use the logical name’s general fallback entry.

Conventional iPhones, iPads and Duo are separate families. Duo’s `open` and `closed` captures are separate states. An unknown model can use an exact-model capture; without known screen geometry it uses the general fallback rather than guessing a closest device. A shared image such as `sharedWallpaper.png` needs only its general entry.

When multiple orientations are supplied, conventional iPhones prefer `portrait`; iPads and open Duo prefer `landscape`. An omitted orientation follows the preferred explicit orientation, then the other orientation. Selection stays stable as the reader rotates or resizes the article. Equal device matches use the file path as a deterministic tie breaker.

The same selection resolves artwork and its size metadata. The decoded-image cache includes the reader’s model and physical display state. Published content updates keep the existing revision and offline caching behavior.

Remote Explore first ships in Deco 3.1. The current Widgets and Layers captures use this convention; the manifest uses the model-specific names directly.
