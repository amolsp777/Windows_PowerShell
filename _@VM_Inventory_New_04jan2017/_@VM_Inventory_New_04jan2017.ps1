<#

=============================================
FileName						: 		VM_Inventory.ps1
=============================================
Created [DD/MMM/YYYY]			:		[ 18.APR.2016 ]
Updated [DD/MMM/YYYY]			:  		[ 05.JAN.2017 ]
Author							: 		Amol Patil
Email							: 		amolsp777@live.com; pscriptsasp@gmail.com
Web								: 		[]
Requirements					:		[PowerCli v2.0 and above, no restriction policy ]
OS								: 		[Windows machine with PowerShell]
Version History					: 		[0.6]
=============================================
|> Purpose:
|					To get VM inventory.

DESCRIPTION:
					This script will connect to vSphere client and get the VMs from connected VC. 
					It will gather all the VM information which needs for every Admin to have as a VM inventory to check quickly or refer in future if something goes wrong.
					Script may takes time to fetch the information as it is gathering deep information of the VM to so you can schedule the script to fetch the information.

					VM inventory output will be store in CSV format so we can manage or play with data. 
                    
                    You can use VC seletion type         

		
VERSION HISTORY:
0.6         [05/Jan/2017]>
					Add VC selection menu.
                    Header added with  basic checks. PowerShell & Cli version. Popup msg will come if PowerCLI not install and it will redirect to VMware site to install PowerCLI.
					
0.5 		All reuqired filed added. 			
0.4			Powered OFF VM date added, output object type change, 		
0.3			Datastore Name, size, provisioning added.			
0.2			Cluster information added			
0.1			Base script
		
#>

# Get Start Time | to get the total elepsed time to complete this script.
$startDTM = (Get-Date)
Write-Host "Script Started at - $(Get-date -format "dd-MMM-yyyy HH:mm:ss")" -foregroundcolor white -backgroundcolor Green

#region 	Header	 <1/5/2017>
$PSVersion=$host | Select-Object -ExpandProperty Version
$PSVersion=$PSVersion -replace '^.+@\s'
$policy = Get-ExecutionPolicy 

#PowerCli Check. 

$snapin = Get-PSSnapin | select *
if($snapin.Name -like 'VMware.VimAutomation.Core'){
#$pcli = ($snapin.Name -eq 'VMware.VimAutomation.Core') | select -ExpandProperty Version -replace '^.+@\s' 
$pcli =($snapin | Where-Object {$_.name  -eq 'VMware.VimAutomation.Core'} | select -ExpandProperty Version) -replace '^.+@\s' 
}
else {
$pcli = "PowerCli Not Installed "

}
#$pcli

Write-Host ""
@"
===================================================
#	                                   @mol patil #
#                                                
#	            VM Inventory Script               	
#
#   Welcome : $env:USERNAME
#                          
#   PowherShell Version : $PSVersion
#   PowherCLI Version   : $pcli
#   Execution Policy    : $policy                                   
===================================================
"@ 
#endregion

If($pcli -ne "PowerCli Not Installed " ){



$SCRIPT_PARENT = Split-Path -Parent $MyInvocation.MyCommand.Definition 


#region VMWARE PLUGIN
if(-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue))
{Add-PSSnapin VMware.VimAutomation.Core}
#endregion

#region GET-VMInventory Function
Function Get-VMInventory {
 
  #region Other needed Functions
 function Get-RDMDisk {  
   [CmdletBinding()]  
   param (  
     [Parameter(Mandatory=$True)]  
     [string[]]$VMName  
     )  
         $RDMInfo = Get-VM -Name $VMName | Get-HardDisk -DiskType RawPhysical, RawVirtual  
         $Result = foreach ($RDM in $RDMInfo) {  
          "{0}/{1}/{2}/{3}"-f ($RDM.Name), ($RDM.DiskType),($RDM.Filename), ($RDM.ScsiCanonicalName)     
         }  
         $Result -join (", ")  
 }  
 function Get-vNicInfo {  
   [CmdletBinding()]  
   param (  
     [Parameter(Mandatory=$True)]  
     [string[]]$VMName  
     )  
         $vNicInfo = Get-VM -Name $VMName | Get-NetworkAdapter  
         $Result = foreach ($vNic in $VnicInfo) {  
           "{0}={1}"-f ($vnic.Name.split("")[2]), ($vNic.Type)  
         }  
         $Result -join (", ")  
 }  
 function Get-InternalHDD {  
   [CmdletBinding()]  
   param (  
     [Parameter(Mandatory=$True)]  
     [string[]]$VMName  
     )  
         $VMInfo = Get-VMGuest -VM $VMName # (get-vm $VMName).extensiondata  
         $InternalHDD = $VMInfo.ExtensionData.disk   
         $result = foreach ($vdisk in $InternalHDD) {  
           "{0}={1}GB/{2}GB"-f ($vdisk.DiskPath), ($vdisk.FreeSpace /1GB -as [int]),($vdisk.Capacity /1GB -as [int])  
         }  
         $result -join (", `n")  
 } 
  #endregion

$props = @()

# Below code can be use to get information based on selected condition. 
  #$VMs = Get-VM | where {($_.Name -like "P-LS*") -or ($_.Name -like "P-OW*")}

# Below code will check all the VMs.
<#
$vmcount = $(
Write-Host " "
 $selection = read-host 'You want to gather information from limited VMs? [Default is all]' 
 if ($selection) {
 $selection
 Write-Host "You have selected < $selection > VMs to fetch the information. "
 } else {$selection = "*"}
 #Write-Host "You have selected < ALL > VMs to fetch the information. "
 #}
 
)
#>

Write-Host " "
Write-Host "...Counting Total VMs."

$VMs = Get-VM #| select -First 5 
 
 $i = 0
 $E = 0
 $count = $vms.Count
 $E = $count

 Write-Host ""
 Write-Host "-----------------------------"
 Write-Host "Total Count of VMs - $count"
 Write-Host "-----------------------------"
     
foreach ($vm in $VMs) { 
    
# Get Start Time
$startVMCheck = (Get-Date)

$i++
Write-Progress -activity “Checking for VM: ($i of $E) >> $VM" -perc (($i / $E)*100)

     #region POWEROFF VM EVENT CHECK
     Get-VIEvent -Entity $VM -MaxSamples ([int]::MaxValue) | where {$_ -is [VMware.Vim.VmPoweredOffEvent]} |
     Group-Object -Property {$_.Vm.Name} | %{
     $lastPO = $_.Group | Sort-Object -Property CreatedTime -Descending | Select -First 1 | Select -ExpandProperty CreatedTime
     }
      
      $VMInfo = {} | Select PowerOFFDate
       If ( $VM.powerstate -eq "poweredoff"){
      $VMInfo.PowerOFFDate = $lastPO
      }
      Else {  $VMInfo.PowerOFFDate = "NA" }
     #endregion

   #region Defined Properties.


   #-----------------------Cluster check 
   If($vm.vmhost.ParentID -match 'Cluster*'){
        $HostType = $vm.vmhost.Parent.Name
         }

        else { $HostType = "Standalone Host" }

    #------------------------


    #region 	THIN Provisioning check 	 <11/15/2016>

    $ThinProView = $vm | Get-View
    $ThinPro = $ThinProView.config.hardware.Device.Backing.ThinProvisioned | Out-String

    #endregion

        $vm | Get-Datastore | %{
        $info = "" | select DataStoreName, DataCenterName, ClusterName, CapacityGB, ProvisionedSpaceGB,UsedSpaceGB,FreeSpaceGB,FreeSpacePer,NumVM 
        $info.DataStoreName = $_.Name
        $info.DataCenterName = $_.Datacenter
       # $info.ClusterName = $cluster.Name         
        $info.CapacityGB = [math]::Round($_.capacityMB/1024,2) 
        $info.ProvisionedSpaceGB = [math]::Round(($_.ExtensionData.Summary.Capacity - $_.ExtensionData.Summary.FreeSpace + $_.ExtensionData.Summary.Uncommitted)/1GB,2) 
        $info.UsedSpaceGB = [Math]::Round(($_.ExtensionData.Summary.Capacity - $_.ExtensionData.Summary.FreeSpace)/1GB,2)
        $info.FreeSpaceGB = [Math]::Round(($_.ExtensionData.Summary.FreeSpace)/1GB,2)
        $info.FreeSpacePer = [math]::Round(((100* ($_.ExtensionData.Summary.FreeSpace/1GB))/ ($_.ExtensionData.Summary.Capacity/1GB)),0) 
        #$info.NumVM = @($_ | Get-VM | where {$_.PowerState -eq "PoweredOn"}).Count 
        $report = $info 
        #$Result += $report 
        }

        # Host IP Details
        $hostIP = $vm.Host | Get-View | select @{N=“IPAddress“;E={($_.Config.Network.Vnic | ? {$_.Device -eq "vmk0"}).Spec.Ip.IpAddress}}
        


   #Associated Datastores  
    #$datastoreinfo = $vm | Get-Datastore
     $datastore = $($info.DataStoreName) -split ", " -join (",`n") #", " 
     $DSCapacity = $($info.CapacityGB) -split ", " -join (",`n") #
     $DSFreeSpace = $($info.FreeSpaceGB) -split ", " -join (",`n")
     $DSProviSpace = $($info.ProvisionedSpaceGB) -split ", " -join (",`n")
     
     #Snapshot info  
     $Snapshotinfo = $vm | Get-Snapshot 
     $snapshot = $Snapshotinfo.count  
     $snapshotCreated = ($Snapshotinfo.Created)  -join (",`n") #
     $snapshotName = ($Snapshotinfo.Name)  -join (",`n") #
     $snapshotSize = ($Snapshotinfo.SizeGB)  -join (",`n") #
     $snapshotDesc = ($Snapshotinfo.Description)  -join (",`n") #

           $Total_HDD= $vm.ProvisionedSpaceGB -as [int]  
           $HDDs_GB = ($vm | get-harddisk | select-object -ExpandProperty CapacityGB) -join " + "            
           $Partition = Get-InternalHDD -VMName $vm.Name

           $ToolsStatus = ($VM | % { get-view $_.id }).Guest.ToolsStatus
           $ToolVersion = ($VM | % { get-view $_.id }).Guest.ToolsVersion
    # VM Uptime calculation
     If ( $VM.powerstate -eq "poweredon"){
      $Timespan = New-Timespan -Seconds (Get-Stat -Entity $VM.Name -Stat sys.uptime.latest -Realtime -MaxSamples 1).Value
        $VMUptime = "" + $Timespan.Days + " Days" #+ $Timespan.Hours + " Hours, " +$Timespan.Minutes + " Minutes"
      }
      Else {  $VMUptime = " " }

    $datacenterName = $vm | Get-Datacenter
   $vCenterServer = ($vm).ExtensionData.Client.ServiceUrl.Split('/')[2]#.trimend(":443") 
   $PortGroup = ($vm | Get-NetworkAdapter).NetworkName -join ", `n"
   $vNic = (Get-VNICinfo -VMName $vm.name) -join ", `n"
   $MacAddress = ($vm | Get-NetworkAdapter).MacAddress -join ", `n"
        $vmTotalDisk = [Int]($vm.HardDisks).Count 
        $VMDiskGb = [Math]::Round((($vm.HardDisks | Measure-Object -Property CapacityKB -Sum).Sum * 1KB / 1GB),2)
        $VMDiskFree = [Math]::Round((($vm.Guest.Disks | Measure-Object -Property FreeSpace -Sum).Sum / 1GB),2)
        $VMDiskUsed = $VMInfo.DiskGb - $VMInfo.DiskFree
        $VMDK = ($vm | Get-HardDisk).filename -join ", `n"

   #endregion

   #region Property Result
           $Results = New-Object Object
           $Results | Add-Member -Type NoteProperty -Name 'VCName' -Value $vCenterServer 
           $Results | Add-Member -Type NoteProperty -Name 'VMName' -Value $vm.Name  
           $Results | Add-Member -Type NoteProperty -Name 'IPAddress'-value $vm.Guest.IPAddress[0] #$VM.ExtensionData.Summary.Guest.IpAddress  
           $Results | Add-Member -Type NoteProperty -Name 'MacAdress' -value $MacAddress
           $Results | Add-Member -Type NoteProperty -Name 'PowerState' -value $vm.PowerState  
           $Results | Add-Member -Type NoteProperty -Name "PowerOFFDate" -Value $VMInfo.PowerOFFDate
           $Results | Add-Member -Type NoteProperty -Name "VM_OS" -Value $vm.Guest.OSFullName
           $Results | Add-Member -Type NoteProperty -Name 'vCPU' -value $vm.NumCpu  
           $Results | Add-Member -Type NoteProperty -Name 'vRAM_GB' -value $vm.MemoryGB
           $Results | Add-Member -Type NoteProperty -Name 'VMVersion' -value $vm.Version
           $Results | Add-Member -Type NoteProperty -Name 'ToolStatus' -value $ToolsStatus
           $Results | Add-Member -Type NoteProperty -Name 'ToolVersion' -value $ToolVersion
           $Results | Add-Member -Type NoteProperty -Name 'VM_Uptime' -value $VMUptime
           $Results | Add-Member -Type NoteProperty -Name 'vNIC' -value $vNic
           $Results | Add-Member -Type NoteProperty -Name 'PortGroup' -value $PortGroup
           
           $Results | Add-Member -Type NoteProperty -Name 'TotalDisk' -value $vmTotalDisk
           $Results | Add-Member -Type NoteProperty -Name 'DiskGb' -value $VMDiskGb
           $Results | Add-Member -Type NoteProperty -Name 'Provision_HDD_GB' -value $Total_HDD
           $Results | Add-Member -Type NoteProperty -Name 'DiskFree' -value $VMDiskFree
           $Results | Add-Member -Type NoteProperty -Name 'HDDs_GB' -value $HDDs_GB
           $Results | Add-Member -Type NoteProperty -Name 'Partition' -value $Partition

           $Results | Add-Member -Type NoteProperty -Name 'Host' -value $vm.vmhost.name
           $Results | Add-Member -Type NoteProperty -Name 'HostIPAddress' -value $hostIP.IPAddress
           $Results | Add-Member -Type NoteProperty -Name 'HostState' -value $vm.VMHost.State
           $Results | Add-Member -Type NoteProperty -Name 'HostVersion' -value $vm.VMHost.Version
           $Results | Add-Member -Type NoteProperty -Name 'HostBuild' -value $vm.VMHost.Build
           
           $Results | Add-Member -Type NoteProperty -Name 'DataCenter' -value $datacenterName
           $Results | Add-Member -Type NoteProperty -Name 'ClusterType' -value $HostType
           $Results | Add-Member -Type NoteProperty -Name 'Cluster_OR_Folder' -value $vm.vmhost.Parent.Name
           #$Results | Add-Member -Type NoteProperty -Name 'Host' -value $vm.vmhost.name
           $Results | Add-Member -Type NoteProperty -Name 'ResourcePool' -value $vm.ResourcePool
           $Results | Add-Member -Type NoteProperty -Name 'VMFolder' -value $vm.folder

           $Results | Add-Member -Type NoteProperty -Name 'Datastore_Name' -value $datastore
           $Results | Add-Member -Type NoteProperty -Name 'Datastore_Capacity' -value $DSCapacity
           $Results | Add-Member -Type NoteProperty -Name 'Datastore_FreeSpace' -value $DSFreeSpace
           $Results | Add-Member -Type NoteProperty -Name 'Datastore_ProvisionSpace' -value $DSProviSpace

           $Results | Add-Member -Type NoteProperty -Name 'SnapShot_Count' -value $snapshot
           $Results | Add-Member -Type NoteProperty -Name 'SnapShot_Name' -value $snapshotName
           $Results | Add-Member -Type NoteProperty -Name 'SnapShot_Created' -value $snapshotCreated
           $Results | Add-Member -Type NoteProperty -Name 'SnapShot_Description' -value $snapshotDesc

           $Results | Add-Member -Type NoteProperty -Name 'VMPath' -value $vm.ExtensionData.config.files.VMpathname
           $Results | Add-Member -Type NoteProperty -Name 'VMDK' -value $VMDK
           $Results | Add-Member -Type NoteProperty -Name 'ThinProvision' -value $ThinPro
           $props += $Results
     #endregion


#Write-Output $obj | select-object -Property 'VMName', 'IP Address', 'Domain Name', 'Real-OS', 'vCPU', 'RAM(GB)', 'Total-HDD(GB)' ,'HDDs(GB)', 'Datastore', 'Partition/Size', 'Hardware Version', 'PowerState', 'Setting-OS', 'EsxiHost', 'vCenter Server', 'Folder', 'MacAddress', 'VMX', 'VMDK', 'VMTools Status', 'VMTools Version', 'VMTools Version Status', 'VMTools Running Status', 'SnapShots', 'DataCenter', 'vNic', 'PortGroup', 'RDMs' # 'Folder', 'Department', 'Environment' 'Environment'  

# Get End Time
$endVMCheck = (Get-Date)
$elapsedTime = $EndVMCheck-$StartVMCheck
$elapsedTimeOut =[Math]::Round(($elapsedTime.TotalMinutes),2)

Write-Host "Elapsed Time :> $elapsedTimeOut Minutes <#> To check VM :> $VM "

   }  
 Write-Output $props 

 
} #Function End
#endregion

#region 	VC Selection Menu <1/5/2017>
#=========================================================================
Function DefaultVC {$vCs = "VC1"}
# ========================================================================
Function manualVC {$VCs = Read-Host "Enter Virtual Center Name (Single) : "}
# ========================================================================
Function VCfromfile {$VCs= Get-Content ($SCRIPT_PARENT + "\VC_List.txt") -ErrorAction SilentlyContinue }
#@========================================================================
Function Bye { Exit }
#@========================================================================
#Gather info from user input.
$strResponse = @()
Write-Host ""
$strResponse = Read-Host "Enter your choice to select VC.
===================================================

[1] Enter VC_Name manually(Enter).

[2] VC_Name entered in Script.

[3] Get VC_Name(s) from file.

[0] Exit.
===================================================
"
            If($strResponse -eq "2"){. DefaultVC}
                elseif($strResponse -eq "1" -or "default"){. manualVC}
                elseif($strResponse -eq "3"){. VCfromfile}
                elseif($strResponse -eq "0"){. Bye}
                else{Write-Host "You did not supply a correct response, `

                Please run script again." -foregroundColor Red} 
#endregion

# Below code will check and go inside the each entered or given VC names.
Foreach($VC in $VCs){

If(Test-Connection $VC -Quiet -Count 1  ){

$U = ""
$P = ""

Write-Host "..Connecting to VC >> $VC"
#$VC_Connect = Connect-VIServer $VC -User $U -Password $P -WarningAction 0
$VC_Connect = Connect-VIServer $VC -WarningAction 0
}

Else {
    Write-Host ">>> VC is not available " -NoNewline -ForegroundColor Red ;Write-Host ": $($VC) " -ForegroundColor Yellow 

}

If($VC_Connect.IsConnected){

$VMout = Get-VMinventory
#$VMout | Out-GridView

  $SCRIPT_PARENT = Split-Path -Parent $MyInvocation.MyCommand.Definition 
  $Date = Get-Date -Format "dd-MM-yyyy"

    #************** Remove old files ***************************
     #remove-item ($SCRIPT_PARENT + "\Reports\$($VC)_VM_Inventory*.csv")  -force

    #************** Creating Outputfile  ***********************
  $outputfile =  ($SCRIPT_PARENT + "\Reports\$($VC)_VM_Inventory_Report(Complete)_$($date).csv")
  # "C:\Users\adm.amolp\Google Drive\_Script\VM_Inventory\_NewVM-Inventory_WIP_18Apr16\vcreport.csv"

  $VMout | Export-Csv -path $outputfile -NoTypeInformation

  Write-Host "Output has been created.."

Disconnect-VIServer $VC -Confirm:$False
}

} # Foreach VC loop end




# Get End Time
$endDTM = (Get-Date)
$totalelapsedTime = $endDTM-$startDTM
$TotalelapsedTimeOut =[Math]::Round(($totalelapsedTime.TotalMinutes),2)

Write-Host "................................................."
Write-Host "__ JOB DONE __" -ForegroundColor Green

Write-Host "Script Ended at - $(Get-date -format "dd-MMM-yyyy HH:mm:ss")" -foregroundcolor white -backgroundcolor red
Write-Host " "


Write-Host "Elapsed Time: $TotalelapsedTimeOut Minutes "

Write-Host "===============================================================================" # 80 * =
}

Else {
#region 	Popup msg 	 <1/5/2017>
function Popup {
# Create the shell object
$WshShell = New-Object -Com Wscript.Shell
# Call the Popup method with a 7 second timeout.
$Btn = $WshShell.Popup("PowerCLI not installed. `nDo you want to install?", 20, "Warning:", 0x4 + 0x20)
# Process the response
switch ($Btn) {
# Yes button pressed.
6 {
Write-Host "`nRun it again once you installed PowerCli.`n`nGood Bye for now!"
Start-Process "https://my.vmware.com/web/vmware/details?downloadGroup=PCLI550&productId=352"}
# No button pressed.
7 {"`nThank you, Good Bye !"}
# Timed out.
-1 {"`nTerminating as you not selected your choice."}
}
}
Popup
#endregion

}