//
//  SearchViewModel.swift
//  SearchApp
//
//  RxSwift Tutorial #5 - リアルタイム検索アプリ
//

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
