---
title: "【RxSwift入門】②ジェネリクス&エクステンションを理解する"
emoji: "📱"
type: "tech"
topics: ["iOS", "Swift", "MVVM", "RxSwift"]
published: true
---

## はじめに

第1回では、RxSwiftの基本概念（Observable、Subject、Disposable）を学びました。
今回は、これまで何気なく使っていた **`Observable<T>`の`<T>`** や **`.rx.tap`** といった記法の仕組みを深く理解していきます。

この記事を読むことで、RxSwiftのコードがより読みやすくなり、自分で拡張機能を作れるようになります。

:::message
📂 **サンプルコード**
この記事で使用しているコードの完全版は[GitHubリポジトリ](https://github.com/WaltRyusan/rxswift-tutorials/tree/main/02-GenericsExtensions)で公開しています。
:::

## この記事で学ぶこと

1. **ジェネリクス** - `Observable<T>` の `<T>` とは何か
   - 型安全性の理解
   - 複数の型でObservableを使う
   - カスタム型での利用

2. **Reactive Extension** - `.rx` の仕組み
   - UIButton.rx.tap はどこから来たのか
   - RxCocoaが提供する機能
   - 自分で拡張を作る方法

## 前提知識

この記事は **第1回「基礎知識編」** を読んだ前提で進めます。
以下の概念を理解していることが前提です：

| 用語 | 日本語訳 | RxSwiftでの概念 |
|------|---------|----------------|
| Observable | 観察可能な | イベントを発行するストリームを表現する型。時間とともに値を発行できる |
| subscribe | 購読する | Observableが発行するイベントを受け取るための操作。イベントストリームの終点として機能する |
| Subject | 主体 | ObservableとObserverの両方の性質を持つ型。値を手動で流せるObservable |
| Relay | 中継器 | エラー・完了イベントを流さない安全なSubject。UIバインディングに最適 |
| Disposable | 破棄可能な | 購読のライフサイクルを管理するオブジェクト |
| DisposeBag | 破棄袋 | 複数のDisposableをまとめて管理し、解放時に一括で購読を解除する |
| weak self | 弱参照 | クロージャ内でのメモリリーク防止のための参照方法 |

まだ読んでいない方は、[第1回の記事](https://zenn.dev/jinjer_techblog/articles/61ce0010c646b3)から始めることをおすすめします。

---

# 1. Observable\<T>のジェネリクスを理解する

## 1-1. なぜObservable\<T>なのか

第1回では、以下のようなコードを書きました：

```swift
let observable = Observable.of(1, 2, 3)
```

実は、このコードは以下のように型が推論されています：

```swift
let observable: Observable<Int> = Observable.of(1, 2, 3)
```

この **`<Int>`** の部分が「ジェネリクス」と呼ばれる仕組みです。

### ジェネリクスとは？

ジェネリクスは、**異なる型に対して同じ処理を適用できる仕組み**です。

例えば、Swiftの配列 `Array<T>` もジェネリクスです：

```swift
let numbers: Array<Int> = [1, 2, 3]        // Int型の配列
let names: Array<String> = ["太郎", "花子"]  // String型の配列
```

同じように、Observableも **流すデータの型** を `<T>` で指定します：

```swift
let numbers: Observable<Int> = Observable.of(1, 2, 3)
let names: Observable<String> = Observable.of("太郎", "花子")
```

### なぜジェネリクスが必要なのか？

ジェネリクスがないと、型ごとに別のObservableを作る必要があります：

```swift
// もしジェネリクスがなかったら...
class ObservableInt { }      // Int専用
class ObservableString { }   // String専用
class ObservableUser { }     // User専用
// ... 型の数だけクラスが必要！
```

ジェネリクスのおかげで、**1つのObservableクラスですべての型に対応**できます。

## 1-2. 型安全性とは

ジェネリクスの最大のメリットは **型安全性** です。

### 型安全性の例

```swift
import RxSwift

// Int型のObservable
let numbers = Observable.of(1, 2, 3)

numbers.subscribe(onNext: { value in
    // valueは必ずInt型
    let doubled = value * 2  // 安全に計算できる
    print("2倍: \(doubled)")
})

// 出力:
// 2倍: 2
// 2倍: 4
// 2倍: 6
```

もし型の情報が失われると、このような安全な計算はできません：
```swift
// Any型を使うと型安全性が失われる
let mixed: [Any] = [1, "Hello", 3]  // Int と String が混在

mixed.forEach { value in
    // value は Any型 → コンパイラが型を判断できない
    // let doubled = value * 2          // ❌ コンパイルエラー（Anyに * は使えない）
    // let doubled = (value as! Int) * 2  // ⚠️ "Hello"で実行時クラッシュ
}
```

### コンパイル時に型エラーを検出

ジェネリクスのおかげで、**実行前にエラーを検出**できます：

```swift
let numbers: Observable<Int> = Observable.of(1, 2, 3)

numbers.subscribe(onNext: { value in
    print(value.uppercased())  // ❌ コンパイルエラー！
    // Int型にuppercased()メソッドは存在しない
})
```

これにより、実行時のクラッシュを防げます。

## 1-3. 複数の型でObservableを使う

それでは、実際に複数の型でObservableを作ってみましょう。

### Int型のObservable

```swift
import RxSwift

let disposeBag = DisposeBag()

// Int型のObservable
let numbers: Observable<Int> = Observable.of(1, 2, 3, 4, 5)

numbers.subscribe(onNext: { value in
    print("値: \(value), 2倍: \(value * 2)")
})
.disposed(by: disposeBag)

// 出力:
// 値: 1, 2倍: 2
// 値: 2, 2倍: 4
// 値: 3, 2倍: 6
// 値: 4, 2倍: 8
// 値: 5, 2倍: 10
```

### String型のObservable

```swift
// String型のObservable
let names: Observable<String> = Observable.of("太郎", "花子", "次郎")

names.subscribe(onNext: { name in
    print("こんにちは、\(name)さん")
})
.disposed(by: disposeBag)

// 出力:
// こんにちは、太郎さん
// こんにちは、花子さん
// こんにちは、次郎さん
```

### Bool型のObservable

```swift
// Bool型のObservable
let flags: Observable<Bool> = Observable.of(true, false, true, true)

flags.subscribe(onNext: { flag in
    print(flag ? "✅ 有効" : "❌ 無効")
})
.disposed(by: disposeBag)

// 出力:
// ✅ 有効
// ❌ 無効
// ✅ 有効
// ✅ 有効
```

## 1-4. カスタム型でObservableを使う

独自の構造体やクラスでもObservableを使えます。

### カスタム型の定義

```swift
// ユーザー情報を表す構造体
struct User {
    let id: Int
    let name: String
    let age: Int
}
```

### カスタム型のObservable

```swift
// User型のObservable
let users: Observable<User> = Observable.of(
    User(id: 1, name: "太郎", age: 25),
    User(id: 2, name: "花子", age: 30),
    User(id: 3, name: "次郎", age: 28)
)

users.subscribe(onNext: { user in
    print("ID: \(user.id), 名前: \(user.name), 年齢: \(user.age)")
})
.disposed(by: disposeBag)

// 出力:
// ID: 1, 名前: 太郎, 年齢: 25
// ID: 2, 名前: 花子, 年齢: 30
// ID: 3, 名前: 次郎, 年齢: 28
```

### より実践的な例：APIレスポンス

実務では、APIから取得したデータをObservableで流すことがよくあります：

```swift
// APIレスポンスを表す構造体
struct APIResponse {
    let statusCode: Int
    let data: Data
    let message: String
}

// APIレスポンスのObservable
let apiResponse: Observable<APIResponse> = Observable.create { observer in
    // APIコールを模擬
    let response = APIResponse(
        statusCode: 200,
        data: Data(),
        message: "成功"
    )

    observer.onNext(response)
    observer.onCompleted()

    return Disposables.create()
}

apiResponse.subscribe(onNext: { response in
    print("ステータス: \(response.statusCode)")
    print("メッセージ: \(response.message)")
})
.disposed(by: disposeBag)

// 出力:
// ステータス: 200
// メッセージ: 成功
```

## 1-5. 型推論の活用

Swiftの型推論により、多くの場合は型を明示的に書く必要がありません。

### 型推論の例

```swift
// 型を明示的に書く場合
let numbers1: Observable<Int> = Observable.of(1, 2, 3)

// 型推論を使う場合（推奨）
let numbers2 = Observable.of(1, 2, 3)  // Observable<Int>と推論される

// どちらも同じ
```

### 型を明示すべき場合

ただし、以下の場合は型を明示する必要があります：

#### ケース1: 空のObservable

```swift
// ❌ これはエラー（型が推論できない）
let empty = Observable.empty()

// ✅ 型を明示する
let empty: Observable<String> = Observable.empty()
```

#### ケース2: Subjectの初期化

```swift
// ❌ これはエラー（型が推論できない）
let subject = PublishSubject()

// ✅ 型を明示する
let subject = PublishSubject<String>()
```

#### ケース3: 複数の型の可能性がある場合

```swift
// 型が曖昧な場合は明示する
let value: Observable<Double> = Observable.just(5)  // IntではなくDouble
```

## 1-6. Subject/Relayでもジェネリクスは同じ

第1回で学んだSubjectやRelayも、同じようにジェネリクスを使います。

### PublishSubject\<T>

```swift
import RxSwift

let disposeBag = DisposeBag()

// String型のPublishSubject
let subject = PublishSubject<String>()

subject.subscribe(onNext: { value in
    print("受信: \(value)")
})
.disposed(by: disposeBag)

subject.onNext("Hello")   // 受信: Hello
subject.onNext("World")   // 受信: World
subject.onNext("RxSwift") // 受信: RxSwift
```

### BehaviorRelay\<T>

```swift
import RxRelay

// Int型のBehaviorRelay
let relay = BehaviorRelay<Int>(value: 0)

relay.subscribe(onNext: { value in
    print("現在の値: \(value)")
})
.disposed(by: disposeBag)

// 出力: 現在の値: 0

relay.accept(10)  // 現在の値: 10
relay.accept(20)  // 現在の値: 20
```

### カスタム型のRelay

```swift
struct Todo {
    let id: Int
    let title: String
    let isCompleted: Bool
}

// Todo型のBehaviorRelay
let todoRelay = BehaviorRelay<Todo>(
    value: Todo(id: 1, title: "RxSwiftを学ぶ", isCompleted: false)
)

todoRelay.subscribe(onNext: { todo in
    print("TODO: \(todo.title), 完了: \(todo.isCompleted ? "✅" : "❌")")
})
.disposed(by: disposeBag)

// 出力: TODO: RxSwiftを学ぶ, 完了: ❌

// TODOを更新
todoRelay.accept(
    Todo(id: 1, title: "RxSwiftを学ぶ", isCompleted: true)
)
// 出力: TODO: RxSwiftを学ぶ, 完了: ✅
```

### 配列型のRelay（実務でよく使う）

配列型のRelayは、リスト表示などでよく使います：

```swift
// Todo配列のBehaviorRelay
let todosRelay = BehaviorRelay<[Todo]>(value: [])

todosRelay.subscribe(onNext: { todos in
    print("TODO数: \(todos.count)")
    todos.forEach { todo in
        print("- \(todo.title)")
    }
})
.disposed(by: disposeBag)

// 出力: TODO数: 0

// TODOを追加
todosRelay.accept([
    Todo(id: 1, title: "RxSwiftを学ぶ", isCompleted: false),
    Todo(id: 2, title: "アプリを作る", isCompleted: false)
])

// 出力:
// TODO数: 2
// - RxSwiftを学ぶ
// - アプリを作る
```

:::message
**なぜ型を明示する必要があるのか？**
SubjectやRelayは値を後から注入できるため、Swiftコンパイラは初期化時に型を推論できません。そのため、`PublishSubject<String>()`のように型を明示する必要があります。
:::

---

# 2. Reactive Extensionの仕組みを理解する

## 2-1. .rxプロパティの正体

第1回のカウンターアプリでは、以下のようなコードを書きました：

```swift
button.rx.tap
    .subscribe(onNext: {
        print("ボタンがタップされました")
    })
```

この **`.rx.tap`** は一体どこから来たのでしょうか？

実は、これは **RxCocoaが提供するReactive Extension** です。

### UIButtonには.rxプロパティがない

通常のUIButtonには `.rx` というプロパティは存在しません：

```swift
let button = UIButton()
// button.rx  ← これはどこから来たのか？
```

### Reactive Extensionの仕組み

RxCocoaは、**Extensionを使ってUIKitコンポーネントに `.rx` プロパティを追加**しています。

簡略化したコードで仕組みを見てみましょう：

```swift
// RxCocoaが内部で行っていること（簡略版）

// 1. Reactive<Base>という汎用的なラッパー構造体を定義
struct Reactive<Base> {
    let base: Base

    init(_ base: Base) {
        self.base = base
    }
}

// 2. すべてのNSObjectに.rxプロパティを追加
extension NSObject {
    var rx: Reactive<Self> {
        return Reactive(self)
    }
}

// 3. UIButtonに対してReactiveの機能を追加
extension Reactive where Base: UIButton {
    var tap: Observable<Void> {
        // タップイベントをObservableに変換
        // （実際の実装は複雑ですが、概念的にはこのような仕組み）
        return Observable.create { observer in
            // タップイベントのハンドリング
            return Disposables.create()
        }
    }
}
```

このように、**Extensionの連鎖**で `.rx.tap` が実現されています：

```
UIButton
  └─ .rx プロパティ（NSObjectのExtensionで追加）
       └─ .tap プロパティ（Reactive<UIButton>のExtensionで追加）
```

## 2-2. RxCocoaが提供するReactive Extension

RxCocoaは、UIKitのほとんどのコンポーネントにReactive Extensionを提供しています。

### UIButton - タップイベント

```swift
import RxSwift
import RxCocoa

let button = UIButton()
let disposeBag = DisposeBag()

// タップイベントを購読
button.rx.tap
    .subscribe(onNext: {
        print("ボタンがタップされました")
    })
    .disposed(by: disposeBag)
```

### UITextField - テキスト入力

```swift
let textField = UITextField()

// テキスト変更を購読（リアルタイム）
textField.rx.text
    .subscribe(onNext: { text in
        print("入力されたテキスト: \(text ?? "")")
    })
    .disposed(by: disposeBag)
```

:::message
`textField.rx.text` の型は `Observable<String?>` です。テキストが空の場合は `nil` になる可能性があるため、オプショナル型になっています。
:::

### UILabel - テキスト設定

```swift
let label = UILabel()
let textRelay = BehaviorRelay<String>(value: "初期値")

// Relayの値をLabelに自動的にバインド
textRelay
    .bind(to: label.rx.text)
    .disposed(by: disposeBag)

textRelay.accept("新しいテキスト")  // Labelのテキストが自動更新される
```

### UISwitch - ON/OFFの状態

```swift
let toggle = UISwitch()

// ON/OFFの状態変化を購読
toggle.rx.isOn
    .subscribe(onNext: { isOn in
        print(isOn ? "ON" : "OFF")
    })
    .disposed(by: disposeBag)
```

### UISlider - 値の変化

```swift
let slider = UISlider()

// スライダーの値変化を購読
slider.rx.value
    .subscribe(onNext: { value in
        print("スライダーの値: \(value)")
    })
    .disposed(by: disposeBag)
```

## 2-3. Reactive Extensionの実装パターン

RxCocoaのReactive Extensionは、主に2つのパターンで実装されています。

### パターン1: イベントをObservableに変換

ユーザーの操作（タップ、入力など）をObservableに変換：

```swift
extension Reactive where Base: UIButton {
    var tap: Observable<Void> {
        // イベントをObservableとして公開
    }
}
```

使用例：

```swift
button.rx.tap  // Observable<Void>
    .subscribe(onNext: {
        print("タップされた")
    })
```

### パターン2: プロパティをObservableに変換

UIコンポーネントのプロパティをObservableに変換：

```swift
extension Reactive where Base: UITextField {
    var text: Observable<String?> {
        // テキストの変化をObservableとして公開
    }
}
```

使用例：

```swift
textField.rx.text  // Observable<String?>
    .subscribe(onNext: { text in
        print("テキスト: \(text ?? "")")
    })
```

### パターン3: Binderを使った単方向バインディング

Observableの値をUIに反映する：

```swift
extension Reactive where Base: UILabel {
    var text: Binder<String?> {
        // Observableの値をLabelに反映
    }
}
```

使用例：

```swift
let textObservable = Observable.just("こんにちは")

textObservable
    .bind(to: label.rx.text)  // Labelに自動反映
    .disposed(by: disposeBag)
```

:::message
**bind(to:) とは？**
`bind(to:)` は、Observableの値をUIコンポーネントに一方向に流す専用メソッドです。`subscribe` よりも意図が明確で、UIバインディングに最適化されています。
:::

---

# 3. 自分でReactive Extensionを作ってみる

それでは、実際に自分でReactive Extensionを作ってみましょう。

## 3-1. UILabelにアニメーション機能を追加

通常、UILabelのテキストを変更しても、アニメーションなしで即座に変わります。
ここでは、**フェードアニメーション付きでテキストを変更する** Reactive Extensionを作ります。

### 実装コード

```swift
import UIKit
import RxSwift
import RxCocoa

// UILabelにカスタムReactive Extensionを追加
extension Reactive where Base: UILabel {

    /// アニメーション付きでテキストを設定するBinder
    var animatedText: Binder<String?> {
        return Binder(self.base) { label, text in
            UIView.transition(
                with: label,
                duration: 0.3,
                options: .transitionCrossDissolve,
                animations: {
                    label.text = text
                },
                completion: nil
            )
        }
    }
}
```

### 使い方

```swift
let label = UILabel()
let textRelay = BehaviorRelay<String>(value: "初期テキスト")
let disposeBag = DisposeBag()

// アニメーション付きでバインド
textRelay
    .bind(to: label.rx.animatedText)  // カスタムExtensionを使用
    .disposed(by: disposeBag)

// テキストを変更すると、フェードアニメーションで切り替わる
textRelay.accept("新しいテキスト")
```

### 仕組みの解説

```swift
extension Reactive where Base: UILabel {
    //         ↑
    //   「BaseがUILabelの場合のみ」という制約

    var animatedText: Binder<String?> {
        //            ↑
        //      Binderは「値を受け取るだけ」の型

        return Binder(self.base) { label, text in
            //          ↑
            //     self.baseはUILabel自身

            // アニメーション処理
            UIView.transition(with: label, ...)
        }
    }
}
```

- `extension Reactive where Base: UILabel` - UILabelのみに機能を追加
- `Binder<String?>` - Observableの値を受け取ってUIに反映する型
- `self.base` - 実際のUILabelインスタンス

:::message
**Binderとは？**
`Binder<T>`は、Observableの値を受け取ってUIに反映するための専用の型です。以下の特徴があります：
- 値を受け取ることしかできない（Observableではない）
- 自動的にメインスレッドで実行される（UI更新に安全）
- エラーを発生させない（UIバインディングに最適）
:::

## 3-2. デバッグ用のカスタムオペレーターを作る

開発中、Observableの流れをデバッグしたいことがよくあります。
ここでは、**ログを出力するカスタムオペレーター** を作ります。

### 実装コード

```swift
import RxSwift

// ObservableTypeを拡張（すべてのObservableで使える）
extension ObservableType {

    /// デバッグログを出力するカスタムオペレーター
    func debug(_ identifier: String) -> Observable<Element> {
        return self.do(
            onNext: { value in
                print("[\(identifier)] Next: \(value)")
            },
            onError: { error in
                print("[\(identifier)] Error: \(error)")
            },
            onCompleted: {
                print("[\(identifier)] Completed")
            },
            onSubscribe: {
                print("[\(identifier)] Subscribe開始")
            },
            onDispose: {
                print("[\(identifier)] Dispose")
            }
        )
    }
}
```

### 使い方

```swift
let disposeBag = DisposeBag()

Observable.of(1, 2, 3, 4, 5)
    .debug("数値ストリーム")  // カスタムオペレーターを使用
    .subscribe()
    .disposed(by: disposeBag)

// 出力:
// [数値ストリーム] Subscribe開始
// [数値ストリーム] Next: 1
// [数値ストリーム] Next: 2
// [数値ストリーム] Next: 3
// [数値ストリーム] Next: 4
// [数値ストリーム] Next: 5
// [数値ストリーム] Completed
// [数値ストリーム] Dispose
```

### 実践的な使用例

複雑なストリームのデバッグに便利です：

```swift
textField.rx.text
    .debug("入力テキスト")
    .orEmpty                          // String? → String に変換
    .filter { $0.count >= 3 }
    .debug("フィルタ後")
    .subscribe(onNext: { text in
        print("検索: \(text)")
    })
    .disposed(by: disposeBag)

// 出力例（"abc"と入力した場合）:
// [入力テキスト] Subscribe開始
// [入力テキスト] Next: Optional("")
// [入力テキスト] Next: Optional("a")
// [入力テキスト] Next: Optional("ab")
// [入力テキスト] Next: Optional("abc")
// [フィルタ後] Subscribe開始
// [フィルタ後] Next: abc
// 検索: abc
```

## 3-3. タップの二重送信を防ぐカスタムExtension

実務でよくある問題：ボタンを連続でタップすると、処理が重複実行されてしまう。
ここでは、**一定時間内の連続タップを防ぐ** Extensionを作ります。

### 実装コード

```swift
import RxSwift
import RxCocoa

extension Reactive where Base: UIButton {

    /// 連続タップを防ぐObservable（デフォルト0.5秒）
    func throttleTap(seconds: Double = 0.5) -> Observable<Void> {
        return self.tap
            .throttle(.milliseconds(Int(seconds * 1000)), scheduler: MainScheduler.instance)
    }
}
```

### 使い方

```swift
let button = UIButton()
let disposeBag = DisposeBag()

// 通常のtap（連続タップで何度も実行される）
button.rx.tap
    .subscribe(onNext: {
        print("通常タップ")
    })
    .disposed(by: disposeBag)

// throttleTapを使う（0.5秒以内の連続タップは無視される）
button.rx.throttleTap()
    .subscribe(onNext: {
        print("API送信処理を実行")
    })
    .disposed(by: disposeBag)
```

:::message
**throttleとは？**
`throttle` は、指定した時間内の連続したイベントを間引くオペレーターです。最初のイベントだけを通し、指定時間が経過するまで後続のイベントを無視します。
これにより、ユーザーが誤って連続タップしても、処理は1回だけ実行されます。
:::

## 3-4. ローディング状態を管理するExtension

API通信中はローディング表示をしたい、というのもよくある要件です。

### 実装コード

```swift
import RxSwift

extension ObservableType {

    /// ローディング状態を自動管理するオペレーター
    func trackActivity(_ activityIndicator: BehaviorRelay<Bool>) -> Observable<Element> {
        return self.do(
            onNext: { _ in
                activityIndicator.accept(false)  // 完了したらfalse
            },
            onError: { _ in
                activityIndicator.accept(false)  // エラーでもfalse
            },
            onCompleted: {
                activityIndicator.accept(false)  // 完了したらfalse
            },
            onSubscribe: {
                activityIndicator.accept(true)   // 開始時はtrue
            }
        )
    }
}
```

### 使い方

```swift
let isLoading = BehaviorRelay<Bool>(value: false)
let disposeBag = DisposeBag()

// ローディング状態をUIに反映
isLoading
    .bind(to: activityIndicator.rx.isAnimating)
    .disposed(by: disposeBag)

// API通信（模擬）
Observable.just("データ")
    .delay(.seconds(2), scheduler: MainScheduler.instance)  // 2秒待つ
    .trackActivity(isLoading)  // 自動でローディング管理
    .subscribe(onNext: { data in
        print("データ取得: \(data)")
    })
    .disposed(by: disposeBag)

// isLoadingは自動的に:
// 1. Subscribe時に true になる
// 2. 完了時に false になる
```

---

# まとめ

この記事では、RxSwiftのジェネリクスとReactive Extensionの仕組みを学びました。

## 学んだこと

### 1. ジェネリクス - Observable\<T>

- **型安全性** - コンパイル時にエラーを検出
- **複数の型** - Int, String, カスタム型など、どんな型でも使える
- **型推論** - 多くの場合、型を明示する必要はない
- **Subject/Relay** - これらもジェネリクスを使う

```swift
let numbers: Observable<Int> = Observable.of(1, 2, 3)
let names: Observable<String> = Observable.of("太郎", "花子")
let users: Observable<User> = Observable.of(user1, user2)
```

### 2. Reactive Extension - .rxの仕組み

- **Extensionの連鎖** - NSObject → Reactive\<Base> → 各機能
- **RxCocoaの機能** - button.rx.tap, textField.rx.text など
- **Binder** - Observableの値をUIに一方向バインド

```swift
button.rx.tap           // Observable<Void>
textField.rx.text       // Observable<String?>
relay.bind(to: label.rx.text)  // Binder<String?>
```

### 3. カスタムExtensionの作り方

- **UIコンポーネントの拡張** - `extension Reactive where Base: UILabel`
- **オペレーターの拡張** - `extension ObservableType`
- **実務で使える例** - アニメーション、デバッグ、二重送信防止

```swift
// カスタムExtension
extension Reactive where Base: UILabel {
    var animatedText: Binder<String?> { ... }
}

// カスタムオペレーター
extension ObservableType {
    func debug(_ identifier: String) -> Observable<Element> { ... }
}
```

## ここまでで理解したこと

第1回と第2回で、以下のRxSwiftの基礎知識が身につきました：

✅ Observable, Subject, Relay - イベントの流れを作る
✅ Disposable/DisposeBag - メモリ管理
✅ ジェネリクス - 型安全なストリーム
✅ Reactive Extension - UIKitとの連携

次回からは、これらの知識を使って **実際にアプリを作りながら** さらに理解を深めていきます！

## 次回予告

第3回では、**MVVMアーキテクチャのカウンターアプリ** を作ります。

学ぶ内容：
- **MVVM** - View、ViewModel、Modelの分離
- **Input/Outputパターン** - ViewModelの設計パターン
- **RxCocoa** - UIとの本格的なバインディング
- **テスト** - ViewModelの単体テスト

いよいよ実践編です。お楽しみに！

---

## 参考資料

- [RxSwift GitHub](https://github.com/ReactiveX/RxSwift)
- [RxSwift公式ドキュメント](https://github.com/ReactiveX/RxSwift/tree/main/Documentation)
- [Reactive Extensions](http://reactivex.io/)

:::message
この記事が役に立ったら、[GitHubリポジトリ](https://github.com/WaltRyusan/rxswift-tutorials)にStarをいただけると嬉しいです！
:::
