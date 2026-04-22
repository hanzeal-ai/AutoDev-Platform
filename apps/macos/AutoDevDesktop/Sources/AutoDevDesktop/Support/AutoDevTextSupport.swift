import Foundation

enum AutoDevTextSupport {
    static func value(for key: String, in lines: [String]) -> String? {
        guard let line = lines.first(where: { $0.hasPrefix("\(key)：") || $0.hasPrefix("\(key):") }) else {
            return nil
        }

        let raw: String
        if let range = line.range(of: "：") {
            raw = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let range = line.range(of: ":") {
            raw = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else {
            raw = line.trimmingCharacters(in: .whitespaces)
        }

        return raw.isEmpty ? nil : raw
    }

    static func firstValue(in lines: [String], keys: [String]) -> String? {
        for key in keys {
            if let value = value(for: key, in: lines) {
                return value
            }
        }
        return nil
    }

    static func compactItems(_ items: [String?]) -> [String] {
        items.compactMap { item in
            guard let value = item?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty,
                  value != "-"
            else {
                return nil
            }
            return value
        }
    }

    static func filteredValues(in lines: [String], keys: [String]) -> [String] {
        compactItems(keys.map { value(for: $0, in: lines) })
    }

    static func filteredArtifacts(_ artifacts: [DeliveryArtifactItem], contains keyword: String) -> [String] {
        compactItems(artifacts.map(\.name).filter { $0.localizedCaseInsensitiveContains(keyword) })
    }

    static func filteredArtifacts(_ artifacts: [DeliveryArtifactItem], containsAny keywords: [String]) -> [String] {
        let matched = artifacts.map(\.name).filter { name in
            keywords.contains { keyword in
                name.localizedCaseInsensitiveContains(keyword)
            }
        }
        return compactItems(matched)
    }
}
