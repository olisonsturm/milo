import SwiftUI

/// Render blocks separately: SwiftUI's inline Markdown alone doesn't lay out fences or tables.
struct MarkdownAnswer: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(MarkdownBlocks.parse(text).enumerated()), id: \.offset) { _, block in
                switch block.kind {
                case .code:
                    ScrollView(.horizontal) {
                        Text(block.text).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    }.padding(10).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                case .heading:
                    Text(inline(block.text)).font(.headline).textSelection(.enabled)
                case .table:
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(block.text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, row in
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(Array(row.split(separator: "|", omittingEmptySubsequences: false).dropFirst().dropLast().enumerated()), id: \.offset) { _, cell in
                                        Text(inline(String(cell).trimmingCharacters(in: .whitespaces))).frame(width: 150, alignment: .leading).textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }.padding(10).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                case .paragraph:
                    Text(inline(block.text)).textSelection(.enabled)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

enum MarkdownBlocks {
    enum Kind: Equatable { case paragraph, heading, code, table }
    struct Block: Equatable { let kind: Kind; let text: String }
    static func parse(_ text: String) -> [Block] {
        var result: [Block] = []
        var code: [String]? = nil
        var paragraph: [String] = []
        var table: [String] = []
        func flush() {
            if !paragraph.isEmpty { result.append(Block(kind: .paragraph, text: paragraph.joined(separator: "\n"))); paragraph = [] }
            if !table.isEmpty { result.append(Block(kind: .table, text: table.joined(separator: "\n"))); table = [] }
        }
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if let contents = code { result.append(Block(kind: .code, text: contents.joined(separator: "\n"))); code = nil }
                else { flush(); code = [] }
            } else if code != nil { code?.append(line) }
            else if trimmed.hasPrefix("#") && trimmed.contains(" ") {
                flush(); result.append(Block(kind: .heading, text: String(trimmed.drop(while: { $0 == "#" || $0 == " " }))))
            } else if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                if !paragraph.isEmpty { flush() }
                if !trimmed.allSatisfy({ "|-: ".contains($0) }) { table.append(trimmed) }
            } else if trimmed.isEmpty { flush() }
            else {
                if !table.isEmpty { flush() }
                paragraph.append(trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") ? "• " + trimmed.dropFirst(2) : line)
            }
        }
        flush()
        if let code { result.append(Block(kind: .code, text: code.joined(separator: "\n"))) }
        return result
    }
}
