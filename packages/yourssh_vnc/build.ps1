$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "rust")
cargo build --release
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force -Path "assets/native/windows" | Out-Null
Copy-Item "rust/target/release/yourssh_vnc.dll" "assets/native/windows/"
Write-Host "yourssh_vnc native library built"
