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
