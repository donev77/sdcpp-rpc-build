$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
git clone https://github.com/leejet/stable-diffusion.cpp.git source
Push-Location source
git checkout 532d2c1
git submodule update --init --recursive
$rev = (Get-Content ggml/scripts/sync-llama.last).Trim()
Write-Host "Matching llama.cpp revision: $rev"
curl.exe -fL --retry 3 -o rpc-server.cpp "https://raw.githubusercontent.com/ggml-org/llama.cpp/$rev/tools/rpc/rpc-server.cpp"
Add-Content CMakeLists.txt ([Environment]::NewLine + 'add_executable(rpc-server rpc-server.cpp)')
Add-Content CMakeLists.txt 'target_link_libraries(rpc-server PRIVATE ggml)'
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="/DGGML_MAX_NAME=160" -DCMAKE_CXX_FLAGS="/bigobj /DGGML_MAX_NAME=160" -DSD_VULKAN=ON -DSD_RPC=ON -DSD_BUILD_SHARED_LIBS=ON -DSD_BUILD_SHARED_GGML_LIB=ON -DSD_SERVER_BUILD_FRONTEND=OFF -DGGML_NATIVE=OFF -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON
cmake --build build --target sd-cli rpc-server --parallel 4
Pop-Location
New-Item -ItemType Directory -Force dist | Out-Null
Get-ChildItem source/build -Recurse -File | Where-Object {
    $_.Extension -eq '.dll' -or $_.Name -in @('sd-cli.exe','rpc-server.exe')
} | ForEach-Object { Copy-Item $_.FullName dist -Force }
foreach ($file in @('sd-cli.exe','rpc-server.exe','ggml-rpc.dll','ggml-vulkan.dll')) {
    if (!(Test-Path "dist/$file")) { throw "Missing binary: $file" }
}
Push-Location dist
.\rpc-server.exe --help
Pop-Location
