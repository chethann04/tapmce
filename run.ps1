Write-Host ''=== TAP-APP Build Helper ===' -ForegroundColor Cyan
Write-Host ''Killing all Java processes...' -ForegroundColor Yellow
Get-Process -Name java,javaw -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
Write-Host ''Removing android/.gradle lock folder...' -ForegroundColor Yellow
Remove-Item -Path 'E:\TAP Application\TAP-APP\android\.gradle' -Recurse -Force -ErrorAction SilentlyContinue
E:\g = 'E:\g'
Write-Host ''GRADLE_USER_HOME = E:\g' -ForegroundColor Green
Write-Host ''Starting flutter run...' -ForegroundColor Green
flutter run
