﻿# Load .NET stuff for file/folder dialog
Add-Type -AssemblyName System.Windows.Forms

Function Get-Folder($initialDirectory) {
    [void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
    $FolderBrowserDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowserDialog.RootFolder = 'MyComputer'
    if ($initialDirectory) { $FolderBrowserDialog.SelectedPath = $initialDirectory }
    [void] $FolderBrowserDialog.ShowDialog()
    return $FolderBrowserDialog.SelectedPath
}

# Set location for running script. This really just dictates where the log file will be located.
clear-host
write-host "Select the working folder for this script. The log file will be stored in this location."
$folder = Get-Folder("C:\")
while ($folder -eq "C:\") {
    write-host "Select the working folder for this script. The log file will be stored in this location."
    $folder = Get-Folder("C:\")
}
write-host "Working folder is " + $folder
start-sleep(3)
set-location $folder

##### Start timer #####
$start_time = get-date

$job_sb = 
{
    param(
        [string]$ip,
        [string]$log_file
    )

    function ping_host($ip) {
        if (test-connection -count 1 -quiet -computername $ip) {
            add-content -path $log_file $ip
        }
    }

    ping_host($ip)
}


##### variables #####
$todays_date = get-date

# Set log file variable
$log_file = $folder + "\alive_hosts.log"
if (test-path -path $log_file) {
    try {
        remove-item $log_file
    } catch {
        write-host "Error. Cannot remove existing log file. Possible permissions issue."
    }
}
try {
    new-item $log_file
} catch {
    write-host "Error. Cannot create new log file. Possible permissions issue."
}


##### Get network to scan #####
clear-host
$start_ip = Read-Host "Enter starting IP address (e.g. 192.168.0.1)"
$end_ip = Read-Host "Enter ending IP address (e.g. 192.168.0.254)"

##### Store addresses for printing #####
$start_ip_print = $start_ip
$end_ip_print = $end_ip

##### Break up starting IP address into sections #####
$start_ip = $start_ip.split(".")
$start_ip_first_octet = [int]$start_ip[0]
$start_ip_second_octet = [int]$start_ip[1]
$start_ip_third_octet = [int]$start_ip[2]
$start_ip_fourth_octet = [int]$start_ip[3]

##### Break up ending IP address into sections #####
$end_ip = $end_ip.Split(".")
$end_ip_first_octet = [int]$end_ip[0]
$end_ip_second_octet = [int]$end_ip[1]
$end_ip_third_octet = [int]$end_ip[2]
$end_ip_fourth_octet = [int]$end_ip[3]

##### TO DO - Input validation #####
# Regex to test IP format
# Make sure starting IP is lower than ending IP
##### TO DO - Input validation #####

##### Scan #####
$next_ip = [string]$start_ip_first_octet + "." + [string]$start_ip_second_octet + "." + [string]$start_ip_third_octet + "." + [string]$start_ip_fourth_octet
add-content -path $log_file "Alive hosts as of: $todays_date"
while ($next_ip -ne $end_ip_print) {
    # Check to ensure all jobs have completed before cleaning up
    $running_job_count = (get-job | where state -eq running).count

    while ($running_job_count -ge 10){
        $running_job_count = (get-job | where state -eq running).count
        write-host "$running_job_count jobs already running. Sleeping for 1 second."
        start-sleep -Seconds 1
    }

    $next_ip = [string]$start_ip_first_octet + "." + [string]$start_ip_second_octet + "." + [string]$start_ip_third_octet + "." + [string]$start_ip_fourth_octet
    start-job -scriptblock $job_sb -argumentlist $next_ip, $log_file
    $start_ip_fourth_octet += 1
}

# Check to ensure all jobs have completed before cleaning up
$running_job_count = (get-job | where state -eq running).count

while ($running_job_count -ne 0){
    $running_job_count = (get-job | where state -eq running).count
    write-host "$running_job_count jobs still running. Sleeping for 1 second."
    start-sleep -seconds 1
}

# Clean up jobs
get-job | receive-job -force -wait
get-job | remove-job -force

##### Read log file and print output #####
clear-host

$log_file_data = get-content -path $log_file
foreach ($line in $log_file_data) {
    write-host $line
}

##### End timer #####
$end_time = get-date
$execution_time = $end_time - $start_time
write-host "Script executed in (HH:MM:SS:MS) $execution_time"