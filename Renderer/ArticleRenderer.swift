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
                    text = Text(Image(uiImage: image)).accessibilityLabel(Text(String(segment.characters)))
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

/// Apply the same viewport and panel to loaded images and their loading states.
struct ArticleImagePanel<Content: View>: View {
    let options: ArticleImageOptions
    let sourceSize: CGSize
    var style = ArticleStyle()
    @ViewBuilder var content: Content

    var body: some View {
        let sourceRatio = sourceSize.width / max(1, sourceSize.height)
        let cuts = options.verticalCuts(sourceAspectRatio: Double(sourceRatio))
        Group {
            if options.background == .secondary {
                content
                    .padding(.top, cuts.top ? 0 : style.panelInset)
                    .padding(.bottom, cuts.bottom ? 0 : style.panelInset)
                    .padding(.horizontal, style.panelInset)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: style.panelRadius))
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct ArticleImageView: View {
    let image: UIImage
    let options: ArticleImageOptions
    var style = ArticleStyle()

    var body: some View {
        if let crop = options.crop {
            GeometryReader { geometry in
                let scale = max(geometry.size.width / image.size.width, geometry.size.height / image.size.height)
                let width = image.size.width * scale
                let height = image.size.height * scale
                Image(uiImage: image)
                    .resizable()
                    .frame(width: width, height: height)
                    .offset(x: (geometry.size.width - width) * CGFloat(crop.x),
                            y: (geometry.size.height - height) * CGFloat(crop.y))
            }
            .aspectRatio(CGFloat(crop.aspectRatio), contentMode: .fit)
            .clipped()
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: style.maximumImageHeight)
        }
    }
}
