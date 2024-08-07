# docker-compose.yml

`docker-compose.yml`ファイルは、Lagoonに以下のようなことを指示します:

* デプロイするべきサービス/コンテナを知る。
* コンテナのイメージがどのようにビルドされるかを定義する。
* 永続ボリュームのような追加の設定を定義する。

Docker Compose(ツール)はYAMLファイルの内容の検証に非常に厳格であるため、サービス定義の`labels`内でのみ設定を行うことが可能です。

!!! Warning "警告"
    Lagoonは`docker-compose.yml`ファイルからラベル、サービス名、イメージ名、ビルド定義のみを読み取ります。ポート、環境変数、ボリューム、ネットワーク、リンク、ユーザーなどの定義は無視されます。

これは意図的なもので、`docker-compose`ファイルはあなたのローカル環境の設定を定義するためのものです。Lagoonは`lagoon.type`からあなたがデプロイしているサービスのタイプを学び、そのサービスが必要とするポート、ネットワーク、その他の追加設定について知ることができます。

以下に、Drupal用の`docker-compose.yml`ファイルの簡単な例を示します:

```yaml title="docker-compose.yml"
version: '2.3'

x-lagoon-project:
  # Lagoonプロジェクト名(これを編集する際は`&lagoon-project`を残してください)
  &lagoon-project drupal-example

x-volumes:
  &default-volumes
 # Dockerコンテナにリアルタイムでマウントしたいすべてのボリュームを定義します
    volumes:
      - .:/app:delegated

x-environment:
  &default-environment
    LAGOON_PROJECT: *lagoon-project
    # ローカルで使用するルート。pygmyを使用している場合、このルートは *必ず* .docker.amazee.ioで終わるようにしてください
    LAGOON_ROUTE: http://drupal-example.docker.amazee.io
    # 本番環境と同様の動作をさせたい場合はコメントアウトを解除してください
    #LAGOON_ENVIRONMENT_TYPE: production
    # Xdebugを有効にし、`docker-compose up -d`で再起動したい場合はコメントアウトを解除してください
    #XDEBUG_ENABLE: "true"

x-user:
  &default-user
    # コンテナが実行されるべきデフォルトのユーザー。Linux上でID `1000`以外のユーザーで実行する場合はこれを変更します
    user: '1000'

services:

  nginx:
    build:
      context: .
      dockerfile: nginx.dockerfile
    labels:
      lagoon.type: nginx-php-persistent # (1)
      lagoon.persistent: /app/web/sites/default/files/

  php:
    build:
      context: .
      dockerfile: php.dockerfile
    labels:
      lagoon.type: nginx-php-persistent # (2)
      lagoon.name: nginx
      lagoon.persistent: /app/web/sites/default/files/

  mariadb:
    image: uselagoon/mariadb-10.11-drupal
    labels:
      lagoon.type: mariadb
```

1. ここで[マルチコンテナポッド](docker-compose-yml.md#multi-container-pods)に注目してください。
2. ここで[マルチコンテナポッド](docker-compose-yml.md#multi-container-pods)に注目してください。

## 基本設定 { #basic-settings }

`x-lagoon-project`:

これはプロジェクトのマシン名で、ここで定義します。"drupal-example"を使用します。

`x-volumes`:

これはLagoonにコンテナにマウントするものを指示します。ウェブアプリケーションは`/app`に存在しますが、必要に応じてこれを追加または変更することができます。

`x-environment`:

1. ここでローカル開発URLを設定できます。pygmyを使用している場合、`.docker.amazee.io`で終わらなければなりません。
2. 本番環境を完全に模倣したい場合は、`LAGOON_ENVIRONMENT_TYPE: production` のコメントを外します。
3. Xdebugを有効にしたい場合は、`DEBUG_ENABLE: "true"` のコメントを外します。

`x-user`:

Linuxを使用していて、`1000`以外のユーザーで実行したい場合を除き、これを変更する必要はほとんどありません。

## **`services`** { #services }

これはデプロイしたいすべてのサービスを定義します。 _残念ながら、_ Docker Composeはそれらをサービスと呼びますが、実際にはコンテナです。これからはサービスと呼ぶことにします、そしてこのドキュメンテーション全体で。

その サービスの名前(上記の例では `nginx`、`php`、`mariadb`)は、Lagoonによって生成されるKubernetesのポッドの名前(また別の用語 - これからはサービスと呼びます)として使用され、さらに定義された `lagoon.type`に基づいて作成されるKubernetesのオブジェクトの名前としても使用されます。これには、サービス、ルート、永続的なストレージなどが含まれる可能性があります。

サービス名は[RFC 1035](https://tools.ietf.org/html/rfc1035)のDNSラベル標準に準拠していることに注意してください。サービス名は以下の要件を満たす必要があります:

* 最大63文字を含む
* 小文字の英数字または'-'のみを含む
* 英字で始まる
* 英数字で終わる

!!! Warning "警告"
    サービスの名前を設定したら、それを改名しないでください。これにより、コンテナ内で様々な問題が発生し、物事が壊れる可能性があります。

### Dockerイメージ { #docker-images }

#### `build` { #build }

デプロイメントごとにLagoonがあなたのサービスのDockerfileをビルドしてほしい場合、ここで定義できます:

`build`

* `context`
  * `docker build` コマンドに渡すべきビルドコンテキストパス。
* `dockerfile:`
  * ビルドするべきDockerfileの場所と名前。

!!! Warning "警告"
    Lagoonは短縮バージョンをサポートしていません `build: <Dockerfile>`の定義が見つかった場合、処理は失敗します。

#### `image` { #image }

Dockerfileをビルドする必要がなく、既存のDockerfileを使用したい場合は、`image`で定義します。

### タイプ { #types }

Lagoonは、KubernetesやOpenShiftのオブジェクトを正しく設定するために、デプロイするサービスのタイプを知る必要があります。

これは`lagoon.type`ラベルを通じて行われます。選択できるタイプは多数あります。すべてのタイプと追加設定の可能性を見るには、[Service Types](../concepts-advanced/service-types.md)を確認してください。

#### コンテナのスキップ/無視 { #skipignore-containers }

たとえば、ローカル開発時にのみコンテナが必要な場合など、Lagoonにサービスを完全に無視させたい場合は、そのタイプに`none`を指定します。

### 永続的なストレージ { #persistent-storage }

一部のコンテナには永続的なストレージが必要です。Lagoonでは、各コンテナが最大1つの永続的なストレージボリュームをコンテナに接続できるようにしています。コンテナに自身の永続的なストレージボリュームを要求させることができます(それは他のコンテナにマウント可能)、または、コンテナに他のコンテナが作成した永続的なストレージをマウントするよう指示することもできます。

多くの場合、Lagoonはその永続的なストレージがどこに行くべきかを知っています。たとえば、 例えば、MariaDBコンテナの場合、Lagoonは永続的なストレージを`/var/lib/mysql`に配置すべきと知っており、それを定義するための追加の設定なしに自動的にそこに配置します。ただし、一部の状況では、Lagoonは永続的なストレージをどこに配置すべきかを知るためにあなたの助けが必要です。

* `lagoon.persistent` - 永続的なストレージをマウントすべき**絶対**パス(上記の例では`/app/web/sites/default/files/`を使用しており、これはDrupalが永続的なストレージを期待する場所です)。
* `lagoon.persistent.name` - Lagoonにそのサービスの新しい永続的なストレージを作成しないように指示し、代わりに他の定義済みのサービスの永続的なストレージをこのサービスにマウントします。
* `lagoon.persistent.size` - 必要な永続的なストレージのサイズ(Lagoonは通常、最小5Gの永続的なストレージを提供します。もしもっと必要なら、ここで定義してください)。
* `lagoon.persistent.class` - デフォルトではLagoonは自動的に適切なストレージクラス(MySQLのSSD、Nginxの大量ストレージなど)をサービスに割り当てます。これを上書きする必要がある場合は、ここで行うことができます。これは、Lagoonが動作するKubernetes/OpenShiftの基礎となるものに大きく依存します。これについてはLagoonの管理者に問い合わせてください。

### 自動生成されるルート { #auto-generated-routes }

docker-compose.ymlファイルは、サービスごとに[自動生成されるルート](./lagoon-yml.md#routes)を有効または無効にすることもサポートしています。

* `lagoon.autogeneratedroute: false` ラベルを使用すると、そのサービスに対して自動的に生成されるルートが停止します。これは自動生成されるルートを持つすべてのサービスに適用できますが、データベースサービスなどの追加の内部向けサービスを作成する際に[`basic`](../concepts-advanced/service-types.md#basic)および[`basic-persistent`](../concepts-advanced/service-types.md#basic-persistent)サービスタイプで特に便利です。逆もまた真であり、.lagoon.ymlファイルがそれらを[無効にする](lagoon-yml.md#routesautogenerate)ときに、サービスに対して自動生成されるルートを有効にします。

## マルチコンテナーポッド { #multi-container-pods }

KubernetesとOpenShiftは単純なコンテナーをデプロイしません。代わりに、それぞれが1つ以上のコンテナーを持つポッドをデプロイします。通常、Lagoonは定義された`docker-compose`サービスごとにコンテナーが内部にある単一のポッドを作成します。しかし、あるケースでは、これらのコンテナーが互いに非常に依存していて、常に一緒にいるべきであるため、単一のポッド内に2つのコンテナーを配置する必要があります。そのような状況の一例は、PHPです。 およびDrupalのようなWebアプリケーションのPHPコードを含むNGINXコンテナ。

これらのケースでは、どのサービスが一緒に残るべきかをLagoonに伝えることが可能で、次のように行います(私たちがコンテナを`docker-compose`のために`services`と呼んでいることを覚えておいてください):

1. 両方のサービスを、二つのサービスを期待する`lagoon.type`で定義します(この例では、`nginx`と`php`サービスで定義されている`nginx-php-persistent`です)。
2. 第二のサービスを第一のサービスにリンクし、第二のサービスのラベル`lagoon.name`を第一のサービスで定義します(この例では、`lagoon.name: nginx`を定義することで行います)。

これにより、Lagoonは`nginx`と`php`コンテナが`nginx`と呼ばれるポッドに組み合わせられていることを認識します。

!!! Warning "警告"
    サービスの`lagooon.name`を設定したら、それをリネームしないでください。これはあなたのコンテナで混乱を引き起こし、物事を壊す原因となります。

Lagoonはまだ、二つのサービスのうちどちらが実際の個別のサービスタイプであるか(この場合は`nginx`と`php`)を理解する必要があります。これは、タイプが与える同じ名前のサービス名を検索することで行います、したがって`nginx-php-persistent`は`ng`という名前のサービスを一つ期待します。 `inx`と`php`を含む`docker-compose.yml`があります。何らかの理由でサービスの名前を変更したい場合や、`nginx-php-persistent`タイプのポッドを複数必要とする場合は、追加のラベル`lagoon.deployment.servicetype`を使用して実際のサービスタイプを定義することができます。

例:

```yaml title="docker-compose.yml"
nginx:
    build:
      context: .
      dockerfile: nginx.dockerfile
    labels:
      lagoon.type: nginx-php-persistent
      lagoon.persistent: /app/web/sites/default/files/
      lagoon.name: nginx # これがないと、Lagoonはコンテナ名、つまりこの場合はnginxを使用します。
      lagoon.deployment.servicetype: nginx
php:
    build:
      context: .
      dockerfile: php.dockerfile
    labels:
      lagoon.type: nginx-php-persistent
      lagoon.persistent: /app/web/sites/default/files/
      lagoon.name: nginx # このサービスをLagoonのNGINXポッドの一部にしたい。
      lagoon.deployment.servicetype: php
```

上記の例では、サービス名は`nginx`と`php`です(しかし、好きな名前をつけることができます)。`lagoon.name`はLagoonにどのサービスが一緒に行くかを伝えます - 同じ名前のすべてのサービスは一緒に行きます。 一緒に。

Lagoonがどれが `nginx` で、どれが `php` サービスであるかを認識するために、これを `lagoon.deployment.servicetype: nginx` および `lagoon.deployment.servicetype: php` で定義します。

## ヘルムテンプレート (Kubernetesのみ) { #helm-templates-kubernetes-only }

LagoonはKubernetesでのテンプレート作成に[Helm](https://helm.sh/)を使用します。これには、`build-deploy-tool` イメージに含まれる一連の[チャート](https://github.com/uselagoon/build-deploy-tool/tree/main/legacy/helmcharts)が必要です。

## カスタムロールアウトモニタータイプ { #custom-rollout-monitor-types }

デフォルトでは、LagoonはカスタムテンプレートからのサービスがKubernetesまたはOpenshift内の [`DeploymentConfig`](https://docs.openshift.com/container-platform/4.4/applications/deployments/what-deployments-are.html#deployments-and-deploymentconfigs_what-deployments-are) オブジェクトを介してロールアウトされることを期待しています。それに基づいてロールアウトを監視します。場合によっては、カスタムデプロイメントで定義されたサービスが異なる監視方法を必要とすることがあります。これは `lagoon.rollout` を通じて定義することができます:

* `deploymentconfig` - これがデフォルトです。 [`DeploymentConfig`](https://docs.openshift.com/container-platform/4.4/applications/deployments/what-deployments-are.html#deployments-and-deployment を期待します。 サービスのテンプレート内の[`Statefulset`](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)オブジェクトを期待します。
* `daemonset` - サービスのテンプレート内の[`Daemonset`](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)オブジェクトを期待します。
* `false` - ロールアウトを監視せず、テンプレートが適用されエラーが発生しなければ満足します。

また、特定の環境のみにロールアウトを上書きすることもできます。これは[`.lagoon.yml`](lagoon-yml.md#environments-name-rollouts)で行います。

## Docker Compose v2互換性 { #docker-compose-v2-compatibility }

!!! Bug "バグ"
    ローカルでDocker Compose V2の古いバージョンを使用していると、一部の既知の問題が発生することがあります - これらの問題は後のリリース(v2.17.3以降)で解決されています。

これらのエラーの解決策は通常、使用しているDocker Composeのバージョンを更新するか(または[新しいバージョンをインストールする](https://docs.docker.com/compose/install/))、あるいは使用しているDocker Desktopのバージョンをアップグレードすることです。 Docker Desktopの[リリースノート](https://docs.docker.com/desktop/release-notes/)を参照してください。 詳しくは

``` shell title="依存関係のエラーを示すDocker Compose出力"
Failed to solve with frontend dockerfile.v0: failed to create LLB definition: pull access denied, repository does not exist or may require authorization

または

Failed to solve: drupal9-base-cli: pull access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed`
```

* これらはDocker Compose v2.13.0で解決されます。
* このメッセージは、ビルドがまだビルドされていないDockerイメージにアクセスしようとしたことを意味します。BuildKitは並列にビルドするため、もしもう一つのDockerイメージを継承するものがある場合(DrupalのCLIのように)はこの事象が発生します。
* マルチステージビルドとして再設定するために、ビルド内の[target](https://docs.docker.com/compose/compose-file/build/#target)フィールドを使用することもできます。
* すでに新しいDocker Composeバージョンを実行している場合、このエラーは、docker-containerビルドコンテキストをbuildxでデフォルトにしている可能性があります。`docker buildx ls`がdocker-containerベースのものではなく、docker builderをデフォルトとして表示することを確認する必要があります。Docker buildxのドキュメントは[こちら](https://docs.docker.com/engine/referenceです。 /commandline/buildx_use/).

``` shell title="volumes_from エラーを示す Docker Compose 出力"
no such service: container:amazeeio-ssh-agent
```

* この問題はDocker Compose v2.17.3で解決されています。
* このメッセージは、ローカルで実行されているコンテナへのSSHアクセスを提供するサービスが、あなたのDocker Composeスタックの外部で実行され、アクセスできないことを意味します。
* あなたのローカル環境からSSHアクセスが必要ない場合、`docker-compose.yml`ファイルからこのセクションを削除することもできます。

## BuildKitとLagoon { #buildkit-and-lagoon }

BuildKitは、ソースコードを効率的で表現力豊かで繰り返し利用可能な方法でビルド成果物に変換するためのツールキットです。

Lagoon v2.11.0のリリースにより、Lagoonはより高度なBuildKitベースのdocker-composeビルドをサポートするようになりました。プロジェクトまたは環境でBuildKitを有効にするには、Lagoonプロジェクトまたは環境に`DOCKER_BUILDKIT=1`をビルド時の変数として追加してください。

## LagoonビルドでのDocker Composeエラー { #docker-compose-errors-in-lagoon-builds }

Docker Composeで一般的なビルドエラーの解決方法については、[Lagoonビルドエラーページ](../using-lagoon-the-basics/lagoon-build-errors-and-warnings.md#docker-compose-errors)を参照してください。

## よくあるDocker Composeの問題 { #common-docker-compose-issues }

このセクションでは、より一般的な Docker Composeのエラーとその対処法。これらはローカル開発で発生するか、または[Lagoonビルドエラーと警告](../using-lagoon-the-basics/lagoon-build-errors-and-warnings.md#docker-compose-errors)として発生するかもしれません。

### 二重マッピングキー { #dual-mapping-keys }

``` shell title="マッピングキーのエラーを示すDocker Composeの出力"
ERR: yaml: unmarshal errors: line 22: mapping key "<<" already defined at line 21
```

Lagoonの初期リリースでは、ボリュームとユーザーコードを提供するために、サービスにYAMLエイリアスのペアが添付されていました。Docker Composeの新しいリリースでは、これをエラーとして報告します。すべての例が現在更新されているものの、更新が必要な古いコードベースがあるかもしれません。

このエラーは、Docker Composeが配列に何を挿入しているのか分からないため、重複していると仮定して発生します。

あなたの`docker-compose.yml`がこの(または類似の)コードブロックを一つ以上含んでいる場合、あなたは影響を受けます。

``` yaml title="二重マッピングキーを含むDocker Composeのエラー"
...
    << : [*default-volumes]
    << : [*default-user]
...
```

修正版では、両方のエイリアスを1つのマッピングキーに統合します - すべての発生を対処する必要があります。

``` yaml title="Docker Compose correct 複数のエイリアスマッピングキーの挿入"
...
    << : [*default-volumes, *default-user]
...
```
