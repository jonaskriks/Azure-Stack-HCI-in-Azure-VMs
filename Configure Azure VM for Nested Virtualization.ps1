# Azure VM Nested Virtualization Hyper-V host setup for Azure Stack HCI
# Change default NIC to Private
$Profile = Get-NetConnectionProfile -InterfaceAlias Ethernet
$Profile.NetworkCategory = "Private"
Set-NetConnectionProfile -InputObject $Profile

# Install Hyper-V
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart

# Configure Hyper-V Network
New-VMSwitch -Name "InternalSwitchNAT" -SwitchType Internal
# Where InternalSwitchNAT is the name of the virtual switch, and Internal is the virtual switch type.

# Check the indexes of the network interfaces
Get-NetAdapter

# In my example, the interface index for the needed adapter is 20.
# Set the IP address for the vEthernet (InternalSwitchNAT) virtual network interface you created previously

New-NetIPAddress -IPAddress 172.16.0.1 -PrefixLength 24 -InterfaceIndex 20

# In this example, the IP address of this interface is 172.16.0.1; 24 is the length of the network mask and is equal to 255.255.255.0

# Create a new virtual network and set the network address for the created network:
New-NetNat -Name "InternalNATnet" -InternalIPInterfaceAddressPrefix 172.16.0.0/24

# Configure Hyper-V host firewall to allow Guest communications
New-NetFirewallRule -RemoteAddress 172.16.0.0/24 -DisplayName "AllowGuestComms" -Profile Any -Action Allow

# Configure Port forward so that you can RDP from Hyper-V host to the VM hosting WAC
Add-NetNatStaticMapping -ExternalIPAddress "0.0.0.0" -ExternalPort 33389 -Protocol TCP -InternalIPAddress "172.16.0.3" -InternalPort 3389 -NatName InternalNATnet

# In this example, the IP address of my Pfsense firewall is 172.16.0.3; my external RDP port is 33389. in Pfsense I have created a NAT rule to forward any traffic to port 33389 to MgmtVmInternalIP:3389
