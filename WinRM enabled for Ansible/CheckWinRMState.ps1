# =============================================================================
# 
# WinRM 状態確認化シェル
#
# 概　要：	このシェルはWinRMの状態確認を行うシェルである。
#
# 引　数：	なし
#
# 戻り値：	0:	正　常
#		    9:	異　常
#
# 実行環境：OS:	Windows Server 2012/2012 R2
# 		PowerShell:	Version 3 以上
# 		ユーザ: 管理者権限を持つローカルユーザ
# 
# 処理概要：
# 		Windows Firewall Allow WinRM エントリ確認
# 		EnableCredSSP role Server 状態確認
# 		Basic 認証 状態確認
# 		SSL 待受けポート状態確認
# 		WinRM サービス状態確認
#
# 修正履歴：	新規作成	2017/02/23	t=hanyu
#
# Version 1.0 = 2017/02/23

$resFW = netsh advfirewall firewall show rule name = "Allow WinRM HTTPS"
Write-Output "=== Windows Firewall ===================="
Write-Output $resFW
Write-Output "========================================="
Write-Output ""

$resListener = Get-ChildItem WSMan:\localhost\Listener
Write-Output "=== Listener Port ======================="
Write-Output $resListener
Write-Output "========================================="
Write-Output ""

$resAuth = Get-ChildItem WSMan:\localhost\Service\Auth\Basic
Write-Output "=== Basic Auth =========================="
Write-Output $resAuth
Write-Output "========================================="
Write-Output ""

$resAuth = Get-ChildItem WSMan:\localhost\Service\Auth\CredSSP
Write-Output "=== CredSSP Auth ========================"
Write-Output $resAuth
Write-Output "========================================="
Write-Output ""

$resSvcState = Get-WmiObject Win32_Service | Where {$_.Name -eq "WinRM"}
Write-Output "=== WinRM Status ========================"
Write-Output $resSvcState
Write-Output "========================================="
