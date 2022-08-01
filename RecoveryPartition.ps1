#requires -version 3

<#
.SYNOPSIS
   Cria partição de recuperação a partir da imagem customizada do Windows
  Versão:       1.0
  Autor: Alexandre Coradi        
  Criado em:    
  Descrição:  Script utilizado para criar partição de recuperação em computadores com Windows 10 UEFI  
#>

#=======================================================[Inicialização]=======================================================
#region 0_Inicializacao
$ScriptVersion = "1.0"
#Variáveis Gerais
$scriptname = $MyInvocation.MyCommand.Name
if ($PSCommandPath -ne "") { $scriptPath = Split-Path -parent $PSCommandPath } else { $scriptPath = (Get-Location).Path }
$retorno = 0
$Infra = "C:\TEMP\Infra"
$DomainVarejo = "rede.local"
$Regrede = "HKLM:\SOFTWARE\rede"
$Folderrede = "$env:ProgramFiles\rede"
$CompDomain = (Get-WmiObject Win32_ComputerSystem).Domain

#Variáveis específicas
$ProductShort = "RecoveryPartition"
$DriveLetter = "U"
$HashFile = "F75E29F692007FE2431415E6BD10A1C8D7F1B5BEF1D07ACAD50984107ABD84EB"
$Source = "https://url.cloudfront.net/image/Windows10.iso" #Altere a URL de download da sua ISO
$Destination = "$Folderrede\$ProductShort"
$ISO = "Windows10.iso"
$ISOPath = "$Destination\$ISO"
$GPTType = "{de94bba4-06d1-4d40-a16a-bfd50179d6ac}" #GPTType Recovery

$RegRecoveryPath = "HKLM:\SOFTWARE\rede\$ProductShort" 
$RegRecovery = (Get-ItemProperty -Path $RegRecoveryPath -ErrorAction SilentlyContinue)
$Bits = Get-BitsTransfer | Where-Object {$_.DisplayName -eq $ProductShort}

if ($null -eq $RegRecovery) { New-Item -Path $Regrede -Name $ProductShort -Force -ErrorAction SilentlyContinue }
New-Item -Path "C:\Program Files\rede\$ProductShort" -ItemType Directory -Force

#Variáveis de Log
$InfraLogs ="C:\TEMP\Infra\Logs" 
if ($ProductShort -eq ""){ $LogPath = $InfraLogs }
else {$LogPath = Join-Path -Path $InfraLogs -ChildPath "$ProductShort"}
$LogName = "$ProductShort-$(Get-Date -Format yyyyMMdd-HHmm).log" 


#endregion 0_Inicializacao


#==========================================================[Funcoes]==========================================================
#region 1_Funcoes

    ### OBRIGATORIA
    Function Write-Log()
    {
        <#
        .SYNOPSIS
            Writes A Given Message To The Specified Log File

        .DESCRIPTION
            Writes a message to the specified log file
            Return: What was written to the log
        .PARAMETER sMessage
            Message to write to the log file

        .PARAMETER iTabs
            Number of tabs to indent text

        .PARAMETER sFileName
            Name of the log file

        .INPUTS
            [-sLogFolder] <String> Path of the log file to write
            [-sLogFileName] <String> Filename of log to write
            [-sMessage] <String> Content to write to the log file
            [-iTabs] <Int32> Number of tabs to append at the beginning of the line

        .OUTPUTS
            <String> What was written to the log

        .EXAMPLE
            Write-Log -sLogFolder "C:\TEMP" -sLogFileName "test_task2.log" -sMessage "The message is ....." -iTabs 0 

        .NOTES
            Requires common log variables:
                #Variáveis de Log
                $InfraLogs ="C:\TEMP\Infra\Logs" 
                if ($ProductShort -eq ""){ $LogPath = $InfraLogs }
                else {$LogPath = Join-Path -Path $InfraLogs -ChildPath "$ProductShort"}
                $LogName = "$ProductShort-$(Get-Date -Format yyyyMMdd-HHmm).log" 
            
        #>
        [CmdletBinding()]
        Param (
            [Parameter(Mandatory = $true, HelpMessage = "Log Text")]
            [Alias("LogText", "LogMessage")]
            [String]$sMessage = "",
            [Parameter(Mandatory = $false, HelpMessage = "Log Path")]
            [Alias("LogPath")]
            [String]$sLogFolder = $LogPath,
            [Parameter(Mandatory = $false, HelpMessage = "Log File Name")]
            [Alias("LogName")]
            [String]$sLogFileName = $LogName, #TODO: remover dependência de variável externa
            [Parameter(Mandatory = $false, HelpMessage = "Tabs at left")]
            [Alias("Tabs")]
            [Int]$iTabs = 0
        )
        #Write to host when $global:bDebug is $true
        If ($global:bDebug) { Write-Host $sContent -ForegroundColor Yellow -BackgroundColor Black }
                
        #Function's main 'Try'
        Try
        {
            #Loop through tabs provided to see If text should be indented within file
            $sTabs = ""
            For ($a = 1; $a -le $iTabs; $a++) { $sTabs = $sTabs + "`t" }
            
            #Populated content with tabs and message
            $sContent = "$(Get-Date -Format G) | $sTabs" + $sMessage
            
            #Define $sLogFile with the full file name
            $sLogFile = Join-Path -Path $sLogFolder -Childpath $sLogFileName
            
            #Verifica se a folder de logs existe, senão cria
            If (!(Test-Path $sLogFolder)) { New-Item $sLogFolder -ItemType Directory }

            #Verifica se o arquivo de log existe
            If (Test-Path $sLogFile -PathType Leaf)
                {
                    #Write contect to the file and If debug is on, to the console for troubleshooting
                    Try { Add-Content -Path $sLogFile -Value $sContent -Force }
                    Catch { $sContent = "ERROR: Log File '$sLogFile' could NOT be appended." }
                }
                Else { 
                    # "Arquivo de log  '$sLogFile'não existe."
                    $result = New-Item $sLogFile -ItemType File
                    $result = Add-Content -Path $sLogFile -Value $sContent -Force
                }
        }
        Catch { throw "Major failure. Error`: $($Error[0].Exception.ToString())" }
    } #End Of Write-Log

    Function Get-Download
    {
        <#
        .SYNOPSIS
            Download software from an URL

        .DESCRIPTION
            Downloads software from an URL provided using multiple methods

        .INPUTS
            [-URL] full URL in the (mandatory)
            [-Path] path where the content should be downloaded
            [-Version] Specific version. Can be partial (optional)

        .OUTPUTS
            [ExitCode] Int number representing the function exit code.
            0 - Donwload Completed successfully
            1 - Error downloading

        .EXAMPLE
            Get-Download -URL "http://server/install.msi" -Path "C:\TEMP\Infra"

        .NOTES
            Currently the function supports only a single file. 
                
        #>
        
        [CmdletBinding()]
        Param (
            [Parameter(Mandatory = $true, HelpMessage = "URL no formato http://..../NNNN.msi, podendo variar o protocolo. Caso seja download de folder sempre terminar com '/' -> http://..../folder/ ")]
            [String]$URL = "",
            [Parameter(Mandatory = $true, HelpMessage = "Caminho de destino")]
            [Alias("Path")]
            [String]$Folder = ".\",
            [Parameter(Mandatory = $false, HelpMessage = "Tempo de espera resposta do download, em segundos")]
            [Alias("Timeout")]
            [int]$DownloadTimeout = 20,
            [Parameter(Mandatory = $false, HelpMessage = "Tentativas de download")]
            [Alias("Attempts")]
            [int]$DownloadRetry = 3,
            [Parameter(Mandatory = $false, HelpMessage = "Tempo de espera entre tentativas, em segundos")]
            [Alias("RetryWait")]
            [int]$DownloadRetryWait = 3
        )

        $Action = "Inicia download"; Write-Log "$Action de $URL" -iTabs 1
        $attempt = 0
        [int16]$return = 0 
        $Error.Clear()

        Write-Log "Criando diretorio destino" -iTabs 1
        If (!(Test-Path $Folder)) { 
            $result = New-Item $Folder -ItemType Directory -Force -ErrorAction Ignore 
        } else {
            Write-Log "Diretorio já existe" -iTabs 2
        }
        
        do {
            try {
                #Monta OutFile, analizando se a URL provida é pasta inteira ou arquivo específico
                $URLChild = $URL.Substring($URL.LastIndexOf("/")+1)
                if ($URLChild -ne ""){
                    $InstallPath = "$Folder\$URLChild"
                } else {
                    $InstallPath = $Folder
                    $FolderDownload = $true
                }
                                
                [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
                $result = (New-Object System.Net.WebClient).DownloadFile($URL, $InstallPath)
                Write-Log "Download OK" -iTabs 1
                                       
                $Action = "Desbloqueio download"; Write-Log "Executando $Action"
                $r = Unblock-File $InstallPath
                $return = 0 
                break
            } catch {
                Write-Log "Falha no download. - Exceção: $($Error[0].ToString())" -iTabs 2
                $return = 1
                try {
                    Write-Log "Tentando método alternativo" -iTabs 1
                    $result = Invoke-WebRequest -Uri $URL -OutFile $InstallPath -ErrorAction Stop -PassThru -TimeoutSec $DownloadTimeout
                    Write-Log "Download $($result.StatusDescription)" -iTabs 1
                    
                    $Action = "Desbloqueio download"; Write-Log "Executando $Action"
                    $r = Unblock-File $InstallPath
                    $return = 0
                    break
                }
                catch {
                    Write-Log "Falha no download alternativo  - Exceção: $($Error[0].ToString())" -iTabs 2
                    $return = 1
                }

                $msg = "Erro no download (tentativa $($attempt+1)). Nova tentativa em $DownloadRetryWait segundos"
                Write-Log $msg -iTabs 2
                #TODO: tentar remover toda atualização de label da função
                $lbStatus.Content = $msg
                [System.Windows.Forms.Application]::DoEvents()

                $attempt++
                Start-Sleep -Seconds $DownloadRetryWait
            }
        } while ($attempt -lt $DownloadRetry)

        return $return

    } #function Get-Download

#endregion 1_Funcoes


#----------------------------------------------------------[Principal]--------------------------------------------------------
#region 2_Principal


try {
    Write-Log "========= Início rotina: $(get-date) ========="
    $Error.Clear()

    if ($null -eq (Test-Path $ISOPath)) {
        $Action = "iniciando download"; Write-Log "Imagem nao encontrada, $Action"
        Get-Download $Source -Folder $Destination 
    } elseif ($HashFile -ne (Get-FileHash -Path $ISOPath -Algorithm SHA256).Hash) {
        $Action = "iniciando download"; Write-Log "Imagem corrompida, $Action novamente"
        Get-Download $Source -Folder $Destination 
    }

    $Action = "Redimensiona particao"; Write-Log "Executando $Action"
    #Decidimos por não alterar as partições de Recovery padrao do Windows por conveniencia, sempre reduzindo a particao principal referente ao drive C
    $p = Get-Partition -DriveLetter C
    $p |Resize-Partition -Size ($p.size - 8589934592) #8GB 

    $Action = "Cria particao Recovery"; Write-Log "Executando $Action"
    $np = New-Partition -DiskNumber 0 -UseMaximumSize -GptType $GPTType -DriveLetter $DriveLetter.ToString() |Format-Volume -FileSystem 'NTFS' -NewFileSystemLabel "Recovery"

    $Action = "Extrai imagem"; Write-Log "Executando $Action"
    .\7z.exe x -y $ISOPath "-o${DriveLetter}`:\"
    
    $Action = "Customiza Windows Boot Manager"; Write-Log "Executando $Action"
    bcdedit /create `{ramdiskoptions`} /d "Ramdisk"
    bcdedit /set `{ramdiskoptions`} ramdisksdidevice partition=$DriveLetter`:
    bcdedit /set `{ramdiskoptions`} ramdisksdipath \boot\boot.sdi
    $gui = bcdedit /create /d "Recovery" /application OSLOADER
    $gui = "{$($gui -replace "^.*?{(.*?)}.*?$",'$1')}"
    bcdedit /set $gui device ramdisk=[$DriveLetter`:]\sources\boot.wim,`{ramdiskoptions`} 
    bcdedit /set $gui path \Windows\System32\winload.efi
    bcdedit /set $gui osdevice ramdisk=[$DriveLetter`:]\sources\boot.wim,`{ramdiskoptions`} 
    bcdedit /set $gui systemroot \windows
    bcdedit /set $gui winpe yes
    bcdedit /set $gui detecthal yes
    bcdedit /displayorder $gui /addlast
    bcdedit /timeout 0

    $Action = "Remove letra de unidade da particao"; Write-Log "Executando $Action"
    $part = Get-Partition -DriveLetter $DriveLetter
    Remove-PartitionAccessPath -DiskNumber 0 -PartitionNumber $part.PartitionNumber -Accesspath "${DriveLetter}:"

    if ($Error.Count -eq 0) {
        Write-Log  -LogText "Particao de recuperacao craida com sucesso."
        New-ItemProperty -Path $RegRecoveryPath -Name "RecoveryPartition" -Value "OK" -PropertyType String -Force
        New-ItemProperty -Path $RegRecoveryPath -Name "Data" -Value (Get-Date -Format dd/MM/yyyy).ToString() -PropertyType String -Force
        New-ItemProperty -Path $RegRecoveryPath -Name "File.ISO" -Value "Windows 10 Pro x64 Build 20H2" -PropertyType String -Force
  
    }

}
catch {
    Write-Log "ERRO no MAIN executando $Action. Excecao: $($Error[0].Exception.ToString()) "
    $retorno = 30003
} 
#endregion 2_Principal

#=======================================================[Finalizacao]=======================================================
#region 3_Finalizacao
Write-Log "========= Fim rotina: $(get-date) ========="


exit $retorno
#endregion 3_Finalizacao
