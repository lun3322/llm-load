Write-Host "--- Building frontend... ---"
Set-Location web
npm install
if ($LASTEXITCODE -ne 0) { Write-Host "npm install failed" -ForegroundColor Red; exit 1 }
npm run build
if ($LASTEXITCODE -ne 0) { Write-Host "npm run build failed" -ForegroundColor Red; exit 1 }
Set-Location ..
Write-Host "--- Preparing backend... ---"
Write-Host "--- Starting backend... ---"
go run ./main.go
