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
# Helm is installed NATIVELY in WSL at v3.x by run_dev-openshift.sh -- the winget Helm is v4.x,
# which breaks Helm-3 charts -- so it is intentionally NOT installed on Windows.
Install-WingetPackage 'Git.Git'                'Git for Windows'

# ---- Podman machine (Podman needs a running Linux VM to pull images / log in) ----
$podmanExe = (Get-Command podman.exe -ErrorAction SilentlyContinue).Source
if (-not $podmanExe) { $podmanExe = Join-Path $env:ProgramFiles 'RedHat\Podman\podman.exe' }
if (Test-Path $podmanExe) {
    # podman writes progress to stderr; with $ErrorActionPreference='Stop' PowerShell turns
    # that into a terminating NativeCommandError, so relax it for just these native calls.
    $eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $machines = & $podmanExe machine list --noheading 2>$null
    if (-not $machines) {
        # --rootful: on WSL the rootless user socket often fails to come up, so the
        # client can't reach the machine ("ssh: rejected: connect failed"). The rootful
        # system socket is reliable, and container dev usually wants root anyway.
        Info "initializing the podman machine (one-time; downloads a VM image, a few minutes)..."
        & $podmanExe machine init --rootful
    }
    Info "ensuring the podman machine is running (no-op if already running)..."
    & $podmanExe machine start
    $ErrorActionPreference = $eap
} else {
    Warn "podman.exe not on PATH yet; open a fresh shell and re-run to init/start the podman machine."
}

# ---- oc (OpenShift CLI) from the public mirror ----
$ocDir = Join-Path $env:LOCALAPPDATA 'Programs\oc'
if (Get-Command oc.exe -ErrorAction SilentlyContinue) {
    Info "oc already on PATH; skipping."
} else {
    Info "downloading oc (OpenShift CLI)..."
    New-Item -ItemType Directory -Force -Path $ocDir | Out-Null
    $zip = Join-Path $env:TEMP 'openshift-client-windows.zip'
    $url = 'https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.18/openshift-client-windows.zip'
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
Write-Host "  1. Install CRC:         https://console.redhat.com/openshift/create/local"
Write-Host "  2. Get the Hyper-V FIPS bundle (4.18.x) and your Red Hat pull secret."
Write-Host "  3. Configure CRC with ABSOLUTE paths (relative paths do not resolve reliably):"
Write-Host "       crc config set bundle           C:\path\to\crc_hyperv_4.18.x_amd64.crcbundle"
Write-Host "       crc config set pull-secret-file C:\path\to\pull-secret.txt"
Write-Host "       crc setup"
Write-Host "       crc start"
Write-Host "  4. In WSL, add the apps-crc.testing hosts entries (doc section 7) using 'crc ip'."
Write-Host ""
Info "Done. In WSL, run 'chezmoi apply' so podman/helm/oc get symlinked from these Windows binaries."
