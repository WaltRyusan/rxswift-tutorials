//
//  TodoListViewController.swift
//  TodoListApp
//
//  RxSwift Tutorial #4 - ToDoリストアプリ
//

import UIKit
import RxSwift
import RxCocoa

/// ToDoリストアプリの ViewController
///
/// ViewModelとUIをバインディングで接続する。
/// 第3回の CounterViewController では Xib を使ったが、
/// 今回はプログラマティックUIで UITableView を構築する。
final class TodoListViewController: UIViewController {

    // MARK: - UI Components

    /// Todo入力用テキストフィールド
    private let textField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "新しいTodoを入力"
        tf.borderStyle = .roundedRect
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    /// 追加ボタン
    private let addButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("追加", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 件数表示ラベル
    private let countLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Todoリスト表示用テーブルビュー
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "TodoCell")
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - Properties

    /// ViewModel - ビジネスロジックを担当
    private let viewModel = TodoListViewModel()
    /// DisposeBag - バインディングのメモリ管理
    private let disposeBag = DisposeBag()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        bind()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "Todoリスト"
        view.backgroundColor = .systemBackground

        // 入力エリア用のスタックビュー
        let inputStack = UIStackView(arrangedSubviews: [textField, addButton])
        inputStack.axis = .horizontal
        inputStack.spacing = 8
        inputStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(inputStack)
        view.addSubview(countLabel)
        view.addSubview(tableView)

        // AutoLayout
        NSLayoutConstraint.activate([
            // 入力エリア
            inputStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            inputStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            inputStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            addButton.widthAnchor.constraint(equalToConstant: 60),

            // 件数ラベル
            countLabel.topAnchor.constraint(equalTo: inputStack.bottomAnchor, constant: 8),
            countLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            countLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // テーブルビュー
            tableView.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Binding

    /// ViewModelとUIをバインディングで接続する
    private func bind() {
        // ============================================
        // Input: UIイベント → ViewModel
        // ============================================

        // 追加ボタンタップ時にテキストフィールドの値を取得（withLatestFrom）
        // → 空文字を除外（filter）
        // → ViewModelのaddTodoに流す
        addButton.rx.tap
            .withLatestFrom(textField.rx.text.orEmpty)
            .filter { !$0.isEmpty }
            .bind(to: viewModel.addTodo)
            .disposed(by: disposeBag)

        // 追加後にテキストフィールドをクリア
        addButton.rx.tap
            .withLatestFrom(textField.rx.text.orEmpty)
            .filter { !$0.isEmpty }
            .subscribe(onNext: { [weak self] _ in
                self?.textField.text = ""
                self?.textField.sendActions(for: .valueChanged)
            })
            .disposed(by: disposeBag)

        // テキストが空のとき追加ボタンを無効にする
        textField.rx.text.orEmpty
            .map { !$0.isEmpty }
            .bind(to: addButton.rx.isEnabled)
            .disposed(by: disposeBag)

        // セルタップ → 完了状態をトグル
        tableView.rx.itemSelected
            .map { $0.row }
            .bind(to: viewModel.toggleTodo)
            .disposed(by: disposeBag)

        // セル選択解除（ハイライトを消す）
        tableView.rx.itemSelected
            .subscribe(onNext: { [weak self] indexPath in
                self?.tableView.deselectRow(at: indexPath, animated: true)
            })
            .disposed(by: disposeBag)

        // スワイプ削除
        tableView.rx.itemDeleted
            .map { $0.row }
            .bind(to: viewModel.deleteTodo)
            .disposed(by: disposeBag)

        // ============================================
        // Output: ViewModel → UI
        // ============================================

        // Todoリスト → テーブルビューのセル表示
        viewModel.todos
            .bind(to: tableView.rx.items(
                cellIdentifier: "TodoCell",
                cellType: UITableViewCell.self
            )) { _, todo, cell in
                var content = cell.defaultContentConfiguration()
                content.text = todo.title

                if todo.isCompleted {
                    // 完了: 取り消し線 + チェックマーク
                    let attributed = NSAttributedString(
                        string: todo.title,
                        attributes: [
                            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                            .foregroundColor: UIColor.secondaryLabel
                        ]
                    )
                    content.attributedText = attributed
                    cell.accessoryType = .checkmark
                } else {
                    // 未完了: 通常表示
                    content.textProperties.color = .label
                    cell.accessoryType = .none
                }

                cell.contentConfiguration = content
            }
            .disposed(by: disposeBag)

        // 未完了件数テキスト → ラベルに表示
        viewModel.incompleteTodoCountText
            .bind(to: countLabel.rx.text)
            .disposed(by: disposeBag)
    }
}
