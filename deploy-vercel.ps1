# Apna Store - Vercel Deployment Script
Write-Host "1. Building Flutter Web release..." -ForegroundColor Cyan
flutter build web --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build failed."
    exit $LASTEXITCODE
}

Write-Host "2. Preparing Vercel configuration for build/web..." -ForegroundColor Cyan
if (Test-Path .vercel) {
    Copy-Item -Path .vercel -Destination build/web/.vercel -Recurse -Force
}

if (Test-Path vercel.json) {
    $cfg = Get-Content vercel.json -Raw | ConvertFrom-Json
    if ($cfg.PSObject.Properties.Match('outputDirectory').Count -gt 0) {
        $cfg.PSObject.Properties.Remove('outputDirectory')
    }
    $cfg | ConvertTo-Json -Depth 10 | Set-Content build/web/vercel.json
}

Write-Host "3. Deploying to Vercel production..." -ForegroundColor Cyan
vercel deploy build/web --prod --yes
