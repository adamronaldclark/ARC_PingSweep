# Load .NET stuff and create function for folder dialog
Add-Type -AssemblyName System.Windows.Forms

function Get-Folder($initialDirectory) {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    $folderBrowserDialog = New-Object System.Windows.Forms.folderBrowserDialog
    $folderBrowserDialog.Description = "Select the working folder for this script. The log file will be stored in this location."
    $folderBrowserDialog.RootFolder = "MyComputer"
    if ($initialDirectory) {
        $folderBrowserDialog.SelectedPath = $initialDirectory
    }
    $result = $folderBrowserDialog.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
    if ($result -eq [Windows.Forms.DialogResult]::OK) {
        return $folderBrowserDialog.SelectedPath
    } else {
        Write-Host "Error. There is an issue with the select folder dialog."
        Start-Sleep(3)
        exit
    }
}

Clear-Host
Write-Host "Select the working folder for this script. The log file will be stored in this location."
$folder = Get-Folder("C:\")
# Loop to ensure user selects a working folder
while ($folder -eq "C:\") {
    Write-Host "Select the working folder for this script. The log file will be stored in this location."
    $folder = Get-Folder("C:\")
}
Write-Host "Working folder is $folder"
Start-Sleep(3)
Set-Location $folder

# startTime is used at the end of the script with endTime to determine executionTime
$startTime = Get-Date

# ScriptBlock for the Start-Job function below
$jobSB = 
{
    param(
        [String]$ipAddress,
        [String]$logFile
    )

    function pingHost($ipAddress) {
        if (Test-Connection -Count 1 -Quiet -Computername $ipAddress) {
            try {
                Add-Content -Path $logFile $ipAddress
            } catch {
                Write-Host "Error. Cannot write to log file. Possible permissions issue."
                Start-Sleep(3)
                exit
            }
        }
    }

    pingHost($ipAddress)
}


# Set log file variable
$logFile = $folder + "\AliveHosts.log"
if (Test-Path -Path $logFile) {
    try {
        Remove-Item $logFile
    } catch {
        Write-Host "Error. Cannot remove existing log file. Possible permissions issue."
        Start-Sleep(3)
        exit
    }
}
try {
    New-Item $logFile
} catch {
    Write-Host "Error. Cannot create new log file. Possible permissions issue."
    Start-Sleep(3)
    exit
}

# Get IP range to scan #
Clear-Host
$startIP = read-host "Enter starting IP address (e.g. 192.168.0.1)"
$endIP = read-host "Enter ending IP address (e.g. 192.168.0.254)"

# Store addresses for printing and comparison
$startIPprint = $startIP
$endIPprint = $endIP

# Break up starting IP address into sections. Need this to increment octets and compare with endIP.
$startIP = $startIP.split(".")
$startIPfirstOctet = [Int]$startIP[0]
$startIPsecondOctet = [Int]$startIP[1]
$startIPthirdOctet = [Int]$startIP[2]
$startIPfourthOctet = [Int]$startIP[3]

# Break up ending IP address into sections.
$endIP = $endIP.Split(".")
$endIPfirstOctet = [Int]$endIP[0]
$endIPsecondOctet = [Int]$endIP[1]
$endIPthirdOctet = [Int]$endIP[2]
$endIPfourthOctet = [Int]$endIP[3]

# Validate starting and ending IP addresses
$ipAddressPattern = "([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}"
if ($startIPprint -notmatch $ipAddressPattern) {
    Write-Host "Error. Starting IP address not valid."
    Start-Sleep(3)
    exit
} elseif ($endIPPrint -notmatch $ipAddressPattern) {
    Write-Host "Error. Ending IP address not valid."
    Start-Sleep(3)
    exit
}

##### Scan #####
$next_ip = [String]$startIPFirstOctet + "." + [String]$startIPsecondOctet + "." + [String]$startIPthirdOctet + "." + [String]$startIPfourthOctet
try {
    Add-Content -path $logFile "Alive hosts as of: $todays_date"
} catch {
    Write-Host "Error. Cannot write to log file. Possible permissions issue."
    Start-Sleep(3)
    exit
}
while ($next_ip -ne $endIP_print) {
    # Check to ensure all jobs have completed before cleaning up
    $running_job_count = (get-job | where state -eq running).count

    while ($running_job_count -ge 10){
        $running_job_count = (get-job | where state -eq running).count
        Write-Host "$running_job_count jobs already running. Sleeping for 1 second."
        Start-Sleep -Seconds 1
    }

    $next_ip = [String]$startIPFirstOctet + "." + [String]$startIPsecondOctet + "." + [String]$startIPthirdOctet + "." + [String]$startIPfourthOctet
    start-job -scriptblock $jobSB -argumentlist $next_ip, $logFile | out-null
    $startIPfourthOctet += 1
}

# Check to ensure all jobs have completed before cleaning up
$running_job_count = (get-job | where state -eq running).count

while ($running_job_count -ne 0){
    $running_job_count = (get-job | where state -eq running).count
    Write-Host "$running_job_count jobs still running. Sleeping for 1 second."
    Start-Sleep -seconds 1
}

# Clean up jobs
get-job | receive-job -force -wait | out-null
get-job | remove-job -force | out-null

##### Read log file and print output #####
Clear-Host

try {
    $logFile_data = get-content -path $logFile
} catch {
    Write-Host "Error. Cannot read log file. Possible permissions issue."
    Start-Sleep(3)
    exit
}
foreach ($line in $logFile_data) {
    Write-Host $line
}

##### End timer #####
$end_time = Get-Date
$execution_time = $end_time - $startTime
Write-Host "Script executed in $execution_time (HH:MM:SS:MS)"