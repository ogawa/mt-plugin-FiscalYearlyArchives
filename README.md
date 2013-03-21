# FiscalYearlyArchivesプラグイン

「年度別」アーカイブを生成するためのプラグイン。MT4以降で動作します。

 - [Download](https://github.com/ogawa/mt-plugin-FiscalYearlyArchives/archive/master.zip)

## 概要

FiscalYearlyArchivesは、通常の年別・月別・週別に加えて、特定月の初日を開始日とする「年度別」アーカイブを実現するプラグインです。

同様に「ユーザー 年度別」アーカイブ、「カテゴリー 年度別」アーカイブも使えます。設定方法は年度別アーカイブと共通なので以下の説明を適宜読み替えてください。

## 使い方

プラグインをインストールするには、パッケージに含まれるFiscalYearlyArchivesディレクトリをMovable Typeのプラグインディレクトリ内にアップロードもしくはコピーしてください。正しくインストールできていれば、Movable Typeのメインメニューにプラグインが新規にリストアップされます。

プラグインをインストールしただけでは、年度別アーカイブは生成されません。また、年度別アーカイブにアクセスするために必要なアーカイブリストも生成されません。以下ではその方法を説明します。

### アーカイブマッピングの設定

年度別アーカイブを生成するようにするためには、アーカイブマッピングを追加する必要があります。

具体的には以下の手順で行います。

 * 各ブログの「ダッシュボード」画面から「デザイン＞テンプレート」を選択し、「ブログテンプレートの管理」を表示します。
 * 次に「ブログテンプレートの管理」画面の右側の「クイックフィルタ」から「アーカイブテンプレート」を選択します。
 * 続いて「アーカイブテンプレートの作成」の「ブログ記事リスト」を選択して、「ブログ記事リスト」のアーカイブテンプレートの作成画面を表示します。
 * テンプレートの中身は既存の「月別ブログ記事リスト」テンプレートなどを参考にしてください。
 * 編集画面の下方の「アーカイブマッピング」の部分で「新しいアーカイブマッピングを作成」をクリックし、「種類」に「年度別」を選択して「追加」します。
 * お疲れ様でした。アーカイブマッピングの追加はこれで終了です。

デフォルトの設定では年度別アーカイブは、

	http://<hostname>/<blog directory>/fiscal/2007/index.html (2007年度)
	http://<hostname>/<blog directory>/fiscal/2006/index.html (2006年度)
	http://<hostname>/<blog directory>/fiscal/2005/index.html (2005年度)

という名前で生成されます。年度別アーカイブが生成される場所を変更する場合には、アーカイブマッピングの追加時に「パス」を変更することで実現できます。デフォルトのパスは、


	fiscal/<$MTArchiveFiscalYear$>/%i

のように設定されており、例えば以下のように書き換えればブログのディレクトリの直下の「nendo」ディレクトリに年度別アーカイブを生成することができます。

	nendo/<$MTArchiveFiscalYear$>/%i

この設定が正しく終われば、再構築時に年度別アーカイブが自動的に生成されるようになります。

### 年度別アーカイブリストを生成するための設定

年度別アーカイブリストは以下のようなテンプレート片で生成できます。

	<MTIfArchiveTypeEnabled archive_type="FiscalYearly">
	  <MTArchiveList archive_type="FiscalYearly">
	    <MTArchiveListHeader>
	    <div class="widget-archives widget">
	      <h3 class="widget-header"><$MTArchiveLabel$> アーカイブ</h3>
	      <div class="widget-content">
	        <ul class="widget-list">
	    </MTArchiveListHeader>
	          <li class="widget-list-item"><a href="<$MTArchiveLink$>"><$MTArchiveTitle$> (<$MTArchiveCount$>)</a></li>
	    <MTArchiveListFooter>
	        </ul>
	      </div>
	    </div>
	    </MTArchiveListFooter>
	  </MTArchiveList>
	</MTIfArchiveTypeEnabled>

要は、MTArchiveListコンテナのarchive_typeオプションをMonthlyにすれば月別、Yearlyにすれば年別、FiscalYearlyにすれば年度別アーカイブリストがそれぞれ生成されるということです。

このテンプレート片を年度別アーカイブリストを生成したいテンプレートに追加するとよいでしょう。

## Adavancedな機能

### 年度の開始月を変更する

FiscalYearlyArchivesは、デフォルトでは4月初日を開始日とする年度ごとのアーカイブを生成します。この年度の開始月は以下の手順で変更することができます。

 * ダッシュボード画面から「システム」ダッシュボード画面を表示します。
 * 「ツール＞プラグイン」を選択し、「システムのプラグイン設定」画面を表示します。
 * 次にプラグイン一覧の中からFiscalYearlyArchivesを選択し、「設定」タブを開きます。
 * 「年度の開始月」を選択して「変更を保存」します。

以降は、選択した開始月の初日から翌年の開始月の前月の末日までを一つの年度とする年度別アーカイブが生成されるようになります。

## テンプレートタグ

プラグインをインストールすると以下のテンプレートタグが利用可能になります。

### MTArchiveFiscalYear変数タグ

現在のアーカイブの年度を返します。オプションなどはありません。アーカイブマッピングの指定用に導入されたテンプレートタグです。

## TODO

 * ダイナミックパブリッシングに対応する。
 * 年度の開始を月で指定しているのを月日で指定できるようにする(おそらく不要)。

## 更新履歴

 - 0.01 (2007-08-24 19:00:32 +0900):
   - 公開。
 - 0.02 (2007-08-26 17:48:43 +0900):
   - 年度の開始月を設定できるようにしました。
 - 0.03 (2007-09-18 14:12:14 +0900):
   - バグフィックスリリース。
 - 0.10 (2008-05-21 17:25:21 +0900):
   - MT 4.15以降で動作するようにしました。
   - Author-FiscalYearly, Category-FiscalYearlyアーカイブに対応しました。

## License

This code is released under the Artistic License. The terms of the Artistic License are described at [here](http://www.perl.com/language/misc/Artistic.html).

## Author & Copyright

Copyright 2007, Hirotaka Ogawa (hirotaka.ogawa at gmail.com)