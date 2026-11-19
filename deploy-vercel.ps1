# Apna Store - Vercel Deployment Script
param (
    [string]$SupabaseUrl = "https://ycpcddegzsdjdnrnoxpk.supabase.co",
    [string]$SupabaseAnonKey = "sb_publishable_OitX-6C7RRwDT10V8QMPrw_ouIlF6it"
)

Write-Host "1. Building Flutter Web release with Supabase config..." -ForegroundColor Cyan
flutter build web --release --dart-define=SUPABASE_URL=$SupabaseUrl --dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey --dart-define=APP_ENV=production
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
    if ($cfg.PSObject.Properties.Match('buildCommand').Count -gt 0) {
        $cfg.PSObject.Properties.Remove('buildCommand')
    }
    $cfg | ConvertTo-Json -Depth 10 | Set-Content build/web/vercel.json
}

Write-Host "3. Deploying build/web to Vercel production..." -ForegroundColor Cyan
vercel deploy build/web --prod --yes
