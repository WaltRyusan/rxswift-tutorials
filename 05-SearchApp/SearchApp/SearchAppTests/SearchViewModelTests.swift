//
//  SearchViewModelTests.swift
//  SearchAppTests
//
//  RxSwift Tutorial #5 - リアルタイム検索アプリ
//

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

        // 100,200,250 の時刻に高速で入力（すべて300ms以内）
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

    /// 同じ検索語が連続した場合は1回しか検索されないこと（distinctUntilChanged）
    func testDistinctUntilChanged() {
        let scheduler = TestScheduler(initialClock: 0, resolution: 0.001)
        let mock = MockSearchService()
        let viewModel = SearchViewModel(searchService: mock, scheduler: scheduler)
        let disposeBag = DisposeBag()

        viewModel.repositories
            .drive(onNext: { _ in })
            .disposed(by: disposeBag)

        // debounce(300ms)より十分に離して同じ語を2回流す
        scheduler.createColdObservable([
            .next(100, "RxSwift"),
            .next(500, "RxSwift")
        ])
        .bind(to: viewModel.searchText)
        .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertEqual(mock.receivedQueries, ["RxSwift"])
    }

    /// 空文字が入力されたら通信しないこと
    func testEmptyQueryDoesNotCallService() {
        let scheduler = TestScheduler(initialClock: 0, resolution: 0.001)
        let mock = MockSearchService()
        let viewModel = SearchViewModel(searchService: mock, scheduler: scheduler)
        let disposeBag = DisposeBag()

        viewModel.repositories
            .drive(onNext: { _ in })
            .disposed(by: disposeBag)

        scheduler.createColdObservable([
            .next(100, "   ") // 空白のみ → trim後は空文字
        ])
        .bind(to: viewModel.searchText)
        .disposed(by: disposeBag)

        scheduler.start()

        XCTAssertTrue(mock.receivedQueries.isEmpty)
    }

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

    /// 通信が失敗してもクラッシュせず、エラーメッセージが流れること
    func testErrorEmitsMessageAndDoesNotCrash() {
        let mock = MockSearchService()
        mock.stubError = SearchError.invalidURL
        let viewModel = SearchViewModel(searchService: mock)
        let disposeBag = DisposeBag()

        let expectation = expectation(description: "エラーメッセージが届く")
        var receivedMessage: String?

        // errorMessage は検索パイプライン（repositories）内で発火するため、
        // パイプラインを起動するために repositories も購読しておく
        viewModel.repositories
            .drive(onNext: { _ in })
            .disposed(by: disposeBag)

        viewModel.errorMessage
            .emit(onNext: { message in
                receivedMessage = message
                expectation.fulfill()
            })
            .disposed(by: disposeBag)

        viewModel.searchText.accept("RxSwift")

        wait(for: [expectation], timeout: 2)
        XCTAssertNotNil(receivedMessage)
    }
}
