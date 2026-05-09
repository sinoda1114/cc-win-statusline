# cc-win-statusline

Windows 環境の [Claude Code](https://docs.anthropic.com/en/docs/claude-code) で動作する 2 行ステータスラインの設定一式。モデル名・コンテキスト使用率・cwd・git ブランチ・effort レベルに加え、5 時間 / 7 日 / extra のレート制限バーをリアルタイム表示する。

```
Opus 4.7 │ ✍️ 7% │ project (master*) │ ◑ medium

current ●●●●○○○○○○  46% ⏰ 5:10pm
weekly  ●○○○○○○○○○  12% ⏰ may 10, 1:00am
extra   ○○○○○○○○○○ $0.00/$10.00 ⏰ jun 1
```

## なぜこのリポジトリが必要か

Windows + Claude Code で statusLine を設定すると、**素直な書き方が高確率で壊れる**。Node.js `spawn` の Windows 固有の挙動と、bash の IFS 仕様という独立した 2 つの罠が重なるため。本リポジトリは両方を回避した実用構成を提供する。

## 動作環境

- Windows 10 / 11
- Claude Code v2.1.x（v2.1.137 で動作確認）
- [Git for Windows](https://git-scm.com/download/win)（Git Bash 同梱）
- [jq](https://stedolan.github.io/jq/)（PATH 上に必要、`~/.local/bin/jq.exe` 等）

PATH に `bash` `jq` `git` `date` `awk` `sed` `curl` が通っていれば OK。

## インストール

### 自動（推奨）

```powershell
git clone https://github.com/<your-account>/cc-win-statusline.git
cd cc-win-statusline
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

実行内容:
1. `~/.claude/statusline.sh` をコピー
2. `~/.claude/settings.json` の `statusLine` セクションをマージ（既存ファイルはバックアップ）
3. ホームディレクトリのパスを Git Bash 形式 (`/c/Users/<you>/...`) に変換して埋め込む
4. PATH 上の依存コマンドを検査

完了後、Claude Code を再起動すれば反映される。

### 手動

1. `template/statusline.sh` を `~/.claude/statusline.sh` にコピー
2. `~/.claude/settings.json` に以下をマージ（パスは自分のホームに合わせて Git Bash 形式で書く）:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /c/Users/<YOU>/.claude/statusline.sh",
    "refreshInterval": 5000
  }
}
```

## 機能と外部通信について（重要）

`statusline.sh` はバックグラウンドで以下の通信を行う。透明性のため明記する。

### 1. Anthropic API へのレート制限取得（主機能）

- エンドポイント: `https://api.anthropic.com/api/oauth/usage`
- 認証: ローカルの `~/.claude/.credentials.json` から OAuth トークンを読む（または環境変数 `CLAUDE_CODE_OAUTH_TOKEN`）
- 頻度: ローカルキャッシュ (`/tmp/claude/statusline-usage-cache.json`) が 60 秒以上古い場合のみ
- 用途: 「current 46%」「weekly 12%」「extra」の表示
- **無効化**: 当該ブロック (line 193-216) を削除すれば機能停止。1 行目（モデル/cwd/branch）は引き続き動作する

### 2. ローカルダッシュボードへの POST（オプション）

- エンドポイント: `http://127.0.0.1:43177/api/ingest`
- 用途: ローカルで動作させているダッシュボードサーバへのメトリクス送信（任意機能）
- サーバが起動していなければ無害に失敗する
- **無効化**: 該当ブロック (line 218-234) を削除

どちらも外部の第三者サーバには送信しない（Anthropic の自分のアカウント情報取得のみ）。

## ハマりどころ（技術メモ）

### Bug A: bash の IFS=$'\t' read で空フィールドが圧縮される

```bash
IFS=$'\t' read -r a b c d e <<< "x\t\ty\tz"
# 期待: a=x, b="", c=y, d=z, e=""
# 実際: a=x, b=y, c=z, d="", e=""  ← 空フィールドが消える
```

bash は **IFS が空白文字（space, tab, newline）の場合、連続を 1 つに圧縮する**。複数値を TAB で渡すなら、空値を sentinel 文字（本実装では `-`）で置換してから join し、bash 側で復元する必要がある。

### Bug B: settings.json の statusLine.command で Node spawn が壊す

NG パターン:

| 形式 | NG 理由 |
|---|---|
| `"\"C:\\Program Files\\Git\\bin\\bash.exe\" -c \"...\""` | Node `spawn` がスペース付きパス + 引用符を再パースしない |
| `C:\\Users\\foo\\.claude\\statusline.cmd` | `.cmd` は `shell:true` 無しでは起動できない |
| `cmd.exe /c <path>` | command 全体が 1 実行ファイル名扱いされ、cmd が対話モード起動 |

OK パターン:

```json
"command": "bash /c/Users/<you>/.claude/statusline.sh"
```

- PATH 上の単一実行ファイル名 `bash`（スペースなし）
- 引数 1 個のみ（space-split されても壊れない）
- Git Bash の `bash.exe` は `/c/Users/...` の Unix 形式パスを解釈する

### Bug C: Claude Code v2.1.137 の `resets_at` フィールド

stdin の JSON で `rate_limits.X.resets_at` は **epoch 整数**（以前は ISO 文字列だった可能性）。`iso_epoch()` ヘルパーは両形式に対応している。

## ファイル構成

```
cc-win-statusline/
├── README.md           # このファイル
├── LICENSE             # MIT
├── install.ps1         # PowerShell インストーラ
├── .gitignore
└── template/
    ├── settings.json   # statusLine 設定テンプレート
    └── statusline.sh   # 表示スクリプト本体
```

## カスタマイズ

`statusline.sh` 冒頭の色定義 (`blue`, `green`, ...) や、レート制限バーの幅 (`bar_width=10`) を変更すれば見た目を調整できる。1 行目 / 2 行目以降の構成は LINE 1 セクションと「Rate limit lines」セクションで個別に組み立てている。

## ライセンス

MIT License. 詳細は [LICENSE](./LICENSE) を参照。

## 謝辞

本構成は Claude Code Windows 環境のステータスライン問題のデバッグから生まれた。詳細な経緯は本リポジトリには含めず要点のみ記載しているが、参考までに「真の根本原因」は上記 Bug A / B / C の 3 点に集約される。
