/// How strongly something asks for attention. The interface picks the style;
/// `SurfaceTone` replaces this once Surface's elements land.
public enum AgenticTone:
    String,
    Sendable,
    Codable,
    Hashable
{
    case neutral
    case active
    case success
    case warning
    case failure
}
