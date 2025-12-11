直感的にカーソルを移動するためのneovimプラグイン
操作方法は https://github.com/skanehira/jumpcursor.vim と同じ

jumpcursor.vim との違い

マルチバイトに対応している
カスタマイズできる:
    ハイライトグループ
    移動する文字
    ラベル (これは jumpcursor.vim でもできる)
    ラベルのnamespace
カスタマイズにグローバル変数を使わず引数を使う
行を無視し さらにマーク数の最適化もするので ほとんど小文字のマークだけで足りる
luaモジュールである

使い方:
    このディレクトリをruntimepathに追加し require("select_position") する
    詳細はhelpを参照

luaの regex モジュールが必要
場所: https://github.com/stg73/modules.nvim
