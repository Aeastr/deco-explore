import Foundation

/// A deliberately small block format. Inline Markdown is parsed by Foundation.
struct ArticleDocument {
    enum PanelLayout: String {
        case grid, stack
    }

    enum Block {
        case heading(Int, String)
        case paragraph(String)
        case image(description: String, source: String)
        case component(kind: String, id: String)
        case panel(layout: PanelLayout, items: [String])
        case bulletList([String])
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
        let lines = source.components(separatedBy: .newlines).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        var index = 0
        while index < lines.count {
            let line = lines[index]
            index += 1
            if line.hasPrefix(":::"),
               let layout = PanelLayout(rawValue: String(line.dropFirst(3))),
               let end = lines[index...].firstIndex(of: ":::") {
                let items = lines[index..<end].filter { !$0.isEmpty }
                // A malformed or nested panel remains readable as ordinary text.
                flush()
                if !items.isEmpty, !items.contains(where: { $0.hasPrefix(":::") }) {
                    blocks.append(.panel(layout: layout, items: items))
                } else {
                    blocks.append(.paragraph(lines[(index - 1)...end].joined(separator: " ")))
                }
                index = end + 1
                continue
            }
            if line.isEmpty {
                flush()
                continue
            }
            if let item = Self.bulletItem(line) {
                flush()
                var items = [item]
                while index < lines.count, let next = Self.bulletItem(lines[index]) {
                    items.append(next)
                    index += 1
                }
                blocks.append(.bulletList(items))
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
                blocks.append(.image(description: String(attributed.characters), source: source.absoluteString))
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
            case .panel(_, let items), .bulletList(let items):
                items.map { String(ArticleInlineText.parse($0).characters) }.joined(separator: " ")
            }
        }.joined(separator: " ")
    }

    private static func bulletItem(_ line: String) -> String? {
        guard let marker = line.first, ["-", "*", "+"].contains(marker),
              line.dropFirst().first == " " || line.dropFirst().first == "\t" else { return nil }
        let item = line.dropFirst().trimmingCharacters(in: .whitespaces)
        return item.isEmpty ? nil : item
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

/// Images are cropped before publication; only their surrounding panel is authored here.
struct ArticleImageOptions {
    enum Background { case none, secondary }
    enum Cut { case none, top, bottom, both }

    var background: Background = .none
    var cut: Cut = .none

    static func parse(_ source: String) -> Self {
        guard let hash = source.firstIndex(of: "#") else { return Self() }
        let fragment = source[source.index(after: hash)...]
        var fields: [String: String] = [:]
        for field in fragment.split(separator: "&", omittingEmptySubsequences: false) {
            let pair = field.split(separator: "=", omittingEmptySubsequences: false)
            guard pair.count == 2 else { return Self() }
            let key = String(pair[0])
            guard ["background", "cut"].contains(key), fields[key] == nil else { return Self() }
            fields[key] = String(pair[1])
        }
        guard fields["background"].map({ ["none", "secondary"].contains($0) }) ?? true,
              fields["cut"].map({ ["none", "top", "bottom", "both"].contains($0) }) ?? true else { return Self() }
        var result = Self()
        result.background = fields["background"] == "secondary" ? .secondary : .none
        switch fields["cut"] {
        case "top": result.cut = .top
        case "bottom": result.cut = .bottom
        case "both": result.cut = .both
        default: break
        }
        return result
    }
}
