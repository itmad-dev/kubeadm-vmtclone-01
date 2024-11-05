<#
  REQUIREMENTS
    PowerCLI
    PSLogging PowerShell Module
     Install-Module PSLogging
    Accessible XML credentials file, with the password encrypted, containing vCenter server credentials
     e.g., "[REDACTED]"
    Acessible local configuration JSON file
     e.g., [REDACTED].json
    Acessible local k8s nodes configuration file
     e.g., [REDACTED].txt
    Accessible logs location
     e.g., C:\scripts\PowerCLI\logs
    Accessible script output location
     e.g., C:\scripts\PowerCLI\output
#>

<#
.SYNOPSIS
Create new VMs for K8s cluster nodes.

.DESCRIPTION
Connects to vCenter, creates resource pool for K8s nodes (if needed), validates node request list file (including existing conflicting VM names), sets the network settings for a VM Customization Specification, creates the VMs.

.PARAMETER localConfigFile
Mandatory. The full path, file name to a JSON configuration file containing local environment specific variables for log and report paths, server names/FQDNs, XML credentials file, and SMTP mail object details

.PARAMETER k8sNodesRequestListFile
Mandatory. A comma delimited list, including headers, for node number, node type, nodeIP, subnet mask, gateway; store/use as text file to ensure node numbers are treated as text.

.PARAMETER outputType
Mandatory. The report outut type: csv, html.


.NOTES
 Version 1.0
 Author:  Jerry Nihen
 Creation Date:  9/27/2022
 Purpose/change: initial creation
 Documentation:
   VMWareCloneTemplateLab3.docx
   JMN GitHub repo scripts\PowerCLI\New-VMK8sClusterNode1.ps1

.EXAMPLE

WINSTON
 .\New-VMK8sClusterNode1.ps1 -localConfigFile '[REDACTED]' -k8sNodesRequestListFile '[REDACTED]' -outputType 'csv'
 .\New-VMK8sClusterNode1.ps1 -localConfigFile '[REDACTED]' -k8sNodesRequestListFile '[REDACTED]' -outputType 'csv'

#>
#------------------------------[Parameters]------------------------------
[CmdletBinding()]
param(
    [Parameter(Mandatory=$True, ParameterSetName="baseParams")]
    [String]$localConfigFile,
    [Parameter(Mandatory=$True, ParameterSetName="baseParams")]
    [String]$k8sNodesRequestListFile,
    [Parameter(Mandatory=$True, ParameterSetName="baseParams")]
    [ValidateSet('csv','html')]
    [String]$outputType
)
#------------------------------[Initializations]------------------------------

Import-Module PSLogging

#------------------------------[Declarations]------------------------------

#Script Version
$script:strScriptVersion = '1.0'

#Date Time format
$script:strDate = (get-date).ToString("MMddyyyy_HHmm")

#Report components
$script:rptHeader = ''
$script:rptHeadingSummary = "<h3>Summary</h3>"
$script:rptHeadingSummaryFragments = ''
$script:rptFragments = ''
$script:rptFooter = ''

#Node settings
$script:arrk8sNodesFromRequestList = @()
$script:arrk8sNewNodesToCreate = @()
$script:nodeNetworkConfigSpec = ''



#------------------------------[Functions]------------------------------

Function Set-ScriptVariablesFromLocalConfigFile(){
  Begin {
       
  }

  Process {
              
         Try {
            $objConfigSettings = Get-Content -Path $localConfigFile | ConvertFrom-Json
            # credentials
            $script:creds = Import-Clixml -Path $objConfigSettings.credentials.credPathFile
            # logs
            $script:strLogPath = $objConfigSettings.logs.path
            $script:strLogFileNamePrelim = $objConfigSettings.logs.fileNamePrelim
            $script:strLogFileName = $script:strLogFileNamePrelim  + '_' + $strDate + '.txt'
            $script:strLogFile = Join-Path -Path $script:strLogPath -ChildPath $script:strLogFileName
            # reports
            $script:strReportPath = $objConfigSettings.reports.path
            $script:strReportFileNamePrelim = $objConfigSettings.reports.fileNamePrelim
            $script:strReportFileName = $script:strReportFileNamePrelim  + '_' + $strDate + '.' + $outputType
            $script:strReportFile = Join-Path -Path $script:strReportPath -ChildPath $script:strReportFileName
            # servers
            $script:vCenter = $objConfigSettings.servers.vCenter
            # nodeConfig
            $script:vCenterClusterName = $objConfigSettings.nodeConfig.vCenterClusterName
            $script:vCenterResourcePool = $objConfigSettings.nodeConfig.vCenterResourcePool
            $script:K8sClusterName = $objConfigSettings.nodeConfig.K8sclusterName
            $script:customizationSpec = $objConfigSettings.nodeConfig.customizationSpec
            $script:vmTemplate = $objConfigSettings.nodeConfig.vmTemplate
            $script:vCenterDatastore = $objConfigSettings.nodeConfig.vCenterDatastore
            $script:vCenterHost = $objConfigSettings.nodeConfig.vCenterHost
            # email
            $script:smtpServer = $objConfigSettings.email.smtpServer
            $script:smtpTo = $objConfigSettings.email.smtpTo
            $script:smtpFrom = $objConfigSettings.email.smtpFrom
            $script:smtpMessageSubject = $objConfigSettings.email.MessageSubject
            }
    Catch {
          Write-LogError -LogPath $script:strLogFile -Message $_.Exception -ExitGracefully
          Break
    }
   }

  End {
    If ($?) {
      Write-LogInfo -LogPath $script:strLogFile -Message 'Completed Successfully.'
      Write-LogInfo -LogPath $script:strLogFile -Message ' '
    }
  }
  }

Function Connect-vCenter {

  Begin {
    Write-LogInfo -LogPath $script:strLogFile -Message "Connecting to vCenter $script:vCenter ..."

  }

  Process {
    Try {
          Connect-VIServer -Server $script:vCenter -Credential $script:creds.vCenterTestCoLabCred -WarningAction SilentlyContinue
    }

    Catch {
      Write-LogError -LogPath $script:strLogFile -Message $_.Exception -ExitGracefully
      Break
    }
  }

  End {
    If ($?) {
      Write-LogInfo -LogPath $script:strLogFile -Message 'Completed Successfully.'
      Write-LogInfo -LogPath $script:strLogFile -Message ' '
    }
  }
}


Function Set-NodevCenterResourcePool(){
  Begin {
        Write-LogInfo -LogPath $script:strLogFile -Message "Setting Node vCenter Resource Pool $script:vCenterResourcePool" 
  }

  Process {
    Try {
            $poolExists = Get-ResourcePool $script:vCenterResourcePool
            if ($poolExists -ne $null) {
              Write-LogInfo -LogPath $script:strLogFile -Message 'vCenter Resource Pool $script:vCenterResourcePool already exists'
              Write-LogInfo -LogPath $script:strLogFile -Message ' '

            } else {
                New-ResourcePool -Name $script:vCenterResourcePool -Location $script:vCenterClusterName
            }
     }

    Catch {
          Write-LogError -LogPath $script:strLogFile -Message $_.Exception -ExitGracefully
          Break
    }

   }

  End {
    If ($?) {
      Write-LogInfo -LogPath $script:strLogFile -Message 'Completed Successfully.'
      Write-LogInfo -LogPath $script:strLogFile -Message ' '
    }
  }
  }


Function Get-K8sNodesFromRequestList(){
  Begin {
        Write-LogInfo -LogPath $script:strLogFile -Message "Getting K8s Nodes From Request List" 
  }

  Process {
    Try {
            $script:arrk8sNodesFromRequestList = Import-Csv -Path $k8sNodesRequestListFile

     }

    Catch {
          Write-LogError -LogPath $script:strLogFile -Message $_.Exception -ExitGracefully
          Break
    }

   }

  End {
    If ($?) {
      Write-LogInfo -LogPath $script:strLogFile -Message 'Completed Successfully.'
      Write-LogInfo -LogPath $script:strLogFile -Message ' '
    }
  }
  }


Function Initialize-ValidNewNodesToCreateDetails(){
  Begin {
        Write-LogInfo -LogPath $script:strLogFile -Message "Getting Node VM Spec Details from K8s Nodes List" 
  }

  Process {
    Try {
            if ($script:arrk8sNodesFromRequestList -ne $null) {
                foreach ($nodeToCreate in $script:arrk8sNodesFromRequestList) {
                    $nodeNumber = $nodeToCreate.nodeNumber
                    $nodeType = $nodeToCreate.nodeType
                    $nodeIP = $nodeToCreate.nodeIP
                    $nodeSubnetMask = $nodeToCreate.subnetMask
                    $nodeGateway = $nodeToCreate.gateway
                    $nodeNamePrefix = $script:K8sClusterName + '-' 
                    switch ($nodeType)
                    {
                        'control' {
                            $nodeVMName = $nodeNamePrefix + 'cp' + $nodeNumber
                        }
                        'worker' {
                            $nodeVMName = $nodeNamePrefix + 'w' + $nodeNumber
                        }
                    }
                    $testNodeVM = Get-VM $nodeVMName -ErrorAction SilentlyContinue
                    if ($testNodeVM -eq $null) {
                        $objNewNodeToCreate = New-Object PSObject -Property @{nodeVMName=$nodeVMName; nodeIP=$nodeIP; nodeSubnetMask=$nodeSubnetMask; nodeGateway=$nodeGateway;}
                        $script:arrk8sNewNodesToCreate += $objNewNodeToCreate
                      }
                    New-K8sClusterNode $nodeVMName $nodeIP $nodeSubnetMask $nodeGateway                
                }
             }
         }
    Catch {
          Write-LogError -LogPath $script:strLogFile -Message $_.Exception -ExitGracefully
          Break
     }
    }


  End {
    If ($?) {
      Write-LogInfo -LogPath $script:strLogFile -Message 'Completed Successfully.'
      Write-LogInfo -LogPath $script:strLogFile -Message ' '
    }
  }
  }


  Function New-K8sClusterNode( $nodeVMName, $nodeIP, $nodeSubnetMask, $nodeGateway){
  Begin {
        Write-LogInfo -LogPath $script:strLogFile -Message "Creating new K8s cluster node $nodeVMName" 
  }

  Process {
    Try {
            if ($script:arrk8sNewNodesToCreate -ne $null) {
               Get-OSCustomizationNicMapping -OSCustomizationSpec (Get-OSCustomizationSpec -name $script:customizationSpec) | Set-OSCustomizationNicMapping -IPmode UseStaticIP -IpAddress $nodeIP -SubnetMask $nodeSubnetMask -DefaultGateway $nodeGateway
               $currNicSpec = Get-OSCustomizationSpec -name $script:customizationSpec
               New-VM -name $nodeVMName -Template (get-template -name $script:vmTemplate) -OSCustomizationSpec  $currNicSpec -VMHost $script:vCenterHost -datastore $script:vCenterDatastore -ResourcePool $script:vCenterResourcePool
            }
    }

    Catch {
          Write-LogError -LogPath $script:strLogFile -Message $_.Exception -ExitGracefully
          Break
    }

   }

  End {
    If ($?) {
      Write-LogInfo -LogPath $script:strLogFile -Message 'Completed Successfully.'
      Write-LogInfo -LogPath $script:strLogFile -Message ' '
    }
  }
  }






  
#------------------------------[Execution]------------------------------

# Script setup settings
Set-ScriptVariablesFromLocalConfigFile
Start-Log -LogPath $script:strLogPath -LogName $script:strLogFileName -ScriptVersion $strScriptVersion
# Server connections
Connect-vCenter
# vCenter ResourcePool, VMs
Set-NodevCenterResourcePool
Get-K8sNodesFromRequestList
Initialize-ValidNewNodesToCreateDetails
# Server disconnects
Disconnect-VIServer -Confirm:$false
# Script teardown settings
Stop-Log -LogPath $strLogFile
Remove-Variable * -ErrorAction SilentlyContinue
