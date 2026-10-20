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
![A full screenshot](asset:Example/full)
![A cropped detail](asset:Example/detail#crop=3:1&position=top)
![A detail without a panel](asset:Example/detail#crop=1:1&position=bottom&background=none)
![An already-trimmed image](asset:Example/detail#background=secondary&cut=bottom)
```

Full screenshots are plain. Cropped details use a rounded secondary-background panel unless `background=none` is explicit. `position` accepts named anchors or `x,y` percentages from 0 to 100. The panel omits padding at cropped edges; `cut=top`, `bottom` or `both` also handles images trimmed before rendering. Existing `#top` and `#setup` aliases retain their plain presentation.

Build an `ArticleDocument(markdown)`, then pass it to `ArticleRenderer`. Its image closure receives the accessible description and source; resolve that source with your own loader, wrap the result in `ArticleImagePanel`, and display it with `ArticleImageView`. The component closure handles optional `[kind:id]` blocks enabled through `componentKinds`. Text links use SwiftUI’s `openURL` environment.
