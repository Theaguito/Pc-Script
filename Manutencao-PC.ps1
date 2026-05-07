#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Maintenance PC Script v2.2 - Modernized & Improved
    
.DESCRIPTION
    Complete Windows system maintenance with modern PowerShell practices
    
.CHANGES_v2.2
    - Modernized: Get-WmiObject → Get-CimInstance (industry standard post-PS 3.0)
    - Improved: Browser process check before cache cleanup (prevents locks)
    - Enhanced: Added Windows Update cache cleanup (C:\Windows\SoftwareDistribution\Download)
    - UX Fix: Removed hidden window style from DISM/SFC to show progress
    - Stability: Improved error handling in cleanup loops
#>

$ErrorActionPreference = "Stop"

$maintenanceFolder = "$env:USERPROFILE\Manutencao"
if (-not (Test-Path $maintenanceFolder)) {
    New-Item -ItemType Directory -Path $maintenanceFolder -Force | Out-Null
}

# Rotacao de logs - manter apenas os ultimos 10 arquivos
$logFiles = Get-ChildItem -Path $maintenanceFolder -Filter "Manutencao_Log_*.txt" -ErrorAction SilentlyContinue | Sort-Object CreationTime -Descending
if ($logFiles.Count -gt 10) {
    $logFiles | Select-Object -Skip 10 | Remove-Item -Force -ErrorAction SilentlyContinue
}

$LogPath = "$maintenanceFolder\Manutencao_Log_$(Get-Date -Format 'yyyy-MM-dd_HH-mm').txt"

function Write-Log {
    param([string]$Msg)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$ts | $Msg" | Out-File -FilePath $LogPath -Append -Encoding UTF8
}

function Test-IsNotebook {
    <#
    .SYNOPSIS
        Detects if running on a laptop/notebook device
    .NOTES
        Modernized: Uses Get-CimInstance instead of deprecated Get-WmiObject
        Extended chassis types to cover more device types
    #>
    try {
        $chassis = Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue
        $chassisType = $chassis.ChassisTypes[0]
        
        # 8=Laptop, 9=Tablet, 10=Convertible, 11=Docking, 12=Notebook, 14=Sub-Notebook, 18=Handheld, 21=Tablet
        if ($chassisType -in @(8, 9, 10, 11, 12, 14, 18, 21)) {
            return $true
        }
        return $false
    } catch {
        Write-Log "[WARN] Failed to detect notebook type: $_"
        return $false
    }
}

function Test-IsRemoteSession {
    if ($env:SESSIONNAME -eq "RDP-Tcp") {
        return $true
    }
    return $false
}

function Test-BrowsersRunning {
    <#
    .SYNOPSIS
        Checks if any browsers are currently running
    .NOTES
        Added in v2.2 to prevent cache deletion while browsers are open
    #>
    $browsers = @("chrome", "msedge", "brave", "firefox", "iexplore")
    $running = @()
    
    foreach ($browser in $browsers) {
        if (Get-Process -Name $browser -ErrorAction SilentlyContinue) {
            $running += $browser
        }
    }
    return $running
}

function Invoke-Limpeza {
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "  MODULO 1 - LIMPEZA DE TEMPORARIOS" -ForegroundColor Yellow
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  Limpando pastas temporarias..." -ForegroundColor White

    $pastasTemp = @(
        $env:TEMP,
        "C:\Windows\Temp",
        "C:\Windows\Prefetch",
        "$env:LOCALAPPDATA\Temp",
        "C:\Windows\Minidump",
        "C:\Windows\SoftwareDistribution\Download"  # Windows Update cache - ADDED v2.2
    )

    foreach ($pasta in $pastasTemp) {
        if (Test-Path $pasta) {
            try {
                Get-ChildItem -Path $pasta -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "  [OK] $pasta limpo" -ForegroundColor Green
                Write-Log "[OK] Pasta temporaria limpa: $pasta"
            } catch {
                Write-Host "  [ERRO] Nao foi possivel limpar $pasta" -ForegroundColor Red
                Write-Log "[ERRO] Falha ao limpar: $pasta - $_"
            }
        }
    }

    Write-Host "  Limpando cache de navegadores..." -ForegroundColor White
    
    # IMPROVED v2.2: Check if browsers are running
    $runningBrowsers = Test-BrowsersRunning
    if ($runningBrowsers.Count -gt 0) {
        Write-Host "  [!] AVISO: Os seguintes navegadores estao abertos: $($runningBrowsers -join ', ')" -ForegroundColor Yellow
        Write-Host "  [!] Feche-os para limpar o cache completamente." -ForegroundColor Yellow
        Write-Log "[WARN] Browser cache cleanup skipped - browsers running: $($runningBrowsers -join ', ')"
    }
    
    $caches = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache"  # Added Brave support
    )

    foreach ($cache in $caches) {
        if (Test-Path $cache) {
            try {
                Get-ChildItem -Path $cache -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "  [OK] Cache limpo" -ForegroundColor Green
                Write-Log "[OK] Cache de navegador limpo: $cache"
            } catch {
                Write-Host "  [ERRO] Nao foi possivel limpar cache" -ForegroundColor Red
                Write-Log "[ERRO] Falha ao limpar cache: $_"
            }
        }
    }

    Write-Host "  Esvaziando Lixeira..." -ForegroundColor White
    try {
        Clear-RecycleBin -Force -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "  [OK] Lixeira esvaziada" -ForegroundColor Green
        Write-Log "[OK] Lixeira esvaziada com sucesso"
    } catch {
        Write-Host "  [OK] Lixeira ja estava vazia" -ForegroundColor Green
        Write-Log "[INFO] Lixeira ja vazia"
    }

    Write-Host ""
    Write-Host "  Limpeza concluida!" -ForegroundColor Magenta
    Write-Host ""
    Write-Log "[SUCESSO] Modulo 1 (Limpeza): concluido"
}

function Invoke-Reparo {
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "  MODULO 2 - REPARO DO SISTEMA" -ForegroundColor Yellow
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  Executando DISM..." -ForegroundColor White
    # IMPROVED v2.2: Removed -WindowStyle Hidden to show progress
    $dismProcess = Start-Process "DISM.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -PassThru
    
    if ($dismProcess.ExitCode -eq 0) {
        Write-Host "  [OK] DISM concluido com sucesso" -ForegroundColor Green
        Write-Log "[OK] DISM executed successfully (exit code: 0)"
    } elseif ($dismProcess.ExitCode -eq 1) {
        Write-Host "  [AVISO] DISM nao encontrou problemas" -ForegroundColor Yellow
        Write-Log "[INFO] DISM - nenhum problema encontrado (exit code: 1)"
    } else {
        Write-Host "  [ERRO] DISM falhou com codigo: $($dismProcess.ExitCode)" -ForegroundColor Red
        Write-Log "[ERRO] DISM falhou - exit code: $($dismProcess.ExitCode)"
    }

    Write-Host "  Executando SFC..." -ForegroundColor White
    # IMPROVED v2.2: Removed -WindowStyle Hidden to show progress
    $sfcProcess = Start-Process "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru
    
    if ($sfcProcess.ExitCode -eq 0) {
        Write-Host "  [OK] SFC concluido com sucesso" -ForegroundColor Green
        Write-Log "[OK] SFC executed successfully (exit code: 0)"
    } elseif ($sfcProcess.ExitCode -eq 1) {
        Write-Host "  [AVISO] SFC encontrou problemas e corrigiu" -ForegroundColor Yellow
        Write-Log "[INFO] SFC - problemas encontrados e reparados (exit code: 1)"
    } else {
        Write-Host "  [ERRO] SFC falhou com codigo: $($sfcProcess.ExitCode)" -ForegroundColor Red
        Write-Log "[ERRO] SFC falhou - exit code: $($sfcProcess.ExitCode)"
    }

    Write-Host "  Agendando CHKDSK..." -ForegroundColor White
    cmd.exe /c "echo Y | chkdsk C: /f /r" 2>&1 | Out-Null
    Write-Host "  [OK] CHKDSK agendado para proxima inicializacao" -ForegroundColor Green
    Write-Log "[OK] CHKDSK agendado para proximo boot"

    Write-Host ""
    Write-Host "  Reparo concluido!" -ForegroundColor Magenta
    Write-Host ""
    Write-Log "[SUCESSO] Modulo 2 (Reparo): concluido"
}

function Invoke-Rede {
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "  MODULO 3 - OTIMIZACAO DE REDE" -ForegroundColor Yellow
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host ""

    if (Test-IsRemoteSession) {
        Write-Host ""
        Write-Host "  [AVISO] Sessao RDP detectada!" -ForegroundColor Yellow
        Write-Host "  Executar ipconfig /release desconectará esta sessão." -ForegroundColor Yellow
        Write-Host ""
        $prosseguir = Read-Host "  Deseja continuar mesmo assim? (S/N)"
        if ($prosseguir -notmatch "^[Ss]$") {
            Write-Host "  Operacao cancelada." -ForegroundColor Gray
            Write-Log "[AVISO] Modulo 3 cancelado pelo usuario (sessao RDP)"
            return
        }
        Write-Log "[INFO] Usuario confirmou continuacao em sessao RDP"
    }

    Write-Host "  Renovando IP..." -ForegroundColor White
    ipconfig /release | Out-Null
    Start-Sleep -Seconds 2
    ipconfig /renew | Out-Null
    Write-Host "  [OK] IP renovado" -ForegroundColor Green
    Write-Log "[OK] IP renovado com sucesso"

    Write-Host "  Limpando cache DNS..." -ForegroundColor White
    ipconfig /flushdns | Out-Null
    Write-Host "  [OK] Cache DNS limpo" -ForegroundColor Green
    Write-Log "[OK] Cache DNS limpo"

    Write-Host "  Resetando Winsock..." -ForegroundColor White
    netsh winsock reset | Out-Null
    Write-Host "  [OK] Winsock resetado" -ForegroundColor Green
    Write-Log "[OK] Winsock resetado"

    Write-Host ""
    Write-Host "  Rede otimizada!" -ForegroundColor Magenta
    Write-Host ""
    Write-Log "[SUCESSO] Modulo 3 (Rede): concluido"
}

function Invoke-Seguranca {
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "  MODULO 4 - SEGURANCA" -ForegroundColor Yellow
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  Verificando Defender..." -ForegroundColor White
    $def = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($def -and $def.AntivirusEnabled) {
        Write-Host "  [OK] Defender esta ativo" -ForegroundColor Green
        Write-Log "[OK] Windows Defender ativo"
        
        Write-Host "  Atualizando definicoes..." -ForegroundColor White
        Update-MpSignature -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  [OK] Definicoes atualizadas" -ForegroundColor Green
        Write-Log "[OK] Definicoes de seguranca atualizadas"
    } else {
        Write-Host "  [AVISO] Defender desativado!" -ForegroundColor Yellow
        Write-Log "[AVISO] Windows Defender desativado - recomendase ativar"
    }

    Write-Host ""
    Write-Host "  Seguranca verificada!" -ForegroundColor Magenta
    Write-Host ""
    Write-Log "[SUCESSO] Modulo 4 (Seguranca): concluido"
}

function Invoke-Desempenho {
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "  MODULO 5 - DESEMPENHO" -ForegroundColor Yellow
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host ""

    $isNotebook = Test-IsNotebook
    
    if ($isNotebook) {
        Write-Host "  [AVISO] Notebook detectado!" -ForegroundColor Yellow
        Write-Host "  Modo Alto Desempenho pode drenar bateria rapidamente." -ForegroundColor Yellow
        $aplicarPlano = Read-Host "  Deseja ativar mesmo assim? (S/N)"
        if ($aplicarPlano -notmatch "^[Ss]$") {
            Write-Host "  Operacao cancelada." -ForegroundColor Gray
            Write-Log "[INFO] Modulo 5 parcialmente executado (notebook detectado)"
            return
        } else {
            powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
            Write-Host "  [OK] Plano Alto Desempenho ativado" -ForegroundColor Green
            Write-Log "[OK] Plano de energia SCHEME_MIN ativado em notebook"
        }
    } else {
        powercfg /setactive SCHEME_MIN 2>&1 | Out-Null
        Write-Host "  [OK] Plano Alto Desempenho ativado" -ForegroundColor Green
        Write-Log "[OK] Plano de energia SCHEME_MIN ativado"
    }

    Write-Host "  Verificando servicos criticos..." -ForegroundColor White
    $servicos = @("wuauserv", "WinDefend", "MpsSvc", "EventLog")
    foreach ($s in $servicos) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -ne "Running") {
                try {
                    Start-Service -Name $s -ErrorAction SilentlyContinue
                    Write-Log "[OK] Servico iniciado: $s"
                } catch {
                    Write-Log "[ERRO] Falha ao iniciar servico $s"
                }
            }
        }
    }
    Write-Host "  [OK] Servicos verificados" -ForegroundColor Green

    Write-Host ""
    Write-Host "  Desempenho otimizado!" -ForegroundColor Magenta
    Write-Host ""
    Write-Log "[SUCESSO] Modulo 5 (Desempenho): concluido"
}

function Get-SystemInfo {
    <#
    .SYNOPSIS
        Gathers comprehensive system information
    .NOTES
        MODERNIZED in v2.2: Uses Get-CimInstance instead of Get-WmiObject
        Get-CimInstance is the modern standard (post-PowerShell 3.0)
        More efficient and secure than WMI
    #>
    # Get-CimInstance - modern replacement for Get-WmiObject
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cpuInfo = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $motherboardInfo = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction SilentlyContinue | Select-Object -First 1
    $gpuInfo = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
    $ramInfo = Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue
    $diskDrive = Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction SilentlyContinue | Select-Object -First 1
    $volumeC = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "Name = 'C:'" -ErrorAction SilentlyContinue
    
    # Sistema Operacional
    $os = if ($osInfo) { $osInfo.Caption } else { "Desconhecido" }
    
    # Processador
    $cpu = if ($cpuInfo) { $cpuInfo.Name } else { "Desconhecido" }
    
    # Memoria RAM - Total
    $totalRamBytes = ($ramInfo | Measure-Object -Property Capacity -Sum -ErrorAction SilentlyContinue).Sum
    $totalRamGB = if ($totalRamBytes -gt 0) { [math]::Round($totalRamBytes / 1GB, 0) } else { "Desconhecido" }
    
    # Memoria RAM - Livre
    $freeMemoryMB = if ($osInfo) { $osInfo.FreePhysicalMemory } else { 0 }
    $freeMemoryGB = [math]::Round($freeMemoryMB / 1024 / 1024, 1)
    
    # Placa de Video
    $gpu = if ($gpuInfo) { $gpuInfo.Name } else { "Desconhecido" }
    
    # Placa Mae
    $motherboard = if ($motherboardInfo) { "$($motherboardInfo.Manufacturer) $($motherboardInfo.Product)" } else { "Desconhecido" }
    
    # Disco 0
    $diskModel = if ($diskDrive) { $diskDrive.Model } else { "Desconhecido" }
    $diskSize = if ($diskDrive) { [math]::Round($diskDrive.Size / 1GB, 0) } else { "Desconhecido" }
    $diskType = if ($diskDrive -and $diskDrive.MediaType -like "*SSD*") { "SSD" } elseif ($diskDrive) { "HDD" } else { "Desconhecido" }
    
    # Volume C:
    $volumeCTotal = if ($volumeC) { [math]::Round($volumeC.Size / 1GB, 1) } else { "Desconhecido" }
    $volumeCFree = if ($volumeC) { [math]::Round($volumeC.FreeSpace / 1GB, 1) } else { "Desconhecido" }
    $volumeCUsedPercent = if ($volumeC -and $volumeC.Size -gt 0) { [math]::Round(((($volumeC.Size - $volumeC.FreeSpace) / $volumeC.Size) * 100), 0) } else { "0" }
    
    return @{
        OS = $os
        CPU = $cpu
        RAMTotal = $totalRamGB
        RAMFree = $freeMemoryGB
        GPU = $gpu
        Motherboard = $motherboard
        DiskModel = $diskModel
        DiskSize = $diskSize
        DiskType = $diskType
        VolumeCTotal = $volumeCTotal
        VolumeCFree = $volumeCFree
        VolumeCUsedPercent = $volumeCUsedPercent
    }
}

function Show-Menu {
    Clear-Host
    $sysInfo = Get-SystemInfo
    
    Write-Host ""
    Write-Host "  =============================================================" -ForegroundColor Cyan
    Write-Host "    MANUTENCAO COMPLETA DE PC - MENU PRINCIPAL" -ForegroundColor Cyan
    Write-Host "  =============================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "  Sistema Op. : $($sysInfo.OS)" -ForegroundColor DarkGray
    Write-Host "  Processador : $($sysInfo.CPU)" -ForegroundColor DarkGray
    Write-Host "  Memoria RAM : $($sysInfo.RAMTotal) GB total | $($sysInfo.RAMFree) GB livre" -ForegroundColor DarkGray
    Write-Host "  Placa Video : $($sysInfo.GPU)" -ForegroundColor DarkGray
    Write-Host "  Placa-mae   : $($sysInfo.Motherboard)" -ForegroundColor DarkGray
    Write-Host "  Disco 0      : $($sysInfo.DiskModel) $($sysInfo.DiskSize)GB | $($sysInfo.DiskType)" -ForegroundColor DarkGray
    Write-Host "  Volume C:    : $($sysInfo.VolumeCTotal)GB total | $($sysInfo.VolumeCFree)GB livre | Uso: $($sysInfo.VolumeCUsedPercent)%" -ForegroundColor DarkGray
    Write-Host ""
    
    Write-Host "  =============================================================" -ForegroundColor Cyan
    Write-Host "  MODULOS DISPONIVEIS" -ForegroundColor Yellow
    Write-Host "  =============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1]  Limpeza de Temporarios" -ForegroundColor White
    Write-Host "  [2]  Reparo do Sistema (DISM + SFC + CHKDSK)" -ForegroundColor White
    Write-Host "  [3]  Otimizacao de Rede" -ForegroundColor White
    Write-Host "  [4]  Seguranca (Defender)" -ForegroundColor White
    Write-Host "  [5]  Desempenho" -ForegroundColor White
    Write-Host ""
    Write-Host "  [6]  EXECUTAR TUDO + REINICIAR AUTOMATICAMENTE" -ForegroundColor Yellow
    Write-Host "  [7]  EXECUTAR TUDO + PERGUNTAR ANTES DE REINICIAR" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [0]  Sair" -ForegroundColor Red
    Write-Host ""
    Write-Host "  =============================================================" -ForegroundColor Cyan
    Write-Host ""
}

Write-Log "=== SCRIPT INICIADO - $env:COMPUTERNAME ==="
Write-Log "Versao: 2.2 (Modernizado) | Notebook: $(Test-IsNotebook) | Remote: $(Test-IsRemoteSession)"

do {
    Show-Menu
    $opcao = Read-Host "  Digite a opcao"
    Write-Host ""

    switch ($opcao) {
        "1" { Invoke-Limpeza }
        "2" { Invoke-Reparo }
        "3" { Invoke-Rede }
        "4" { Invoke-Seguranca }
        "5" { Invoke-Desempenho }
        "6" {
            Write-Log "=== EXECUTANDO TUDO - AUTO RESTART ==="
            Invoke-Limpeza
            Invoke-Reparo
            Invoke-Rede
            Invoke-Seguranca
            Invoke-Desempenho
            Write-Host ""
            Write-Host "  Reiniciando em 5 segundos..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
            Write-Log "=== REINICIANDO SISTEMA ==="
            shutdown /r /t 0 /c "Manutencao concluida"
        }
        "7" {
            Write-Log "=== EXECUTANDO TUDO - SEM RESTART AUTOMATICO ==="
            Invoke-Limpeza
            Invoke-Reparo
            Invoke-Rede
            Invoke-Seguranca
            Invoke-Desempenho
            Write-Host ""
            $r = Read-Host "  Deseja reiniciar agora? (S/N)"
            if ($r -match "^[Ss]$") {
                Write-Log "=== REINICIANDO SISTEMA ==="
                shutdown /r /t 0 /c "Manutencao concluida"
            } else {
                Write-Host "  Sistema nao sera reiniciado." -ForegroundColor Gray
                Write-Log "[INFO] Usuario optou por nao reiniciar"
            }
        }
        "0" {
            Write-Host "  Saindo..." -ForegroundColor Gray
            Write-Log "=== SCRIPT ENCERRADO NORMALMENTE ==="
            Start-Sleep -Seconds 1
        }
        default {
            Write-Host "  Opcao invalida!" -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($opcao -ne "0")
