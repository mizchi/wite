# ADR 0001: `wite.cfp_const_hints` による const-forwarding optimize hint

- Status: Accepted (Experimental)
- Date: 2026-03-21

## Context

`wite` は `wasm-opt` との差分を詰める中で、producer が確実に知っている wrapper 構造を
optimizer 側へ伝えたい場面がある。特に `const-forward` / `interleaved-const` 系 wrapper は、
最終 wasm だけを見た auto detect では取りこぼしが出やすい。

一方で、producer 固有 metadata に最適化器全体を依存させると再利用性が落ちる。そこで
`wite` は producer 非依存の custom section 規約として `wite.cfp_const_hints` を受け付け、
experimental flag が有効なときだけ `cfp-const` と `cfp-const-specialize` の seed に使う。

この ADR は、`vibe` を含む producer がこの hint を埋めるときの契約を固定する。

## Decision

`wite` は core wasm に埋め込まれた custom section `wite.cfp_const_hints` v1 を読む。

- section 名は `wite.cfp_const_hints`
- section は advisory であり、`wite` は常に無視してよい
- default では無効で、`enable_experimental_cfp_const_hints=true` の optimize 実行だけが読む
- CLI では `--experimental-cfp-const-hints` または `--enable-experimental-cfp-const-hints` で有効化する
- hint は `cfp-const` と `cfp-const-specialize` の candidate を与えるだけで、最適化を強制しない

## Schema

payload v1:

```text
version: u32 = 1
entry_count: u32
repeat entry_count times:
  wrapper_index: u32
  target_index: u32
  arg_instr_count: u32
  repeat arg_instr_count times:
    instr_len: u32
    instr_bytes: byte[instr_len]
```

`wrapper_index` / `target_index` は import を含んだ absolute function index とする。

`instr_bytes` は target へ渡す引数 recipe を表す raw wasm instruction bytes で、v1 では次のみ許可する。

- `local.get <wrapper_param_index>`
- `i32.const`
- `i64.const`
- `f32.const`
- `f64.const`

各 `instr_bytes` は「1 引数 = 1 instruction」でなければならない。余計な bytes を含んではならない。

## Producer Contract

producer は次を満たす entry だけを出力する。

- `wrapper_index` / `target_index` は emitted wasm に対する実 index と一致する
- arg recipe は target の全 param を順に埋める
- `local.get` は wrapper param のみを参照し、wrapper local を参照しない
- wrapper の各 param は recipe 全体でちょうど 1 回だけ使う
- 重複参照、未使用 param、block/if/call など複合命令は出さない
- malformed section や unknown version を consumer が無視してよい前提で作る

この契約は producer に対する「最適化候補の宣言」であって、意味論の保証ではない。
`pure`, `no-trap`, `alias-free` のような強い意味論はこの section には載せない。

## Consumer Semantics

### `cfp-const`

hint entry は次を満たすときだけ alias candidate になる。

- wrapper が local function
- wrapper と target の function type が recipe と整合する
- recipe に const arg が 1 つ以上ある
- 各 recipe instruction が raw bytes 全体でちょうど 1 命令として decode できる
- scratch local が必要な場合、wrapper param type を 1-byte value type として再構成できる
- 既存 auto detect alias がある場合はそちらを優先する

さらに既存 `cfp-const` の profitability 判定を通った場合のみ rewrite する。

### `cfp-const-specialize`

structural に valid な hint でも、specialize は次を満たす場合だけ候補になる。

- wrapper が root ではない
- wrapper が local decl を持たない
- target が local function
- target の direct caller 数が 1
- recipe が scratch local を必要とする
- 既存の type / profitability / root policy をすべて通る

つまり hint は「この形の wrapper がある」という情報だけを渡し、発火可否は optimizer 側の既存 heuristic で決める。

## Observability

experimental flag が有効な場合、consumer は hint の観測結果を次に出す。

- `analyze host`
  - section 数
  - unknown version section 数
  - malformed section 数
  - parsed entry 数
  - usable entry 数
  - `cfp-const` structural reject reason 件数
  - `cfp-const-specialize` candidate 数
  - `cfp-const-specialize` reject reason 件数
- `OptimizeResult.observations`
  - 通常 optimize でも同じ hint 集計を返す
  - multi-round のときだけ `round#N:` を前置する
  - component optimize では `core#M:` を前置する
- `analyze optimize metadata`
  - DCE stage の `observations` に同じ集計を入れる
  - その stage で `cfp-const` / `cfp-const-specialize` が実際に発火したかも併記する

主な reject reason は次。

`cfp-const` structural reject:

- `wrapper-not-local`
- `self-target`
- `wrapper-index-out-of-range`
- `target-index-out-of-range`
- `wrapper-type-missing`
- `target-type-missing`
- `recipe-type-mismatch`
- `scratch-local-types-unsupported`

`cfp-const-specialize` reject:

- `wrapper-root`
- `wrapper-body-missing`
- `wrapper-index-out-of-range`
- `wrapper-type-missing`
- `wrapper-has-locals`
- `self-target`
- `target-root`
- `target-direct-callers!=1`
- `target-not-local`
- `target-index-out-of-range`
- `target-body-missing`
- `target-type-missing`
- `scratch-not-needed`
- `cfp-const-still-profitable`
- `recipe-type-mismatch`
- `specialize-build-invalid`

## Strip Policy

`wite.cfp_const_hints` を使った `cfp-const` または `cfp-const-specialize` の rewrite が成功した場合、
consumer は最終出力からその section を除去してよい。

experimental flag が無効な場合、consumer はこの section を hint としては読まず、
通常の custom section として扱う。

rewrite が発火しなかった場合に常に strip するかは未確定であり、現状は analyze/debug 運用を見ながら決める。

## Guidance For `vibe`

`vibe` がこの hint を埋めるときは次の順で実装する。

1. wrapper / target の最終 function index を確定した後に section を組み立てる
2. recipe は target param 順に raw wasm instruction bytes へ落とす
3. `local.get` は wrapper param だけを指すようにし、local/temp を混ぜない
4. wrapper param の重複使用や未使用があれば hint を出さない
5. 最初は `const-forward` / `interleaved-const` だけを対象にし、他の意味論は載せない
6. optimize 時は experimental flag を opt-in で渡し、`analyze host` / `OptimizeResult.observations` で結果を確認する

## Consequences

- producer は optimizer が auto detect しづらい wrapper 情報を安全に渡せる
- `wite` は producer 非依存のまま hint を解釈できる
- hint は advisory なので miscompile リスクを限定しやすい
- その代わり、サイズ改善は既存 heuristic に依存し、hint を付けても必ず最適化されるわけではない

## Follow-ups

- `cfp` / `signature-refining` 系にも同じ方式の hint を広げるかを検討する
- `wite.cfp_const_hints` v2 を設計する場合は version を上げ、v1 consumer が安全に無視できる形を保つ
