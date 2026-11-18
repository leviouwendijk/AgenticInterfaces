import AgenticInterfaces
import Terminal

/// A narrow viewport wraps the header, long paths included, instead of
/// cropping it; notices follow the workspace line.
enum AgenticConversationHeaderSmoke {
    enum Failure: Error {
        case cropped(String), notice, transcript
    }

    static func run() throws {
        var snapshot = AgenticConversationSmoke.fixture()
        snapshot.workspace = "/Users/someone/main/programming/libraries/swiftlibs/AgenticHost"
        snapshot.notices = ["settings.frame is behind template 2; agentic settings-modernize"]
        snapshot.messages = [.init(id: "first", role: .user, body: "First message")]
        var control = AgenticConversationControl(snapshot: snapshot)
        let columns = 24
        var frame = TerminalFrame(rows: 30, columns: columns)
        control.render(into: &frame, in: TerminalRegion(rows: 30, columns: columns))

        let spans = frame.spans
            .sorted { ($0.row, $0.leading) < ($1.row, $1.leading) }
            .map { (row: $0.row, text: plain($0.content)) }
        guard let transcriptRow = spans.first(where: { $0.text.contains("First message") })?.row else {
            throw Failure.transcript
        }
        let header = spans.filter { $0.row < transcriptRow }.map(\.text)
        for line in header where line.count > columns {
            throw Failure.cropped(line)
        }
        let joined = header.joined()
        guard joined.contains(snapshot.workspace) else { throw Failure.cropped(snapshot.workspace) }
        guard joined.replacingOccurrences(of: " ", with: "")
            .contains(snapshot.notices[0].replacingOccurrences(of: " ", with: "")) else { throw Failure.notice }
    }

    static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{1B}\\[[0-9;]*[A-Za-z]", with: "", options: .regularExpression)
    }
}
