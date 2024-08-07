# プロジェクトデフォルトユーザーとSSHキー

Lagoonプロジェクトが作成されると、デフォルトで関連するSSH "プロジェクトキー"が生成され、その秘密キーがプロジェクトのCLIポッド内で利用可能になります。サービスアカウント`default-user@project`も作成され、プロジェクトへの`MAINTAINER`アクセスが付与されます。SSH "プロジェクトキー"は、その`default-user@project`に添付されます。

これにより、任意の環境のCLIポッド内から同じプロジェクト内の他の任意の環境にSSHでアクセスすることが可能になります。このアクセスは、環境間でデータベースを同期化するなど、コマンドラインからタスクを実行するために使用されます(例:drush `sql-sync`)。

`MAINTAINER`ロールについての詳しい情報は、[RBAC](../interacting/rbac.md)のドキュメンテーションにあります。

## プロジェクトキーの指定

プロジェクトを作成する際にSSH秘密キーを指定することは可能ですが、これにはセキュリティ上の問題があるため推奨されません。
