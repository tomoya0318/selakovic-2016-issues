# 上流からの変更点 (Modifications relative to upstream)

このリポジトリは https://github.com/marijaselakovic/JavaScriptIssuesStudy (上流コミット
`c2f63062aab6e76513696a3962e37d57b39dccad`) の fork で、
[MB-Scanner](https://github.com/tomoya0318/MB-scanner) の等価検証器
(`mbs check-equivalence`) が最適化パッチを sandbox 実行する際の評価データセット
として用いる。

## 何を変えたか

**追加したのは「データセットが同梱していない npm 依存を宣言する `package.json` +
`pnpm-lock.yaml` のみ」。** 大きく 2 種類:

**(1) server 系 issue の `require()` 依存。** 上流データセットは各 issue に
`<lib>_before/` / `<lib>_after/` (検証対象のライブラリ本体) を同梱しているが、その
**ライブラリ自身の npm 依存は同梱していない**。そのため server 系 issue は
`require('<npm-dep>')` で落ち、`test()` まで到達できない。本 fork は各 issue
(または共通カテゴリ) に `package.json` を置き、`<lib>_before/package.json` の
`dependencies` フィールド (ディレクトリ形式の lib) または `<lib>_before.js` の
`require()` 列 (単一ファイル形式の lib) で宣言される依存を `dependencies` として
再宣言する。

**(2) client / clientServer 系 issue の `<script src>` 依存** (2026-05-12 追加)。
これらの issue の `v_before.html` / `v_after.html` は jquery・handlebars・underscore
を CDN (`ajax.googleapis.com` / `cdnjs.cloudflare.com` 等) から `<script src>` で
読み込むが、jsdom は `<script src>` を auto-load しない。MB-Scanner の preprocess は
これらを `node_modules/<pkg>/dist/<pkg>.js` (= browser ビルド) として読み出し、
変更関数候補の `setup` に出現順に連結する。版は `v_*.html` の `<script src>` URL を
典拠とする (before/after で版が異なることはなかった)。なお `execute.js` /
`jstat*.js` / `JSXTransformer.js` は測定ハーネス、`<lib>_before.js` /
`<lib>_after.js` は検証対象 (SUT) 本体なので「依存」ではなく、ここでは宣言しない。

両者とも `pnpm-lock.yaml` で版を byte 単位で固定し、`pnpm install --frozen-lockfile`
で offline-reproducible に展開できる。`require()` 依存は sandbox が `createRequire`
で解決し、`<script src>` 依存は preprocess が browser ビルドを読んで連結する、という
解決経路の違いがある。

> 注: 古い jquery (`< 1.9`) を npm から入れると、`lib/node-jquery.js` が依存する
> `jsdom@0.2.x` / `request@2.x` / `contextify` (native, optional) の transitive な
> 木が `pnpm-lock.yaml` に入る。本 fork はこの木を **使わない** (読むのは
> `tmp/jquery.js` のみ) が、npm パッケージの仕様上 install 時には展開される。
> `~/.npmrc` の `ignore-scripts=true` (または `pnpm install --ignore-scripts`) で
> `contextify` の native build はスキップされ、`--frozen-lockfile` install は成功する。

`node_modules/` は **git に commit しない** (`.gitignore` 済)。fork ルートの
`scripts/install-vendor-deps.sh` を 1 回叩けば lockfile から再生成される。これにより
リポジトリを軽量に保ちつつ、commit 済み `node_modules` の弊害 (symlink・パーミッション・
プラットフォーム依存) を避ける。

**issue の中身は一切変更していない** — `*.js` パッチファイル・`Description.md`・
`Confirmed.md`・issue 選定・ディレクトリ構造は上流と byte-identical。

## レイアウト (21 箇所の vendor location)

配置戦略は「**版衝突がある場合は issue 単位、無い場合は親で共有**」:

### server 系 `require()` 依存 (9 箇所)

| 配置場所 | 検証対象 lib (版) | 宣言依存 |
|---|---|---|
| `serverIssues/ChalkIssues/issues/issue_27a/` | chalk ~1.x (単一ファイル `chalk_before.js`) | ansi-styles@2.2.1, escape-string-regexp@1.0.5, strip-ansi@3.0.1, supports-color@2.0.0, has-ansi@2.0.0 |
| `serverIssues/ChalkIssues/issues/issue_27b/` | chalk ~1.x | (27a と同じ) |
| `serverIssues/ChalkIssues/issues/issue_28/` | chalk@0.4.0 (issue 単位 — `ansi-styles` 等の major が 27a/27b と衝突) | ansi-styles@1.1.0, escape-string-regexp@1.0.5, has-ansi@0.1.0, strip-ansi@0.3.0, supports-color@0.2.0 |
| `serverIssues/CheerioIssues/` (8 issue 共通) | cheerio@0.13.1 | htmlparser2@3.4.0, underscore@1.5.2, entities@0.3.0, CSSselect@0.4.1 |
| `serverIssues/MochaIssues/issues/issue_763/` | mocha@1.8.2 | commander@0.6.1, growl@1.7.0, jade@0.26.3, diff@1.0.2, debug@4.4.3, mkdirp@0.3.3, ms@0.3.0 |
| `serverIssues/RequestIssues/issues/issue_403/` | request@2.12.1 | form-data@0.0.10, mime@1.2.11 |
| `serverIssues/RequestIssues/issues/issue_1165/` | request@2.45.1 (`optionalDependencies` は省略) | bl@0.9.5, caseless@0.6.0, forever-agent@0.5.2, form-data@0.1.4, json-stringify-safe@5.0.1, mime-types@1.0.2, node-uuid@1.4.8, qs@1.2.2, tunnel-agent@0.4.3 |
| `serverIssues/Socket.ioIssues/issues/issue_573/` | socket.io@0.8.5 | socket.io-client@0.8.5, policyfile@0.0.4, redis@0.6.6 |
| `serverIssues/Socket.ioIssues/issues/issue_689/` | socket.io@0.8.7 | socket.io-client@0.8.7, policyfile@0.0.4, redis@0.6.7 |

### client / clientServer 系 `<script src>` 依存 (12 箇所)

| 配置場所 | 検証対象 lib (SUT) | 宣言依存 (= `<script src>` の CDN dep) |
|---|---|---|
| `clientIssues/AngularIssues/` (27 issue 共通) | angular (`angular_before.js`) | jquery@1.11.3 |
| `clientIssues/EmberIssues/` (issue 単位 override 以外で共通) | ember (`ember_before.js`) | jquery@2.1.3, handlebars@1.1.0 |
| `clientIssues/EmberIssues/issues/issue_3174/` (jquery 版が category と衝突) | ember 1.x | jquery@1.7.2 (handlebars@1.1.0 は親 `EmberIssues/` から解決) |
| `clientIssues/EmberIssues/issues/issue_3288/` (同上) | ember 1.x | jquery@1.7.2 (handlebars は親から解決) |
| `clientIssues/ReactIssues/` (5 issue 共通) | react (`react_before.js`) | jquery@1.7.2 |
| `clientServerIssues/BackboneIssues/` (5 issue 共通: 707/1097/1766/2768/2858) | backbone@0.5.3〜1.1.0 (`backbone_before.js`) | underscore@1.8.3 (`<script src>` の版 & backbone の全 require() range `>=1.1.2` / `>=1.3.1` / `>=1.4.3` を充足), jquery@2.1.3 |
| `clientServerIssues/EjsIssues/` (3 issue 共通) | ejs (`ejs_before.js`) | jquery@2.1.3 |
| `clientServerIssues/MomentIssues/` (3 issue 共通) | moment (`moment_before.js`) | jquery@2.1.3 |
| `clientServerIssues/NodeLruCacheIssues/` (issue_8) | lru-cache (`nodelrucache_before.js`) | jquery@2.1.3 |
| `clientServerIssues/QIssues/` (issue_169) | q (`q_before.js`) | jquery@1.7.2 |
| `clientServerIssues/Underscore.stringIssues/` (3 issue 共通) | underscore.string (`underscore.string_before.js`) | jquery@2.1.3 |
| `clientServerIssues/UnderscoreIssues/` (12 issue 共通) | underscore (`underscore_before.js`) | jquery@2.1.3 |

> `clientIssues/JQueryIssues/` (9 issue) は jquery 自身が SUT で `jquery_before.js` /
> `jquery_after.js` として読み込まれるため、vendor すべき CDN dep は無い。
> jquery `1.7` の Google CDN パス (`/1.7/jquery.min.js`) は実体 jQuery 1.7.0 だが npm に
> 公開されていない (最古は `1.7.2`) ため `jquery@1.7.2` で代替する。preprocess は
> `<script src>` URL の版番号を見ず「issue から最も近い `node_modules/` にある版」を
> 読むので機能的に問題はない。jquery `1.7.2` は `dist/` を持たず browser ビルドは
> `tmp/jquery.js` (`.min` 無し)。`2.1.3` / `1.11.3` は `dist/jquery.js` /
> `dist/jquery.min.js`、handlebars `1.1.0` は `dist/handlebars.js` /
> `dist/handlebars.min.js`、underscore `1.8.3` はパッケージ root の `underscore.js` /
> `underscore-min.js`。

配置を分ける理由:
- **版衝突があるので issue 単位**: chalk@1 (27a/27b) と chalk@0.4 (28) は
  `ansi-styles` 等の major が異なる / request@2.12 (403) と request@2.45 (1165) は
  非互換な dep set / socket.io は patch 版違い (0.8.5 vs 0.8.7) / Ember は category が
  jquery@2.1.3 なのに issue_3174 / issue_3288 の `v_*.html` だけ jquery@1.7 を読む
- **版衝突が無いので共有**: cheerio 8 件は cheerio@0.13.1 で同 dep / backbone 5 件は
  underscore@1.8.3 + jquery@2.1.3 で共通 / Angular 27 件は jquery@1.11.3 で共通 /
  React 5 件は jquery@1.7.2 で共通 / 残りの clientServer 系は jquery@2.1.3 で共通
- node の module 解決 (および preprocess の「最寄り」判定) はディレクトリツリーを
  上向きに辿るため、issue より上の階層に `node_modules/` があれば issue から解決可能

## 触れていないもの (実行不能だが理由が依存問題ではない、as-is)

以下の issue は **依存解決とは別の理由で実行できない** ため、本 fork ではそれ以上は
触れていない (これらが属する category には上の表の通り `<script src>` 依存が宣言される
が、それだけで実行可能になる訳ではない)。

- `clientIssues/EmberIssues/issues/issue_9991`: Ember 1.x の内部 AMD ローダーが
  `jquery` を **AMD モジュールとして** 要求する (npm パッケージとしてではない)。
  npm 依存を vendor しても解決しない。Ember 専用 bootstrap が要る (本 fork の
  対象外)。
- `clientIssues/ReactIssues/issues/issue_934`: インライン `<script>` が JSX で、
  parser plugin + transpilation が要る。依存問題ではない。
- `clientServerIssues/MomentIssues/issues/issue_1785`: パッチが 2 ファイル
  (`Gruntfile.js` + `moment.js`) に跨る。依存問題ではない。

## install 手順 (clone / submodule update 後に 1 回)

```bash
# fork ルートで:
./scripts/install-vendor-deps.sh
```

上記 21 箇所で `pnpm install --frozen-lockfile` が走り、lockfile から `node_modules/`
が再生成される。`pnpm` が PATH にあること (`npm i -g pnpm` または `corepack enable`)。
古い jquery の `contextify` native build を避けるため、グローバル `~/.npmrc` に
`ignore-scripts=true` が無い環境では `./scripts/install-vendor-deps.sh` の中の
`pnpm install` に `--ignore-scripts` を足してもよい (本 fork は vendor した js ソースを
読むだけで dep の native binary は使わない)。

## lockfile の再生成手順 (依存を変更したい時のみ)

```bash
cd <issue または共通ディレクトリ>
# package.json の dependencies を編集
pnpm install --lockfile-only       # node_modules を触らずに pnpm-lock.yaml だけ更新
git add package.json pnpm-lock.yaml
```

宣言依存のリストの典拠:
- server `require()` 依存 → `<lib>_before/package.json` の `dependencies`
  (ディレクトリ形式の lib) または `<lib>_before.js` の `require()` 列 (単一ファイル
  形式の lib)
- client `<script src>` 依存 → 当該 category 配下の `v_before.html` /
  `v_after.html` の `<script src>` (ハーネス `execute.js` / `jstat*` /
  `JSXTransformer.js` と SUT `<lib>_before/after.js` を除く)

## 再現性に関する注記

- lockfile はすべての transitive dep を `integrity` hash で固定するため、対象
  パッケージが npm registry に存在する限り install は byte 単位で再現される。
- 長期 archive (npm registry の package un-publish や registry outage への対策) は
  本 fork の対象外。MB-Scanner 側で将来 `nix` derivation (content-addressable cache)
  を別途用意する想定。

## 出自 (provenance)

レイアウト・版選択・版衝突戦略は MB-Scanner の **ADR-0017** ("等価検証 sandbox の
SUT 依存解決 — lockfile-vendored fork 方式") に従う。client `<script src>` 依存への
拡張 (2026-05-12) は ADR-0016 (dataset 非同梱の npm dep を fork に lockfile で宣言して
解決) の client 方面への適用。決定の根拠と評価軸の詳細は MB-Scanner リポジトリの ADR
を参照。
