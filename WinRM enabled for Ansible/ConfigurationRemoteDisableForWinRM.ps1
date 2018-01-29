#Requires -Version 3.0

# =============================================================================
# 
# WinRM �������V�F��
#
# �T�@�v�F	���̃V�F����Ansible�����T�C�g�Œ񋟂���Ă���WinRM�L����PowerShell��
#		���C��WinRM�AOS�̏�Ԃ�WinRM�L�����V�F�����s�O�̏�Ԃɖ߂��ׂ�
#		�V�F���ł���B
#
# ���@���F	�Ȃ�
#
# �߂�l�F	0:	���@��
#		9:	�ف@��
#
# ���s���FOS:	Windows Server 2012/2012 R2
# 		PowerShell:	Version 3 �ȏ�
# 		���[�U: �Ǘ��Ҍ����������[�J�����[�U
# 
# �����T�v�F���[�U�����`�F�b�N
# 		Windows �C�x���g���O(Application)�쐬
# 		PowerShell �o�[�W�����`�F�b�N
# 		Windows Firewall Allow WinRM HTTPS �|�[�g�폜
# 		EnableCredSSP role Server ������
# 		Basic �F�� ������
# 		SSL �Ҏ󂯃|�[�g�폜
# 		WinRM �T�[�r�X�ċN��(KCPS�ɂ�����WinRM�̌��̏�Ԃ͏��: �N���A�X�^�[�g�A�b�v�̎��: ����)
# 		HTTP/HTTPS ��Ԋm�F
#
# �C�������F	�V�K�쐬	2017/02/16	t-hanyu
#
# Version 1.0 - 2017/02/16	Configuration RemotingForAnsible.ps1 Version 1.5 �x�[�X

# Support -Verbose option
[CmdletBinding()]

$SubjectName = $env:COMPUTERNAME

# -------------------------------------
# �ց@��
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
# ���C�����[�`��
# -------------------------------------
# Setup error handling.
Trap
{
    $_
	Write-HostLog $_
    Exit 9
}
$ErrorActionPreference = "Stop"

# ���[�U�����`�F�b�N
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

# Windows �C�x���g���O(Application)�쐬
$EventSource = $MyInvocation.MyCommand.Name
If (-Not $EventSource)
{
    $EventSource = "Powershell CLI"
}

If ([System.Diagnostics.EventLog]::Exists('Application') -eq $False -or [System.Diagnostics.EventLog]::SourceExists($EventSource) -eq $False)
{
    New-EventLog -LogName Application -Source $EventSource
}

# PowerShell �o�[�W�����`�F�b�N
# Detect PowerShell version.
If ($PSVersionTable.PSVersion.Major -lt 3)
{
    Write-HostLog "PowerShell version 3 or higher is required."
    Throw "PowerShell version 3 or higher is required."
}

# Windows Firewall Allow WinRM HTTPS �|�[�g�폜
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

# EnableCredSSP role Server ������
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

# Basic �F�� ������
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

# SSL �Ҏ󂯃|�[�g�폜
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

# WinRM �T�[�r�X�ċN��
# Find and Restart the WinRM service.
Write-HostLog "Restarting WinRM service."
Restart-Service -Name "WinRM"
Write-HostLog "Restarted WinRM service."
Write-HostLog ""

# HTTP/HTTPS ��Ԋm�F
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
