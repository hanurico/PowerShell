#Requires -Version 3.0

# =============================================================================
# 
# WinRM 無効化シェル
#
# 概　要：	このシェルはAnsible公式サイトで提供されているWinRM有効化PowerShellを
#		改修しWinRM、OSの状態をWinRM有効化シェル実行前の状態に戻す為の
#		シェルである。
#
# 引　数：	なし
#
# 戻り値：	0:	正　常
#		9:	異　常
#
# 実行環境：OS:	Windows Server 2012/2012 R2
# 		PowerShell:	Version 3 以上
# 		ユーザ: 管理者権限を持つローカルユーザ
# 
# 処理概要：ユーザ権限チェック
# 		Windows イベントログ(Application)作成
# 		PowerShell バージョンチェック
# 		Windows Firewall Allow WinRM HTTPS ポート削除
# 		EnableCredSSP role Server 無効化
# 		Basic 認証 無効化
# 		SSL 待受けポート削除
# 		WinRM サービス再起動(KCPSにおけるWinRMの元の状態は状態: 起動、スタートアップの種類: 自動)
# 		HTTP/HTTPS 状態確認
#
# 修正履歴：	新規作成	2017/02/16	t-hanyu
#
# Version 1.0 - 2017/02/16	Configuration RemotingForAnsible.ps1 Version 1.5 ベース

# Support -Verbose option
[CmdletBinding()]

$SubjectName = $env:COMPUTERNAME

# -------------------------------------
# 関　数
# -------------------------------------
Function Write-Log
{
    $Message = $args[0]
    Write-EventLog -LogName Application -Source $EventSource -EntryType Information -EventId 1 -Message $Message
}

Function Write-VerboseLog
{
    $Message = $args[0]
    Write-Verbose $Message
    Write-Log $Message
}

Function Write-HostLog
{
	$Message = $args[0]
	$now = Get-Date -Format "G"
	$Message2 = $now + "        " + $Message
    Write-Host $Message2
	If ($Message -ne "")
	{
		Write-Log $Message2
	}
}

# -------------------------------------
# メインルーチン
# -------------------------------------
# Setup error handling.
Trap
{
    $_
	Write-HostLog $_
    Exit 9
}
$ErrorActionPreference = "Stop"

# ユーザ権限チェック
# Get the ID and security principal of the current user account
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)

# Get the security principal for the Administrator role
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator

# Check to see if we are currently running "as Administrator"
if (-Not $myWindowsPrincipal.IsInRole($adminRole))
{
	Write-HostLog "ERROR: You need elevated Administrator privileges in order to run this script."
	Write-HostLog "       Start Windows PowerShell by using the Run as Administrator option."
	Exit 9
}

# Windows イベントログ(Application)作成
$EventSource = $MyInvocation.MyCommand.Name
If (-Not $EventSource)
{
    $EventSource = "Powershell CLI"
}

If ([System.Diagnostics.EventLog]::Exists('Application') -eq $False -or [System.Diagnostics.EventLog]::SourceExists($EventSource) -eq $False)
{
    New-EventLog -LogName Application -Source $EventSource
}

# PowerShell バージョンチェック
# Detect PowerShell version.
If ($PSVersionTable.PSVersion.Major -lt 3)
{
    Write-HostLog "PowerShell version 3 or higher is required."
    Throw "PowerShell version 3 or higher is required."
}

# Windows Firewall Allow WinRM HTTPS ポート削除
# Configure firewall to Delete "Allow WinRM HTTPS" connection.
Write-HostLog ""
$fwtest1 = netsh advfirewall firewall show rule name="Allow WinRM HTTPS"
If ($fwtest1.count -gt 5)
{
	Write-HostLog "Removing firewall rule to allow WinRM HTTPS."
	$fwdel = netsh advfirewall firewall delete rule name="Allow WinRM HTTPS"
	Write-HostLog "Removed firewall rule to allow WinRM HTTPS."
}
Else
{
    Write-HostLog "allow WinRM HTTPS rule is already removed."
}
Write-HostLog ""

# EnableCredSSP role Server 無効化
# If EnableCredSSP if set to false
# Check for CredSSP authentication
$credsspAuthSetting = Get-ChildItem WSMan:\localhost\Service\Auth | Where {$_.Name -eq "CredSSP"}
If (($credsspAuthSetting.Value) -eq $true)
{
    Write-HostLog "Disabling CredSSP auth support."
    Disable-WSManCredSSP -role server
    Write-HostLog "Disabled CredSSP auth support."
}
Else
{
	Write-HostLog "CredSSP role Server is already disabled."
}
Write-HostLog ""

# Basic 認証 無効化
# Check for basic authentication.
$basicAuthSetting = Get-ChildItem WSMan:\localhost\Service\Auth | Where {$_.Name -eq "Basic"}
If (($basicAuthSetting.Value) -eq $true)
{
    Write-HostLog "Disabling basic auth support."
    Set-Item -Path "WSMan:\localhost\Service\Auth\Basic" -Value $false
    Write-HostLog "Disabled basic auth support."
}
Else
{
    Write-HostLog "Basic auth is already disabled."
}
Write-HostLog ""

# SSL 待受けポート削除
# Delete the listener for SSL
$SSLlsnr = Get-ChildItem WSMan:\localhost\Listener | Where {$_.Keys -eq "Transport=HTTPS"}
If (!($SSLlsnr.Count -eq 0))
{
	$selectorset = @{
		Address = "*"
		Transport = "HTTPS"
	}

	$WSManInst = Get-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet $selectorset

	If (!($WSManInst.IsEmpty))
	{
		Write-HostLog "Deleting HTTPS Listener."
		Remove-WSManInstance -ResourceURI 'winrm/config/Listener' -SelectorSet $selectorset
		Write-HostLog "Deleted HTTPS Listener."
	}
}
Else
{
	Write-HostLog "SSL Listener is already Removed."
}
Write-HostLog ""

# WinRM サービス再起動
# Find and Restart the WinRM service.
Write-HostLog "Restarting WinRM service."
Restart-Service -Name "WinRM"
Write-HostLog "Restarted WinRM service."
Write-HostLog ""

# HTTP/HTTPS 状態確認
# Test a remoting connection to localhost, which should work.
$httpResult = Invoke-Command -ComputerName "localhost" -ScriptBlock {$env:COMPUTERNAME} -ErrorVariable httpError -ErrorAction SilentlyContinue
$httpsOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck

$httpsResult = New-PSSession -UseSSL -ComputerName "localhost" -SessionOption $httpsOptions -ErrorVariable httpsError -ErrorAction SilentlyContinue

If ($httpResult -and $httpsResult)
{
    Write-HostLog "HTTP: Enabled | HTTPS: Enabled"
	Write-HostLog "WinRM invalidation failed."
	Write-HostLog ""
	Throw "WinRM invalidation failed."
}
ElseIf ($httpsResult -and !$httpResult)
{
    Write-HostLog "HTTP: Disabled | HTTPS: Enabled"
	Write-HostLog "WinRM invalidation failed."
	Write-HostLog ""
	Throw "WinRM invalidation failed."
}
ElseIf ($httpResult -and !$httpsResult)
{
    Write-HostLog "HTTP: Enabled | HTTPS: Disabled"
	Write-HostLog "WinRM configuration restored successfully."
	Write-HostLog ""
	Exit 0
}
Else
{
	Write-HostLog "Exeption Err. WinRM configuration restore fail."
	Write-HostLog ""
	Throw "Exeption Err. WinRM configuration restore fail."
}
