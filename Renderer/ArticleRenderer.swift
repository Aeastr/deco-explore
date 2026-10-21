import SwiftUI
import UIKit

struct ArticleStyle {
    var design: Font.Design = .default
    var body: Font.TextStyle = .body
    var headings: [Font.TextStyle] = [.title, .title2, .headline, .subheadline, .subheadline, .caption]
    var blockSpacing: CGFloat = 20
    var headingTopSpacing: CGFloat = 12
    var maximumImageHeight: CGFloat = 620
    var panelInset: CGFloat = 12
    var panelRadius: CGFloat = 30
    var panelItemAlignment: HorizontalAlignment = .leading

    func heading(_ level: Int) -> Font.TextStyle {
        guard !headings.isEmpty else { return .headline }
        return headings[min(max(level - 1, 0), headings.count - 1)]
    }
}

/// Image loading and app-specific components belong to the caller.
struct ArticleRenderer<ImageContent: View, ComponentContent: View>: View {
    let document: ArticleDocument
    var style = ArticleStyle()
    var transformText: (AttributedString) -> AttributedString = { $0 }
    @ViewBuilder var image: (String, String) -> ImageContent
    @ViewBuilder var component: (String, String) -> ComponentContent

    var body: some View {
        VStack(alignment: .leading, spacing: style.blockSpacing) {
            ForEach(document.blocks.indices, id: \.self) { index in
                switch document.blocks[index] {
                case .heading(let level, let title):
                    ArticleInlineText.text(transformText(ArticleInlineText.parse(title)), style: style,
                                           textStyle: style.heading(level))
                        .bold()
                        .padding(.top, index == 0 ? 0 : style.headingTopSpacing)
                        .accessibilityAddTraits(.isHeader)
                case .paragraph(let markdown):
                    ArticleInlineText.text(transformText(ArticleInlineText.parse(markdown)), style: style)
                        .fixedSize(horizontal: false, vertical: true)
                case .image(let description, let source):
                    image(description, source)
                case .panel(let layout, let items):
                    ArticleTextPanel(layout: layout, items: items, style: style, transformText: transformText)
                case .bulletList(let items):
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(items.indices, id: \.self) { index in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•")
                                    .font(.system(style.body, design: style.design))
                                    .accessibilityHidden(true)
                                ArticlePanelItem(
                                    text: transformText(ArticleInlineText.parse(items[index])),
                                    style: style
                                )
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                case .component(let kind, let id):
                    component(kind, id)
                }
            }
        }
    }
}

extension ArticleInlineText {
    static func text(_ attributed: AttributedString, style: ArticleStyle = ArticleStyle(),
                     textStyle: Font.TextStyle? = nil) -> Text {
        var interpolation = LocalizedStringKey.StringInterpolation(literalCapacity: 0, interpolationCount: attributed.runs.count)
        for run in attributed.runs {
            var segment = AttributedString(attributed[run.range])
            let inlineStyle = run[ArticleTextStyle.self].flatMap(namedStyle) ?? textStyle ?? style.body
            let inlineDesign = run[ArticleFontDesign.self].flatMap(namedDesign) ?? style.design
            var text: Text
            if let url = run.imageURL, let scheme = url.scheme, ["symbol", "symbol-asset"].contains(scheme) {
                segment.imageURL = nil
                let name = String(url.absoluteString.dropFirst(scheme.count + 1))
                let image = scheme == "symbol" ? UIImage(systemName: name) : UIImage(named: name)
                if let image, image.isSymbolImage {
                    let symbol = scheme == "symbol" ? Image(systemName: name) : Image(name)
                    text = Text(symbol).baselineOffset(0)
                        .accessibilityLabel(Text(String(segment.characters)))
                    if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true { text = text.bold() }
                    if run.inlinePresentationIntent?.contains(.emphasized) == true { text = text.italic() }
                } else {
                    text = Text(segment)
                }
            } else {
                text = Text(segment)
            }
            let isCode = run.inlinePresentationIntent?.contains(.code) == true
            text = text.font(.system(inlineStyle, design: isCode ? .monospaced : inlineDesign))
            interpolation.appendInterpolation(text)
        }
        return Text(LocalizedStringKey(stringInterpolation: interpolation))
    }

    private static func namedDesign(_ value: String) -> Font.Design? {
        switch value {
        case "default": .default
        case "serif": .serif
        case "monospaced": .monospaced
        case "rounded": .rounded
        default: nil
        }
    }

    private static func namedStyle(_ value: String) -> Font.TextStyle? {
        switch value {
        case "largeTitle": .largeTitle
        case "title": .title
        case "title2": .title2
        case "title3": .title3
        case "headline": .headline
        case "subheadline": .subheadline
        case "body": .body
        case "callout": .callout
        case "footnote": .footnote
        case "caption": .caption
        case "caption2": .caption2
        default: nil
        }
    }
}

/// A shared surface for text panels, images and image loading states.
struct ArticlePanel<Content: View>: View {
    var style = ArticleStyle()
    var cut: ArticleImageOptions.Cut = .none
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, cut == .top || cut == .both ? 0 : style.panelInset)
            .padding(.bottom, cut == .bottom || cut == .both ? 0 : style.panelInset)
            .padding(.horizontal, style.panelInset)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(.rect(cornerRadius: style.panelRadius))
    }
}

struct ArticleTextPanel: View {
    let layout: ArticleDocument.PanelLayout
    let items: [String]
    var style = ArticleStyle()
    var transformText: (AttributedString) -> AttributedString = { $0 }
    @ScaledMetric(relativeTo: .body) private var minimumColumnWidth: CGFloat = 140
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ArticlePanel(style: style) {
            LazyVGrid(
                columns: layout == .grid && !dynamicTypeSize.isAccessibilitySize
                    ? [GridItem(.adaptive(minimum: minimumColumnWidth), alignment: .leading)]
                    : [GridItem(.flexible(), alignment: .leading)],
                alignment: .leading,
                spacing: style.panelInset
            ) {
                ForEach(items.indices, id: \.self) { index in
                    ArticlePanelItem(
                        text: transformText(ArticleInlineText.parse(items[index])),
                        style: style
                    )
                        .frame(maxWidth: .infinity, alignment: style.panelItemAlignment == .center ? .center : .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                }
            }
        }
    }
}

/// A leading symbol gets the same space in every item, regardless of its shape.
private struct ArticlePanelItem: View {
    let text: AttributedString
    let style: ArticleStyle
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var iconSpacing: CGFloat = 8

    var body: some View {
        if let parts = symbolAndLabel {
            HStack(alignment: .firstTextBaseline, spacing: iconSpacing) {
                ArticleInlineText.text(parts.symbol, style: style)
                    .frame(width: iconWidth)
                    .accessibilityHidden(true)
                ArticleInlineText.text(parts.label, style: style)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            ArticleInlineText.text(text, style: style)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var symbolAndLabel: (symbol: AttributedString, label: AttributedString)? {
        guard let run = text.runs.first, let url = run.imageURL,
              let scheme = url.scheme, ["symbol", "symbol-asset"].contains(scheme),
              run.link == nil else { return nil }
        let name = String(url.absoluteString.dropFirst(scheme.count + 1))
        let image = scheme == "symbol" ? UIImage(systemName: name) : UIImage(named: name)
        guard let image, image.isSymbolImage else { return nil }
        var label = AttributedString(text[run.range.upperBound...])
        while label.characters.first?.isWhitespace == true {
            label.removeSubrange(label.startIndex..<label.characters.index(after: label.startIndex))
        }
        guard !label.characters.isEmpty else { return nil }
        return (AttributedString(text[run.range]), label)
    }
}

/// Apply the same panel to loaded images and their loading states.
struct ArticleImagePanel<Content: View>: View {
    let options: ArticleImageOptions
    var style = ArticleStyle()
    @ViewBuilder var content: Content

    var body: some View {
        Group {
            if options.background == .secondary {
                ArticlePanel(style: style, cut: options.cut) {
                    content
                }
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ArticleImageView: View {
    let image: UIImage
    var style = ArticleStyle()

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: style.maximumImageHeight)
    }
}
