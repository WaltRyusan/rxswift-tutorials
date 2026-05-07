//
//  Todo.swift
//  TodoListApp
//
//  RxSwift Tutorial #4 - ToDoリストアプリ
//

import Foundation

/// Todoアイテムのデータモデル
///
/// MVVMの「Model」にあたる層。
/// データの構造のみを定義し、ロジックは持たない。
struct Todo {
    /// 一意の識別子
    let id: UUID
    /// Todoのタイトル
    var title: String
    /// 完了状態
    var isCompleted: Bool

    init(title: String, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
    }
}
