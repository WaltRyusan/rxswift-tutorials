//
//  SearchServiceProtocol.swift
//  SearchApp
//
//  RxSwift Tutorial #5 - リアルタイム検索アプリ
//

import RxSwift

protocol SearchServiceProtocol {
    /// キーワードでリポジトリを検索する
    func searchRepositories(query: String) -> Single<[Repository]>
}
