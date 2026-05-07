---
title: "【RxSwift入門】④ToDoリストアプリで配列データを管理する"
emoji: "✅"
type: "tech"
topics: ["iOS", "Swift", "MVVM", "RxSwift", "RxCocoa"]
published: false
---

## はじめに

第3回では、カウンターアプリを通じてMVVMの基礎とInput/Outputパターンを学びました。
しかし、カウンターアプリで管理していたのは **たった1つのInt値** です。

実際のアプリでは、**配列データ**（ユーザーリスト、商品一覧、メッセージ履歴など）を扱うことがほとんどです。
今回は **ToDoリストアプリ** を作りながら、配列データの管理とUITableViewとの連携を学びます。

:::message
📂 **サンプルコード**
この記事で使用しているコードの完全版は[GitHubリポジトリ](https://github.com/RyuzoHiruma-jinjer/rxswift-tutorials/tree/main/04-TodoListApp)で公開しています。
:::

## この記事で学ぶこと

| No | トピック | 内容 |
| ---- | ---- | ---- |
| 1 | Modelの定義 | 構造体でデータモデルを作る（MVVMの"M"） |
| 2 | BehaviorRelay<[T]> | 配列データのリアクティブな管理 |
| 3 | UITableView × RxSwift | rx.items, rx.itemSelected, rx.itemDeleted |
| 4 | 新しいOperator | filter, withLatestFrom |
| 5 | ViewModelのテスト | 配列操作の単体テスト |

## 前提知識

この記事は **第1回〜第3回** を読んだ前提で進めます。

| 用語 | 日本語訳 | RxSwiftでの概念 |
| ---- | ---- | ---- |
| Observable | 観察可能な | イベントを発行するストリームを表現する型 |
| PublishRelay | 公開中継器 | 初期値を持たず、エラーを流さないSubject |
| BehaviorRelay | 振る舞い中継器 | 現在の値を保持し、エラーを流さないSubject |
| bind(to:) | バインド | ObservableとUIを一方向で接続するメソッド |
| map | 変換 | 流れてきた値を別の値に変換するOperator |
| DisposeBag | 破棄袋 | 複数の購読をまとめて管理する |

まだ読んでいない方は、[第1回の記事](https://zenn.dev/jinjer_techblog/articles/61ce0010c646b3)から始めることをおすすめします。

---

# 1. 前回の振り返りと今回のゴール

## 1-1. 第3回と第4回の違い

```
第3回（カウンター）: BehaviorRelay<Int>     →  単一の値を管理
第4回（Todoリスト）: BehaviorRelay<[Todo]>  →  配列データを管理
```

| | 第3回 (カウンター) | 第4回 (Todoリスト) |
| ---- | ---- | ---- |
| データ | `BehaviorRelay<Int>` | `BehaviorRelay<[Todo]>` |
| UI | UILabel + UIButton | UITableView + UITextField |
| Model | なし（Intのみ） | Todo構造体 |
| Operator | map | map, filter, withLatestFrom |

## 1-2. 完成イメージ

```
┌──────────────────────────┐
│  Todoリスト         　    │ ← ナビゲーションバー
├──────────────────────────┤
│ [新しいTodoを入力  ] [追加]│ ← テキスト入力 + ボタン
├──────────────────────────┤
│  残り2件                  │ ← 未完了件数
├──────────────────────────┤
│ ☐ 牛乳を買う              │ ← 未完了Todo
│ ☐ レポートを書く           │ ← 未完了Todo
│ ✓ 部屋を掃除する      ✓   │ ← 完了Todo（取り消し線）
└──────────────────────────┘
```

- テキストフィールドにタイトルを入力して「追加」
- セルをタップすると完了/未完了を切り替え
- セルを左スワイプで削除

---

# 2. プロジェクトのセットアップ

## 2-1. プロジェクトを開く

```bash
cd rxswift-tutorials
open 04-TodoListApp/TodoListApp/TodoListApp.xcodeproj
```

## 2-2. SPMの依存関係

第3回と同じライブラリを使用します。

| ライブラリ | 用途 | ターゲット |
| ---- | ---- | ---- |
| **RxSwift** | Observable、Subject などの基本機能 | TodoListApp |
| **RxCocoa** | UIKit とのバインディング | TodoListApp |
| **RxRelay** | PublishRelay、BehaviorRelay | TodoListApp |
| **RxBlocking** | テスト用（同期的に値を取得） | TodoListAppTests |

## 2-3. プロジェクト構成

```
TodoListApp/
├── AppDelegate.swift
├── SceneDelegate.swift
├── Models/                          # ← NEW! MVVMの"M"
│   └── Todo.swift
├── ViewModels/
│   └── TodoListViewModel.swift
├── Views/
│   └── TodoListViewController.swift # ← プログラマティックUI
├── Assets.xcassets/
└── TodoListApp.entitlements
```

:::message
💡 **ポイント: Modelsフォルダの追加**
第3回ではModelファイルがありませんでした（カウンターのデータはただのIntだったため）。
今回から **MVVMの"M"（Model）** が独立したファイルになります。
:::

---

# 3. Modelを定義する

## 3-1. Todo構造体

```swift
import Foundation

struct Todo {
    let id: UUID
    var title: String
    var isCompleted: Bool

    init(title: String, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.isCompleted = isCompleted
    }
}
```

| プロパティ | 型 | 説明 |
| ---- | ---- | ---- |
| `id` | `UUID` | 一意の識別子（`let` = 変更不可） |
| `title` | `String` | Todoのタイトル（`var` = 変更可能） |
| `isCompleted` | `Bool` | 完了状態（`var` = 変更可能） |

:::message
💡 **let vs var の使い分け**
`id` は一度決まったら変わらないので `let`。
`title` と `isCompleted` は後から変更する可能性があるので `var`。
この使い分けがデータの安全性を高めます。
:::

---

# 4. ViewModelを作る（配列データの管理）

## 4-1. BehaviorRelay\<[Todo]> とは

第3回では `BehaviorRelay<Int>` で単一の値を管理しました。
今回は **`BehaviorRelay<[Todo]>`** で配列を管理します。

```swift
// 第3回: 単一の値
let countRelay = BehaviorRelay<Int>(value: 0)

// 第4回: 配列データ
let todosRelay = BehaviorRelay<[Todo]>(value: [])
```

配列への操作パターン：

```swift
// 現在の値を取得
var current = todosRelay.value

// 追加
current.insert(newTodo, at: 0)

// 変更
current[index].isCompleted.toggle()

// 削除
current.remove(at: index)

// 更新を反映
todosRelay.accept(current)
```

:::message
💡 **配列操作のポイント**
BehaviorRelayの `value` は読み取り専用です。
配列を変更するには、一度 `var` にコピーし、操作してから `accept()` で反映します。
:::

## 4-2. Input/Outputの設計

```
┌──────────────────────────────────────────────────────┐
│              TodoListViewModel                        │
│                                                       │
│  【Input】                  【Output】                │
│  addTodo(String)    ──→     todos: Observable<[Todo]>  │
│  toggleTodo(Int)    ──→     todoCountText              │
│  deleteTodo(Int)    ──→     incompleteTodoCountText    │
│                                                       │
│  【Private】                                          │
│  todosRelay = BehaviorRelay<[Todo]>(value: [])        │
└──────────────────────────────────────────────────────┘
```

| 分類 | 名前 | 型 | 役割 |
| ---- | ---- | ---- | ---- |
| Input | addTodo | `PublishRelay<String>` | Todoタイトルを受け取り追加 |
| Input | toggleTodo | `PublishRelay<Int>` | インデックスの完了状態をトグル |
| Input | deleteTodo | `PublishRelay<Int>` | インデックスのTodoを削除 |
| Output | todos | `Observable<[Todo]>` | Todoリスト全体 |
| Output | todoCountText | `Observable<String>` | "3件のTodo" |
| Output | incompleteTodoCountText | `Observable<String>` | "残り2件" |

## 4-3. TodoListViewModel の実装

```swift
import RxSwift
import RxCocoa
import RxRelay

final class TodoListViewModel {

    // MARK: - Inputs（ViewからViewModelへ）
    let addTodo = PublishRelay<String>()
    let toggleTodo = PublishRelay<Int>()
    let deleteTodo = PublishRelay<Int>()

    // MARK: - Outputs（ViewModelからViewへ）
    let todos: Observable<[Todo]>
    let todoCountText: Observable<String>
    let incompleteTodoCountText: Observable<String>

    // MARK: - Private
    private let todosRelay = BehaviorRelay<[Todo]>(value: [])
    private let disposeBag = DisposeBag()

    init() {
        // ============================================
        // Outputs の定義
        // ============================================

        todos = todosRelay.asObservable()

        // 全件数テキスト（map）
        todoCountText = todosRelay
            .map { "\($0.count)件のTodo" }

        // 未完了件数テキスト（map + filter）
        incompleteTodoCountText = todosRelay
            .map { todos in
                let incompleteCount = todos.filter { !$0.isCompleted }.count
                return "残り\(incompleteCount)件"
            }

        // ============================================
        // Inputs の処理
        // ============================================

        // Todo追加: 配列の先頭に挿入
        addTodo
            .subscribe(onNext: { [weak self] title in
                guard let self = self else { return }
                var currentTodos = self.todosRelay.value
                let newTodo = Todo(title: title)
                currentTodos.insert(newTodo, at: 0)
                self.todosRelay.accept(currentTodos)
            })
            .disposed(by: disposeBag)

        // Todo完了切り替え
        toggleTodo
            .subscribe(onNext: { [weak self] index in
                guard let self = self else { return }
                var currentTodos = self.todosRelay.value
                guard index < currentTodos.count else { return }
                currentTodos[index].isCompleted.toggle()
                self.todosRelay.accept(currentTodos)
            })
            .disposed(by: disposeBag)

        // Todo削除
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
```

## 4-4. 新しいOperator: filter

`filter` は、**条件に合う要素だけを残す** Operatorです。

```swift
// 配列の filter（Swift標準）
let todos = [Todo(完了), Todo(未完了), Todo(完了)]
let incomplete = todos.filter { !$0.isCompleted }
// → [Todo(未完了)] だけが残る

// ViewModelでの使用例
incompleteTodoCountText = todosRelay
    .map { todos in
        let incompleteCount = todos.filter { !$0.isCompleted }.count
        return "残り\(incompleteCount)件"
    }
```

```
todosRelay: [Todo✓, Todo☐, Todo✓, Todo☐]
                    ↓ filter { !$0.isCompleted }
              [Todo☐, Todo☐]
                    ↓ .count
                    2
                    ↓ map
              "残り2件"
```

## 4-5. データフロー

**Todo追加の流れ:**

```
① addTodo に "牛乳を買う" が流れる（Input）
   ↓
② subscribe で受け取り、todosRelay の配列先頭に挿入
   ↓
③ todosRelay の値が変わる（[] → [Todo("牛乳を買う")]）
   ↓
④ todos（Output）が反応 → テーブルビューが自動更新
⑤ todoCountText が反応 → "1件のTodo"
⑥ incompleteTodoCountText が反応 → "残り1件"
```

---

# 5. ViewControllerを作る（UITableView × RxSwift）

## 5-1. 従来のUITableView vs RxSwift

```
【従来の方法】
- UITableViewDataSource（numberOfRows, cellForRow）
- UITableViewDelegate（didSelectRow）
- 手動で tableView.reloadData()
- delegateの設定が必要

【RxSwiftの方法】
- tableView.rx.items ← Observable<[T]> をバインド
- tableView.rx.itemSelected ← タップイベント
- tableView.rx.itemDeleted ← スワイプ削除
- 自動でUI更新（reloadData不要！）
```

| 機能 | 従来 | RxSwift |
| ---- | ---- | ---- |
| セル表示 | `cellForRowAt` | `rx.items` |
| セル数 | `numberOfRowsInSection` | 自動 |
| タップ | `didSelectRowAt` | `rx.itemSelected` |
| 削除 | `commit editingStyle` | `rx.itemDeleted` |
| UI更新 | `reloadData()` | 自動 |

## 5-2. 新しいOperator: withLatestFrom

`withLatestFrom` は、**あるイベントが発生した瞬間に、別のObservableの最新値を取得する** Operatorです。

```swift
// ボタンタップの瞬間に、テキストフィールドの値を取得
addButton.rx.tap                              // Observable<Void>
    .withLatestFrom(textField.rx.text.orEmpty) // Observable<String>
    .filter { !$0.isEmpty }                    // 空文字を除外
    .bind(to: viewModel.addTodo)
    .disposed(by: disposeBag)
```

```
addButton.rx.tap:         ──tap──────tap──────tap──→
                              ↓          ↓          ↓
textField.rx.text:  "牛" → "牛乳" → "牛乳を買う" → ""
                              ↓          ↓          ↓
withLatestFrom:          "牛乳"  "牛乳を買う"      ""
                              ↓          ↓          ↓
filter(!isEmpty):        "牛乳"  "牛乳を買う"     (除外)
```

:::message
💡 **withLatestFrom vs combineLatest**
- `withLatestFrom`: **片方のイベント時** にもう片方の最新値を取得（ボタンタップ時にテキスト取得）
- `combineLatest`: **どちらかが変化するたび** に両方の最新値を組み合わせる

今回のケースでは、テキストが変わるたびではなく **ボタンタップ時だけ** テキストが必要なので `withLatestFrom` が最適です。
:::

## 5-3. TodoListViewController の実装

```swift
import UIKit
import RxSwift
import RxCocoa

final class TodoListViewController: UIViewController {

    // MARK: - UI Components
    private let textField: UITextField = { /* ... */ }()
    private let addButton: UIButton = { /* ... */ }()
    private let countLabel: UILabel = { /* ... */ }()
    private let tableView: UITableView = { /* ... */ }()

    // MARK: - Properties
    private let viewModel = TodoListViewModel()
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bind()
    }

    // MARK: - Binding
    private func bind() {
        // ============================================
        // Input: UIイベント → ViewModel
        // ============================================

        // 追加ボタン → withLatestFrom でテキスト取得 → filter で空文字除外
        addButton.rx.tap
            .withLatestFrom(textField.rx.text.orEmpty)
            .filter { !$0.isEmpty }
            .bind(to: viewModel.addTodo)
            .disposed(by: disposeBag)

        // 追加後にテキストフィールドをクリア
        addButton.rx.tap
            .withLatestFrom(textField.rx.text.orEmpty)
            .filter { !$0.isEmpty }
            .subscribe(onNext: { [weak self] _ in
                self?.textField.text = ""
                self?.textField.sendActions(for: .valueChanged)
            })
            .disposed(by: disposeBag)

        // テキストが空なら追加ボタンを無効に
        textField.rx.text.orEmpty
            .map { !$0.isEmpty }
            .bind(to: addButton.rx.isEnabled)
            .disposed(by: disposeBag)

        // セルタップ → 完了切り替え
        tableView.rx.itemSelected
            .map { $0.row }
            .bind(to: viewModel.toggleTodo)
            .disposed(by: disposeBag)

        // スワイプ削除
        tableView.rx.itemDeleted
            .map { $0.row }
            .bind(to: viewModel.deleteTodo)
            .disposed(by: disposeBag)

        // ============================================
        // Output: ViewModel → UI
        // ============================================

        // Todoリスト → テーブルビュー
        viewModel.todos
            .bind(to: tableView.rx.items(
                cellIdentifier: "TodoCell",
                cellType: UITableViewCell.self
            )) { _, todo, cell in
                var content = cell.defaultContentConfiguration()
                content.text = todo.title

                if todo.isCompleted {
                    let attributed = NSAttributedString(
                        string: todo.title,
                        attributes: [
                            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                            .foregroundColor: UIColor.secondaryLabel
                        ]
                    )
                    content.attributedText = attributed
                    cell.accessoryType = .checkmark
                } else {
                    content.textProperties.color = .label
                    cell.accessoryType = .none
                }

                cell.contentConfiguration = content
            }
            .disposed(by: disposeBag)

        // 未完了件数 → ラベル
        viewModel.incompleteTodoCountText
            .bind(to: countLabel.rx.text)
            .disposed(by: disposeBag)
    }
}
```

## 5-4. バインディングの全体図

```
┌─── TodoListViewController ──────┐    ┌─── TodoListViewModel ───┐
│                                  │    │                          │
│ [追加ボタン].rx.tap              │    │                          │
│   + withLatestFrom(テキスト)     │    │                          │
│   + filter(!isEmpty)   ──bind──→ │ →  │  addTodo                 │
│                                  │    │                          │
│ tableView.rx.itemSelected        │    │                          │
│   .map { $0.row }      ──bind──→ │ →  │  toggleTodo              │
│                                  │    │                          │
│ tableView.rx.itemDeleted         │    │                          │
│   .map { $0.row }      ──bind──→ │ →  │  deleteTodo              │
│                                  │    │                          │
│ tableView.rx.items ←────bind──── │ ←  │  todos                   │
│ countLabel.rx.text ←────bind──── │ ←  │  incompleteTodoCountText │
│                                  │    │                          │
└──────────────────────────────────┘    └──────────────────────────┘
```

---

# 6. テストを書く

## 6-1. テストパターン

| テスト名 | Input | 期待するOutput |
| ---- | ---- | ---- |
| 初期値は空 | なし | todos.count = 0 |
| 1件追加 | addTodo("買い物") | todos.count = 1, title = "買い物" |
| 複数追加で順序確認 | 3件追加 | 新しいものが先頭 |
| 件数テキスト | 2件追加 | "2件のTodo" |
| 完了トグル | add → toggle(0) | isCompleted = true |
| 完了→未完了 | toggle × 2 | isCompleted = false |
| 未完了件数 | 3件追加, 1件完了 | "残り2件" |
| 削除 | 2件追加, delete(0) | 1件残る |
| 範囲外トグル | toggle(99) | クラッシュしない |
| 範囲外削除 | delete(99) | クラッシュしない |
| 複合操作 | 追加→完了→削除 | 正しい状態 |

## 6-2. テストコード（抜粋）

```swift
import XCTest
import RxSwift
import RxBlocking
@testable import TodoListApp

final class TodoListViewModelTests: XCTestCase {

    var viewModel: TodoListViewModel!

    override func setUp() {
        super.setUp()
        viewModel = TodoListViewModel()
    }

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

        XCTAssertEqual(todos?[0].title, "3番目")
        XCTAssertEqual(todos?[2].title, "1番目")
    }

    /// 完了切り替え後の未完了件数が正しいこと
    func testIncompleteCountAfterToggle() throws {
        viewModel.addTodo.accept("Todo 1")
        viewModel.addTodo.accept("Todo 2")
        viewModel.addTodo.accept("Todo 3")
        viewModel.toggleTodo.accept(0) // 先頭を完了に

        let text = try viewModel.incompleteTodoCountText
            .toBlocking()
            .first()

        XCTAssertEqual(text, "残り2件")
    }

    /// 範囲外のインデックスでクラッシュしないこと
    func testToggleOutOfBoundsDoesNotCrash() throws {
        viewModel.addTodo.accept("テスト")
        viewModel.toggleTodo.accept(99)

        let todos = try viewModel.todos
            .toBlocking()
            .first()

        XCTAssertEqual(todos?.first?.isCompleted, false)
    }
}
```

## 6-3. テスト実行結果

Xcode で `Cmd + U` を押すと、すべてのテストが実行されます。

```
Test Suite 'TodoListViewModelTests' started
✅ testInitialTodosIsEmpty
✅ testInitialCountText
✅ testInitialIncompleteCountText
✅ testAddOneTodo
✅ testAddMultipleTodos
✅ testCountTextAfterAdd
✅ testToggleTodo
✅ testToggleTodoTwice
✅ testIncompleteCountAfterToggle
✅ testDeleteTodo
✅ testCountTextAfterDelete
✅ testToggleOutOfBoundsDoesNotCrash
✅ testDeleteOutOfBoundsDoesNotCrash
Test Suite 'TodoListViewModelTests' passed (13 tests)
```

---

# 7. まとめ

## 7-1. 学んだこと

### 配列データの管理

```swift
// BehaviorRelay<[Todo]> で配列を管理
let todosRelay = BehaviorRelay<[Todo]>(value: [])

// 変更するには: 取得 → 操作 → accept
var current = todosRelay.value
current.insert(newTodo, at: 0)
todosRelay.accept(current)
```

### UITableView × RxSwift

```swift
// データバインディング（cellForRowAt の代わり）
viewModel.todos
    .bind(to: tableView.rx.items(...))

// タップ（didSelectRowAt の代わり）
tableView.rx.itemSelected
    .map { $0.row }
    .bind(to: viewModel.toggleTodo)

// 削除（commit editingStyle の代わり）
tableView.rx.itemDeleted
    .map { $0.row }
    .bind(to: viewModel.deleteTodo)
```

### 新しいOperator

```swift
// filter: 条件に合う要素だけを残す
todos.filter { !$0.isCompleted }

// withLatestFrom: イベント発生時に別の最新値を取得
addButton.rx.tap
    .withLatestFrom(textField.rx.text.orEmpty)
```

## 7-2. 第3回 vs 第4回 比較

| | 第3回 (カウンター) | 第4回 (Todoリスト) |
| ---- | ---- | ---- |
| データ | `BehaviorRelay<Int>` | `BehaviorRelay<[Todo]>` |
| UI | UILabel + UIButton (Xib) | UITableView + UITextField (プログラマティック) |
| Model | なし | Todo構造体 |
| Operator | map | map, filter, withLatestFrom |
| テスト数 | 9件 | 13件 |

---

## 次回予告

次回（第5回）は **検索アプリ** を作ります。

今回のTodoリストはローカルデータのみでしたが、次回は **API通信** を組み合わせます。

学ぶ内容：
- **API通信 × RxSwift** - URLSession をリアクティブに使う
- **debounce** - 入力のたびにAPIを叩かないようにする
- **flatMapLatest** - 古いリクエストを自動キャンセルする
- **Scheduler** - メインスレッドとバックグラウンドスレッドの使い分け

お楽しみに！

---

## 🔗 関連リンク

- [第1回: Observable、Subject、Disposableを理解する](https://zenn.dev/jinjer_techblog/articles/61ce0010c646b3)
- [第2回: ジェネリクス&エクステンションを理解する](記事URL)
- [第3回: カウンターアプリでMVVMを学ぶ](記事URL)
- [GitHubリポジトリ](https://github.com/RyuzoHiruma-jinjer/rxswift-tutorials)
- [RxSwift公式ドキュメント](http://reactivex.io/)
- [RxSwift GitHub](https://github.com/ReactiveX/RxSwift)
