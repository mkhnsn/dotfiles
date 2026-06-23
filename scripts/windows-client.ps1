#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the Windows-side OpenShift client toolchain for the WSL dev box.

.DESCRIPTION
    Run this ONCE from *Windows PowerShell* (not WSL). It installs the tools that
    the client doc expects on the Windows side and that the WSL dotfiles then shim
    into WSL (Podman / Helm / oc). chezmoi (running in WSL) deliberately does NOT
    install Windows software — this script keeps that boundary explicit.

    The repo lives in WSL; from Windows you can run this via:
        \\wsl$\<distro>\home\<you>\.local\share\chezmoi\scripts\windows-client.ps1

    Idempotent: winget skips already-installed packages; oc is only downloaded if missing.

.NOTES
    CRC and its FIPS bundle require a Red Hat pull secret (auth) and cannot be fully
    automated — see the printed instructions at the end.
#>

$ErrorActionPreference = 'Stop'

function Info($msg)  { Write-Host "[windows-client] $msg" -ForegroundColor Cyan }
function Warn($msg)  { Write-Host "[windows-client] $msg" -ForegroundColor Yellow }

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Warn "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
    return
}

function Install-WingetPackage($id, $name) {
    Info "installing $name ($id)..."
    winget install -e --id $id --accept-source-agreements --accept-package-agreements `
        --disable-interactivity 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0)            { Info "$name installed." }
    elseif ($LASTEXITCODE -eq -1978335189) { Info "$name already installed." }  # APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE / no upgrade
    else                                { Warn "${name}: winget exit $LASTEXITCODE (may already be present)." }
}

# ---- winget packages ----
Install-WingetPackage 'RedHat.Podman'          'Podman'
Install-WingetPackage 'RedHat.Podman-Desktop'  'Podman Desktop'
Install-WingetPackage 'Helm.Helm'              'Helm'
Install-WingetPackage 'Git.Git'                'Git for Windows'

# ---- oc (OpenShift CLI) from the public mirror ----
$ocDir = Join-Path $env:LOCALAPPDATA 'Programs\oc'
if (Get-Command oc.exe -ErrorAction SilentlyContinue) {
    Info "oc already on PATH; skipping."
} else {
    Info "downloading oc (OpenShift CLI)..."
    New-Item -ItemType Directory -Force -Path $ocDir | Out-Null
    $zip = Join-Path $env:TEMP 'openshift-client-windows.zip'
    $url = 'https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-windows.zip'
    try {
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $ocDir -Force
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
        # Add oc dir to the user PATH (idempotent).
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        if ($userPath -notlike "*$ocDir*") {
            [Environment]::SetEnvironmentVariable('Path', "$userPath;$ocDir", 'User')
            Info "added $ocDir to user PATH (restart shells to pick it up)."
        }
        Info "oc installed to $ocDir."
    } catch {
        Warn "oc download failed: $($_.Exception.Message)"
        Warn "Grab it manually from the Red Hat console: https://console.redhat.com/openshift/downloads"
    }
}

# ---- CRC + FIPS bundle (manual; auth-gated) ----
Write-Host ""
Warn "CRC (OpenShift Local) + the FIPS bundle need a Red Hat pull secret and are not automated:"
Write-Host "  1. Download CRC:        https://console.redhat.com/openshift/create/local"
Write-Host "  2. Download the FIPS bundle (Hyper-V) from the same page."
Write-Host "  3. crc setup --bundle <path-to-fips-bundle.crcbundle>"
Write-Host ""
Info "Done. In WSL, run 'chezmoi apply' so podman/helm/oc get symlinked from these Windows binaries."
