import AgenticPresentation
import Difference
import Terminal

public extension AgenticExecutionTreeRenderer {
    static func render(_ layout: TreeDifferenceLayout) -> String {
        TerminalDifferenceRenderer.render(layout)
    }
}
