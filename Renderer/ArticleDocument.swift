import Foundation

/// A deliberately small block format. Inline Markdown is parsed by Foundation.
struct ArticleDocument {
    enum Block {
        case heading(Int, String)
        case paragraph(String)
        case image(description: String, source: String)
        case component(kind: String, id: String)
    }

    let blocks: [Block]

    init(_ source: String, componentKinds: Set<String> = []) {
        var blocks: [Block] = []
        var paragraph: [String] = []
        func flush() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: " ")))
            paragraph.removeAll()
        }
        for raw in source.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flush()
                continue
            }
            if line.hasPrefix("["), line.hasSuffix("]"), let colon = line.firstIndex(of: ":") {
                let kind = String(line.dropFirst().prefix(upTo: colon))
                let id = String(line[line.index(after: colon)..<line.index(before: line.endIndex)])
                if componentKinds.contains(kind), !id.isEmpty {
                    flush()
                    blocks.append(.component(kind: kind, id: id))
                    continue
                }
            }
            // Let Foundation handle escaped descriptions, destination parentheses and titles.
            if line.hasPrefix("!["), let attributed = try? AttributedString(markdown: line),
               let source = attributed.runs.first?.imageURL,
               attributed.runs.allSatisfy({ $0.imageURL == source }) {
                flush()
                blocks.append(.image(description: String(attributed.characters), source: source.absoluteString.removingPercentEncoding ?? source.absoluteString))
                continue
            }
            let markers = line.prefix(while: { $0 == "#" }).count
            let remainder = line.dropFirst(markers)
            if (1...6).contains(markers), remainder.isEmpty || remainder.first == " " || remainder.first == "\t" {
                flush()
                var title = remainder.trimmingCharacters(in: .whitespaces)
                let closing = title.reversed().prefix(while: { $0 == "#" }).count
                if closing > 0 {
                    let before = title.dropLast(closing)
                    if before.last == " " || before.last == "\t" {
                        title = before.trimmingCharacters(in: .whitespaces)
                    }
                }
                blocks.append(.heading(markers, title))
            } else {
                paragraph.append(line)
            }
        }
        flush()
        self.blocks = blocks
    }

    func plainText(componentLabel: (String, String) -> String = { _, id in id }) -> String {
        blocks.map {
            switch $0 {
            case .heading(_, let text), .paragraph(let text): String(ArticleInlineText.parse(text).characters)
            case .image(let description, _): description
            case .component(let kind, let id): componentLabel(kind, id)
            }
        }.joined(separator: " ")
    }
}

struct ArticleFontDesign: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
    typealias Value = String
    static let name = "fontDesign"
}

struct ArticleTextStyle: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
    typealias Value = String
    static let name = "textStyle"
}

struct ArticleAttributes: AttributeScope {
    let fontDesign: ArticleFontDesign
    let textStyle: ArticleTextStyle
    let foundation: AttributeScopes.FoundationAttributes
}

enum ArticleInlineText {
    static func parse(_ markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown, including: ArticleAttributes.self,
                               options: .init(allowsExtendedAttributes: true))) ?? AttributedString(markdown)
    }
}

/// Crop coordinates describe the available overflow, from zero to one.
struct ArticleImageOptions {
    struct Crop {
        let aspectRatio: Double
        let x: Double
        let y: Double
    }
    enum Background { case none, secondary }
    enum Cut { case none, top, bottom, both }

    var crop: Crop?
    var background: Background = .none
    var cut: Cut = .none

    static func parse(_ source: String) -> Self {
        guard let hash = source.firstIndex(of: "#") else { return Self() }
        let fragment = String(source[source.index(after: hash)...])
        // Preserve existing background-free aliases.
        if fragment == "top" { return Self(crop: Crop(aspectRatio: 3, x: 0.5, y: 0)) }
        if fragment == "setup" { return Self(crop: Crop(aspectRatio: 1.5, x: 0.5, y: 0)) }
        var fields: [String: String] = [:]
        for field in fragment.split(separator: "&", omittingEmptySubsequences: false) {
            let pair = field.split(separator: "=", omittingEmptySubsequences: false)
            guard pair.count == 2 else { return Self() }
            let key = String(pair[0])
            guard ["crop", "position", "background", "cut"].contains(key), fields[key] == nil else { return Self() }
            fields[key] = String(pair[1])
        }
        guard fields["background"].map({ ["none", "secondary"].contains($0) }) ?? true,
              fields["cut"].map({ ["none", "top", "bottom", "both"].contains($0) }) ?? true else { return Self() }
        var result = Self()
        switch fields["cut"] {
        case "top": result.cut = .top
        case "bottom": result.cut = .bottom
        case "both": result.cut = .both
        default: break
        }
        if let ratio = fields["crop"] {
            let dimensions = ratio.split(separator: ":", omittingEmptySubsequences: false)
            guard dimensions.count == 2, let w = Double(dimensions[0]), let h = Double(dimensions[1]),
                  w.isFinite, h.isFinite, w > 0, h > 0, (w / h).isFinite, w / h > 0 else { return Self() }
            let anchors: [String: (Double, Double)] = [
                "top-left": (0, 0), "top": (0.5, 0), "top-right": (1, 0),
                "left": (0, 0.5), "center": (0.5, 0.5), "right": (1, 0.5),
                "bottom-left": (0, 1), "bottom": (0.5, 1), "bottom-right": (1, 1)
            ]
            let position = fields["position"] ?? "center"
            let point: (Double, Double)
            if let anchor = anchors[position] {
                point = anchor
            } else {
                let coordinates = position.split(separator: ",", omittingEmptySubsequences: false)
                guard coordinates.count == 2, let x = Double(coordinates[0]), let y = Double(coordinates[1]),
                      x.isFinite, y.isFinite, (0...100).contains(x), (0...100).contains(y) else { return Self() }
                point = (x / 100, y / 100)
            }
            result.crop = Crop(aspectRatio: w / h, x: point.0, y: point.1)
        } else if fields["position"] != nil {
            return Self()
        }
        result.background = fields["background"] == "secondary" || (fields["background"] == nil && result.crop != nil)
            ? .secondary : .none
        return result
    }

    func verticalCuts(sourceAspectRatio: Double) -> (top: Bool, bottom: Bool) {
        var top = cut == .top || cut == .both
        var bottom = cut == .bottom || cut == .both
        if let crop, sourceAspectRatio < crop.aspectRatio {
            top = top || crop.y > 0
            bottom = bottom || crop.y < 1
        }
        return (top, bottom)
    }
}
