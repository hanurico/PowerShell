. .\logmod.ps1

$LogPath = ".\Test.log"

$Summary = "SUMMARY_SUMMARY"


log_start $LogPath $Summary

log_write $LogPath "     OK     okokokokokokokokokokokokokokokokokokokokok"
log_write $LogPath "     OK     okokokokokokokokokokokokokokokokokokokokok"
log_write $LogPath "     OK     okokokokokokokokokokokokokokokokokokokokok"
log_write $LogPath "     NG     "

log_end $LogPath $Summary 0

log_end $LogPath $Summary 9


