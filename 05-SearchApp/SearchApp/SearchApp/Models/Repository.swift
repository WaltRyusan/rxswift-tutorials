//
//  Repository.swift
//  SearchApp
//
//  RxSwift Tutorial #5 - リアルタイム検索アプリ
//

import Foundation

/// 検索結果のリポジトリ1件
struct Repository: Decodable, Equatable {
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
