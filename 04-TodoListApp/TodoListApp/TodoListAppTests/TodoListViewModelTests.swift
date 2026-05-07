//
//  TodoListViewModelTests.swift
//  TodoListAppTests
//
//  RxSwift Tutorial #4 - ToDoリストアプリ
//

import XCTest
import RxSwift
import RxBlocking
@testable import TodoListApp

final class TodoListViewModelTests: XCTestCase {

    var viewModel: TodoListViewModel!
    var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()
        viewModel = TodoListViewModel()
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        viewModel = nil
        disposeBag = nil
        super.tearDown()
    }

    // MARK: - 初期値のテスト

    /// 初期状態でTodoリストが空であること
    func testInitialTodosIsEmpty() throws {
        let todos = try viewModel.todos
            .toBlocking()
            .first()

        XCTAssertEqual(todos?.count, 0)
    }

    /// 初期状態で件数テキストが "0件のTodo" であること
    func testInitialCountText() throws {
        let text = try viewModel.todoCountText
            .toBlocking()
            .first()

        XCTAssertEqual(text, "0件のTodo")
    }

    /// 初期状態で未完了件数テキストが "残り0件" であること
    func testInitialIncompleteCountText() throws {
        let text = try viewModel.incompleteTodoCountText
            .toBlocking()
            .first()

        XCTAssertEqual(text, "残り0件")
    }

    // MARK: - 追加のテスト

    /// Todoを1件追加するとリストに含まれること
    func testAddOneTodo() throws {
        viewModel.addTodo.accept("買い物に行く")

        let todos = try viewModel.todos
            .toBlocking()
            .first()

        XCTAssertEqual(todos?.count, 1)
        XCTAssertEqual(todos?.first?.title, "買い物に行く")
        XCTAssertEqual(todos?.first?.isCompleted, false)
    }

    /// 複数追加すると新しいものが先頭にあること
    func testAddMultipleTodos() throws {
        viewModel.addTodo.accept("1番目")
        viewModel.addTodo.accept("2番目")
        viewModel.addTodo.accept("3番目")

        let todos = try viewModel.todos
            .toBlocking()
            .first()

        XCTAssertEqual(todos?.count, 3)
        XCTAssertEqual(todos?[0].title, "3番目")
        XCTAssertEqual(todos?[1].title, "2番目")
        XCTAssertEqual(todos?[2].title, "1番目")
    }

    /// 追加後の件数テキストが正しいこと
    func testCountTextAfterAdd() throws {
        viewModel.addTodo.accept("Todo 1")
        viewModel.addTodo.accept("Todo 2")

        let text = try viewModel.todoCountText
            .toBlocking()
            .first()

        XCTAssertEqual(text, "2件のTodo")
    }

    // MARK: - 完了切り替えのテスト

    /// Todoの完了状態をトグルできること
    func testToggleTodo() throws {
        viewModel.addTodo.accept("テスト")
        viewModel.toggleTodo.accept(0)

        let todos = try viewModel.todos
            .toBlocking()
            .first()

        XCTAssertEqual(todos?.first?.isCompleted, true)
    }

    /// 完了→未完了に戻せること
    func testToggleTodoTwice() throws {
        viewModel.addTodo.accept("テスト")
        viewModel.toggleTodo.accept(0)
        viewModel.toggleTodo.accept(0)

        let todos = try viewModel.todos
            .toBlocking()
            .first()

        XCTAssertEqual(todos?.first?.isCompleted, false)
    }

    /// 完了切り替え後の未完了件数が正しいこと
    func testIncompleteCountAfterToggle() throws {
        viewModel.addTodo.accept("Todo 1")
        viewModel.addTodo.accept("Todo 2")
        viewModel.addTodo.accept("Todo 3")
        viewModel.toggleTodo.accept(0)

        let text = try viewModel.incompleteTodoCountText
            .toBlocking()
            .first()

        XCTAssertEqual(text, "残り2件")
    }

    // MARK: - 削除のテスト

    /// Todoを削除できること
    func testDeleteTodo() throws {
        viewModel.addTodo.accept("Todo 1")
        viewModel.addTodo.accept("Todo 2")
        viewModel.deleteTodo.accept(0)

        let todos = try viewModel.todos
            .toBlocking()
            .first()

        XCTAssertEqual(todos?.count, 1)
        XCTAssertEqual(todos?.first?.title, "Todo 1")
    }

    /// 削除後の件数テキストが正しいこと
    func testCountTextAfterDelete() throws {
        viewModel.addTodo.accept("Todo 1")
        viewModel.addTodo.accept("Todo 2")
        viewModel.deleteTodo.accept(0)

        let text = try viewModel.todoCountText
            .toBlocking()
            .first()

        XCTAssertEqual(text, "1件のTodo")
    }

    // MARK: - 範囲外インデックスのテスト

    /// 範囲外のインデックスでトグルしてもクラッシュしないこと
    func testToggleOutOfBoundsDoesNotCrash() throws {
        viewModel.addTodo.accept("テスト")
        viewModel.toggleTodo.accept(99)

        let todos = try viewModel.todos
            .toBlocking()
            .first()

        XCTAssertEqual(todos?.count, 1)
        XCTAssertEqual(todos?.first?.isCompleted, false)
    }

    /// 範囲外のインデックスで削除してもクラッシュしないこと
    func testDeleteOutOfBoundsDoesNotCrash() throws {
        viewModel.addTodo.accept("テスト")
        viewModel.deleteTodo.accept(99)

        let todos = try viewModel.todos
            .toBlocking()
            .first()

        XCTAssertEqual(todos?.count, 1)
    }

    // MARK: - 複合テスト

    /// 追加・完了・削除の複合操作テスト
    func testComplexOperations() throws {
        // 3件追加
        viewModel.addTodo.accept("Todo 1")
        viewModel.addTodo.accept("Todo 2")
        viewModel.addTodo.accept("Todo 3")

        var todos = try viewModel.todos.toBlocking().first()
        XCTAssertEqual(todos?.count, 3)

        // Todo 3（先頭）を完了
        viewModel.toggleTodo.accept(0)
        todos = try viewModel.todos.toBlocking().first()
        XCTAssertEqual(todos?[0].isCompleted, true)

        // Todo 2（index 1）を削除
        viewModel.deleteTodo.accept(1)
        todos = try viewModel.todos.toBlocking().first()
        XCTAssertEqual(todos?.count, 2)
        XCTAssertEqual(todos?[0].title, "Todo 3")
        XCTAssertEqual(todos?[1].title, "Todo 1")

        // 未完了件数の確認
        let text = try viewModel.incompleteTodoCountText.toBlocking().first()
        XCTAssertEqual(text, "残り1件")
    }
}
