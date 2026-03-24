Connect-AzAccount

$subscriptionlist = Get-AzSubscription
$outpath = "C:\temp\azurevmdetails.csv"

$result = @()

foreach ($subscription in $subscriptionlist){

    $subname = $subscription.Name
    Select-AzSubscription -Subscription $subname

    $nics = Get-AzNetworkInterface | Where-Object {
        $_.IpConfigurations.PrivateIpAllocationMethod -eq "Dynamic"
    }

    foreach ($nic in $nics){

        $nicname = $nic.Name
        $rg = $nic.ResourceGroupName

        # VM Name
        $vmName = (($nic.VirtualMachine.Id) -split "/virtualMachines/")[-1]

        # Private IP
        $privateIP = ($nic.IpConfigurations | ForEach-Object {
            $_.PrivateIpAddress
        }) -join ";"

        # Public IP
        $publicIP = ($nic.IpConfigurations | ForEach-Object {
            if ($_.PublicIpAddress -ne $null) {
                (Get-AzPublicIpAddress -ResourceGroupName $rg -Name ($_.PublicIpAddress.Id.Split('/')[-1])).IpAddress
            }
        }) -join ";"

        # VM Details
        $vm = Get-AzVM -ResourceGroupName $rg -Name $vmName -ErrorAction SilentlyContinue

        if ($vm) {
            $vmSize = $vm.HardwareProfile.VmSize
            $osType = $vm.StorageProfile.OsDisk.OsType
        }
        else {
            $vmSize = "N/A"
            $osType = "N/A"
        }

        # Create object
        $result += [PSCustomObject]@{
            SubscriptionName = $subname
            VMName           = $vmName
            ResourceGroup    = $rg
            NICName          = $nicname
            PrivateIP        = $privateIP
            PublicIP         = $publicIP
            VMSize           = $vmSize
            OSType           = $osType
        }
    }
}

# Export to CSV
$result | Export-Csv -Path $outpath -NoTypeInformation -Encoding UTF8