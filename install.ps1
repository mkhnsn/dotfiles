# Windows Bootstrap Script for dotfiles
# Download and run: iwr -useb https://raw.githubusercontent.com/mkhnsn/dotfiles/main/install.ps1 | iex
#
# Or save and run:
# Invoke-WebRequest -Uri https://raw.githubusercontent.com/mkhnsn/dotfiles/main/install.ps1 -OutFile install.ps1
# .\install.ps1

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$DotfilesRepo = "mkhnsn/dotfiles",
    [switch]$SkipWinget
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    Write-Host "[dotfiles] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[dotfiles] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[dotfiles] ERROR: $Message" -ForegroundColor Red
}

function Add-ToPath {
    param([string]$Path)
    
    if (Test-Path $Path) {
        $env:Path = "$Path;$env:Path"
        return $true
    }
    return $false
}

function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-Winget {
    Write-Log "Checking for winget..."
    
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Success "winget is already installed"
        return $true
    }
    
    Write-Log "winget not found. Attempting to install..."
    
    # winget is part of App Installer on Windows 10+
    # Try to install from Microsoft Store
    try {
        Write-Log "Installing App Installer (includes winget)..."
        # This requires Windows 10 1809+ or Windows 11
        # Note: Start-Process returns immediately with URI schemes
        Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
        Write-Log "Please complete the App Installer installation from the Microsoft Store, then re-run this script."
        return $false
    } catch {
        Write-Error "Could not install winget. Please install it manually from: https://aka.ms/getwinget"
        return $false
    }
}

function Install-GitForWindows {
    Write-Log "Checking for Git..."
    
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Success "Git is already installed"
        return $true
    }
    
    Write-Log "Git not found. Installing Git for Windows via winget..."
    
    try {
        $result = winget install --id Git.Git --exact --silent --accept-package-agreements --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Git for Windows installed successfully"
            
            # Try common Git installation paths
            $gitPaths = @(
                "C:\Program Files\Git\cmd",
                "C:\Program Files (x86)\Git\cmd",
                "$env:ProgramFiles\Git\cmd",
                "${env:ProgramFiles(x86)}\Git\cmd"
            )
            
            foreach ($path in $gitPaths) {
                if (Add-ToPath $path) {
                    break
                }
            }
            
            Write-Log "Git Bash is now available. You may need to restart your terminal for it to appear in your Start Menu."
            return $true
        } else {
            Write-Error "Failed to install Git: $result"
            return $false
        }
    } catch {
        Write-Error "Failed to install Git: $_"
        return $false
    }
}

function Install-Chezmoi {
    Write-Log "Checking for chezmoi..."
    
    if (Get-Command chezmoi -ErrorAction SilentlyContinue) {
        Write-Success "chezmoi is already installed"
        return $true
    }
    
    Write-Log "chezmoi not found. Installing via winget..."
    
    try {
        $result = winget install --id twpayne.chezmoi --exact --silent --accept-package-agreements --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "chezmoi installed successfully"
            
            # Try common chezmoi installation paths
            $chezmoiPaths = @(
                "$env:LOCALAPPDATA\Programs\chezmoi",
                "$env:ProgramFiles\chezmoi",
                "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\twpayne.chezmoi_Microsoft.Winget.Source_*"
            )
            
            foreach ($path in $chezmoiPaths) {
                if ($path -like "*`**") {
                    # Handle wildcard paths
                    $resolvedPaths = Get-Item $path -ErrorAction SilentlyContinue
                    foreach ($resolved in $resolvedPaths) {
                        if (Add-ToPath $resolved.FullName) {
                            break
                        }
                    }
                } else {
                    if (Add-ToPath $path) {
                        break
                    }
                }
            }
            
            return $true
        } else {
            Write-Error "Failed to install chezmoi via winget: $result"
            Write-Log "Attempting manual installation..."
            
            # Fallback: download binary directly
            $chezmoiDir = "$env:LOCALAPPDATA\Programs\chezmoi"
            New-Item -ItemType Directory -Force -Path $chezmoiDir | Out-Null
            
            $chezmoiExe = Join-Path $chezmoiDir "chezmoi.exe"
            $downloadUrl = "https://github.com/twpayne/chezmoi/releases/latest/download/chezmoi_windows_amd64.zip"
            
            Write-Log "Downloading chezmoi from GitHub..."
            $tempZip = Join-Path $env:TEMP "chezmoi.zip"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip -UseBasicParsing
            
            Write-Log "Extracting chezmoi..."
            Expand-Archive -Path $tempZip -DestinationPath $chezmoiDir -Force
            Remove-Item $tempZip
            
            if (Test-Path $chezmoiExe) {
                Add-ToPath $chezmoiDir
                Write-Success "chezmoi installed manually to $chezmoiDir"
                return $true
            } else {
                Write-Error "Failed to install chezmoi"
                return $false
            }
        }
    } catch {
        Write-Error "Failed to install chezmoi: $_"
        return $false
    }
}

function Initialize-Dotfiles {
    param([string]$Repo)
    
    Write-Log "Initializing dotfiles from repository: $Repo"
    
    try {
        # Run chezmoi init with apply
        Write-Log "Running: chezmoi init --apply $Repo"
        chezmoi init --apply $Repo
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Dotfiles applied successfully!"
            return $true
        } else {
            Write-Error "Failed to apply dotfiles"
            return $false
        }
    } catch {
        Write-Error "Failed to initialize dotfiles: $_"
        return $false
    }
}

# ============================================================================
# Main Script
# ============================================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Windows Dotfiles Bootstrap" -ForegroundColor Cyan
Write-Host "  Repository: $DotfilesRepo" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
if (Test-Administrator) {
    Write-Log "Running as Administrator"
} else {
    Write-Log "Running as regular user (recommended)"
}

# Step 1: Ensure winget is available
if (-not $SkipWinget) {
    if (-not (Install-Winget)) {
        Write-Error "winget is required but not available. Exiting."
        exit 1
    }
} else {
    Write-Log "Skipping winget check (--SkipWinget specified)"
}

# Step 2: Install Git for Windows (includes Git Bash)
if (-not (Install-GitForWindows)) {
    Write-Error "Git is required but installation failed. Exiting."
    exit 1
}

# Step 3: Install chezmoi
if (-not (Install-Chezmoi)) {
    Write-Error "chezmoi is required but installation failed. Exiting."
    exit 1
}

# Step 4: Initialize dotfiles
Write-Host ""
Write-Log "Ready to initialize dotfiles..."
Start-Sleep -Seconds 1

if (Initialize-Dotfiles -Repo $DotfilesRepo) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  Bootstrap Complete!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Success "Next steps:"
    Write-Host "  1. Open 'Git Bash' from your Start Menu" -ForegroundColor Yellow
    Write-Host "  2. Git Bash will automatically launch zsh" -ForegroundColor Yellow
    Write-Host "  3. Your dotfiles are now active!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To apply dotfile updates later, run:" -ForegroundColor Gray
    Write-Host "  chezmoi update" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Error "Bootstrap failed. Please check the errors above."
    exit 1
}
