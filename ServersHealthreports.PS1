# ==============================
# Server List
# ==============================
#$servers = @("localhost")
 or use: $servers = Get-Content "C:\Reports\ServerList.csv"

$report = @()

foreach ($server in $servers) {

    Write-Host "Checking $server ..." -ForegroundColor Cyan

    try {
        $os = Get-CimInstance Win32_OperatingSystem -ComputerName $server
        $uptime = (Get-Date) - $os.LastBootUpTime
        $uptimeDays = [math]::Round($uptime.TotalDays,2)

        # CPU
        $cpu = Get-Counter "\Processor(_Total)\% Processor Time" -ComputerName $server
        $cpuUsage = [math]::Round($cpu.CounterSamples.CookedValue,2)

        # RAM
        $totalRAM = [math]::Round($os.TotalVisibleMemorySize/1MB,2)
        $freeRAM = [math]::Round($os.FreePhysicalMemory/1MB,2)
        $usedRAM = [math]::Round($totalRAM - $freeRAM,2)
        $ramPercent = [math]::Round(($usedRAM/$totalRAM)*100,2)

        # Disk
        $disks = Get-CimInstance Win32_LogicalDisk -ComputerName $server -Filter "DriveType=3"

        foreach ($disk in $disks) {
            $size = [math]::Round($disk.Size/1GB,2)
            $free = [math]::Round($disk.FreeSpace/1GB,2)
            $used = [math]::Round($size - $free,2)
            $diskPercent = [math]::Round(($used/$size)*100,2)

            $report += [PSCustomObject]@{
                Server      = $server
                UptimeDays  = $uptimeDays
                CPUPercent  = "$cpuUsage %"
                RAMPercent  = "$ramPercent %"
                TotalRAMGB  = $totalRAM
                Drive       = $disk.DeviceID
                DiskUsedGB  = $used
                DiskFreeGB  = $free
                DiskUsedPct = "$diskPercent %"
            }
        }
    }
    catch {
        $report += [PSCustomObject]@{
            Server      = $server
            UptimeDays  = "Error"
            CPUPercent  = "Error"
            RAMPercent  = "Error"
            TotalRAMGB  = "Error"
            Drive       = "-"
            DiskUsedGB  = "-"
            DiskFreeGB  = "-"
            DiskUsedPct = "Connection Failed"
        }
    }
}

# ==============================
# HTML STYLE
# ==============================
$style = @"
<style>
body { font-family: Arial; background-color:#f4f6f7; }
table { border-collapse: collapse; width:100%; }
th { background-color:#2e86c1; color:white; padding:8px; }
td { padding:8px; border:1px solid #ddd; text-align:center; }
tr:nth-child(even){background-color:#f2f2f2;}
h2 { text-align:center; }
</style>
"@

$date = Get-Date -Format "yyyy-MM-dd HH:mm"

$html = $report | ConvertTo-Html -Head $style -Title "Server Health Report" `
-PreContent "<h2>Windows Server Health Report</h2><h4>Generated: $date</h4>"

# ==============================
# SAVE REPORT
# ==============================
$output = "C:\Reports\ServerHealthReport.html"
$html | Out-File $output

Write-Host "Report generated: $output" -ForegroundColor Green

# ==============================
# EMAIL SETTINGS
# ==============================
$smtpServer = "smtp.office365.com"
$port = 587
$from = "monitor@company.com"
$to = "admin@company.com"
$subject = "Daily Windows Server Health Report"

# Credential prompt (secure)
$cred = Get-Credential

Send-MailMessage `
-To $to `
-From $from `
-Subject $subject `
-Body "Attached is the latest Windows Server health report." `
-Attachments $output `
-SmtpServer $smtpServer `
-Port $port `
-UseSsl `
-Credential $cred

Write-Host "Email sent successfully!" -ForegroundColor Green
