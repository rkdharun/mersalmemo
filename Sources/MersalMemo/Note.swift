import Foundation

struct Note: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String       // explicit name; empty = derive from content
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(title: String = "", content: String = "") {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // Backward-compatible decode: old saved notes have no "title" key
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,   forKey: .id)
        title     = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        content   = try c.decode(String.self, forKey: .content)
        createdAt = try c.decode(Date.self,   forKey: .createdAt)
        updatedAt = try c.decode(Date.self,   forKey: .updatedAt)
    }

    // Explicit title wins; otherwise derive from first non-empty content line
    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { return t }
        let first = content.components(separatedBy: "\n")
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    var previewText: String {
        let nonEmpty = content.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard nonEmpty.count > 1 else { return "" }
        return nonEmpty.dropFirst().joined(separator: " ")
    }
}
