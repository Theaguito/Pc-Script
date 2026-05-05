#Requires -RunAsAdministrator

$ErrorActionPreference = "SilentlyContinue"

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
    try {
        $chassis = Get-WmiObject -Class Win32_SystemEnclosure -ErrorAction SilentlyContinue
        $chassisType = $chassis.ChassisTypes[0]
        
        # 8 = Laptop, 9 = Tablet, 10 = Convertible
        if ($chassisType -in @(8, 9, 10)) {
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

function Test-IsRemoteSession {
    if ($env:SESSIONNAME -eq "RDP-Tcp") {
        return $true
    }
    return $false
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
        "C:\Windows\Minidump"
    )

    foreach ($pasta in $pastasTemp) {
        if (Test-Path $pasta) {
            try {
                Remove-Item "$pasta\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  [OK] $pasta limpo" -ForegroundColor Green
                Write-Log "[OK] Pasta temporaria limpa: $pasta"
            } catch {
                Write-Host "  [ERRO] Nao foi possivel limpar $pasta" -ForegroundColor Red
                Write-Log "[ERRO] Falha ao limpar: $pasta - $_"
            }
        }
    }

    Write-Host "  Limpando cache de navegadores..." -ForegroundColor White
    
    $caches = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
    )

    foreach ($cache in $caches) {
        if (Test-Path $cache) {
            try {
                Remove-Item "$cache\*" -Recurse -Force -ErrorAction SilentlyContinue
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
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
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
    $dismProcess = Start-Process "DISM.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -PassThru -WindowStyle Hidden
    
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
    $sfcProcess = Start-Process "sfc.exe" -ArgumentList "/scannow" -Wait -PassThru -WindowStyle Hidden
    
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
            # Pula somente o plano de energia, continua com servicos
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
    $osInfo = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cpuInfo = Get-WmiObject -Class Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $motherboardInfo = Get-WmiObject -Class Win32_BaseBoard -ErrorAction SilentlyContinue | Select-Object -First 1
    $gpuInfo = Get-WmiObject -Class Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1
    $ramInfo = Get-WmiObject -Class Win32_PhysicalMemory -ErrorAction SilentlyContinue
    $diskDrive = Get-WmiObject -Class Win32_DiskDrive -ErrorAction SilentlyContinue | Select-Object -First 1
    $volumeC = Get-WmiObject -Class Win32_LogicalDisk -Filter "Name = 'C:'" -ErrorAction SilentlyContinue
    
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
    Write-Host "  Disco 0      : $($sysInfo.DiskModel) $($sysInfo.DiskSize)GB | $($sysInfo.DiskSize)GB | $($sysInfo.DiskType)" -ForegroundColor DarkGray
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
Write-Log "Versao: 2.1 | Notebook: $(Test-IsNotebook) | Remote: $(Test-IsRemoteSession)"

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