# =============================
# CONFIGURAÇÃO DE INTERFACE
# =============================
# Detecta a primeira interface de rede com status "Up" e que tenha um endereço IPv4 válido
$Interface = Get-NetAdapter |
    Where-Object { $_.Status -eq "Up" -and $_.InterfaceOperationalStatus -eq "Up" } |
    Sort-Object -Property ifIndex |
    Select-Object -First 1 -ExpandProperty Name

if (-not $Interface) {
    Write-Error "Nenhuma interface de rede ativa encontrada."
    exit
}

Write-Output "Interface de rede detectada: $Interface"


# Pega IP atual, máscara e gateway
$CurrentIP = (Get-NetIPAddress -InterfaceAlias $Interface -AddressFamily IPv4 | Where-Object {$_.PrefixOrigin -eq "Dhcp"}).IPAddress
$CurrentPrefix = (Get-NetIPAddress -InterfaceAlias $Interface -AddressFamily IPv4 | Where-Object {$_.PrefixOrigin -eq "Dhcp"}).PrefixLength
$CurrentGateway = (Get-NetIPConfiguration -InterfaceAlias $Interface).IPv4DefaultGateway.NextHop
$CurrentDNS = (Get-DnsClientServerAddress -InterfaceAlias $Interface -AddressFamily IPv4).ServerAddresses

# =============================
# INSTALA WIRESHARK SILENCIOSAMENTE
# =============================
$WiresharkUrl = "https://2.na.dl.wireshark.org/win64/Wireshark-4.4.9-x64.exe"
$InstallerPath = "$env:TEMP\WiresharkInstaller.exe"

Write-Output "Baixando Wireshark..."
Invoke-WebRequest -Uri $WiresharkUrl -OutFile $InstallerPath

Write-Output "Instalando Wireshark silenciosamente..."
Start-Process -FilePath $InstallerPath -ArgumentList "/S" -Wait

# Adiciona Wireshark ao PATH e atualiza sessão
$WiresharkPath = "C:\Program Files\Wireshark"
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$WiresharkPath", "User")
$env:Path += ";$WiresharkPath"

Write-Output "Wireshark version:"
wireshark --version

# =============================
# INSTALA E CONFIGURA OPENSSH SERVER
# =============================
Write-Output "Instalando OpenSSH Server..."
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

Set-Service -Name sshd -StartupType 'Automatic'
Start-Service sshd

# Firewall
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow

Write-Output "OpenSSH Server status:"
Get-Service sshd

# =============================
# CONFIGURA IP ESTÁTICO BASEADO NO IP ATUAL
# =============================
Write-Output "Configurando IP estático baseado no IP atual..."

# Remove IP atual dinâmico antes de adicionar estático
Remove-NetIPAddress -InterfaceAlias $Interface -AddressFamily IPv4 -Confirm:$false

# Adiciona IP estático
New-NetIPAddress -InterfaceAlias $Interface -IPAddress $CurrentIP -PrefixLength $CurrentPrefix -DefaultGateway $CurrentGateway

# Configura DNS
Set-DnsClientServerAddress -InterfaceAlias $Interface -ServerAddresses $CurrentDNS

Write-Output "IP estático configurado com sucesso:"
Get-NetIPAddress -InterfaceAlias $Interface
Get-DnsClientServerAddress -InterfaceAlias $Interface

Write-Output "Script finalizado com sucesso!"

#executar Invoke-WebRequest -Uri 'https://github.com/Kirishimya/ApoioTecnicoNPITISala201/raw/refs/heads/main/setupwiresharkopenssh.ps1' -OutFile "$env:TEMP\setupwiresharkopenssh.ps1"; & "$env:TEMP\setupwiresharkopenssh.ps1"

