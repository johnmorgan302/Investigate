$subject = Read-Host -Prompt "Host Name to Investigate"
Write-Output "Collecting information from $subject based on volitility"
$timestamp = Get-Date
$tsStr = $timestamp.ToString("yyyyMMdd")
$of = $subject+'_'+$tsStr+'.html'

## Write Report Header
$html_header = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-T3c6CoIi6uLrA9TneNEoa7RxnatzjcDSCmG1MXxSR1GAsXEV/Dwwykc2MPK8M2HN" crossorigin="anonymous">
    <title>Kelsey-Seybold Investigation</title>
</head>
<body>
"@

$html_footer = @"
</body>
</html>
"@

#Generate the HTML Report

$html_header > $of
$line = '<h1 class="bg-primary text-light">Investigation of <b>'+$subject+'</b> Executed '+$timestamp+'</h1>'
$line >> $of
$line = '<p>Report generated by <b>investigate.ps1</b> Written by John Morgan Nov 2023. '
$line += 'This report serves a quick way to preserve evidence, and locate malware.  it is not intended as a replacement for complete forensic analysis.</p>'
$line += '<h2 class="bg-primary text-light">Locard&#8217;s Transfer Information</h2>'
$line += '<p>It is impossible to investigate a computer without creating additional information on that computer.  Locard&#8217;s Transfer is the term for contamination done to an investigation by the act of investigating'
$line += 'To that end this report includes information on the system that performed the investigation of the subject computer.  Any information from the block below on the investigated computer comes from the process of doing the investigation.</p>'
$line >> $of
Write-Output '<pre>' >> $of
systeminfo >> $of
Write-Output '</pre>' >> $of


$subjectTimeStamp = Invoke-Command -ComputerName $subject -ScriptBlock { Get-Date }
Write-Output "Subject Timestamp: $subjectTimeStamp"
Write-Output "Gathering Hashes of all currently executing process executables"
$processExcecutables = Invoke-Command -ComputerName $subject -ScriptBlock{ $paths = [System.Collections.ArrayList]@();$processes=get-process;foreach($path in $processes.path){if((!$paths.contains($path)) -and ($path.Length -gt 3)){$paths.add($path)>$null;$hash = get-fileHash -Algorithm SHA256 $path;$result=[string]$hash.Hash + ' ' + $hash.Path;Write-Output $result}} }
Write-Output "Gathering Command Line Arguments of all executing processes"
$commandLines = Invoke-Command -ComputerName $subject -ScriptBlock{$names = [System.Collections.ArrayList]@();$ps=get-wmiobject win32_process;foreach($cmd in $ps.CommandLine){if(!$names.contains($cmd)){$names.add($cmd)>$null}};Write-Output $names}
Write-Output "Collecting ARP table"
$arp = Invoke-Command -ComputerName $subject -ScriptBlock{ arp /a }
Write-Output "Capturing all active network connections"
$netstat = Invoke-Command -ComputerName $subject -ScriptBlock{ netstat /naob }
Write-Output "Dumping DNS cache"
$dns = Invoke-Command -ComputerName $subject -ScriptBlock{ ipconfig /displaydns }
Write-Output "Gathering System Information"

## Write out the Subject Computer Info
$line = '<h2 class="bg-primary text-light">System Information</h2>'
$line += '<p><b>System Time Stamp:</b>'+$subjectTimeStamp+'</p><p>'
$line >> $of
Write-Output '<p><pre>' >> $of
Invoke-Command -ComputerName $subject -ScriptBlock{ systeminfo } >> $of
Write-Output '</pre></p>' >> $of

Write-Output "Gathering last 90 minutes of System Logs"
$sysLog = Invoke-Command -ComputerName $subject -ScriptBlock {get-eventlog system -after (get-date).addminutes(-90) | select-object timegenerated,instanceid, message}
Write-Output "Gathering last 90 minutes of Security Logs"
$securityLog = Invoke-Command -ComputerName $subject -ScriptBlock {get-eventlog security -after (get-date).addminutes(-90) | select-object timegenerated,instanceid, message}
Write-Output "Gathering last 90 minutes of Security Logs by User"
$secEventByUser = Invoke-Command -ComputerName $subject -ScriptBlock {$logs=get-eventlog security -after (get-date).AddMinutes(-90);foreach($l in $logs){$s=[string]$l.TimeGenerated+' '+$l.EventID+' '+$l.ReplacementStrings[1];$s}}
Write-Output "Gathering Last 90 minutes of Application Logs"
$appLog = Invoke-Command -ComputerName $subject -ScriptBlock {get-eventlog application -after (get-date).addminutes(-90) | select-object timegenerated,instanceid, message}
Write-Output "Enumerating all accounts with Admin rights"
$admins = Invoke-Command -ComputerName $subject -ScriptBlock {$n = [System.Collections.ArrayList]@();$admin=Get-LocalGroupMember Administrators;foreach($a in $admin.Name){if(!$n.contains($a)){$n.add($a)>$null}};Write-Output $n}
Write-Output "Collecting names of all attached printers"
$printers = Invoke-Command -ComputerName $subject -ScriptBlock { $names = [System.Collections.ArrayList]@();$printers=get-printer;foreach($pName in $printers.Name){if(!$names.contains($pName)){$names.add($pName)>$null}};Write-Output $names}
Write-Output "Collecting data on all attached storage devices"
$AttachedStorage = Invoke-Command -ComputerName $subject -ScriptBlock{ $names = [System.Collections.ArrayList]@();$drives=get-wmiobject win32_diskdrive;foreach($d in $drives.Caption){if(!$names.contains($d)){$names.add($d)>$null}};Write-Output $names }
Write-Output "Dumping Pre-Fetch Cache in chronological order (if available)"
$pf = Invoke-Command -ComputerName $subject -ScriptBlock {$fl=Get-ChildItem 'c:\windows\prefetch\';foreach($f in $fl){$o=[string]$f.CreationTime +'  '+$f.LastAccessTime+'  '+$f.Name; $o }}
Write-Output "Hasing all files an all download folders"
$DownloadFolder = Invoke-Command -ComputerName $subject -ScriptBlock { $users = ls 'c:\users' | select-Object name; foreach($user in $users.name){ $p = 'c:\users\'+$user+'\Downloads\' ; ls $p -Recurse | Get-Filehash}}
Write-Output "Enumerating all installed software"
$installedSW = Invoke-Command -ComputerName $subject -ScriptBlock { $s=[System.Collections.ArrayList]@();$s=Get-ItemProperty HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*;foreach ($i in $s.DisplayName){$i}}
Write-Output "Gathering all startup commands"
$startUp = Invoke-Command -ComputerName $subject -ScriptBlock {  $su=[System.Collections.ArrayList]@();$su=Get-CimInstance Win32_StartupCommand;foreach($s in $su.Command){$s} }
Write-Output "Collecting names and status of configured services"
$Services = Invoke-Command -ComputerName $subject -ScriptBlock { Get-Service | ft -AutoSize}
Write-Output "Listing all scheduled tasks"
$scheduledTasks = Invoke-Command -ComputerName $subject -ScriptBlock { Get-ScheduledTask }
Write-Output "Placing report in $of"

## Output the rest of the system info before dumping logs due to size
Write-Output '<h2>Administrators</h2>' >> $of
Write-Output '<p><pre>' >> $of
$admins >> $of
Write-Output '</pre></p>' >> $of

Write-Output '<h2>Attached Printers</h2>' >> $of
Write-Output '<p><pre>' >> $of
$printers >> $of
Write-Output '</pre></p>' >> $of

Write-Output '<h2>Attached Storage</h2>' >> $of
Write-Output '<p><pre>' >> $of
$AttachedStorage >> $of
Write-Output '</pre></p>' >> $of

Write-Output '<h2>Pre-Fetch Cache (if available)</h2>' >> $of
Write-Output '<p><pre>' >> $of
$pf >> $of
Write-Output '</pre></p>' >> $of

Write-Output '<h2>Files in all Download Folders</h2>' >> $of
Write-Output '<p><pre>' >> $of
$DownloadFolder >> $of
Write-Output '</pre></p>' >> $of

Write-Output '<h2>Pre-Fetch Cache Contents</h2>' >> $of
Write-Output '<p><pre>' >> $of
$pf >> $of
Write-Output '</pre></p>' >> $of

Write-Output '<h2>Startups</h2>' >> $of
Write-Output '<p><pre>' >> $of
$startUp >> $of
Write-Output '</pre></p>' >> $of

Write-Output '<h2>Installed Software</h2>' >> $of
Write-Output '<p><pre>' >> $of
$installedSW >> $of
Write-Output '</pre></p>' >> $of

Write-Output '<h2>Services</h2>' >> $of
Write-Output '<p><pre>' >> $of
$Services >> $of
Write-Output '</pre></p>' >> $of

Write-Output '<h2>Scheduled Tasks</h2>' >> $of
Write-Output '<p><pre>' >> $of
$scheduledTasks >> $of
Write-Output '</pre></p>' >> $of



## Dump Logs
Write-Output '<h2>LOGS</h2>' >> $of

Write-Output '<h3 class="bg-primary text-light">Application Log</h3>' >> $of
Write-Output '<p><pre>' >> $of
$appLog >> $of
Write-Output '</pre></p>' >> $of

Write-Output '<h3 class="bg-primary text-light">System Log</h3>' >> $of
Write-Output '<p><pre>' >> $of
$sysLog >> $of
Write-Output '</pre></p>' >> $of

Write-Output '<h3 class="bg-primary text-light">Security Log</h3>' >> $of
Write-Output '<p><pre>' >> $of
$securityLog >> $of
Write-Output '</pre></p>' >> $of

Write-Output '<h3 class="bg-primary text-light">Security Log - EventID by User</h3>' >> $of
Write-Output '<p><pre>' >> $of
$secEventByUser >> $of
Write-Output '</pre></p>' >> $of

## Write HTML Footer
$html_footer >> $of