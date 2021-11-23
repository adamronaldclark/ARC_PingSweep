# Load .NET stuff and create the function for folder dialog
Add-Type -AssemblyName System.Windows.Forms

function get_folder($initial_dir) {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    $folder_browser_dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folder_browser_dialog.Description = "Select the working folder for this script. The log file will be stored in this location."
    $folder_browser_dialog.RootFolder = "MyComputer"
    if ($initial_dir) {
        $folder_browser_dialog.SelectedPath = $initial_dir
    }
    $result = $folder_browser_dialog.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
    if ($result -eq [Windows.Forms.DialogResult]::OK) {
        return $folder_browser_dialog.SelectedPath
    } else {
        Write-Host "Error. There is an issue with the select folder dialog."
        Start-Sleep(3)
        exit
    }
}

Clear-Host
Write-Host "Select the working folder for this script. The log file will be stored in this location."
$folder = get_folder("C:\")
# Loop to ensure user selects a working folder
while ($folder -eq "C:\") {
    Write-Host "Select the working folder for this script. The log file will be stored in this location."
    $folder = get_folder("C:\")
}
Write-Host "Working folder is $folder"
Start-Sleep(3)
Set-Location $folder

# start_time is used at the end of the script with end_time to determine execution_time
$start_time = Get-Date

# ScriptBlock for the Start-Job function below
$job_sb = 
{
    param(
        [String]$ip_address,
        [String]$log_file
    )

    function ping_host($ip_address) {
        if (Test-Connection -Count 1 -Quiet -Computername $ip_address) {
            try {
                Add-Content -Path $log_file $ip_address
            } catch {
                Write-Host "Error. Cannot write to log file. Possible permissions issue."
                Start-Sleep(3)
                exit
            }
        }
    }

    ping_host($ip_address)
}


# Set log file variable
$log_file = $folder + "\alive_hosts.log"
if (Test-Path -Path $log_file) {
    try {
        Remove-Item $log_file
    } catch {
        Write-Host "Error. Cannot remove existing log file. Possible permissions issue."
        Start-Sleep(3)
        exit
    }
}
try {
    New-Item $log_file
} catch {
    Write-Host "Error. Cannot create new log file. Possible permissions issue."
    Start-Sleep(3)
    exit
}

# Get IP range to scan #
Clear-Host
$start_ip = read-host "Enter starting IP address (e.g. 192.168.0.1)"
$end_ip = read-host "Enter ending IP address (e.g. 192.168.0.254)"

# Store addresses for printing and comparison
$start_ip_print = $start_ip
$end_ip_print = $end_ip

# Break up starting IP address into sections. Need this to increment octets and compare with end_ip.
$start_ip = $start_ip.split(".")
$start_ip_first_octet = [Int]$start_ip[0]
$start_ip_second_octet = [Int]$start_ip[1]
$start_ip_third_octet = [Int]$start_ip[2]
$start_ip_fourth_octet = [Int]$start_ip[3]

# Break up ending IP address into sections.
$end_ip = $end_ip.Split(".")
$end_ip_first_octet = [Int]$end_ip[0]
$end_ip_second_octet = [Int]$end_ip[1]
$end_ip_third_octet = [Int]$end_ip[2]
$end_ip_fourth_octet = [Int]$end_ip[3]

# Validate starting and ending IP addresses
$ip_address_pattern = "([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}"
if ($start_ip_print -notmatch $ip_address_pattern) {
    Write-Host "Error. Starting IP address not valid."
    Start-Sleep(3)
    exit
} elseif ($end_ip_print -notmatch $ip_address_pattern) {
    Write-Host "Error. Ending IP address not valid."
    Start-Sleep(3)
    exit
}

# Scan
$next_ip = [String]$start_ip_first_octet + "." + [String]$start_ip_second_octet + "." + [String]$start_ip_third_octet + "." + [String]$start_ip_fourth_octet
try {
    Add-Content -Path $log_file "Alive hosts as of: $todays_date"
} catch {
    Write-Host "Error. Cannot write to log file. Possible permissions issue."
    Start-Sleep(3)
    exit
}
while ($next_ip -ne $end_ip_print) {
    # Check to ensure all jobs have completed before cleaning up
    $running_job_count = (Get-Job | Where-Object State -eq Running).Count

    # Limit running jobs to 10
    while ($running_job_count -ge 10){
        $running_job_count = (Get-Job | Where-Object State -eq Running).Count
        Write-Host "$running_job_count jobs already running. Sleeping for 1 second."
        Start-Sleep -Seconds 1
    }

    $next_ip = [String]$start_ip_first_octet + "." + [String]$start_ip_second_octet + "." + [String]$start_ip_third_octet + "." + [String]$start_ip_fourth_octet
    Start-Job -ScriptBlock $job_sb -ArgumentList $next_ip, $log_file | Out-Null
    $start_ip_fourth_octet += 1
}

# Check to ensure all jobs have completed before cleaning up
$running_job_count = (Get-Job | Where-Object State -eq Running).Count

while ($running_job_count -ne 0){
    $running_job_count = (Get-Job | Where-Object State -eq Running).Count
    Write-Host "$running_job_count jobs still running. Sleeping for 1 second."
    Start-Sleep -Seconds 1
}

# Clean up jobs
Get-Job | Receive-Job -Force -Wait | Out-Null
Get-Job | Remove-Job -Force | Out-Null

# Read log file and print output
Clear-Host

try {
    $log_file_data = Get-Content -Path $log_file
} catch {
    Write-Host "Error. Cannot read log file. Possible permissions issue."
    Start-Sleep(3)
    exit
}
foreach ($line in $log_file_data) {
    Write-Host $line
}

# End timer
$end_time = Get-Date
$execution_time = $end_time - $start_time
Write-Host "Script executed in $execution_time (HH:MM:SS:MS)"