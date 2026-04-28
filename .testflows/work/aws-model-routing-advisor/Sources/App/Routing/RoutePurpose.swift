public enum RoutePurpose: String, Sendable, Codable, Hashable {
    case executor
    case advisor
    case reviewer
    case coder
    case summarizer
    case classifier
    case extractor
}