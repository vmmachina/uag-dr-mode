param(
    [string]$vCenter,
    [string]$vmName,
    [string]$vip,
    [string]$guestPassword
)

# Prompt only if values not passed in
if (-not $vCenter) {
    $vCenter = Read-Host "Enter vCenter hostname/IP"
}
if (-not $vmName) {
    $vmName = Read-Host "Enter UAG VM name"
}
if (-not $vip) {
    $vip = Read-Host "Enter Virtual IP (VIP) to assign"
}
$guestUser = "root"
if (-not $guestPassword) {
    $securePassword = Read-Host "Enter root password (will not be displayed)" -AsSecureString
    $guestPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    )
}

# Connect to vCenter
Write-Host "`nConnecting to vCenter $vCenter..." -ForegroundColor Cyan
Connect-VIServer -Server $vCenter | Out-Null

# Get the VM
$uagVM = Get-VM -Name $vmName
if (-not $uagVM) {
    Write-Error "❌ VM $vmName not found in vCenter."
    exit 1
}

# Build commands to set up LVS DR routing
$cmds = @(
  "ip addr add $vip/32 dev lo",
  "echo 1 > /proc/sys/net/ipv4/conf/lo/arp_ignore",
  "echo 2 > /proc/sys/net/ipv4/conf/lo/arp_announce",
  "echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore",
  "echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce",
  "grep -qxF 'ip addr add $vip/32 dev lo' /etc/rc.local || echo 'ip addr add $vip/32 dev lo' >> /etc/rc.local",
  "grep -qxF 'echo 1 > /proc/sys/net/ipv4/conf/lo/arp_ignore' /etc/rc.local || echo 'echo 1 > /proc/sys/net/ipv4/conf/lo/arp_ignore' >> /etc/rc.local",
  "grep -qxF 'echo 2 > /proc/sys/net/ipv4/conf/lo/arp_announce' /etc/rc.local || echo 'echo 2 > /proc/sys/net/ipv4/conf/lo/arp_announce' >> /etc/rc.local",
  "grep -qxF 'echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore' /etc/rc.local || echo 'echo 1 > /proc/sys/net/ipv4/conf/all/arp_ignore' >> /etc/rc.local",
  "grep -qxF 'echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce' /etc/rc.local || echo 'echo 2 > /proc/sys/net/ipv4/conf/all/arp_announce' >> /etc/rc.local",
  "chmod +x /etc/rc.local"
)

Write-Host "`nConfiguring VIP and ARP settings on $vmName..." -ForegroundColor Cyan
foreach ($cmd in $cmds) {
    $result = Invoke-VMScript -VM $uagVM -ScriptText $cmd -GuestUser $guestUser -GuestPassword $guestPassword -ScriptType Bash
    if ($result.ExitCode -ne 0) {
        Write-Warning "⚠️ Command failed: $cmd"
    }
}

Write-Host "`n✅ DR routing configuration complete and persistent!" -ForegroundColor Green
