---
title: "【RxSwift入門】③カウンターアプリでMVVMを学ぶ"
emoji: "🔢"
type: "tech"
topics: ["iOS", "Swift", "MVVM", "RxSwift", "RxCocoa"]
published: false
---

## はじめに

第1回・第2回ではPlaygroundを使ってRxSwiftの基礎概念とジェネリクス・エクステンションを学びました。
今回からは **実際にアプリを作りながら** RxSwiftを学んでいきます。

この第3回では、シンプルな **カウンターアプリ** を題材に、以下を身につけます：

- **MVVM**（Model-View-ViewModel）アーキテクチャの基礎
- **RxCocoa** を使ったUIバインディング
- **Input/Output パターン** によるViewModelの設計
- **XCTest + RxBlocking** を使ったViewModelの単体テスト

:::message
📂 **サンプルコード**
この記事で使用しているコードの完全版は[GitHubリポジトリ](https://github.com/WaltRyusan/rxswift-tutorials/tree/main/03-CounterApp)で公開しています。
:::

## この記事で学ぶこと

| No | トピック | 内容 |
|----|---------|------|
| 1 | MVVMアーキテクチャ | View / ViewModel / Model の役割分担 |
| 2 | RxCocoa の基礎 | `rx.tap`、`bind(to:)` でUIとロジックを接続 |
| 3 | Input/Output パターン | ViewModelの入力と出力を明確に分離する設計 |
| 4 | Operator の活用 | `map` でデータを変換する |
| 5 | テストの書き方 | RxBlocking で ViewModel を単体テスト |

## 前提知識

この記事は **第1回・第2回** を読んだ前提で進めます。
以下の概念を理解していることが前提です：

- **Observable** - 時間とともに流れるイベント
- **Subject / Relay** - 値を手動で流せる Observable
- **Disposable / DisposeBag** - メモリ管理
- **Observable\<T>** - ジェネリクスによる型安全性
- **.rx** - Reactive Extension の仕組み

まだ読んでいない方は、[第1回の記事](https://zenn.dev/jinjer_techblog/articles/61ce0010c646b3)から始めることをおすすめします。

---

# 1. MVVMアーキテクチャとは

## 1-1. なぜMVVMが必要なのか

学習過程や小規模な開発では、ViewControllerにすべてのコードをまとめて書くことがあります。
シンプルな画面ではこのアプローチでも十分ですが、プロジェクトが大きくなるにつれて課題が生じることがあります。

```swift
// 従来の手法: ViewControllerにロジックをまとめた例
class CounterViewController: UIViewController {
    var count = 0  // データ

    @IBAction func incrementTapped(_ sender: UIButton) {
        count += 1                              // ロジック
        countLabel.text = "\(count)"            // UI更新
        decrementButton.isEnabled = count > 0   // UI制御
    }
}
```

プロジェクトの規模が大きくなると、以下のような課題が生じやすくなります：

| 課題 | 説明 |
|------|------|
| テストが困難 | UIに依存しているためViewControllerを丸ごと生成する必要がある |
| 責務が混在 | データ管理、ロジック、UI更新がすべて同じ場所にある |
| 拡張が困難 | 機能追加のたびにViewControllerが肥大化する |

## 1-2. MVVMの構造

MVVMは、アプリの構造を **3つの層** に分離するアーキテクチャパターンです。

```
┌─────────────────┐
│      View        │  UIViewController + Xib
│   （画面表示）    │  ・ボタンタップをViewModelに伝える
│                  │  ・ViewModelのデータをUIに反映
└────────┬─────────┘
         │ rx.tap / bind(to:)
         ↓
┌─────────────────┐
│    ViewModel     │  ビジネスロジック
│  （データ処理）   │  ・Inputを受け取る（PublishRelay）
│                  │  ・Outputを流す（Observable）
└────────┬─────────┘
         │
         ↓
┌─────────────────┐
│      Model       │  データ構造
│    （データ）     │  ・構造体やクラス
└─────────────────┘
```

| 層 | 役割 | 今回の実装 |
|----|------|-----------|
| **View** | UIの表示とユーザー操作の受付 | `CounterViewController` + Xib |
| **ViewModel** | ビジネスロジック、データの加工 | `CounterViewModel` |
| **Model** | データ構造 | （今回はシンプルなIntのみ） |

## 1-3. MVVMの最大のメリット：テスト容易性

MVVMの最大のメリットは **ViewModelを単体でテストできる** ことです。

```
【テスト対象】
                    ┌──────────────┐
Input（テストから） → │  ViewModel   │ → Output（テストで検証）
                    └──────────────┘
※ UIに一切依存しない！
```

ViewModelはUIを知らないので、テストコードから直接 Input を送り、Output を検証できます。
これが、すべてをViewControllerに書く方法との決定的な違いです。

---

# 2. プロジェクトのセットアップ

## 2-1. プロジェクトを開く

```bash
cd rxswift-tutorials
open 03-CounterApp/CounterApp/CounterApp.xcodeproj
```

## 2-2. SPMの依存関係

プロジェクトを開くと、Swift Package Managerが自動的にRxSwiftをダウンロードします。
初回は少し時間がかかります。

使用するライブラリ：

| ライブラリ | 用途 | ターゲット |
|-----------|------|-----------|
| **RxSwift** | Observable、Subject などの基本機能 | CounterApp |
| **RxCocoa** | UIKit とのバインディング（rx.tap, rx.text） | CounterApp |
| **RxRelay** | PublishRelay、BehaviorRelay | CounterApp |
| **RxBlocking** | テスト用（Observableの値を同期的に取得） | CounterAppTests |

## 2-3. プロジェクト構成

```
CounterApp/
├── AppDelegate.swift          # アプリの起動処理
├── SceneDelegate.swift        # 画面の初期化
├── ViewModels/
│   └── CounterViewModel.swift # ← ビジネスロジック
├── Views/
│   ├── CounterViewController.swift  # ← UI表示
│   └── CounterViewController.xib    # ← レイアウト
├── Assets.xcassets/
└── CounterApp.entitlements
```

:::message
💡 **ポイント**
ViewModelとViewを別フォルダに分けることで、責務の分離が視覚的にも明確になります。
:::

---

# 3. ViewModelを作る（Input/Outputパターン）

## 3-1. Input/Outputパターンとは

ViewModelの設計で最も重要なのは、**入力（Input）と出力（Output）を明確に分離する** ことです。

```
┌──────────────────────────────────────────────────┐
│                CounterViewModel                   │
│                                                   │
│  【Input】              【Output】                │
│  incrementTapped ──→    countText: Observable      │
│  decrementTapped ──→    isDecrementEnabled         │
│  resetTapped     ──→                              │
│                                                   │
│  【Private】                                      │
│  countRelay = BehaviorRelay<Int>(value: 0)        │
└──────────────────────────────────────────────────┘
```

| 分類 | 型 | 役割 |
|------|----|------|
| **Input** | `PublishRelay<Void>` | Viewからのイベントを受け取る |
| **Output** | `Observable<T>` | Viewに表示するデータを流す |
| **Private** | `BehaviorRelay<T>` | 内部で状態を保持する |

### なぜ PublishRelay を Input に使うのか？

- **Relay** はエラーを流さない → UIイベントにエラーは不要
- **Publish** は初期値がない → ボタンタップには初期値が不要
- `.accept()` で外部から値を流せる → テストからも使える

### なぜ BehaviorRelay を Private に使うのか？

- **Behavior** は現在の値を保持する → カウント値を記憶
- `.value` で現在値を参照できる → ロジックで便利
- `.accept()` で更新できる → 状態の変更が簡単

## 3-2. CounterViewModel の実装

```swift
import RxSwift
import RxCocoa
import RxRelay

final class CounterViewModel {

    // MARK: - Inputs（ViewからViewModelへ）
    let incrementTapped = PublishRelay<Void>()
    let decrementTapped = PublishRelay<Void>()
    let resetTapped = PublishRelay<Void>()

    // MARK: - Outputs（ViewModelからViewへ）
    let countText: Observable<String>
    let isDecrementEnabled: Observable<Bool>

    // MARK: - Private
    private let countRelay = BehaviorRelay<Int>(value: 0)
    private let disposeBag = DisposeBag()

    init() {
        // ============================================
        // Outputs の定義
        // ============================================

        // Int → String に変換（map オペレーター）
        countText = countRelay
            .map { "\($0)" }

        // 0より大きいときだけ−ボタンを有効にする
        isDecrementEnabled = countRelay
            .map { $0 > 0 }

        // ============================================
        // Inputs の処理
        // ============================================

        // +ボタン: カウントを+1
        incrementTapped
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                self.countRelay.accept(self.countRelay.value + 1)
            })
            .disposed(by: disposeBag)

        // −ボタン: カウントを-1（0未満にはならない）
        decrementTapped
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                let newValue = max(0, self.countRelay.value - 1)
                self.countRelay.accept(newValue)
            })
            .disposed(by: disposeBag)

        // Resetボタン: カウントを0にリセット
        resetTapped
            .subscribe(onNext: { [weak self] in
                self?.countRelay.accept(0)
            })
            .disposed(by: disposeBag)
    }
}
```

## 3-3. コードの流れを追う

+ボタンがタップされたときの流れを見てみましょう：

```
① incrementTapped に Void が流れる（Input）
   ↓
② subscribe で受け取り、countRelay の値を +1
   ↓
③ countRelay の値が変わる（1 → 2 など）
   ↓
④ countText = countRelay.map { "\($0)" } が反応
   ↓
⑤ countText から "2" が流れる（Output）
   ↓
⑥ View側で countLabel.rx.text にバインドされている
   ↓
⑦ ラベルが "2" に更新される
```

:::message
💡 **map オペレーター**
`map` は、流れてきた値を別の値に変換するオペレーターです。
ここでは `Int → String` の変換に使っています。
```swift
countRelay.map { "\($0)" }
// 0 → "0"
// 1 → "1"
// 42 → "42"
```
:::

---

# 4. ViewControllerを作る（RxCocoaバインディング）

## 4-1. RxCocoa とは

第2回で学んだ **Reactive Extension**（.rx）の仕組みを覚えていますか？
RxCocoa は、UIKit のコンポーネントに `.rx` プロパティを追加するライブラリです。

```swift
// RxCocoaが提供する主な拡張
button.rx.tap        // UIButton のタップイベント → Observable<Void>
label.rx.text        // UILabel のテキスト ← Observable<String?>
textField.rx.text    // UITextField のテキスト ↔ Observable<String?>
switch.rx.isOn       // UISwitch の状態 ↔ Observable<Bool>
```

これにより、**UIイベントをObservableとして扱える**ようになります。

## 4-2. CounterViewController の実装

```swift
import UIKit
import RxSwift
import RxCocoa

final class CounterViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet private weak var countLabel: UILabel!
    @IBOutlet private weak var incrementButton: UIButton!
    @IBOutlet private weak var decrementButton: UIButton!
    @IBOutlet private weak var resetButton: UIButton!

    // MARK: - Properties
    private let viewModel = CounterViewModel()
    private let disposeBag = DisposeBag()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        bind()
    }

    // MARK: - Binding
    private func bind() {
        // ============================================
        // Input: ボタンタップをViewModelに伝える
        // ============================================
        incrementButton.rx.tap
            .bind(to: viewModel.incrementTapped)
            .disposed(by: disposeBag)

        decrementButton.rx.tap
            .bind(to: viewModel.decrementTapped)
            .disposed(by: disposeBag)

        resetButton.rx.tap
            .bind(to: viewModel.resetTapped)
            .disposed(by: disposeBag)

        // ============================================
        // Output: ViewModelのデータをUIに反映する
        // ============================================
        viewModel.countText
            .bind(to: countLabel.rx.text)
            .disposed(by: disposeBag)

        viewModel.isDecrementEnabled
            .bind(to: decrementButton.rx.isEnabled)
            .disposed(by: disposeBag)
    }
}
```

## 4-3. bind(to:) を理解する

`bind(to:)` は RxSwift の最も重要なメソッドの1つです。
**データの流れを一方向で接続** します。

```swift
// ソース → 宛先
viewModel.countText.bind(to: countLabel.rx.text)
//                  ^^^^^^^^^^^^^^^^^^^^^^
//                  「countTextの値が変わったら、
//                    countLabelのtextを自動更新する」
```

`bind(to:)` は `subscribe` のシンタックスシュガーです：

```swift
// bind(to:) は内部でこう動く（概念的なコード）
viewModel.countText
    .subscribe(onNext: { [weak countLabel] text in
        countLabel?.text = text
    })
    .disposed(by: disposeBag)
```

:::message
💡 **bind vs subscribe**
- `bind(to:)` → UIへのバインディングに使う（メインスレッドで実行される）
- `subscribe` → 汎用的な購読（スレッドの指定が必要な場合も）

UIバインディングには `bind(to:)` を使うのがベストプラクティスです。
:::

## 4-4. バインディングの全体図

ViewControllerの `bind()` メソッドで行っているバインディングの全体図です：

```
┌─── CounterViewController ───┐    ┌─── CounterViewModel ───┐
│                              │    │                         │
│  [+ボタン].rx.tap ──bind──→  │ →  │  incrementTapped        │
│  [−ボタン].rx.tap ──bind──→  │ →  │  decrementTapped        │
│  [Resetボタン].rx.tap ─bind→ │ →  │  resetTapped            │
│                              │    │                         │
│  countLabel.rx.text ←─bind── │ ←  │  countText              │
│  [−ボタン].rx.isEnabled ←──  │ ←  │  isDecrementEnabled     │
│                              │    │                         │
└──────────────────────────────┘    └─────────────────────────┘
         View（UI）                       ViewModel（ロジック）
```

**ポイント:**
- ViewControllerにはロジックが一切ない
- すべてのデータの流れが `bind()` メソッドに集約されている
- ViewModelとViewの接続が宣言的で見通しが良い

---

# 5. テストを書く

## 5-1. なぜViewModelをテストするのか

MVVMの最大の利点は **ViewModelをUIなしでテストできる** ことです。

```swift
// テストの流れ
let viewModel = CounterViewModel()       // 1. ViewModelを生成
viewModel.incrementTapped.accept(())     // 2. Inputを送る
let result = try viewModel.countText     // 3. Outputを検証
    .toBlocking().first()
XCTAssertEqual(result, "1")              // 4. 期待値と比較
```

UIを起動する必要がないため、テストは **高速** で **安定** しています。

## 5-2. RxBlocking とは

`RxBlocking` は、Observableの値を **同期的に取得** するテスト用ライブラリです。

```swift
// 通常のObservableは非同期
viewModel.countText
    .subscribe(onNext: { text in
        // ここで検証したいが、非同期なのでテストが難しい
    })

// RxBlockingなら同期的に取得できる
let text = try viewModel.countText
    .toBlocking()    // Observable → BlockingObservable に変換
    .first()         // 最初の値を同期的に取得
// text == "0"
```

## 5-3. CounterViewModelTests の実装

```swift
import XCTest
import RxSwift
import RxBlocking
@testable import CounterApp

final class CounterViewModelTests: XCTestCase {

    var viewModel: CounterViewModel!
    var disposeBag: DisposeBag!

    override func setUp() {
        super.setUp()
        viewModel = CounterViewModel()
        disposeBag = DisposeBag()
    }

    override func tearDown() {
        viewModel = nil
        disposeBag = nil
        super.tearDown()
    }

    // MARK: - 初期値のテスト

    /// 初期状態でカウントが "0" であること
    func testInitialCountIsZero() throws {
        let countText = try viewModel.countText
            .toBlocking()
            .first()

        XCTAssertEqual(countText, "0")
    }

    /// 初期状態で−ボタンが無効であること
    func testInitialDecrementIsDisabled() throws {
        let isEnabled = try viewModel.isDecrementEnabled
            .toBlocking()
            .first()

        XCTAssertEqual(isEnabled, false)
    }

    // MARK: - インクリメントのテスト

    /// +ボタンを1回タップするとカウントが "1" になること
    func testIncrementOnce() throws {
        viewModel.incrementTapped.accept(())

        let countText = try viewModel.countText
            .toBlocking()
            .first()

        XCTAssertEqual(countText, "1")
    }

    /// +ボタンを3回タップするとカウントが "3" になること
    func testIncrementMultipleTimes() throws {
        viewModel.incrementTapped.accept(())
        viewModel.incrementTapped.accept(())
        viewModel.incrementTapped.accept(())

        let countText = try viewModel.countText
            .toBlocking()
            .first()

        XCTAssertEqual(countText, "3")
    }

    // MARK: - デクリメントのテスト

    /// カウントが0のとき−ボタンを押しても0のままであること
    func testDecrementDoesNotGoBelowZero() throws {
        viewModel.decrementTapped.accept(())

        let countText = try viewModel.countText
            .toBlocking()
            .first()

        XCTAssertEqual(countText, "0")
    }

    // MARK: - リセットのテスト

    /// Resetでカウントが "0" に戻ること
    func testResetAfterIncrements() throws {
        viewModel.incrementTapped.accept(())
        viewModel.incrementTapped.accept(())
        viewModel.incrementTapped.accept(())
        viewModel.resetTapped.accept(())

        let countText = try viewModel.countText
            .toBlocking()
            .first()

        XCTAssertEqual(countText, "0")
    }
}
```

## 5-4. テストを実行する

Xcode で `Cmd + U` を押すと、すべてのテストが実行されます。

```
Test Suite 'CounterViewModelTests' started
✅ testInitialCountIsZero
✅ testInitialDecrementIsDisabled
✅ testIncrementOnce
✅ testIncrementMultipleTimes
✅ testDecrementDoesNotGoBelowZero
✅ testResetAfterIncrements
Test Suite 'CounterViewModelTests' passed
```

:::message
💡 **テストのポイント**
1. **各テストは独立**: `setUp()` で毎回新しいViewModelを生成
2. **Inputを送ってOutputを検証**: UIに一切触れない
3. **エッジケースもテスト**: 0以下にならないこと、リセット後の状態
:::

## 5-5. テストパターンの整理

| テスト名 | Input | 期待するOutput |
|---------|-------|---------------|
| 初期値は0 | なし | countText = "0" |
| −ボタン初期無効 | なし | isDecrementEnabled = false |
| +1回で1 | increment × 1 | countText = "1" |
| +3回で3 | increment × 3 | countText = "3" |
| 0で−は0のまま | decrement × 1 | countText = "0" |
| リセットで0 | increment × 3, reset | countText = "0" |

---

# 6. まとめ

## 6-1. 学んだこと

この記事で学んだ内容を振り返りましょう。

### MVVMアーキテクチャ

```
View（UI表示）
  ↕ bind
ViewModel（ロジック）
  ↕
Model（データ）
```

- **View**: UIの表示とユーザー操作の受付のみ
- **ViewModel**: ビジネスロジック（Input → 処理 → Output）
- **Model**: データ構造

### RxCocoaのバインディング

```swift
// Input: UIイベント → ViewModel
button.rx.tap.bind(to: viewModel.someTapped)

// Output: ViewModel → UI
viewModel.someText.bind(to: label.rx.text)
```

### Input/Outputパターン

```swift
// Input:  PublishRelay<Void>  ← Viewからのイベント
// Output: Observable<T>      → Viewへのデータ
// Private: BehaviorRelay<T>  内部状態の保持
```

### テスト

```swift
// RxBlocking で同期的にテスト
viewModel.input.accept(())
let result = try viewModel.output.toBlocking().first()
XCTAssertEqual(result, expected)
```

## 6-2. MVVMの利点（実感できたこと）

| 利点 | 実感 |
|------|------|
| テスト容易性 | UIに依存しないため、ViewModelのロジックを単体でテストできた |
| 責務の分離 | ViewControllerにロジックが一切なく、変更時の影響範囲が限定される |
| 見通しの良さ | データと表示の依存関係がbind()メソッドに集約され、変更箇所の特定が容易 |
| 再利用性 | ViewModelがUIに依存しないため、異なるViewからでも同じロジックを利用できる |

---

## 次回予告

次回（第4回）は **ToDoリストアプリ** を作ります。

今回のカウンターアプリは1つの値（Int）を管理するだけでしたが、次回は **配列データ** を扱います。

学ぶ内容：
- **MVVMでの配列データ管理** - BehaviorRelay<[Todo]> で配列を管理
- **UITableView × RxSwift** - セルの表示、タップ、スワイプ削除
- **より複雑なOperator** - filter, combineLatest, withLatestFrom
- **ViewModelのテスト** - 配列操作のテスト

お楽しみに！

---

## 🔗 関連リンク

- [第1回: Observable、Subject、Disposableを理解する](https://zenn.dev/jinjer_techblog/articles/61ce0010c646b3)
- [第2回: ジェネリクス&エクステンションを理解する](記事URL)
- [GitHubリポジトリ](https://github.com/WaltRyusan/rxswift-tutorials)
- [RxSwift公式ドキュメント](http://reactivex.io/)
- [RxSwift GitHub](https://github.com/ReactiveX/RxSwift)
