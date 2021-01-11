
import Foundation

public struct Either<Output>: Parser {
    private let maxPrefixLength: Int
    private let prefixMap: [Int : [String : [Int]]]
    private let fallbackParsers: [Int]
    private let options: [InternalParser]

    private init(options: [AnyParser<Output>]) {
        self.options = options.map { $0 }
        var fallbackParsers = [Int]()
        var prefixMap = [Int : [String : [Int]]]()
        for (offset, option) in self.options.enumerated() {
            let prefixes = option.prefixes()
            guard !prefixes.isEmpty else {
                fallbackParsers.append(offset)
                continue
            }

            if prefixes.contains("") {
                fallbackParsers.append(offset)
            }

            for prefix in prefixes where !prefix.isEmpty {
                prefixMap[
                    prefix.count,
                    default: [:]
                ][
                    prefix,
                    default: []
                ].append(offset)
            }
        }
        self.maxPrefixLength = prefixMap.map(\.key).max() ?? 0
        self.fallbackParsers = fallbackParsers
        self.prefixMap = prefixMap
    }

    public init(@ParserBuilder options: () -> [AnyParser<Output>]) {
        self.init(options: options())
    }

    public var body: AnyParser<Output> {
        return neverBody()
    }
}

extension Either {

    public init<S : Sequence>(_ data: S, @ParserBuilder option: (S.Element) -> AnyParser<Output>) {
        self.init(options:  data.map { option($0) })
    }

}

extension Either: InternalParser {

    func prefixes() -> Set<String> {
        var prefixes: Set<String> = []
        for parser in options {
            let current = parser.prefixes()
            guard current != [] else { return [] }
            prefixes.formUnion(current)
        }
        return prefixes
    }

    func parse(using scanner: Scanner) throws {
        var errors = [Error]()

        scanner.enterNode()
        defer { scanner.exitNode() }

        let prefix = try scanner.prefix(maxPrefixLength)
        let options = parsers(for: prefix)

        for option in options {
            scanner.begin()
            do {
                try option.parse(using: scanner)
                try scanner.commit()
                return
            } catch {
                errors.append(error)
                try scanner.rollback()
            }
        }

        throw ParserError.failedToParseAnyCase(dueTo: errors)
    }

}

extension Either {

    func parsers(for prefix: Substring) -> [InternalParser] {
        var alreadyUsed = Set<Int>()
        var parsers = [InternalParser]()
        
        if !prefix.isEmpty {
            for numberOfCharacters in (1...prefix.count).reversed() {
                guard let map = prefixMap[numberOfCharacters],
                      let indices = map[String(prefix[prefix.startIndex..<prefix.index(prefix.startIndex, offsetBy: numberOfCharacters)])] else {

                    continue
                }

                for index in indices where !alreadyUsed.contains(index) {
                    parsers.append(options[index])
                    alreadyUsed.formUnion([index])
                }
            }
        }

        for index in fallbackParsers where !alreadyUsed.contains(index) {
            parsers.append(options[index])
            alreadyUsed.formUnion([index])
        }

        return parsers
    }

}
