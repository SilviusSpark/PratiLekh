import Foundation

/// A narrow, purpose-built scanner that finds an object's or array's
/// immediate child key/value (or element) boundaries in raw JSON text.
///
/// This exists because `JSONDecoder`/`JSONSerialization` cannot answer two
/// questions this trust boundary needs answered: whether a JSON object
/// repeats a key, and whether it contains a key outside a known set.
/// Verified empirically against this toolchain: a duplicate key is silently
/// resolved to its first occurrence before a `KeyedDecodingContainer` is
/// ever constructed, so even `container.allKeys` never reveals it.
///
/// This is deliberately NOT a general JSON parser: it never interprets a
/// value's content (numbers, escapes, booleans) beyond what is required to
/// find where that value ends -- it only tracks string/escape state and
/// bracket/brace nesting depth well enough to locate sibling boundaries.
/// All actual value decoding is left to `JSONDecoder` once these structural
/// questions are answered.
enum RawJSONObjectKeyScanner {
    struct ScanError: Error, Equatable {
        enum Kind: Equatable {
            case malformedStructure
            case duplicateKey(String)
        }

        let kind: Kind
    }

    /// One immediate child of a scanned object: its key and the raw,
    /// unparsed source text of its value.
    struct Entry: Equatable {
        let key: String
        let value: Substring
    }

    /// Returns the immediate keys of the object starting at `start`
    /// (`text[start]` must be `"{"`), each paired with its value's raw
    /// source text, in source order. Throws `.duplicateKey` if the same key
    /// appears twice at this object's own level. Never recurses into nested
    /// objects/arrays to collect further keys -- callers that need a nested
    /// object's keys validated call this again on that value's substring.
    static func scanObject(_ text: String, start: String.Index) throws -> (entries: [Entry], end: String.Index) {
        guard start < text.endIndex, text[start] == "{" else {
            throw ScanError(kind: .malformedStructure)
        }
        var index = text.index(after: start)
        var entries: [Entry] = []
        var seenKeys = Set<String>()

        self.skipInsignificantWhitespace(text, &index)
        if index < text.endIndex, text[index] == "}" {
            return (entries, text.index(after: index))
        }

        while true {
            self.skipInsignificantWhitespace(text, &index)
            guard index < text.endIndex, text[index] == "\"" else {
                throw ScanError(kind: .malformedStructure)
            }
            let keyStart = index
            index = try self.skipString(text, from: index)
            let key = String(text[text.index(after: keyStart)..<text.index(before: index)])

            self.skipInsignificantWhitespace(text, &index)
            guard index < text.endIndex, text[index] == ":" else {
                throw ScanError(kind: .malformedStructure)
            }
            index = text.index(after: index)
            self.skipInsignificantWhitespace(text, &index)

            let valueStart = index
            index = try self.skipValue(text, from: index)
            let value = text[valueStart..<index]

            guard seenKeys.insert(key).inserted else {
                throw ScanError(kind: .duplicateKey(key))
            }
            entries.append(Entry(key: key, value: value))

            self.skipInsignificantWhitespace(text, &index)
            guard index < text.endIndex else { throw ScanError(kind: .malformedStructure) }
            if text[index] == "," {
                index = text.index(after: index)
                continue
            }
            if text[index] == "}" {
                return (entries, text.index(after: index))
            }
            throw ScanError(kind: .malformedStructure)
        }
    }

    /// Returns the raw source text of each element of the array starting at
    /// `start` (`text[start]` must be `"["`), in source order.
    static func scanArrayElements(_ text: String, start: String.Index) throws -> (elements: [Substring], end: String.Index) {
        guard start < text.endIndex, text[start] == "[" else {
            throw ScanError(kind: .malformedStructure)
        }
        var index = text.index(after: start)
        var elements: [Substring] = []

        self.skipInsignificantWhitespace(text, &index)
        if index < text.endIndex, text[index] == "]" {
            return (elements, text.index(after: index))
        }

        while true {
            self.skipInsignificantWhitespace(text, &index)
            let elementStart = index
            index = try self.skipValue(text, from: index)
            elements.append(text[elementStart..<index])

            self.skipInsignificantWhitespace(text, &index)
            guard index < text.endIndex else { throw ScanError(kind: .malformedStructure) }
            if text[index] == "," {
                index = text.index(after: index)
                continue
            }
            if text[index] == "]" {
                return (elements, text.index(after: index))
            }
            throw ScanError(kind: .malformedStructure)
        }
    }

    private static func skipInsignificantWhitespace(_ text: String, _ index: inout String.Index) {
        while index < text.endIndex, text[index].isWhitespace {
            index = text.index(after: index)
        }
    }

    /// Skips a well-formed JSON string starting at its opening quote,
    /// returning the index just past the closing quote. Backslash escapes
    /// are skipped without validating legality -- this scanner only needs
    /// to find where the string ends, never to interpret its content; an
    /// illegal escape sequence is still caught later, when `JSONDecoder`
    /// actually decodes the string's value.
    private static func skipString(_ text: String, from start: String.Index) throws -> String.Index {
        var index = text.index(after: start)
        while index < text.endIndex {
            let char = text[index]
            if char == "\\" {
                index = text.index(after: index)
                guard index < text.endIndex else { throw ScanError(kind: .malformedStructure) }
                index = text.index(after: index)
                continue
            }
            if char == "\"" {
                return text.index(after: index)
            }
            index = text.index(after: index)
        }
        throw ScanError(kind: .malformedStructure)
    }

    /// Skips one well-formed JSON value (string, object, array, or a bare
    /// token such as a number/`true`/`false`/`null`) starting at its first
    /// character, returning the index just past it. Used only to locate
    /// sibling key/value or element boundaries -- never interprets the
    /// value.
    private static func skipValue(_ text: String, from start: String.Index) throws -> String.Index {
        guard start < text.endIndex else { throw ScanError(kind: .malformedStructure) }
        switch text[start] {
        case "\"":
            return try self.skipString(text, from: start)
        case "{":
            return try self.skipBalanced(text, from: start, open: "{", close: "}")
        case "[":
            return try self.skipBalanced(text, from: start, open: "[", close: "]")
        default:
            var index = start
            while index < text.endIndex, !",}]".contains(text[index]), !text[index].isWhitespace {
                index = text.index(after: index)
            }
            guard index > start else { throw ScanError(kind: .malformedStructure) }
            return index
        }
    }

    /// Skips a balanced `{...}` or `[...]` span. Counting only the one
    /// bracket type this call cares about (ignoring the other type
    /// entirely) still correctly finds the true matching close: in
    /// well-formed JSON any nested nested nested brackets, of either kind,
    /// are themselves balanced, so they never change which occurrence of
    /// *this* bracket type is the real match. String contents are skipped
    /// wholesale so a bracket character inside a string value is never
    /// mistaken for a structural one.
    private static func skipBalanced(_ text: String, from start: String.Index, open: Character, close: Character) throws -> String.Index {
        var index = text.index(after: start)
        var depth = 1
        while index < text.endIndex {
            let char = text[index]
            if char == "\"" {
                index = try self.skipString(text, from: index)
                continue
            }
            if char == open {
                depth += 1
            } else if char == close {
                depth -= 1
                if depth == 0 {
                    return text.index(after: index)
                }
            }
            index = text.index(after: index)
        }
        throw ScanError(kind: .malformedStructure)
    }
}
