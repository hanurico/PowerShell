# ==============================================================================
#
#
#
#
#
# ==============================================================================


# ------------------------------------------------------------------------------
# Over View: Log Start
#
# Arguments: $argLogPath: Log File FullPath
#            $argSummary: Script Name
#
#    Result: None
# ------------------------------------------------------------------------------
function log_start ($argLogPath, $argSummary) {
    $msg = (Get-Date).ToString() + " ----- $Summary --- Start --------------------"
    Write-Host $msg
    Write-Output $msg | Out-File $argLogPath -Append
}


# ------------------------------------------------------------------------------
# Over View: Log End
#
# Arguments: $argLogPath: Log File FullPath
#            $argMessage: Logging Message
#
#    Result: None
# ------------------------------------------------------------------------------
function log_write ($argLogPath, $argMessage) {
    $msg = (Get-Date).ToString() + $argMessage
    Write-Host $msg
    Write-Output $msg | Out-File $argLogPath -Append
}


# ------------------------------------------------------------------------------
# Over View: Log End
#
# Arguments: $argLogPath: Log File FullPath
#            $argSummary: Script Name
#            $argEndFlg: Script End Flag
#
#    Result: None
# ------------------------------------------------------------------------------
function log_end ($argLogPath, $argSummary, $argEndFlg) {
    $msg = (Get-Date).ToString() + ""
    Write-Host $msg
    Write-Output $msg | Out-File $argLogPath -Append

    if ( $argEndFlg -eq 0 ) {
        $msg = (Get-Date).ToString() + " ----- $Summary --- Success End --------------------"
    } elseif ( $argEndFlg -eq 9 ) {
        $msg = (Get-Date).ToString() + " !!!!! $Summary --- Error End !!!!!!!!!!!!!!!!!!!!!!"
    }
    Write-Host $msg
    Write-Output $msg | Out-File $argLogPath -Append

    $msg = (Get-Date).ToString() + ""
    Write-Host $msg
    Write-Output $msg | Out-File $argLogPath -Append
}
