//
//  TodoListViewModel.swift
//  TodoListApp
//
//  RxSwift Tutorial #4 - ToDoリストアプリ
//

import RxSwift
import RxCocoa
import RxRelay

/// ToDoリストアプリの ViewModel
///
/// Input/Output パターンで実装。
/// 第3回の CounterViewModel では BehaviorRelay<Int> で単一値を管理したが、
/// 今回は BehaviorRelay<[Todo]> で配列データを管理する。
final class TodoListViewModel {

    // MARK: - Inputs（ViewからViewModelへ）

    /// Todo追加（タイトル文字列を受け取る）
    let addTodo = PublishRelay<String>()
    /// Todo完了状態の切り替え（インデックスを受け取る）
    let toggleTodo = PublishRelay<Int>()
    /// Todo削除（インデックスを受け取る）
    let deleteTodo = PublishRelay<Int>()

    // MARK: - Outputs（ViewModelからViewへ）

    /// Todoリスト - UITableViewにバインド
    let todos: Observable<[Todo]>
    /// Todoの件数テキスト（例: "3件のTodo"）
    let todoCountText: Observable<String>
    /// 未完了Todoの件数テキスト（例: "残り2件"）
    let incompleteTodoCountText: Observable<String>

    // MARK: - Private

    /// Todoリストを保持する BehaviorRelay（初期値: 空配列）
    private let todosRelay = BehaviorRelay<[Todo]>(value: [])
    private let disposeBag = DisposeBag()

    // MARK: - Initializer

    init() {
        // ============================================
        // Outputs の定義
        // ============================================

        // todosRelay をそのまま公開
        todos = todosRelay.asObservable()

        // 全件数のテキスト（map オペレーター）
        todoCountText = todosRelay
            .map { "\($0.count)件のTodo" }

        // 未完了件数のテキスト（map + filter の組み合わせ）
        incompleteTodoCountText = todosRelay
            .map { todos in
                let incompleteCount = todos.filter { !$0.isCompleted }.count
                return "残り\(incompleteCount)件"
            }

        // ============================================
        // Inputs の処理
        // ============================================

        // Todo追加: 新しいTodoを配列の先頭に追加
        addTodo
            .subscribe(onNext: { [weak self] title in
                guard let self = self else { return }
                var currentTodos = self.todosRelay.value
                let newTodo = Todo(title: title)
                currentTodos.insert(newTodo, at: 0)
                self.todosRelay.accept(currentTodos)
            })
            .disposed(by: disposeBag)

        // Todo完了切り替え: 指定インデックスの isCompleted をトグル
        toggleTodo
            .subscribe(onNext: { [weak self] index in
                guard let self = self else { return }
                var currentTodos = self.todosRelay.value
                guard index < currentTodos.count else { return }
                currentTodos[index].isCompleted.toggle()
                self.todosRelay.accept(currentTodos)
            })
            .disposed(by: disposeBag)

        // Todo削除: 指定インデックスのTodoを削除
        deleteTodo
            .subscribe(onNext: { [weak self] index in
                guard let self = self else { return }
                var currentTodos = self.todosRelay.value
                guard index < currentTodos.count else { return }
                currentTodos.remove(at: index)
                self.todosRelay.accept(currentTodos)
            })
            .disposed(by: disposeBag)
    }
}
