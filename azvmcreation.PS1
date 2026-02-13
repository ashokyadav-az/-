# Variables
$resourceGroup = "MyResourceGroup"
$location = "West US"
$vmName = "MyWin2019VM"
$vmSize = "Standard_DS1_v2"
$adminUser = "azureuser"
$adminPassword = ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force

# Create Resource Group
New-AzResourceGroup -Name $resourceGroup -Location $location

# Create Virtual Network and Subnet
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
  -Name "$vmName-vnet" -AddressPrefix "10.0.0.0/16"
$subnet = Add-AzVirtualNetworkSubnetConfig -Name "$vmName-subnet" `
  -AddressPrefix "10.0.0.0/24" -VirtualNetwork $vnet
$vnet | Set-AzVirtualNetwork

# Create Public IP
$publicIP = New-AzPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name "$vmName-ip" -AllocationMethod Dynamic

# Create Network Security Group
$nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name "Allow-RDP" -Protocol Tcp `
  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * `
  -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow
$nsg = New-AzNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
  -Name "$vmName-nsg" -SecurityRules $nsgRuleRDP

# Create NIC
$nic = New-AzNetworkInterface -ResourceGroupName $resourceGroup -Location $location `
  -Name "$vmName-nic" -SubnetId $subnet.Id -PublicIpAddressId $publicIP.Id -NetworkSecurityGroupId $nsg.Id

# Create VM Configuration
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize | `
  Set-AzVMOperatingSystem -Windows -ComputerName $vmName -Credential (New-Object System.Management.Automation.PSCredential($adminUser, $adminPassword)) -ProvisionVMAgent -EnableAutoUpdate | `
  Set-AzVMSourceImage -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Sku "2019-Datacenter" -Version "latest" | `
  Add-AzVMNetworkInterface -Id $nic.Id

# Create VM
New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig
