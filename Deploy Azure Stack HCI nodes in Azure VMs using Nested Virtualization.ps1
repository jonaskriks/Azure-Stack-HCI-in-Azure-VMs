############### Part 1 - Create and install all HCI Nodes in Hyper-V ###############
# Define the characteristics of the VM, and create
$nodeName = "hci-prod-node01"
New-VM `
    -Name $nodeName  `
    -MemoryStartupBytes 24GB `
    -SwitchName "HCI" `
    -Path "D:\HyperV\VM\" `
    -NewVHDPath "D:\HyperV\VM\$nodeName\Virtual Hard Disks\$nodeName.vhdx" `
    -NewVHDSizeBytes 128GB `
    -Generation 2

# Disable Dynamic Memory
Set-VMMemory -VMName $nodeName -DynamicMemoryEnabled $false
# Add the DVD drive, attach the ISO to DC01 and set the DVD as the first boot device
$DVD = Add-VMDvdDrive -VMName $nodeName -Path "D:\ISO\Azure Stack HCI\AzSHCI.iso" -Passthru
Set-VMFirmware -VMName $nodeName -FirstBootDevice $DVD

# Set the VM processor count for the VM
Set-VM -VMname $nodeName -ProcessorCount 16
# Add the virtual network adapters for SMB to the VM and configure appropriately
1..3 | ForEach-Object { 
    Add-VMNetworkAdapter -VMName $nodeName -SwitchName "HCI"
    Set-VMNetworkAdapter -VMName $nodeName -MacAddressSpoofing On -AllowTeaming On
}

# Create the DATA virtual hard disks and attach them
$dataDrives = 1..4 | ForEach-Object { New-VHD -Path "D:\HyperV\VM\$nodeName\Virtual Hard Disks\DATA0$_.vhdx" -Dynamic -Size 1024GB }
$dataDrives | ForEach-Object {
    Add-VMHardDiskDrive -Path $_.path -VMName $nodeName
}
# Disable checkpoints
Set-VM -VMName $nodeName -CheckpointType Disabled  -AutomaticStartAction Start -AutomaticStartDelay 180 -AutomaticStopAction ShutDown
# Enable nested virtualization
Set-VMProcessor -VMName $nodeName -ExposeVirtualizationExtensions $true -Verbose

# Open a VM Connect window, and start the VM
vmconnect.exe localhost $nodeName
Start-Sleep -Seconds 5
Start-VM -Name $nodeName

# Complete the Out of Box Experience (OOBE) for all nodes

############### Part 2- Rename HCI nodes, Domain Join, and Install Hyper-V ###############
# Define nodename
$nodeName = "hci-prod-node01"

# Define local credentials
$azsHCILocalCreds = Get-Credential -UserName "Administrator" -Message "Enter the password used when you deployed the Azure Stack HCI 20H2 OS"

# Define domain-join credentials
$domainName = "lab.local"
$domainAdmin = "$domainName\jonathan"
$domainCreds = Get-Credential -UserName "$domainAdmin" -Message "Enter the password for your Admin account"

# Rename and restart node
Invoke-Command -VMName $nodeName -Credential $azsHCILocalCreds -ScriptBlock {
    # Change the name
    Rename-Computer -NewName $Using:nodeName -Force -Restart
}

# Wait for node to restart
Start-Sleep -Seconds 15

# Domain join and restart node
Invoke-Command -VMName $nodeName -Credential $azsHCILocalCreds -ScriptBlock {
    # Join the domain
    Add-Computer -DomainName lab.local -Credential $Using:domainCreds -Force -Restart
}

# Wait for node to restart
Start-Sleep -Seconds 30

# Install Hyper-V Role
Invoke-Command -VMName "$nodeName" -Credential $domainCreds -ScriptBlock {
    # Enable the Hyper-V role within the Azure Stack HCI OS
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart -Verbose
}
Invoke-Command -VMName "$nodeName" -Credential $domainCreds -ScriptBlock {
    # Enable the Hyper-V PowerShell within the Azure Stack HCI OS
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell -All -NoRestart -Verbose
}

# Reboot
Write-Verbose "Rebooting node for changes to take effect" -Verbose
Stop-VM -Name $nodeName
Start-VM -Name $nodeName
