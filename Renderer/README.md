# Article renderer

Copy the two Swift files into an iOS app. `ArticleStyle` controls typography and spacing; image loading and app actions are supplied by the caller.

We support paragraphs, `#` through `######` headings, **bold**, *italic*, `inline code`, links and standalone images. Inline text uses Apple’s Markdown parser. Font choices use [Apple’s extended Markdown attributes](https://developer.apple.com/documentation/foundation/markdowndecodableattributedstringkey):

```markdown
## A heading
**Bold**, *italic*, and `code` within a paragraph.
^[A serif phrase](fontDesign: 'serif')
^[An inline title](fontDesign: 'rounded', textStyle: 'title2')
```

`fontDesign` accepts `default`, `serif`, `monospaced` and `rounded`. `textStyle` accepts Apple’s text styles, such as `body`, `headline`, `title`, `title2` and `caption`.

```markdown
:::grid
![Small](symbol:widget.small) **Small**
![Medium](symbol:widget.medium) **Medium**
![Large](symbol:widget.large) **Large**
![Extra Large](symbol:widget.extralarge) **Extra Large**
:::

![A full screenshot](asset:Example/full)
![A pre-cropped detail](asset:Example/detail#background=secondary&cut=bottom)
```

Use `:::stack` for a single column. Each nonempty line is one inline Markdown item; symbols, emphasis and links work as in paragraphs. Panels use a rounded secondary background. Grids adapt to width and text size. Nested panels are unsupported; malformed panels remain readable as ordinary text.

Crop images before publication and record their final dimensions in the manifest. Images are plain by default; `background=secondary` adds the same panel used for grids and stacks. `cut=top`, `bottom` or `both` removes padding at an already-trimmed edge. The reader does not crop images.

Build an `ArticleDocument(markdown)`, then pass it to `ArticleRenderer`. Its image closure receives the accessible description and source; resolve that source with your own loader, wrap the result in `ArticleImagePanel`, and display it with `ArticleImageView`. The component closure handles optional `[kind:id]` blocks enabled through `componentKinds`. Text links use SwiftUI’s `openURL` environment.

## Bullet lists

Use `- `, `* ` or `+ ` at the beginning of consecutive lines for a flat bullet list. Each line is one item and supports inline symbols, emphasis and links. Wrapped text aligns with the item text. Lists have no panel background; grid and stack panels remain available. Nesting and multiline items are outside this small format.

```markdown
Widgets support these sizes:

- ![Small](symbol:widget.small) **Small**
- ![Medium](symbol:widget.medium) **Medium**
- ![Large](symbol:widget.large) **Large**
- ![Extra Large](symbol:widget.extralarge) **Extra Large**
```
