//
//  NavigationHistory.swift
//  Example
//
//  导航历史记录器 —— 记录完整的导航轨迹
//

import Foundation
import MTCoordinator

struct NavigationRecord {
    enum Direction: String {
        case forward = "→"
        case backward = "←"
        case failed = "✗"
    }

    let module: Module
    let direction: Direction
    let timestamp: Date

    var description: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return "\(direction.rawValue) \(module) @ \(formatter.string(from: timestamp))"
    }
}

class NavigationHistory: ModuleCoordinatorDelegate {

    static let shared = NavigationHistory()

    private(set) var records: [NavigationRecord] = []
    var maxRecords: Int = 200

    private init() {}

    func coordinatorDidNavigate(to module: Module) {
        append(.init(module: module, direction: .forward, timestamp: Date()))
    }

    func coordinatorDidReturn(to module: Module) {
        append(.init(module: module, direction: .backward, timestamp: Date()))
    }

    func coordinatorDidFailNavigation(to module: Module, reason: String) {
        append(.init(module: module, direction: .failed, timestamp: Date()))
    }

    var lastRecord: NavigationRecord? { records.last }

    func recentRecords(_ count: Int) -> [NavigationRecord] {
        Array(records.suffix(count))
    }

    func printHistory() {
        print("📜 导航历史 (\(records.count) 条):")
        for record in records { print("  \(record.description)") }
    }

    func reset() {
        records.removeAll()
        print("📜 导航历史已清空")
    }

    private func append(_ record: NavigationRecord) {
        records.append(record)
        if records.count > maxRecords { records.removeFirst(records.count - maxRecords) }
    }
}
