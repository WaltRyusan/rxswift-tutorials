---
title: "【RxSwift入門】①Observable、Subject、Disposableを理解する"
emoji: "📱"
type: "tech"
topics: ["iOS", "Swift", "MVVM", "RxSwift"]
published: true
---

## はじめに

RxSwiftはクセがあり最初はとっつきにくいのですが、理解すれば非常に強力なツールです。
この記事では、RxSwiftとはなんぞや？というところから、ミニマムなコード例とともに理解を深めていきます。

:::message
📂 **サンプルコード**
この記事で使用しているコードの完全版は[GitHubリポジトリ](https://github.com/WaltRyusan/rxswift-tutorials?tab=readme-ov-file)で公開しています。
:::

### RxSwiftとは

RxSwiftは、**非同期処理とイベント処理を統一的かつ宣言的に扱えるSwiftライブラリ**です。
そしてMicrosoftで誕生した「Reactive Extensions」という技術を、AppleのSwift言語向けに実装したライブラリです。

:::details Rxの語源と誕生
Rxは「Reactive Extensions（リアクティブ・エクステンションズ）」の略称で、2008年から2009年にかけてマイクロソフトのCloud Programmabilityチームが開発したライブラリ。

プロジェクトを率いたのはC#やLINQの開発にも携わったオランダ人コンピューター科学者Erik Meijer（エリック・マイヤー）で、彼はこの業績により2009年にマイクロソフトの優れた技術リーダーシップ賞を受賞。by Wikipedia

名前の由来を紐解くと、「Reactive」は値の変化に反応するリアクティブプログラミングを指し、「Extensions」は同時期に開発されたParallel Extensions技術に由来する相補的な拡張機能という意味が込められています。プロジェクトのロゴが電気ウナギなのは、元となった大規模プロジェクト「Volta」への言及らしい。

2009年11月のMicrosoft Professional Developer Conference（PDC）で初めて公開され、2011年6月21日に.NET Framework向けの最初の公式リリースが出荷。

2012年11月、マイクロソフトはReactive Extensionsをオープンソース化することを発表し、当初はCodePlex、後にGitHubで公開されました。 Wikipediaその後、JavaScript（RxJS）、Java（RxJava）、C++など多数の言語に実装が広がり、ReactiveXという統一された標準へと進化。
:::

### RxSwiftのメリット・デメリット

#### メリット

- **非同期処理を簡潔に記述できる** - コールバック地獄から解放される
- **宣言的な記述** - 「何をするか」を明確に書ける
- **データバインディングが容易** - UIとロジックの同期が簡単
- **MVVMアーキテクチャとの相性が良い** - データの流れが明確になる
- **コード全体の一貫性** - イベント処理の統一的な扱い

#### デメリット

- **学習コストが高い** - 習得まで1ヶ月程度かかる
- **デバッグが難しい** - ストリームの流れを追いにくい
- **メモリ管理に注意が必要** - DisposeBag、weak selfの理解が必須

:::message
💡 **なぜ今RxSwiftを学ぶのか？**
Swift公式の「Combine」や「Swift Concurrency（async/await）」が登場した現在でも、RxSwiftを学ぶ価値があります。
- **既存プロダクトの技術資産**: jinjerをはじめ、多くの大規模iOSプロダクトがRxSwiftで構築されており、保守・拡張に不可欠です
- **リアクティブの思考は共通**: RxSwiftで身につけた考え方はCombineやRxJS等にもそのまま転用できます
- **エコシステムの充実**: RxCocoa、RxDataSources等の豊富な周辺ライブラリが実践的な開発を支えます
:::

## Excelから学ぶリアクティブプログラミング

リアクティブプログラミングとは、「データストリーム（値の流れ）と変化の伝播」に焦点を当てたプログラミングパラダイムです。

個人的に最も分かりやすい例は、**Excelの計算式**です。以下の例を見てください。

| A1 | B1 | C1 |
| ---- | ---- | ---- |
| 2 | 5 | =A1*B1 |

上記のExcelのセル**A1** or **B1**の値を変更すると、それを参照している計算式の値が自動的に更新されます。
この「関係性を定義すれば自動的に更新される」仕組みこそがリアクティブプログラミングの核心です。

### Swiftコードで実現する

このような仕組みをSwiftで実現するのがRxSwiftです。
先ほどのExcelの例をコードで実現すると以下のようになります。

```swift
// ExcelのA1セル
let a1 = BehaviorRelay<Int>(value: 2)

// ExcelのB1セル
let b1 = BehaviorRelay<Int>(value: 5)

// ExcelのC1セル（=A1*B1）
let c1 = Observable.combineLatest(a1, b1) { $0 * $1 }

// C1の変化を監視
c1.subscribe(onNext: { result in
    print("C1の値: \(result)")
})

// A1の値を変更すると、C1が自動的に更新される
a1.accept(3) // C1の値: 15 が出力される
```

この記事では、こうした仕組みを一つずつ理解していきます。

## RxSwiftの核となる基本概念

今回の導入編では、RxSwiftの基礎となる以下の概念を学びます：

| 用語 | 日本語訳 | RxSwiftでの概念 |
|------|---------|----------------|
| Observable | 観察可能な | イベントを発行するストリームを表現する型。時間とともに値を発行できる |
| subscribe | 購読する | Observableが発行するイベントを受け取るための操作。イベントストリームの終点として機能する |
| Subject | 主体 | ObservableとObserverの両方の性質を持つ型。値を手動で流せるObservable |
| BehaviorSubject | 振る舞い | 最新の値を保持し、新規購読者に即座にその値を提供する特性を持つSubject |
| PublishSubject | 公開する | 購読開始後のイベントのみを提供する特性を持つSubject |
| ReplaySubject | 再生する | 指定した数の過去のイベントを保持し、新規購読者に提供するSubject |
| Relay | 中継器 | エラー・完了イベントを流さない安全なSubject。UIバインディングに最適 |
| Disposable | 破棄可能な | 購読のライフサイクルを管理するオブジェクト |
| DisposeBag | 破棄袋 | 複数のDisposableをまとめて管理し、解放時に一括で購読を解除する |
| weak self | 弱参照 | クロージャ内でのメモリリーク防止のための参照方法。self（インスタンス自身）への強参照を避けることで循環参照を防ぐ |

これらの概念を理解することで、次回以降で実際にアプリを作る準備が整います。

:::message
**Operator（データ加工）** と **Scheduler（スレッド制御）** は次回以降の記事で紹介します。
:::

## 1. Observable - 時間とともに流れるイベントの川

**Observableは「時間の経過とともにイベントやデータを放出する非同期シーケンス」です。**
川の流れに例えると理解しやすく、データは上流から下流へと時間とともに流れていきます。

### Observableが放出する3種類のイベント

Observableは以下の3種類のイベントを放出します：

- `.next(値)` - 通常の値イベント（複数回発生可能）
- `.error(エラー)` - エラー通知（1回だけ、これで終了）
- `.completed` - 正常完了通知（1回だけ、これで終了）

```
--●--●--●--|-->  時間の流れ
  ↑  ↑  ↑  ↑
  値 値 値 完了
```

:::message
errorまたはcompletedが発生するとストリームが終了し、それ以降nextイベントは発生しません。
:::

### 最もシンプルなコード例

まずは最もシンプルなObservableから始めましょう。

```swift
import RxSwift

// 数値を3つ流すObservable
let observable = Observable.of(1, 2, 3)

// 購読して値を受け取る
observable.subscribe { event in
    print(event)
}

// 出力:
// next(1)
// next(2)
// next(3)
// completed
```

:::message
コード内の `.subscribe` については、この後の「2. Observer/Subscribe」セクションで詳しく解説します。ここでは「Observableが発行した値を受け取る役割」だと理解しておいてください。
:::

このコードでは：

1. `Observable.of(1, 2, 3)` で3つの値を流すObservableを作成
2. `subscribe` メソッドで購読開始
3. 各イベントが順番に流れてくる

### Observableの主な生成方法

Observableを生成する方法はいくつかあります：

#### just - 単一の値を流す

```swift
let observable = Observable.just(42)

observable.subscribe { event in
    print(event)
}

// 出力:
// next(42)
// completed
```

#### of - 複数の値を流す

```swift
let observable = Observable.of(1, 2, 3, 4, 5)

observable.subscribe { event in
    print(event)
}

// 出力:
// next(1)
// next(2)
// next(3)
// next(4)
// next(5)
// completed
```

#### from - 配列から生成

```swift
let numbers = [10, 20, 30]
let observable = Observable.from(numbers)

observable.subscribe { event in
    print(event)
}

// 出力:
// next(10)
// next(20)
// next(30)
// completed
```

#### empty - 何も流さずに完了

```swift
let observable = Observable<Int>.empty()

observable.subscribe { event in
    print(event)
}

// 出力:
// completed
```

#### never - 何も流さず完了もしない

```swift
let observable = Observable<Int>.never()

observable.subscribe { event in
    print(event)
}

// 出力なし（何も起こらない）
```

#### create - カスタムObservable

より複雑なObservableを作成したい場合は`create`を使います：

```swift
let observable = Observable<Int>.create { observer in
    observer.onNext(1)
    observer.onNext(2)
    observer.onNext(3)
    observer.onCompleted()

    return Disposables.create()
}

observable.subscribe { event in
    print(event)
}

// 出力:
// next(1)
// next(2)
// next(3)
// completed
```

:::message
コード内の `Disposables.create()` や `.disposed(by:)` については、「4. Disposable/DisposeBag」セクションで詳しく解説します。これはメモリ管理のための仕組みです。
:::

## 2. Observer/Subscribe - 観測する仕組み

**ObserverはObservableから放出されるイベントを受け取り、それに反応する側です。**
実際のコードでは、`subscribe()`メソッドを通じてObserverをObservableに接続します。

### 基本的なsubscribe

先ほどのコードでは簡略化していましたが、実際には各イベントごとに処理を分けることができます：

```swift
import RxSwift

let observable = Observable.of(1, 2, 3)

let disposable = observable.subscribe(
    onNext: { value in
        print("値: \(value)")
    },
    onError: { error in
        print("エラー: \(error)")
    },
    onCompleted: {
        print("完了")
    }
)

// 出力:
// 値: 1
// 値: 2
// 値: 3
// 完了
```

### イベント別の処理

それぞれのイベントに対して、異なる処理を書くことができます：

#### onNext - 通常の値を受け取る

```swift
observable.subscribe(onNext: { value in
    print("受け取った値: \(value)")
})
```

#### onError - エラーを処理

```swift
let errorObservable = Observable<Int>.create { observer in
    observer.onNext(1)
    observer.onError(NSError(domain: "TestError", code: -1))
    return Disposables.create()
}

errorObservable.subscribe(
    onNext: { value in
        print("値: \(value)")
    },
    onError: { error in
        print("エラーが発生: \(error)")
    }
)

// 出力:
// 値: 1
// エラーが発生: Error Domain=TestError Code=-1 "(null)"
```

#### onCompleted - 完了を検知

```swift
observable.subscribe(
    onNext: { value in
        print("値: \(value)")
    },
    onCompleted: {
        print("すべての値を受け取りました")
    }
)
```

### 必要なイベントだけ処理する

すべてのイベントを処理する必要はありません。必要なものだけ指定できます：

```swift
// onNextだけ処理
observable.subscribe(onNext: { value in
    print(value)
})

// onErrorとonCompletedだけ処理
observable.subscribe(
    onError: { error in
        print("エラー: \(error)")
    },
    onCompleted: {
        print("完了")
    }
)
```

## 3. Subject と Relay - 双方向の橋渡し役

**SubjectとRelayは、ObservableでありながらObserverのように値を注入できる特殊な型です。**
通常のObservableは読み取り専用ですが、SubjectとRelayは実行時に手動でイベントを送信できます。

RxSwiftには主に以下の種類があります：

### Subject（RxSwiftが提供）

1. **PublishSubject** - 購読した時点以降のイベントのみを受け取る
2. **BehaviorSubject** - 最後の値を保持し、購読時にその値を受け取る
3. **ReplaySubject** - 指定した数の過去のイベントを保持し、購読時に受け取る

### Relay（RxRelayが提供）

4. **BehaviorRelay** - BehaviorSubjectのエラーなし版（**実務で推奨**）

:::message alert
**SubjectとRelayの重要な違い**
- **Subject**：エラーや完了イベントを送信できる（終了する可能性がある）
- **Relay**：エラーや完了イベントを送信できない（**絶対に終了しない**）

BehaviorRelayは**RxRelay**という別フレームワークで提供されており、`import RxRelay`が必要です。技術的にはSubjectではなく、Relay型という独立した型です。
:::

### PublishSubject - 購読後のイベントのみ

#### 特徴

- 購読した時点以降のイベントのみを受信
- 過去のイベントは受け取れない
- リアルタイムなイベント通知に適している

#### コード例

```swift
import RxSwift

let subject = PublishSubject<String>()
let disposeBag = DisposeBag()

// イベントを送信（まだ誰も購読していない）
subject.onNext("Hello")

// 購読開始
subject.subscribe(onNext: { value in
    print("購読者1: \(value)")
})
.disposed(by: disposeBag)

// イベントを送信
subject.onNext("World")  // 購読者1: World
subject.onNext("!")      // 購読者1: !

// 新しい購読者を追加
subject.subscribe(onNext: { value in
    print("購読者2: \(value)")
})
.disposed(by: disposeBag)

subject.onNext("RxSwift")
// 購読者1: RxSwift
// 購読者2: RxSwift
```

#### 出力結果

```
購読者1: World
購読者1: !
購読者1: RxSwift
購読者2: RxSwift
```

:::message
最初の`"Hello"`は購読前に送信されたため、誰も受信していません。
:::

### BehaviorSubject - 最後の値を保持

#### 特徴

- **初期値が必須**
- 最後に送信された値を保持
- 新しい購読者は購読時点の最新値を即座に受け取る
- 状態管理に適している

#### コード例

```swift
import RxSwift

// 初期値 "Initial" で作成
let subject = BehaviorSubject<String>(value: "Initial")
let disposeBag = DisposeBag()

// 購読開始（初期値を受け取る）
subject.subscribe(onNext: { value in
    print("購読者1: \(value)")
})
.disposed(by: disposeBag)

// 出力: 購読者1: Initial

subject.onNext("Hello")   // 購読者1: Hello
subject.onNext("World")   // 購読者1: World

// 新しい購読者を追加（最新値 "World" を受け取る）
subject.subscribe(onNext: { value in
    print("購読者2: \(value)")
})
.disposed(by: disposeBag)

// 出力: 購読者2: World

subject.onNext("!")
// 購読者1: !
// 購読者2: !
```

#### 出力結果

```
購読者1: Initial
購読者1: Hello
購読者1: World
購読者2: World
購読者1: !
購読者2: !
```

### ReplaySubject - 複数の過去イベントを保持

#### 特徴

- 指定した数の過去のイベントを保持
- 新しい購読者は過去のイベントをまとめて受け取る
- 履歴管理や分析に適している

#### コード例

```swift
import RxSwift

// 過去2つのイベントを保持
let subject = ReplaySubject<String>.create(bufferSize: 2)
let disposeBag = DisposeBag()

subject.onNext("A")
subject.onNext("B")
subject.onNext("C")

// 購読開始（過去2つ "B", "C" を受け取る）
subject.subscribe(onNext: { value in
    print("購読者1: \(value)")
})
.disposed(by: disposeBag)

// 出力:
// 購読者1: B
// 購読者1: C

subject.onNext("D")  // 購読者1: D

// 新しい購読者（過去2つ "C", "D" を受け取る）
subject.subscribe(onNext: { value in
    print("購読者2: \(value)")
})
.disposed(by: disposeBag)

// 出力:
// 購読者2: C
// 購読者2: D
```

#### 出力結果

```
購読者1: B
購読者1: C
購読者1: D
購読者2: C
購読者2: D
```

### BehaviorRelay - エラーなし版（実務推奨）

#### 特徴

- `onError`と`onCompleted`がない（**絶対に終了しない**）
- BehaviorSubjectと同じく初期値が必須
- 最新の値を保持
- `.accept()`で値を更新
- **UIの状態管理に最適**

:::message alert
BehaviorRelayは**RxRelay**フレームワークで提供されているため、`import RxRelay`が必要です。
:::

:::details RxRelayとRxCocoaの関係について
BehaviorRelayは、RxSwift 5.0（2019年4月）以降、**RxRelay**という独立したフレームワークに分離されました。

**フレームワークの構成：**
- **RxSwift** - コア機能（Observable、Subjectなど）
- **RxRelay** - 非終了ストリーム（BehaviorRelay、PublishRelayなど）
- **RxCocoa** - UIバインディング機能

**import文の選択肢：**

1. **`import RxRelay`（推奨）** - 必要最小限
```swift
import RxSwift
import RxRelay  // BehaviorRelayのために明示的に
```

2. **`import RxCocoa`でも動作する** - RxCocoaがRxRelayを再エクスポートしているため
```swift
import RxSwift
import RxCocoa  // RxRelayも自動的に含まれる
```

**どちらを使うべきか？**
- **ViewModelやビジネスロジック層**：`import RxRelay`（UI非依存）
- **ViewやUIコード**：`import RxCocoa`（UIバインディングも使うため）

この記事では、技術的に正確な`import RxRelay`を使用していますが、実務では両方のインポート方法が広く使われています。
:::

#### コード例

```swift
import RxSwift
import RxRelay  // ← これが必要！

let relay = BehaviorRelay<Int>(value: 0)
let disposeBag = DisposeBag()

// 購読開始
relay.subscribe(onNext: { value in
    print("現在の値: \(value)")
})
.disposed(by: disposeBag)

// 出力: 現在の値: 0

// 値を更新（onNextではなくacceptを使う）
relay.accept(1)  // 現在の値: 1
relay.accept(2)  // 現在の値: 2
relay.accept(3)  // 現在の値: 3

// 現在の値を取得
print("最新値: \(relay.value)")  // 最新値: 3
```

#### なぜBehaviorRelayが実務で推奨されるのか？

1. **エラーで終了しない** - UIの状態管理で予期しない終了を防ぐ
2. **シンプルなAPI** - `.accept()`だけで値を更新
3. **安全性** - エラー処理を気にする必要がない
4. **型安全** - コンパイル時に終了イベントの送信を防げる

### Subject/Relayの選び方

どのSubject/Relayを使うべきか迷ったら、以下のフローチャートを参考にしてください：

```
ストリームが終了する可能性がある？
├─ Yes（エラーや完了がある）→ Subject
│   └─ 値を保持する必要がある？
│       ├─ No  → PublishSubject
│       ├─ 1個  → BehaviorSubject
│       └─ 複数 → ReplaySubject
│
└─ No（絶対に終了しない）→ Relay
    └─ BehaviorRelay（推奨）
```

### 実際の使用例

```swift
import RxSwift
import RxRelay

class ViewModel {
    // UI状態（エラーなし、終了なし）→ Relay
    let userName = BehaviorRelay<String>(value: "")
    let isLoading = BehaviorRelay<Bool>(value: false)

    // リアルタイムイベント（通知など）→ Subject
    let notification = PublishSubject<String>()

    // API結果（エラーあり）→ Subject
    let apiResult = BehaviorSubject<Result<Data, Error>>(value: .success(Data()))

    // 履歴（最新3件を保持）→ Subject
    let searchHistory = ReplaySubject<String>.create(bufferSize: 3)
}
```

### メモリ管理

SubjectやRelayを使う際は、必ず`disposed(by: disposeBag)`を使ってメモリリークを防ぎましょう：

```swift
let subject = PublishSubject<String>()
let disposeBag = DisposeBag()

subject
    .subscribe(onNext: { value in
        print(value)
    })
    .disposed(by: disposeBag)  // ← これ重要！
```

:::message
`disposed(by:)` と `DisposeBag` の詳細は、次の「4. Disposable/DisposeBag」セクションで解説します。
:::

## 4. Disposable/DisposeBag - メモリ管理の仕組み

**Disposableは購読を管理し、メモリリークを防ぐための仕組みです。**
RxSwiftでは、Observableを`subscribe`すると`Disposable`オブジェクトが返されます。

### なぜDisposableが必要なのか？

Observableを購読すると、そのストリームは自動的には解放されません。
購読を解除しないと、以下の問題が発生します：

1. **メモリリーク** - 不要なオブジェクトがメモリに残り続ける
2. **予期しない動作** - 画面を閉じた後もイベントが流れ続ける
3. **循環参照** - ViewControllerが解放されない

### DisposeBag - 自動的な購読解除（基本）

**DisposeBagは複数のDisposableをまとめて管理し、自動的に解放するコンテナです。**

これが**RxSwiftにおける基本的かつ推奨される使い方**です。

#### 基本的な使い方

```swift
import RxSwift

class ViewController: UIViewController {
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        Observable.of(1, 2, 3)
            .subscribe(onNext: { value in
                print("値: \(value)")
            })
            .disposed(by: disposeBag)  // DisposeBagに追加
    }

    deinit {
        print("ViewControllerが解放されました")
        // この時点でDisposeBagが自動的にすべての購読を解除
    }
}
```

:::message
**deinit** はSwiftのデイニシャライザで、オブジェクトがメモリから解放される直前に自動的に呼ばれます。ViewControllerが画面から消えてメモリから解放されるときに実行されます。
:::

#### DisposeBagの仕組み

1. ViewControllerが作成されると、`disposeBag`も作成される
2. 各購読を`.disposed(by: disposeBag)`でDisposeBagに追加
3. ViewControllerが解放される（`deinit`）と、DisposeBagも一緒に解放される
4. DisposeBagが解放されると、登録されたすべての購読が自動的に解除される

### Disposableの手動解除（特殊なケース）

DisposeBagを使わず手動で購読を解除もできますが、**これは特殊なケースでのみ使用します。**
一般的なiOSアプリ開発では、DisposeBagによる自動解除が推奨されます。

#### 手動で購読解除する例

```swift
import RxSwift

let observable = Observable<Int>.interval(.seconds(1), scheduler: MainScheduler.instance)

// 購読開始
let disposable = observable.subscribe(onNext: { value in
    print("値: \(value)")
})

// 5秒後に購読解除
DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
    disposable.dispose()
    print("購読解除")
}
```

#### 手動解除が必要なケース

- タイマーを途中で停止したい場合
- 特定の条件で購読を解除したい場合
- ViewControllerのライフサイクルとは無関係に管理したい場合

:::message
基本的には**DisposeBagを使った自動解除**を使い、手動での`dispose()`呼び出しは必要な場合のみにしましょう。
:::

### 循環参照を防ぐ - [weak self]

Observableのクロージャ内で`self`を参照すると、循環参照が発生する可能性があります。

#### 循環参照とは？

オブジェクト同士がお互いを強く参照し合うことで、どちらも解放されなくなる問題です。

```
ViewController → Observable（強参照）
       ↑              ↓
       └──── クロージャ内でselfを参照（強参照）
```

この状態だと、ViewControllerを閉じてもメモリから解放されません。

#### 悪い例（循環参照が発生）

```swift
class ViewController: UIViewController {
    private let disposeBag = DisposeBag()
    private var count = 0

    func setupObservable() {
        let button = UIButton()

        button.rx.tap
            .subscribe(onNext: {
                self.count += 1  // ← selfを強参照
                print("Count: \(self.count)")
            })
            .disposed(by: disposeBag)
    }

    deinit {
        print("解放されました")  // ← これが呼ばれない！
    }
}
```

#### 良い例（[weak self]で解決）

```swift
class ViewController: UIViewController {
    private let disposeBag = DisposeBag()
    private var count = 0

    func setupObservable() {
        let button = UIButton()

        button.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let self = self else { return }
                self.count += 1
                print("Count: \(self.count)")
            })
            .disposed(by: disposeBag)
    }

    deinit {
        print("解放されました")  // ← 正しく呼ばれる
    }
}
```

#### [weak self]の仕組み

- `[weak self]` - selfを**弱参照**する（循環参照を防ぐ）
- `guard let self = self else { return }` - selfがnilでないことを確認

selfが既に解放されている（ViewControllerが閉じられた）場合、クロージャは実行されずに`return`されます。

### [weak self] vs [unowned self]

| | weak self | unowned self |
|---|---|---|
| **安全性** | 安全（nilチェック必須） | 危険（nilの場合クラッシュ） |
| **使用場面** | ほとんどの場合 | selfが必ず存在する場合のみ |
| **推奨度** | ⭐⭐⭐⭐⭐ 推奨 | ⭐ 非推奨 |

:::message alert
基本的に **[weak self]を使うことを強く推奨** します。`[unowned self]`は予期しないクラッシュの原因になります。
:::

### DisposeBagの実践的な使い方

#### ViewControllerでの典型的なパターン

```swift
import UIKit
import RxSwift
import RxCocoa

class MyViewController: UIViewController {
    // MARK: - Properties
    private let disposeBag = DisposeBag()
    private let viewModel = MyViewModel()

    // MARK: - UI Components
    private let button = UIButton()
    private let label = UILabel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBindings()
    }

    // MARK: - Setup
    private func setupBindings() {
        // ボタンタップを監視
        button.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.handleButtonTap()
            })
            .disposed(by: disposeBag)

        // ViewModelの値を監視
        viewModel.text
            .bind(to: label.rx.text)
            .disposed(by: disposeBag)

        // 複数のストリームをまとめて管理
        Observable.combineLatest(
            viewModel.isLoading,
            viewModel.isValid
        )
        .subscribe(onNext: { [weak self] isLoading, isValid in
            self?.updateUI(isLoading: isLoading, isValid: isValid)
        })
        .disposed(by: disposeBag)
    }

    private func handleButtonTap() {
        print("ボタンがタップされました")
    }

    private func updateUI(isLoading: Bool, isValid: Bool) {
        // UI更新処理
    }

    deinit {
        print("MyViewControllerが解放されました")
    }
}
```

### DisposeBagのベストプラクティス

1. **ViewControllerごとに1つのDisposeBag** - クラスのプロパティとして定義
2. **必ず.disposed(by: disposeBag)を書く** - これを忘れるとメモリリーク
3. **[weak self]を使う** - 循環参照を防ぐ
4. **guard let self = self else { return }** - selfがnilの場合の安全な処理

## まとめ

この記事では、RxSwiftの基礎として以下の概念を学びました。

### 学んだこと

#### 1. Observable - 時間とともに流れるイベント

- `just`, `of`, `from`, `create`などで生成
- 3種類のイベント: `next`, `error`, `completed`
- Observableは時間とともにイベントを流すストリーム

#### 2. Observer/Subscribe - 観測する仕組み

- `subscribe(onNext:onError:onCompleted:)`でイベントを受信
- 必要なイベントだけ処理できる
- Observableを購読してイベントに反応する

#### 3. Subject と Relay - 双方向の橋渡し

- **Subject（RxSwift提供）**：
  - PublishSubject：購読後のイベントのみ
  - BehaviorSubject：最後の値を保持
  - ReplaySubject：複数の過去イベントを保持
- **Relay（RxRelay提供）**：
  - BehaviorRelay：エラーなし版（**実務推奨**）
- **選択基準**：終了する可能性があるか→値の保持が必要か→過去値の数

#### 4. Disposable/DisposeBag - メモリ管理

- `disposed(by: disposeBag)`で自動的に購読解除（**基本的な使い方**）
- `[weak self]`で循環参照を防ぐ
- ViewControllerなどのライフサイクルに合わせて自動解放

### 次のステップ

基礎概念を理解したら、次は実際にアプリを作りながら学んでいきましょう！

## 今後の学習ロードマップ

### 第2回：ジェネリクス&エクステンション編 ⭐

- **Observable のジェネリクス** - 型安全なストリーム
- **Reactive Extension** - UIKitコンポーネントへのRx拡張
- **カスタムExtension** - 独自のRx機能を追加

### 第3回：カウンターアプリ ⭐

- **RxCocoa の基礎** - UIKitとの連携
- **基本的な Operator** - `map`, `bind(to:)`
- **MVVM パターン** - ViewとViewModelの分離
- **テストの書き方** - RxSwiftアプリのテスト

### 第4回：ToDoリストアプリ ⭐⭐

- **配列の管理** - `BehaviorRelay<[Todo]>`
- **Operator の活用** - `filter`, `map`, `scan`
- **UITableView との連携**
- **複数のイベントを組み合わせる**

### 第5回：リアルタイム検索アプリ ⭐⭐⭐

- **高度な Operator** - `debounce`, `distinctUntilChanged`, `flatMap`
- **API通信** - URLSession + RxSwift
- **Scheduler** - バックグラウンド処理とUI更新
- **Hot vs Cold Observable** - 詳細解説

### 第6回以降

- **タイマー/ストップウォッチアプリ** - 時間ベースのObservable
- **フォームバリデーションアプリ** - 複数条件のリアルタイムチェック
- **天気アプリ** - エラーハンドリングと位置情報連携

---

## 参考資料

- [ReactiveX公式ドキュメント](http://reactivex.io/)
- [RxSwift GitHub](https://github.com/ReactiveX/RxSwift)
- [RxMarbles](https://rxmarbles.com/) - Operatorの視覚化

:::message
この記事がRxSwiftを学ぶ助けになれば幸いです。次回のジェネリクス&エクステンション編で、さらに理解を深めていきましょう！
:::
