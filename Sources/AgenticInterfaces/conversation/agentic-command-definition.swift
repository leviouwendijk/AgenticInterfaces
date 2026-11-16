/// One `:` command as the interface knows it. The same definition decides
/// which command a line names, how it is dispatched, how it is completed and
/// what help says about it, so these cannot drift apart.
public struct AgenticCommandDefinition:
    Sendable,
    Hashable,
    Identifiable
{
    /// The help chapter, and the family that dispatches the command.
    public enum Chapter:
        String,
        Sendable,
        Hashable,
        CaseIterable
    {
        case workspace
        case run
        case capabilities
        case review
        case context

        public var title: String {
            switch self {
            case .workspace: "Workspace and paths"
            case .run: "Run control"
            case .capabilities: "Programs and Inferences"
            case .review: "Review and publication"
            case .context: "Context window"
            }
        }
    }

    /// What the command does to what the next model request carries.
    public enum ContextEffect:
        String,
        Sendable,
        Hashable
    {
        /// Nothing the model sees.
        case none
        /// A note opens the next turn (e.g. a workspace change).
        case note
        /// Adds a message or result to the transcript (e.g. an Inference's output).
        case transcript
        /// Changes which history the next request carries.
        case history
    }

    public enum Surface:
        String,
        Sendable,
        Hashable
    {
        /// The open conversation.
        case conversation
        /// The dashboard, acting on the conversation under the cursor.
        case dashboard
    }

    public var name: String
    public var aliases: [String]
    /// `path add <dir|file> [--read|--ask]`, one form per line.
    public var syntax: [String]
    public var summary: String
    public var chapter: Chapter
    public var surfaces: Set<Surface>
    /// The Host records the command and its effects in the session log.
    public var isTraced: Bool
    public var contextEffect: ContextEffect

    public var id: String { name }

    public init(
        name: String,
        aliases: [String] = [],
        syntax: [String],
        summary: String,
        chapter: Chapter,
        surfaces: Set<Surface> = [.conversation, .dashboard],
        isTraced: Bool = false,
        contextEffect: ContextEffect = .none
    ) {
        self.name = name
        self.aliases = aliases
        self.syntax = syntax
        self.summary = summary
        self.chapter = chapter
        self.surfaces = surfaces
        self.isTraced = isTraced
        self.contextEffect = contextEffect
    }

    /// `usage: :path add … · :path rm …`
    public var usage: String {
        "usage: " + syntax.map { ":" + $0 }.joined(separator: " · ")
    }
}

/// The commands an interface installs, in help order.
public struct AgenticCommandCatalog:
    Sendable,
    Hashable
{
    public var definitions: [AgenticCommandDefinition]

    public init(
        _ definitions: [AgenticCommandDefinition]
    ) {
        self.definitions = definitions
    }

    /// Every name and alias.
    public var names: Set<String> {
        Set(definitions.flatMap { [$0.name] + $0.aliases })
    }

    /// The definition a command line (without `:`) names by its first word.
    public func definition(
        for text: String
    ) -> AgenticCommandDefinition? {
        let word = text.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? text
        return definitions.first { $0.name == word || $0.aliases.contains(word) }
    }

    public func definitions(
        in chapter: AgenticCommandDefinition.Chapter
    ) -> [AgenticCommandDefinition] {
        definitions.filter { $0.chapter == chapter }
    }
}

/// What one `:` command did, as its entry in the conversation shows it.
public struct AgenticCommandOutcomePresentation:
    Sendable,
    Hashable,
    Identifiable
{
    public var id: String
    /// As typed, without `:`.
    public var command: String
    public var outcome: String
    public var isRefused: Bool
    public var contextEffect: AgenticCommandDefinition.ContextEffect
    /// What the Host recorded in the session log for it: `kind  summary`.
    public var trace: [String]

    public init(
        id: String,
        command: String,
        outcome: String,
        isRefused: Bool = false,
        contextEffect: AgenticCommandDefinition.ContextEffect = .none,
        trace: [String] = []
    ) {
        self.id = id
        self.command = command
        self.outcome = outcome
        self.isRefused = isRefused
        self.contextEffect = contextEffect
        self.trace = trace
    }

    /// What the model will see of it; `nil` when nothing.
    public var contextNote: String? {
        guard !isRefused else { return nil }
        switch contextEffect {
        case .none: return nil
        case .note: return "context: the next request opens with a note of this change"
        case .transcript: return "context: added to the transcript the model reads"
        case .history: return "context: changes which history the next request carries"
        }
    }

    public var transcriptTitle: String {
        (isRefused ? "refused · :" : ":") + command
    }

    public var transcriptBody: String {
        let lines = outcome.split(separator: "\n", omittingEmptySubsequences: false)
        // A long listing stays in Details.
        let shown = lines.prefix(6).joined(separator: "\n")
            + (lines.count > 6 ? "\n… \(lines.count - 6) more lines" : "")
        return ([shown] + [contextNote].compactMap { $0 }).joined(separator: "\n")
    }

    public var detailsBody: String {
        var sections = [":" + command, "", outcome]
        if let contextNote { sections += ["", contextNote] }
        sections += ["", "trace"]
        sections += trace.isEmpty ? ["  not traced by the Host"] : trace.map { "  " + $0 }
        return sections.joined(separator: "\n")
    }
}
