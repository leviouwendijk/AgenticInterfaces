/// Candidates for the end of a `:` command line, e.g. paths for
/// `path add`. ctrl-n / ctrl-p select one; Enter puts it in place of the
/// last `replacing` characters instead of running the command.
public struct AgenticCommandCompletion:
    Sendable,
    Hashable
{
    public struct Candidate:
        Sendable,
        Hashable
    {
        /// What replaces the completed text.
        public var text: String
        /// What the list shows.
        public var title: String

        public init(
            text: String,
            title: String
        ) {
            self.text = text
            self.title = title
        }
    }

    public var replacing: Int
    public var candidates: [Candidate]

    public init(
        replacing: Int,
        candidates: [Candidate]
    ) {
        self.replacing = replacing
        self.candidates = candidates
    }
}

/// Completes a command line's text, given without `:`; `nil` when the
/// command takes no completion there.
public typealias AgenticCommandCompleter = @Sendable (String) -> AgenticCommandCompletion?
