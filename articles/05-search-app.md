---
title: "【RxSwift入門】⑤リアルタイム検索アプリでAPI通信とSchedulerを学ぶ"
emoji: "🔍"
type: "tech"
topics: ["iOS", "Swift", "MVVM", "RxSwift", "RxCocoa"]
published: false
---

## はじめに

第4回では、ToDoリストアプリを通じて **配列データの管理** と **UITableView × RxSwift** を学びました。
ただし、あのToDoリストが扱っていたのは **ローカルのデータだけ** でした。

実際のアプリでは、**サーバーと通信して結果を表示する** 場面がほとんどです。
そして通信が絡むと、「入力のたびにAPIを叩いてしまう」「古いリクエストの結果が後から返ってきて画面がちらつく」「重い処理でUIが固まる」といった、これまで出てこなかった課題が一気に増えます。

今回はシリーズ最終回として、**リアルタイム検索アプリ**（GitHubのリポジトリ検索）を作りながら、RxSwiftがこれらの課題をどれだけ美しく解決してくれるかを体験します。

:::message
📂 **サンプルコード**
この記事で使用しているコードの完全版は[GitHubリポジトリ](https://github.com/WaltRyusan/rxswift-tutorials/tree/main/05-SearchApp)で公開しています。
:::

## この記事で学ぶこと

| No | トピック | 内容 |
| ---- | ---- | ---- |
| 1 | API通信 × RxSwift | `URLSession.rx` で通信をObservableにする |
| 2 | debounce | 入力が落ち着いてからAPIを叩く |
| 3 | flatMapLatest | 古いリクエストを自動でキャンセルする |
| 4 | Scheduler | 通信はバックグラウンド、UI更新はメインスレッド |
| 5 | Hot / Cold Observable | 「いつ処理が始まるか」を理解する |
| 6 | 依存性注入（DI） | サービスを差し替えてViewModelをテストする |

## 前提知識

この記事は **第1回〜第4回** を読んだ前提で進めます。

| 用語 | 日本語訳 | RxSwiftでの概念 |
| ---- | ---- | ---- |
| Observable | 観察可能な | イベントを発行するストリームを表現する型 |
| PublishRelay | 公開中継器 | 初期値を持たず、エラーを流さないSubject |
| BehaviorRelay | 振る舞い中継器 | 現在の値を保持し、エラーを流さないSubject |
| flatMap | 平坦化変換 | 値を別のObservableに変換して1本の流れにまとめる |
| Single | 単発 | 成功1回 or エラー1回だけを流すObservable |
| bind(to:) | バインド | ObservableとUIを一方向で接続するメソッド |
| DisposeBag | 破棄袋 | 複数の購読をまとめて管理する |

まだ読んでいない方は、[第1回の記事](https://zenn.dev/jinjer_techblog/articles/61ce0010c646b3)から始めることをおすすめします。

---

# 1. 前回の振り返りと今回のゴール

## 1-1. 第4回と第5回の違い

```
第4回（Todoリスト）: ローカル配列を操作      →  同期処理（すぐ結果が出る）
第5回（検索アプリ）: サーバーから取得       →  非同期処理（結果が返るまで待つ）
```

| | 第4回 (Todoリスト) | 第5回 (検索アプリ) |
| ---- | ---- | ---- |
| データの取得元 | ローカル（メモリ） | リモート（Web API） |
| 処理 | 同期（即時） | 非同期（通信待ち） |
| スレッド | メインだけ | メイン + バックグラウンド |
| Model | Todo構造体 | Repository構造体 + JSONデコード |
| Operator | map, filter, withLatestFrom | debounce, distinctUntilChanged, flatMapLatest |
| 新概念 | なし | Scheduler, Hot/Cold, 依存性注入 |

## 1-2. 完成イメージ

```
┌──────────────────────────┐
│  🔍 RxSwift            　  │ ← 検索バー（UISearchBar）
├──────────────────────────┤
│  ⏳ 検索中...              │ ← ローディング表示
├──────────────────────────┤
│ RxSwift/RxSwift           │ ← リポジトリ名
│ ⭐ 24000  Reactive...      │ ← スター数 + 説明
├──────────────────────────┤
│ RxSwiftCommunity/...      │
│ ⭐ 3600   RxSwift extens.. │
└──────────────────────────┘
```

- 検索バーに文字を打つと、**入力が落ち着いた瞬間** に自動で検索
- 検索中はローディングを表示
- 文字を消すと結果もクリア
- 通信が失敗してもクラッシュせず、メッセージを表示

## 1-3. なぜRxSwiftが向いているのか

検索機能を「素朴に」実装すると、こんな問題が起きます。

```
【素朴な実装の問題】
- キーを打つたびにAPIを叩く         → 通信量が爆発、レート制限に引っかかる
- "sw" の結果が "swift" より後に返る → 画面に古い結果が表示される
- 通信中にメインスレッドを止める     → UIが固まる（フリーズ）
- コールバック地獄                  → ネストが深く読みにくい
```

RxSwiftでは、これらを **Operatorの組み合わせ** で宣言的に解決できます。
今回学ぶ `debounce` / `flatMapLatest` / `Scheduler` が、それぞれの問題にきれいに対応します。

---

# 2. プロジェクトのセットアップ

## 2-1. プロジェクトを開く

```bash
cd rxswift-tutorials
open 05-SearchApp/SearchApp/SearchApp.xcodeproj
```

## 2-2. SPMの依存関係

今回はテストで時間の流れを扱うため、**RxTest** を追加します。

| ライブラリ | 用途 | ターゲット |
| ---- | ---- | ---- |
| **RxSwift** | Observable、Single などの基本機能 | SearchApp |
| **RxCocoa** | UIKit / URLSession とのバインディング | SearchApp |
| **RxRelay** | PublishRelay、BehaviorRelay | SearchApp |
| **RxTest** | テスト用（時間を仮想的に進める TestScheduler） | SearchAppTests |
| **RxBlocking** | テスト用（第4回で使用。今回は補助的） | SearchAppTests |

:::message
💡 **RxCocoaにURLSession拡張が入っている**
`URLSession.rx.data(request:)` はRxCocoaが提供するリアクティブ拡張です。
通信結果を `Observable<Data>` として受け取れるので、`URLSession` を自前でクロージャで包む必要がありません。
:::

## 2-3. プロジェクト構成

```
SearchApp/
├── AppDelegate.swift
├── SceneDelegate.swift
├── Models/
│   └── Repository.swift           # ← APIレスポンスのモデル
├── Services/                      # ← NEW! API通信を担当する層
│   ├── SearchServiceProtocol.swift
│   └── GitHubSearchService.swift
├── ViewModels/
│   └── SearchViewModel.swift
├── Views/
│   └── SearchViewController.swift # ← UISearchBar + UITableView
└── Assets.xcassets/
```

:::message
💡 **ポイント: Services層の追加**
第4回まではViewModelが直接データを持っていました。
今回は **通信を担当するService層** を独立させます。
こうすることで、ViewModelは「どこからデータが来るか」を気にせず、**テスト時にはニセのService（Mock）に差し替え**られます。これが依存性注入（DI）です。
:::

---

# 3. Modelを定義する

## 3-1. GitHub検索APIのレスポンス

GitHubのリポジトリ検索APIは、次のようなJSONを返します（一部抜粋）。

```
GET https://api.github.com/search/repositories?q=RxSwift

{
  "items": [
    {
      "full_name": "ReactiveX/RxSwift",
      "description": "Reactive Programming in Swift",
      "stargazers_count": 24000
    }
  ]
}
```

## 3-2. Repository構造体

`Decodable` に準拠させて、JSONを構造体に変換できるようにします。

```swift
import Foundation

/// 検索結果のリポジトリ1件
struct Repository: Decodable {
    let fullName: String
    let description: String?
    let stargazersCount: Int

    // JSONのキー（snake_case）とプロパティ（camelCase）を対応させる
    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case description
        case stargazersCount = "stargazers_count"
    }
}

/// レスポンス全体（items配列を包む）
struct SearchResponse: Decodable {
    let items: [Repository]
}
```

| プロパティ | 型 | 説明 |
| ---- | ---- | ---- |
| `fullName` | `String` | `owner/repo` 形式の名前 |
| `description` | `String?` | 説明（無いリポジトリもあるので `Optional`） |
| `stargazersCount` | `Int` | スター数 |

:::message
💡 **CodingKeysでsnake_case対応**
APIのJSONは `full_name` のようなsnake_caseですが、SwiftのプロパティはcamelCaseが慣例です。
`CodingKeys` でキーを対応させれば、`JSONDecoder` が自動で変換してくれます。
:::

---

# 4. Service層を作る（API通信 × RxSwift）

## 4-1. プロトコルで「窓口」を定義する

まず、ViewModelが依存する **抽象的な窓口** をプロトコルで定義します。

```swift
import RxSwift

protocol SearchServiceProtocol {
    /// キーワードでリポジトリを検索する
    func searchRepositories(query: String) -> Single<[Repository]>
}
```

:::message
💡 **なぜ Single？**
API通信は「成功して結果が1回返る」か「失敗する」かのどちらかで、その後は完了します。
この「単発の結果」を表すのに最適なのが `Single` です（第1回で学んだObservableの仲間）。
`Observable` でも書けますが、`Single` の方が「1回だけ」という意図が明確になります。
:::

## 4-2. 本番用の実装（GitHubSearchService）

`URLSession.rx.data` を使って、通信結果をリアクティブに扱います。

```swift
import Foundation
import RxSwift
import RxCocoa

final class GitHubSearchService: SearchServiceProtocol {

    func searchRepositories(query: String) -> Single<[Repository]> {
        // 1. URLを組み立てる（空白や記号を安全にエンコード）
        var components = URLComponents(string: "https://api.github.com/search/repositories")!
        components.queryItems = [URLQueryItem(name: "q", value: query)]

        guard let url = components.url else {
            return .error(SearchError.invalidURL)
        }

        let request = URLRequest(url: url)

        // 2. 通信をObservableとして実行し、JSONをデコードする
        return URLSession.shared.rx
            .data(request: request)                // Observable<Data>（通信）
            .map { data in
                try JSONDecoder().decode(SearchResponse.self, from: data)
            }
            .map { $0.items }                      // items配列だけ取り出す
            .asSingle()                            // Single<[Repository]> に変換
    }
}

/// 通信で起こりうるエラー
enum SearchError: Error {
    case invalidURL
}
```

**処理の流れ:**

```
URLSession.shared.rx.data(request:)
        ↓ Observable<Data>（サーバーからのデータ）
   .map { JSONDecoder().decode(...) }
        ↓ Observable<SearchResponse>
   .map { $0.items }
        ↓ Observable<[Repository]>
   .asSingle()
        ↓ Single<[Repository]>  ← ViewModelはこれを受け取る
```

:::message alert
⚠️ **GitHub APIのレート制限**
未認証のGitHub検索APIは **1分あたり10回** までしか呼べません。
だからこそ、次に学ぶ `debounce` で「叩く回数を減らす」ことが実用上とても重要になります。
:::

---

# 5. ViewModelを作る（debounce・flatMapLatest・Scheduler）

## 5-1. Input/Outputの設計

```
┌────────────────────────────────────────────────────────────┐
│                     SearchViewModel                          │
│                                                              │
│  【Input】                    【Output】                     │
│  searchText(String)   ──→     repositories: [Repository]     │
│                       ──→     isLoading: Bool                │
│                       ──→     errorMessage: String?         │
│                                                              │
│  【依存】                                                    │
│  searchService: SearchServiceProtocol                        │
└────────────────────────────────────────────────────────────┘
```

| 分類 | 名前 | 型 | 役割 |
| ---- | ---- | ---- | ---- |
| Input | searchText | `PublishRelay<String>` | 検索バーの文字 |
| Output | repositories | `Driver<[Repository]>` | 検索結果 |
| Output | isLoading | `Driver<Bool>` | 通信中かどうか |
| Output | errorMessage | `Signal<String>` | エラー時のメッセージ |

:::message
💡 **Driver / Signal とは？**
第3回でも少し触れましたが、`Driver` と `Signal` は **UIバインディング専用** のObservableです。
- エラーを流さない（UIが途中で止まらない）
- 必ずメインスレッドで値が届く（UI更新が安全）

検索結果や状態表示は「UIに出すもの」なので、`Observable` ではなく `Driver` / `Signal` を使います。
:::

## 5-2. 新しいOperator① debounce

`debounce` は、**イベントが止まってから指定時間が経ったら、最後の値だけを流す** Operatorです。

```swift
searchText
    .debounce(.milliseconds(300), scheduler: MainScheduler.instance)
```

```
入力:      k───ka──kaz──kazu──────────────────
              ↑    ↑    ↑    ↑
              300ms経つ前に次が来るのでリセットされる
                                └─ 300ms 無入力
                                        ↓
debounce:  ─────────────────────────kazu──→   ← ここで初めて1回流れる
```

つまり、`k` `ka` `kaz` `kazu` と打っても、**APIを叩くのは "kazu" の1回だけ**。
これでレート制限問題と通信量問題が解決します。

:::message
💡 **debounce vs throttle**
- `debounce`: 入力が **止まってから** 流す（検索に最適）
- `throttle`: 一定間隔で **間引いて** 流す（連打ボタンの防止などに使う）

「打ち終わったら検索」という今回のケースには `debounce` がぴったりです。
:::

## 5-3. 新しいOperator② flatMapLatest

`flatMapLatest` は、**新しい値が来たら、前のObservable（＝進行中の通信）を破棄して、新しいObservableに乗り換える** Operatorです。

```swift
.flatMapLatest { query in
    searchService.searchRepositories(query: query)
}
```

```
検索語:    ──"swift"──────────"swiftui"──────────→
               ↓ 通信A開始         ↓ 通信B開始（通信Aは即キャンセル）
通信A:     ───[========✗]                          ← 結果は捨てられる
通信B:     ───────────────[==========]──→          ← こちらだけ採用
                                    ↓
結果:      ────────────────────────[swiftuiの結果]──→
```

これにより「古いリクエストの結果が後から届いて画面がちらつく」問題が解決します。

:::message
💡 **flatMap との違い**
- `flatMap`: すべての通信を **並行して** 実行し、返ってきた順に流す（順序が保証されない）
- `flatMapLatest`: **最新の通信だけ** を残し、古いものはキャンセルする

検索では「最後に入力した語の結果」だけが欲しいので、`flatMapLatest` が正解です。
:::

## 5-4. 新しい概念 Scheduler（スレッドの切り替え）

通信のような重い処理をメインスレッドで実行すると、UIが固まります。
`Scheduler` を使うと、**どのスレッドで処理を実行/受信するか** を指定できます。

| メソッド | 意味 | 使いどころ |
| ---- | ---- | ---- |
| `subscribe(on:)` | 処理を **開始** するスレッド | 通信・重い計算はバックグラウンド |
| `observe(on:)` | 値を **受け取る** スレッド | UI更新はメインスレッド |

```
[メインスレッド] 検索語入力
        ↓ observe(on: バックグラウンド)
[バックグラウンド] API通信・JSONデコード（重い処理）
        ↓ observe(on: メイン)
[メインスレッド] tableView更新（UI）
```

:::message
💡 **Driverを使うと自動でメインに戻る**
今回は出力を `Driver` にするので、UIに届く時点では自動的にメインスレッドになっています。
そのため `observe(on: MainScheduler.instance)` を明示しなくても安全ですが、「どこで何のスレッドを使っているか」を意識することが大切です。
:::

## 5-5. SearchViewModel の実装

```swift
import RxSwift
import RxCocoa
import RxRelay

final class SearchViewModel {

    // MARK: - Inputs（ViewからViewModelへ）
    let searchText = PublishRelay<String>()

    // MARK: - Outputs（ViewModelからViewへ）
    let repositories: Driver<[Repository]>
    let isLoading: Driver<Bool>
    let errorMessage: Signal<String>

    // MARK: - Private
    private let disposeBag = DisposeBag()

    // MARK: - Init（依存性注入）
    init(
        searchService: SearchServiceProtocol = GitHubSearchService(),
        scheduler: SchedulerType = MainScheduler.instance
    ) {
        // ローディング・エラーを内部で中継するためのRelay
        let loadingRelay = PublishRelay<Bool>()
        let errorRelay = PublishRelay<String>()

        // ============================================
        // 検索結果のストリーム
        // ============================================
        repositories = searchText
            // ① 前後の空白を除去
            .map { $0.trimmingCharacters(in: .whitespaces) }
            // ② 入力が落ち着くまで待つ（300ms）
            .debounce(.milliseconds(300), scheduler: scheduler)
            // ③ 同じ語が続けて来たら無視
            .distinctUntilChanged()
            // ④ 最新の検索語だけ通信する（古い通信はキャンセル）
            .flatMapLatest { query -> Observable<[Repository]> in
                // 空文字なら通信せず、結果を空にする
                guard !query.isEmpty else {
                    return .just([])
                }
                loadingRelay.accept(true)
                return searchService.searchRepositories(query: query)
                    .asObservable()
                    // 通信エラーはメッセージに変換し、ストリームは止めない
                    .catch { error in
                        errorRelay.accept("検索に失敗しました: \(error.localizedDescription)")
                        return .just([])
                    }
                    // 成功・失敗どちらでもローディングを終了する
                    .do(onNext: { _ in loadingRelay.accept(false) })
            }
            // ⑤ UI用にDriverへ（エラーを流さず、メインスレッド保証）
            .asDriver(onErrorJustReturn: [])

        isLoading = loadingRelay.asDriver(onErrorJustReturn: false)
        errorMessage = errorRelay.asSignal()
    }
}
```

## 5-6. データフロー（全体像）

```
① searchText に "R" "Rx" "RxSwift" が高速に流れる
        ↓ debounce(300ms)
② 入力が止まった "RxSwift" だけが通過
        ↓ distinctUntilChanged
③ 直前と同じ語でなければ通過
        ↓ flatMapLatest
④ API通信を開始（前の通信があればキャンセル）
        ↓ catch でエラーを吸収
⑤ 結果 [Repository] を repositories(Driver) に流す
        ↓ bind
⑥ UISearchBar / UITableView が自動更新
```

---

# 6. ViewControllerを作る（UISearchBar × UITableView）

## 6-1. Input / Output のバインド

```swift
import UIKit
import RxSwift
import RxCocoa

final class SearchViewController: UIViewController {

    // MARK: - UI Components
    private let searchBar = UISearchBar()
    private let tableView = UITableView()
    private let loadingView = UIActivityIndicatorView(style: .medium)

    // MARK: - Properties
    private let viewModel = SearchViewModel()
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bind()
    }

    // MARK: - Binding
    private func bind() {
        // ============================================
        // Input: 検索バー → ViewModel
        // ============================================
        searchBar.rx.text.orEmpty
            .bind(to: viewModel.searchText)
            .disposed(by: disposeBag)

        // ============================================
        // Output: ViewModel → UI
        // ============================================

        // 検索結果 → テーブルビュー
        viewModel.repositories
            .drive(tableView.rx.items(
                cellIdentifier: "RepositoryCell",
                cellType: UITableViewCell.self
            )) { _, repository, cell in
                var content = cell.defaultContentConfiguration()
                content.text = repository.fullName
                content.secondaryText = "⭐ \(repository.stargazersCount)  \(repository.description ?? "")"
                cell.contentConfiguration = content
            }
            .disposed(by: disposeBag)

        // ローディング表示
        viewModel.isLoading
            .drive(loadingView.rx.isAnimating)
            .disposed(by: disposeBag)

        // エラー → アラート表示
        viewModel.errorMessage
            .emit(onNext: { [weak self] message in
                self?.showAlert(message: message)
            })
            .disposed(by: disposeBag)
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: "エラー", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

## 6-2. Driver / Signal の受け取り方

`Observable` では `bind(to:)` でしたが、`Driver` / `Signal` は専用のメソッドで受け取ります。

| 出力の型 | 受け取るメソッド |
| ---- | ---- |
| `Observable` | `bind(to:)` |
| `Driver` | `drive(...)` |
| `Signal` | `emit(...)` |

意味は同じ（UIに流す）ですが、`Driver` / `Signal` は「メインスレッドで届く・エラーで止まらない」ことが型で保証されているぶん安全です。

## 6-3. バインディングの全体図

```
┌─── SearchViewController ────────┐    ┌─── SearchViewModel ─────┐
│                                  │    │                          │
│ searchBar.rx.text     ──bind──→  │ →  │  searchText              │
│                                  │    │    ↓ debounce            │
│                                  │    │    ↓ flatMapLatest       │
│                                  │    │    ↓ (API通信)           │
│ tableView.rx.items ←────drive─── │ ←  │  repositories            │
│ loadingView.isAnimating←──drive─ │ ←  │  isLoading               │
│ (アラート表示)      ←────emit──── │ ←  │  errorMessage            │
│                                  │    │                          │
└──────────────────────────────────┘    └──────────────────────────┘
```

---

# 7. Hot / Cold Observable を理解する

今回のアプリには、性質の違う2種類のObservableが登場しています。

## 7-1. Cold Observable（購読すると始まる）

`URLSession.rx.data(request:)` は **Cold** です。
**subscribe（購読）した瞬間に通信が始まり**、購読ごとに新しい通信が走ります。

```
[未購読]  通信は始まっていない
   ↓ subscribe
[購読]    ここで初めてリクエストが飛ぶ
   ↓ dispose（flatMapLatestが古い購読を破棄）
[破棄]    通信がキャンセルされる
```

`flatMapLatest` が新しい検索語のたびに「古い購読をdispose → 新しい購読を作成」しているため、
**古い通信が自動でキャンセルされる**のです。これがColdの性質を利用した仕組みです。

## 7-2. Hot Observable（購読と無関係に流れる）

`searchBar.rx.text` や `PublishRelay` は **Hot** です。
**誰が購読していようがいまいが、イベント（文字入力）は発生します。**

```
入力:  R──Rx──RxS──   ← 購読の有無に関係なくイベントは起きている
              ↑
           ここで購読を始めると、それ以降のイベントだけ受け取れる
```

## 7-3. まとめ

| | Cold | Hot |
| ---- | ---- | ---- |
| 例 | `URLSession.rx.data` | `searchBar.rx.text`, `PublishRelay` |
| 処理の開始 | 購読した時 | 購読と無関係 |
| 購読ごとの動作 | 毎回やり直す（通信し直す） | 途中から共有される |

:::message
💡 **なぜこの区別が重要？**
「Coldは購読しないと動かない」と知っていれば、`flatMapLatest` が古い通信をキャンセルできる理由が腹落ちします。
逆にHotの `searchBar.rx.text` は、購読前の入力は受け取れません。
この違いを意識すると、RxSwiftの挙動が予測できるようになります。
:::

---

# 8. テストを書く（依存性注入とTestScheduler）

## 8-1. なぜ本物のAPIを叩かないのか

テストで本物のGitHub APIを叩くと、

- ネットワークが無いと失敗する
- レート制限に引っかかる
- 結果が毎回変わる（不安定なテスト）

そこで、**ニセのService（Mock）に差し替え** ます。これが5-5でDIにした理由です。

## 8-2. Mockサービスを作る

```swift
import RxSwift
@testable import SearchApp

final class MockSearchService: SearchServiceProtocol {
    /// 返す結果を差し替えられるようにする
    var stubResult: [Repository] = []
    var stubError: Error?
    /// どんなクエリで呼ばれたかを記録する
    private(set) var receivedQueries: [String] = []

    func searchRepositories(query: String) -> Single<[Repository]> {
        receivedQueries.append(query)
        if let error = stubError {
            return .error(error)
        }
        return .just(stubResult)
    }
}
```

## 8-3. 時間を仮想的に進める（TestScheduler）

`debounce` は「300ミリ秒待つ」処理なので、普通にテストすると時間がかかります。
**RxTestの `TestScheduler`** を使うと、時間を仮想的に一瞬で進められます。

```swift
import XCTest
import RxSwift
import RxCocoa
import RxTest
@testable import SearchApp

final class SearchViewModelTests: XCTestCase {

    /// 入力が落ち着いたら1回だけ検索されること（debounce）
    func testDebounceCallsSearchOnce() {
        // 仮想時間のスケジューラ（1目盛り=1ms。debounceの300msを300目盛りとして扱う）
        let scheduler = TestScheduler(initialClock: 0, resolution: 0.001)
        let mock = MockSearchService()
        mock.stubResult = [
            Repository(fullName: "ReactiveX/RxSwift", description: "Reactive", stargazersCount: 24000)
        ]

        // ViewModelにMockと仮想スケジューラを注入
        let viewModel = SearchViewModel(searchService: mock, scheduler: scheduler)
        let disposeBag = DisposeBag()

        // ストリームを活性化する（購読しないと処理が始まらない）
        viewModel.repositories
            .drive(onNext: { _ in })
            .disposed(by: disposeBag)

        // 100,200,250ms に高速で入力（すべて300ms以内）
        scheduler.createColdObservable([
            .next(100, "R"),
            .next(200, "Rx"),
            .next(250, "RxSwift")
        ])
        .bind(to: viewModel.searchText)
        .disposed(by: disposeBag)

        // 仮想時間を進める
        scheduler.start()

        // 検索は最後の "RxSwift" の1回だけ呼ばれる
        XCTAssertEqual(mock.receivedQueries, ["RxSwift"])
    }
}
```

:::message alert
⚠️ **TestSchedulerの目盛りは「秒」がデフォルト**
`TestScheduler(initialClock: 0)` は1目盛り=1秒として扱うため、`.milliseconds(300)` は0目盛りに丸められ、debounceが効かなくなります（全入力が素通りしてテストが失敗します）。
`resolution: 0.001` を指定して1目盛り=1msにすると、`createColdObservable` の時刻（100/200/250）とdebounce（300ms）が同じ単位で噛み合います。
:::

:::message
💡 **なぜ `repositories` を購読するのか**
検索パイプライン（debounce〜flatMapLatest）は `repositories`（Driver）の中に組み込まれています。Driverは購読者がいて初めて動き出す（Hotに変換される）ため、購読しないと `searchText` を流しても何も起きません。実際のアプリでは画面がテーブルビューを常にdriveしているので意識しませんが、テストでは明示的に購読して起動させます。
:::

```
時刻:   100     200     250        550(=250+300)
入力:   "R" →  "Rx" → "RxSwift" ─── 無入力 ───→
                                        ↓ debounce満了
検索:                              searchRepositories("RxSwift") が1回だけ
```

## 8-4. 実時間のテスト（expectation）

「結果が正しく届くか」は、実時間のMainSchedulerで動かし、`XCTestExpectation` でdebounce満了を待って検証します。

```swift
/// 検索結果がそのまま出力に流れること
func testSearchResultIsEmitted() {
    let mock = MockSearchService()
    mock.stubResult = [
        Repository(fullName: "ReactiveX/RxSwift", description: nil, stargazersCount: 24000)
    ]
    // 実時間のMainSchedulerで動かし、debounce満了を待つ
    let viewModel = SearchViewModel(searchService: mock)
    let disposeBag = DisposeBag()

    let expectation = expectation(description: "検索結果が届く")
    var received: [Repository]?

    viewModel.repositories
        .drive(onNext: { repositories in
            if !repositories.isEmpty {
                received = repositories
                expectation.fulfill()
            }
        })
        .disposed(by: disposeBag)

    viewModel.searchText.accept("RxSwift")

    wait(for: [expectation], timeout: 2)
    XCTAssertEqual(received?.first?.fullName, "ReactiveX/RxSwift")
}
```

:::message
💡 **toBlocking を使わない理由**
第4回では `RxBlocking`（`toBlocking()`）で同期的に値を取り出しました。しかし今回の出力は `Driver`（メインスレッドで値が届く）で、`toBlocking()` はメインスレッドを止めてしまうため、debounceのタイマーと相性が悪くデッドロックしやすくなります。非同期＋メインスレッドが絡む場合は `XCTestExpectation` の方が安全です。
:::

## 8-5. テストパターン

| テスト名 | Input | 期待するOutput |
| ---- | ---- | ---- |
| debounceで1回だけ検索 | 300ms以内に3回入力 | 検索は1回だけ呼ばれる |
| 検索結果が流れる | "RxSwift" | 結果がrepositoriesに届く |
| 空文字で結果クリア | "" | repositoriesが空になる |
| 同じ語は無視 | "Rx" → "Rx" | 検索は1回だけ |
| エラーでもクラッシュしない | stubError設定 | errorMessageが流れ、空配列になる |

## 8-6. テスト実行結果

```
Test Suite 'SearchViewModelTests' started
✅ testDebounceCallsSearchOnce
✅ testDistinctUntilChanged
✅ testEmptyQueryDoesNotCallService
✅ testSearchResultIsEmitted
✅ testErrorEmitsMessageAndDoesNotCrash
Test Suite 'SearchViewModelTests' passed (5 tests)
```

---

# 9. まとめ

## 9-1. 学んだこと

### API通信をObservableにする

```swift
URLSession.shared.rx
    .data(request: request)
    .map { try JSONDecoder().decode(SearchResponse.self, from: $0) }
    .map { $0.items }
    .asSingle()
```

### 検索の3点セット（debounce → distinctUntilChanged → flatMapLatest）

```swift
searchText
    .debounce(.milliseconds(300), scheduler: scheduler) // 打ち終わりを待つ
    .distinctUntilChanged()                             // 同じ語は無視
    .flatMapLatest { query in                           // 古い通信をキャンセル
        searchService.searchRepositories(query: query)
    }
```

### 依存性注入でテスト可能にする

```swift
// 本番: 本物のService / テスト: Mockを注入
init(searchService: SearchServiceProtocol = GitHubSearchService()) { ... }
```

## 9-2. 第4回 vs 第5回 比較

| | 第4回 (Todoリスト) | 第5回 (検索アプリ) |
| ---- | ---- | ---- |
| データ取得 | ローカル | Web API（非同期） |
| Operator | map, filter, withLatestFrom | debounce, distinctUntilChanged, flatMapLatest |
| スレッド | メインのみ | Scheduler で使い分け |
| 出力の型 | Observable | Driver / Signal |
| 設計 | ViewModelがデータ保持 | Service層 + 依存性注入 |
| テスト | RxBlocking | RxBlocking + RxTest(TestScheduler) |

## 9-3. よくあるハマりどころ

:::message alert
⚠️ **flatMapの中でエラーを流すとストリームが止まる**
`flatMapLatest` の中でエラーがそのまま外に出ると、検索ストリーム全体が完了してしまい、
以降の検索が効かなくなります。今回のように `.catch { ... return .just([]) }` で
**内側でエラーを吸収** するのが定石です。
:::

---

## シリーズ完結にあたって

第1回から第5回まで、お疲れさまでした！

```
第1回: RxSwiftの基本概念（Observable / Subject / Disposable）
   ↓
第2回: ジェネリクスとエクステンション（Observable<T> / rx名前空間）
   ↓
第3回: カウンターアプリ（MVVM / Input・Output）
   ↓
第4回: ToDoリストアプリ（配列管理 / UITableView連携）
   ↓
第5回: 検索アプリ（API通信 / Scheduler / Hot・Cold / DI）★今回
```

このシリーズを通して、単なる文法だけでなく、
**「イベントの流れを宣言的に組み立てる」というRxSwiftの考え方** を体験してもらえたと思います。

ここから先は、実際のアプリで使われる `RxDataSources`（複雑なテーブル/コレクション）、
`RxRealm` / `RxCoreData`（永続化との連携）、そして **async/await との併用** など、
発展的なトピックが待っています。ぜひ自分のアプリで手を動かしてみてください。

---

## 🔗 関連リンク

- [第1回: Observable、Subject、Disposableを理解する](https://zenn.dev/jinjer_techblog/articles/61ce0010c646b3)
- [第2回: ジェネリクス&エクステンションを理解する](https://zenn.dev/jinjer_techblog/articles/14283b21430a07)
- [第3回: カウンターアプリでMVVMを学ぶ](https://zenn.dev/jinjer_techblog/articles/77a6d658e3e66a)
- [第4回: ToDoリストアプリで配列データを管理する](記事URL)
- [GitHubリポジトリ](https://github.com/WaltRyusan/rxswift-tutorials)
- [RxSwift公式ドキュメント](http://reactivex.io/)
- [RxSwift GitHub](https://github.com/ReactiveX/RxSwift)
- [RxMarbles](https://rxmarbles.com/) - Operatorの視覚化
