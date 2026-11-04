/// App groups have the same order whether their optional divider is visible.
enum DockAppSectionOrder {
    nonisolated static func compose<Element>(running: [Element], pinned: [Element], separator: Element?) -> [Element] {
        guard !running.isEmpty else { return pinned }
        guard !pinned.isEmpty else { return running }
        return running + (separator.map { [$0] } ?? []) + pinned
    }
}
