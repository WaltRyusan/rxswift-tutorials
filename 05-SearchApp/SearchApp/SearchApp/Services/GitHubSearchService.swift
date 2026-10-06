//
//  GitHubSearchService.swift
//  SearchApp
//
//  RxSwift Tutorial #5 - リアルタイム検索アプリ
//

import Foundation
import RxSwift
import RxCocoa

/// 通信で起こりうるエラー
enum SearchError: Error {
    case invalidURL
}

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
