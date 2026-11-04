// swiftc Docky/Services/DockAppSectionOrder.swift scripts/test_dock_app_section_order.swift -o /tmp/test-dock-app-section-order
@main
struct DockAppSectionOrderTests {
    static func main() {
        let pinned = ["Finder", "pinned-browser", "pinned-editor"]
        let running = ["running-terminal", "running-notes"]
        precondition(DockAppSectionOrder.compose(running: running, pinned: pinned, separator: "divider:running")
                     == running + ["divider:running"] + pinned)
        precondition(DockAppSectionOrder.compose(running: running, pinned: pinned, separator: nil)
                     == running + pinned)
        precondition(DockAppSectionOrder.compose(running: [], pinned: pinned, separator: "divider:running") == pinned)
        precondition(DockAppSectionOrder.compose(running: running, pinned: [], separator: "divider:running") == running)
        precondition(DockAppSectionOrder.compose(running: [String](), pinned: [], separator: "divider:running").isEmpty)
        // Opening another app extends the leading block; pinned order and the
        // suffix anchored at the bottom/right remain exactly the same.
        let trailing = ["divider:trailing", "Downloads", "Trash"]
        let before = DockAppSectionOrder.compose(running: running, pinned: pinned, separator: "divider:running") + trailing
        let after = DockAppSectionOrder.compose(running: running + ["new-app"], pinned: pinned, separator: "divider:running") + trailing
        precondition(before.suffix(pinned.count + trailing.count) == after.suffix(pinned.count + trailing.count))
        precondition(after == running + ["new-app", "divider:running"] + pinned + trailing)
        print("Running-first app section order and pinned suffix stability tests passed")
    }
}
