//
//  MockSearchService.swift
//  SearchAppTests
//
//  RxSwift Tutorial #5 - リアルタイム検索アプリ
//

import RxSwift
@testable import SearchApp

/// テスト用のニセ検索サービス（本物のAPIを叩かない）
final class MockSearchService: SearchServiceProtocol {
    /// 返す結果を差し替えられるようにする
    var stubResult: [Repository] = []
    var stubError: Error?
    /// true にすると結果を返さない（通信中のまま止まる状態を再現する）
    var stubNeverResponds = false
    /// どんなクエリで呼ばれたかを記録する
    private(set) var receivedQueries: [String] = []

    func searchRepositories(query: String) -> Single<[Repository]> {
        receivedQueries.append(query)
        if stubNeverResponds {
            return .never()
        }
        if let error = stubError {
            return .error(error)
        }
        return .just(stubResult)
    }
}
