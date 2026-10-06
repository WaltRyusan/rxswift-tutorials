//
//  SearchViewController.swift
//  SearchApp
//
//  RxSwift Tutorial #5 - リアルタイム検索アプリ
//

import UIKit
import RxSwift
import RxCocoa

final class SearchViewController: UIViewController {

    // MARK: - UI Components
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "GitHubリポジトリを検索"
        searchBar.autocapitalizationType = .none
        searchBar.searchBarStyle = .minimal
        return searchBar
    }()

    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "RepositoryCell")
        tableView.keyboardDismissMode = .onDrag
        return tableView
    }()

    private let loadingView: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // MARK: - Properties
    private let viewModel = SearchViewModel()
    private let disposeBag = DisposeBag()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bind()
    }

    // MARK: - Setup
    private func setupUI() {
        title = "リポジトリ検索"
        view.backgroundColor = .systemBackground

        [searchBar, tableView, loadingView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
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
                content.secondaryTextProperties.numberOfLines = 2
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
