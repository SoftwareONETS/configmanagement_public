$COMMVAULT_CVD =  (Get-Process -Name cvd).Id
$COMMVAULT_CVFWD = (Get-Process -Name cvfwd).Id

if ($COMMVAULT_CVD -ne $null -or $COMMVAULT_CVFWD -ne $null){
Write-Output "Commvault is already installed & Running!"
exit 00
}

##Code Added For Taking Blob Url & Auth Code as arguments
$WindowsBlobUrl=$args[0]
$CommvaultAuthCode=$args[1]
if ($WindowsBlobUrl -eq $null -or $CommvaultAuthCode -eq $null){
Write-Host "Looks Like Script Does not have Required Arguments Please check Agent Blob or AuthCode if specified" -ForegroundColor Red
exit 12345} else {
write-host "Installing Commvault Agent through blob $WindowsBlob & authcode $CommvaultAuthCode" -ForegroundColor Green}



Function DEBUG([string]$line) {
    if ($_debug -eq $true) {
        Write-Host ("DEBUG:   " + $line)
    }
    return
}

Function WARNING([string]$line) {
    Write-Warning $line
    return
}

Function OUTPUT([string]$line) {
    if ($outFileName) {
        Add-Content $outFileName $line
    } else {
        Write-Host $line
    }
    return
}

Function GenerateOutput() {

$_debug = $true

    DEBUG ("Entered GenerateOutput()")
    # Determine if at least one app was discovered
    if ($discoveredApps.Count -gt 0) {
        OUTPUT "<CV_APP_LIST_START>"
        foreach ($app in $discoveredApps) {
            OUTPUT $app
        }
        OUTPUT "<CV_APP_LIST_END>"
    } else {
        DEBUG "No apps were discovered"
    }

    # Determine if the cluster info was requested
    if ($includeClusterInfo -eq $true) {
        # Generate the cluster info
        OUTPUT "<CV_CLUSTER_INFO_START>"
        if ($script:clusterInfo['isCluster'] -eq $true) {
            OUTPUT ("isCluster=" + $script:delim + "1" + $script:delim)
            if ($script:clusterInfo['isNode'] -eq $true) {
                OUTPUT ("isNode=" + $script:delim + "1" + $script:delim)
            } else {
                OUTPUT ("isNode=" + $script:delim + "0" + $script:delim)
            }
            OUTPUT ("clusterName=" + $script:delim + $script:clusterInfo['clusterName'] + $script:delim)
            OUTPUT ("nodeOrVirtualServerName=" + $script:delim + $script:clusterInfo['virtualServerName'] + $script:delim)
            if ($script:clusterInfo['isNode'] -eq $true) {
                [string]$hostableVirtualServerNames = ""
                [bool]$ignoreFirst = $true
                foreach ($hostableServerName in $script:clusterInfo['serverNames']) {
                    if ($ignoreFirst -eq $true) {
                        $ignoreFirst = $false
                    } else {
                        $hostableVirtualServerNames += "," + $hostableServerName
                    }
                }
                if ($hostableVirtualServerNames.Length -gt 0) {
                    $hostableVirtualServerNames = $hostableVirtualServerNames.Substring(1)
                }
                OUTPUT ("hostableVirtualServerNames=" + $script:delim + $hostableVirtualServerNames + $script:delim)
            } else {
                OUTPUT ("hostableVirtualServerNames=" + $script:delim + "" + $script:delim)
            }
        } else {
            OUTPUT ("isCluster=" + $script:delim + "0" + $script:delim)
            OUTPUT ("isNode=" + $script:delim + "0" + $script:delim)
            OUTPUT ("clusterName=" + $script:delim + "" + $script:delim)
            OUTPUT ("nodeOrVirtualServerName=" + $script:delim + "" + $script:delim)
            OUTPUT ("hostableVirtualServerNames=" + $script:delim + "" + $script:delim)
        }
        OUTPUT "<CV_CLUSTER_INFO_END>"
    }

    return
}

Function CleanUp() {
    DEBUG ("Entered CleanUp()")
    # Determine if a CIM session was created
    if ($script:cimSession -ne $null) {
        # Destroy the CIM session
        Remove-CimSession -CimSession $script:cimSession
    }
    return
}

Function GetRegistryStringValue([string]$keyName,
                                [string]$valueName) {
    DEBUG ("Entered GetRegistryStringValue(" + $script:delim + $keyName + $script:delim + ", " + $script:delim + $valueName + $script:delim + ")")
    # Determine if we have a CIM session
    [string]$value = ""
    if ($script:session -ne $null) {
        $value = (Invoke-CimMethod -CimSession $session -CimClass $registry -MethodName "GetStringValue" -Arguments @{ hDefKey = $script:HKLM; sSubKeyName = $keyName; sValueName = $valueName }).sValue
    } else {
        $valueObject = $script:registry.GetStringValue($script:HKLM, $keyName, $valueName)
        if ($valueObject.ReturnValue -eq 0) {
            $value = $valueObject.sValue
        }
    }
    DEBUG ("GetRegistryStringValue returning value " + $script:delim + $value + $script:delim)
    return $value
}

Function GetRegistryMultiStringValue([string]$keyName,
                                     [string]$valueName) {
    DEBUG ("Entered GetRegistryMultiStringValue(" + $script:delim + $keyName + $script:delim + ", " + $script:delim + $valueName + $script:delim + ")")
    # Determine if we have a CIM session
    [string[]]$values = @()
    if ($script:session -ne $null) {
        $values = (Invoke-CimMethod -CimSession $session -CimClass $registry -MethodName "GetMultiStringValue" -Arguments @{ hDefKey = $script:HKLM; sSubKeyName = $keyName; sValueName = $valueName }).sValue
    } else {
        $values = ($script:registry.GetMultiStringValue($script:HKLM, $keyName, $valueName)).sValue
    }
    DEBUG ("GetRegistryMultiStringValue returning values " + $script:delim + $values + $script:delim)
    return $values
}

Function GetRegistrySubKeys([string]$keyName) {
    DEBUG ("Entered GetRegistrySubKeys(" + $script:delim + $keyName + $script:delim + ")")
    # Determine if we have a CIM session
    [string[]]$subKeys = @()
    if ($script:session -ne $null) {
        $subKeys = (Invoke-CimMethod -CimSession $script:session -CimClass $script:registry -MethodName "EnumKey" -Arguments @{ hDefKey = $script:HKLM; sSubKeyName = $keyName }).sNames
    } else {
        $subKeys = $script:registry.EnumKey($script:HKLM, $keyName).sNames
    }
    DEBUG ("GetRegistrySubKeys returning subkeys " + $script:delim + $subKeys + $script:delim)
    return $subKeys
}

Function FindRegistrySubKey([string]$keyName, [string]$subKeyName) {
    DEBUG ("Entered FindRegistrySubKey(" + $script:delim + $keyName + $script:delim + ", " + $script:delim + $subKeyName + $script:delim + ")")
    [string[]]$subKeys = GetRegistrySubKeys $keyName
    [bool]$found = $false
    foreach ($subKey in $subKeys) {
        if ($subKey -eq $subKeyName) {
           $found = $true
        }
    }
    DEBUG ("FindRegistrySubKey returning " + $found)
    return $found
}

Function FindServiceServiceName([string]$serviceName,
                                [bool]$exactMatch = $false) {
    ############################################################################
    # Service names are found by exact match when $exactMatch is $true         #
    # Service names are found by partial match when $exactMatch is $false      #
    ############################################################################
    DEBUG ("Entered FindServiceServiceName(" + $script:delim + $serviceName + $script:delim + ", " + $exactMatch + ")")
    [bool]$found = $false
    if ($exactMatch -eq $true) {
        $foundServices = $script:services | Where-Object { ($_.Name -ne $null -and $_.Name -eq $serviceName) }
    } else {
        $sn = "*" + $serviceName + "*"
        $foundServices = $script:services | Where-Object { ($_.Name -ne $null -and $_.Name -like $sn) }
    }
    if ($foundServices -ne $null) {
        $found = $true
		        
    }
    DEBUG ("FindServiceServiceName returning " + $found)
    return $found
}

Function FindServiceBinaryName([string]$binaryName) {
    ############################################################################
    # Binary names are found by partial match always as .PathName is a FQFN    #
    ############################################################################
    DEBUG ("Entered FindServiceBinaryName(" + $script:delim + $binaryName + $script:delim + ")")
    [bool]$found = $false
    $bn = "*" + $binaryName + "*"
    $foundServices = $script:services | Where-Object { ($_.PathName -ne $null -and $_.PathName -like $bn) }
    if ($foundServices -ne $null) {
        $found = $true
    }
    DEBUG ("FindServiceBinaryName returning " + $found)
    return $found
}

Function FindServiceServiceNameAndBinaryName([string]$serviceName,
                                             [string]$binaryName,
                                             [bool]$exactMatch = $false) {
    ############################################################################
    # Service names are found by exact match when $exactMatch is $true         #
    # Service names are found by partial match when $exactMatch is $false      #
    # Binary names are found by partial match always as .PathName is a FQFN    #
    ############################################################################
    DEBUG ("Entered FindServiceServiceNameAndBinaryName(" + $script:delim + $serviceName + $script:delim + ", " + $script:delim + $binaryName + $script:delim + ", " + $exactMatch + ")")
    [bool]$found = $false
    $bn = "*" + $binaryName + "*"
    if ($exactMatch -eq $true) {
        $foundServices = $script:services | Where-Object { ($_.Name -ne $null -and $_.Name -eq $serviceName -and $_.PathName -ne $null -and $_.PathName -like $bn) }
    } else {
        $sn = "*" + $serviceName + "*"
        $foundServices = $script:services | Where-Object { ($_.Name -ne $null -and $_.Name -like $sn -and $_.PathName -ne $null -and $_.PathName -like $bn) }
    }
    if ($foundServices -ne $null) {
        $found = $true
    }
    DEBUG ("FindServiceServiceNameAndBinaryName returning " + $found)
    return $found
}

Function FindProcessBinaryName([string]$binaryName) {
    ############################################################################
    # Binary names are found by exact match always as .Name is not a FQFN      #
    ############################################################################
    DEBUG ("Entered FindProcessBinaryName(" + $script:delim + $binaryName + $script:delim + ")")
    [bool]$found = $false
    $foundProcesses = $script:processes | Where-Object { ($_.Name -ne $null -and $_.Name -eq $binaryName) }
    if ($foundProcesses -ne $null) {
        $found = $true
    }
    DEBUG ("FindProcessBinaryName returning " + $found)
    return $found
}

Function DumpInstanceInfo([string]$cvInstance = "") {
    DEBUG ("Entered DumpInstanceInfo(" + $script:delim + $cvInstance + $script:delim + ")")
    [string]$value=$cvInstance
    if ($value -ne "") {
        #OUTPUT ("CvInstance=" + $value)

        $value = GetRegistryStringValue ($script:cvRegistryRoot + "\" + $cvInstance) "sPhysicalNodeName"
        #OUTPUT ("CvClientName=" + $value)

        $value = GetRegistryStringValue ($script:cvRegistryRoot + "\" + $cvInstance) "sProductVersion"
        #OUTPUT ("CvProdVersion=" + $value)

        $value = GetRegistryStringValue ($script:cvRegistryRoot + "\" + $cvInstance + "\Base") "dBASEHOME"
        #OUTPUT ("CvGalaxyBase=" + $value)

        GenerateOutput

        OUTPUT "<CV_PKG_LIST_START>"

        [string[]]$installedPackages = GetRegistrySubKeys ($script:cvRegistryRoot + "\" + $cvInstance + "\InstalledPackages")
        foreach ($installedPackage in $installedPackages) {
            $value = GetRegistryStringValue ($script:cvRegistryRoot + "\" + $cvInstance + "\InstalledPackages\" + $installedPackage) "sInstallState"
            if ($value.Trim() -eq "Installed") {
                OUTPUT $installedPackage
            }
        }

        OUTPUT "<CV_PKG_LIST_END>"
    } else {
        OUTPUT ("CvInstance=" + $value)
        OUTPUT ("CvClientName=" + $value)
        OUTPUT ("CvProdVersion=" + $value)
        OUTPUT ("CvGalaxyBase=" + $value)
        GenerateOutput
        OUTPUT "<CV_PKG_LIST_START>"
        OUTPUT "<CV_PKG_LIST_END>"
        CleanUp
        Exit 00
    }
    return
}

Function GetClientDetails([string]$commServeName) {
    DEBUG ("Entered GetClientDetails(" + $script:delim + $commServeName + $script:delim + ")")
    $commServeName = $commServeName.Trim()
    DEBUG ("Finding the subkeys under key " + $script:delim + $script:cvRegistryRoot + $script:delim)

    # Get all of the installed Galaxy instances
    [string]$foundInstance = ""
    [string[]]$instances = GetRegistrySubKeys $script:cvRegistryRoot
    foreach ($instance in $instances) {
        # Determine if this is an instance key
        if ($instance.StartsWith("Instance") -eq $true) {
            # Read the sCSCLIENTNAME value of this instance key
            [string]$csName = GetRegistryStringValue ($script:cvRegistryRoot + "\" + $instance + "\CommServe") "sCSCLIENTNAME"

            # Determine if this is the sCSCLIENTNAME value we are looking for
            DEBUG ("Looking for " + $script:delim + $commServeName + $script:delim + " found sCSCLIENTNAME value " + $script:delim + $csName + $script:delim + " in key " + $script:delim + $script:cvRegistryRoot + "\" + $instance + "\CommServe" + $script:delim)
            if ($commServeName -eq $csName) {
                # Determine if this sCSCLIENTNAME value is not unique to this instance
                if ($foundInstance -ne "") {
                    WARNING ("Found two or more instances for CS Name " + $script:delim + $commServeName + $script:delim + ".")
                    DumpInstanceInfo ""   # This will cause the script to exit with a non-zero return code
                }

                # Save the first instance where sCSCLIENTNAME was found
                $foundInstance = $instance
            }
        }
    }

    # Determine if an instance for the specified CommServer name was not found
    if ($foundInstance -eq "") {
        #WARNING ("An instance for CS Name " + $script:delim + $commServeName + $script:delim + " was not found.")
        DumpInstanceInfo ""           # This will cause the script to exit with a non-zero return code
    }

    # Dump the instance info for the instance that was found
    DEBUG ("Found instance " + $script:delim + $foundInstance + $script:delim + " for CS Name " + $script:delim + $commServeName + $script:delim)
    DumpInstanceInfo $foundInstance

    return
}

Function DiscoverApps([string[]]$appList) {
    DEBUG ("Entered DiscoverApps(" + $script:delim + $appList + $script:delim + ")")
    foreach ($app in $appList) {
        DEBUG ("Application " + $app + ":  Discovering")
        [bool]$recognized = $false
        [bool]$found = $false
        switch ($app) {
            "ActiveDirectory" {
                $recognized = $true
                if ($found -eq $false) {
                    $found = FindServiceServiceName "NTDS" $true
                }
                if ($found -eq $false) {
                    $found = FindServiceServiceName "ADWS" $true
                }
            }

            "DB2" {
                $recognized = $true
                if ($found -eq $false) {
                    $found = FindServiceServiceNameAndBinaryName "DB2" "db2syscs.exe" $false
                }
            }

            "Exchange" {
                $recognized = $true
                if ($found -eq $false) {
                    $found = FindServiceServiceName "MSExchangeIS" $true
                }
            }

            "MSSQL" {
                $recognized = $true
                if ($found -eq $false -and
                    $script:clusterInfo['isCluster'] -eq $true) {
                    foreach ($serverName in $script:clusterInfo['serverNames']) {
                        if ($found -eq $false) {
                            [string]$serviceName = ([char]36 + $serverName)
                            $found = FindServiceServiceName $serviceName $false
                        }
                    }
                }
                if ($found -eq $false) {
                    $found = FindServiceServiceNameAndBinaryName "" "sqlservr.exe" $false
                }
                if ($found -eq $false) {
                    $found = FindServiceServiceNameAndBinaryName "" "SQLAGENT.exe" $false
                }
                if ($found -eq $false) {
                    $found = FindServiceServiceNameAndBinaryName "" "sqlceip.exe" $false
                }
            }

            "MySQL" {
                $recognized = $true
                if ($found -eq $false) {
                    $found = FindProcessBinaryName "mysqld.exe"
                }
                if ($found -eq $false) {
                    $found = FindRegistrySubKey "SOFTWARE\Wow6432Node" "MySQL AB"
                }
            }

            "Oracle" {
                $recognized = $true
                if ($found -eq $false) {
                    $found = FindServiceServiceNameAndBinaryName "OracleService" "ORACLE.EXE" $false
                }
            }

            "PostgreSQL" {
                $recognized = $true
                if ($found -eq $false) {
                    $found = FindServiceServiceName "postgresql" $false
                }
            }

            "SharePoint" {
                $recognized = $true
                if ($found -eq $false) {
                    $found = FindServiceServiceName "SPAdmin" $false
                }
            }

            "Sybase" {
                $recognized = $true
                if ($found -eq $false) {
                    $found = FindServiceServiceName "SYBSQL" $false
                }
            }
        }

        # Determine if the app was recognized
        if ($recognized -eq $true) {
            # Determine if the app was found
            if ($found -eq $true) {
                DEBUG ("Application " + $app + ":  Found")
                $script:discoveredApps += $app
            } else {
                DEBUG ("Application " + $app + ":  Not found")
            }
        } else {
            # The caller of this script passed in a bad iAppList
            WARNING ("Application " + $app + ":  Not recognized")
        }
        DEBUG ""
    }
    return
}

Function GetAppList([string]$apps) {
    DEBUG ("Entered GetAppList(" + $script:delim + $apps + $script:delim + ")")
    [string[]]$appList = @()
    if ($apps -ne "") {
        $appList = $apps.Trim(',').Split(",")
    } else {
        $appList = ("ActiveDirectory", "DB2", "Exchange", "MSSQL", "MySQL", "Oracle", "PostgreSQL", "SharePoint", "Sybase")
    }
    if ($appList -ne $null) {
        $found = $true
		
        #Installing FileSystemCore using Windows Blob
		Write-Host "Installing Filesystem Core Agent on Machine with blob $WindowsBlob & Authcode $CommvaultAuthCode"
        $ProgressPreference = 'SilentlyContinue'
		Invoke-WebRequest -Uri $WindowsBlobUrl -OutFile C:/Windows/WindowsFileSystemCore.exe ; C:/Windows/WindowsFileSystemCore.exe /silent /install /silent /authcode $CommvaultAuthCode
   
    }
       
    DEBUG ("GetAppList returning app list " + $script:delim + $appList + $script:delim)
    return $appList
}

Function GetClusterInfo() {
    DEBUG ("Entered GetClusterInfo()")

    # Initialize the cluster information
    [string]$clusterName = ""
    [bool]$isCluster = $false
    [bool]$isNode = $false
    [string[]]$serverNames = @()

    # Determine if the specified server is the local server
    if ($script:serverName -eq "") {
        # The target server is the local server
        [string]$virtualServerName = [System.Net.Dns]::GetHostName()
    } else {
        # The target server is a remote server
        [string]$virtualServerName = ((([System.Net.Dns]::GetHostEntry($script:serverName)).HostName).Split('.'))[0]
    }

    # The target server name is one of the server names
    $serverNames += $virtualServerName

    # Determine if the target server is not part of a cluster
    if ((FindRegistrySubKey "" "Cluster") -eq $false) {
        # The target server is a stand-alone server (not clustered)
    } else {
        # Get the cluster name
        $clusterName = GetRegistryStringValue "Cluster" "ClusterName"
        $isCluster = $true

        # Get the cluster node names
        [string[]]$nodeNames = @()
        [string[]]$nodeNumbers = GetRegistrySubKeys "Cluster\Nodes"
        foreach ($nodeNumber in $nodeNumbers) {
           $nodeNames += GetRegistryStringValue ("Cluster\Nodes\" + $nodeNumber) "NodeName"
        }

        # Determine if the targe server is a cluster virtual server
        [bool]$isNode = $false
        foreach ($nodeName in $nodeNames) {
           if ($virtualServerName -eq $nodeName) {
              $isNode = $true
           }
        }
        if ($isNode -eq $false) {
            # The target server is a cluster virtual server
        } else {
            # The target server is a cluster node
            # Find and check the network name resources
            [string[]]$resourceGuids = GetRegistrySubKeys "Cluster\Resources"
            foreach ($resourceGuid in $resourceGuids) {
                # Determine if this is a network name resource
                [string]$keyName = "Cluster\Resources\" + $resourceGuid
                [string]$type = GetRegistryStringValue $keyName "Type"
                if ($type -eq "Network Name") {
                    # Find the possible owners of this network name resource
                    [string[]]$possibleOwners = GetRegistryMultiStringValue $keyName "PossibleOwners"
                    [bool]$possibleOwner = $false
                    if ($possibleOwners.Count -eq 0) {
                        $possibleOwner = $true
                    } else {
                        foreach ($nodeNumber in $possibleOwners) {
                            [int]$nodeNameIndex = ([int]$nodeNumber) - 1
                            [string]$nodeName = $nodeNames[$nodeNameIndex]
                            if ($nodeName -eq $virtualServerName) {
                                $possibleOwner = $true
                            }
                        }
                    }

                    # Determine if this node is a possible owner of this network
                    # name resource
                    if ($possibleOwner -eq $true) {
                        # Add this network name as one of the available server
                        # names for this node
                        [string]$value = GetRegistryStringValue ("Cluster\Resources\" + $resourceGuid + "\Parameters") "Name"
                        $serverNames += $value
                    }
                }
            }
        }
    }

    $script:clusterInfo['virtualServerName'] = $virtualServerName
    $script:clusterInfo['clusterName']       = $clusterName
    $script:clusterInfo['isCluster']         = $isCluster
    $script:clusterInfo['isNode']            = $isNode
    $script:clusterInfo['serverNames']       = $serverNames

    DEBUG "Cluster Information:"
    DEBUG ("   Virtual server name  " + $script:delim + $script:clusterInfo['virtualServerName']  + $script:delim)
    DEBUG ("   Cluster name         " + $script:delim + $script:clusterInfo['clusterName']        + $script:delim)
    DEBUG ("   Is cluster           " + $script:delim + $script:clusterInfo['isCluster']          + $script:delim)
    DEBUG ("   Is cluster node      " + $script:delim + $script:clusterInfo['isNode']             + $script:delim)
    [int]$i = 0
    foreach ($serverName in $script:clusterInfo['serverNames']) {
        $i++
        DEBUG ("   Server name #" + $i + "       " + $script:delim + $serverName + $script:delim)
    }
    DEBUG ""
    return
}

Function OpenRegistry() {
    DEBUG ("Entered OpenRegistry()")
    [System.Management.ManagementClass]$registry = $null
    try {
        if ($script:session -ne $null) {
            DEBUG ("Using CIM to open registry")
            [Microsoft.Management.Infrastructure.CimClass]$registry = Get-CimClass -CimSession $session -ClassName "StdRegProv"
        } else {
            DEBUG ("Using WMI to open registry")
            if ($script:serverName -ne "" -and
                $script:credentials -ne $null)
            {
                [System.Management.ManagementClass]$registry = Get-WmiObject -List "StdRegProv" -Computer $script:serverName -Credential $script:credentials -ErrorAction Stop
            }
            else
            {
                [System.Management.ManagementClass]$registry = Get-WmiObject -List "StdRegProv" -ErrorAction Stop
            }
        }
    } catch {
        WARNING ("Exception:  Unable to open the registry - " + $($_.Exception.Message))
        $registry = $null
    }
    return $registry
}

Function GetProcesses() {
    DEBUG ("Entered GetProcesses()")
    [System.Management.ManagementObject[]]$processes = $null
    try {
        if ($script:session -ne $null) {
            DEBUG ("Using CIM to get processes")
            [Microsoft.Management.Infrastructure.CimInstance[]]$processes = Get-CimInstance -CimSession $script:session -ClassName "Win32_Process"
        } else {
            DEBUG ("Using WMI to get processes")
            if ($script:serverName -ne "" -and
                $script:credentials -ne $null)
            {
                [System.Management.ManagementObject[]]$processes = Get-WmiObject -Class "Win32_Process" -Computer $script:serverName -Credential $script:credentials -ErrorAction Stop
            }
            else
            {
                [System.Management.ManagementObject[]]$processes = Get-WmiObject -Class "Win32_Process" -ErrorAction Stop
            }
        }
    } catch {
        WARNING ("Exception:  Unable to get running processes - " + $($_.Exception.Message))
        $processes = $null
    }
    return $processes
}

Function GetServices() {
    DEBUG ("Entered GetServices()")
    [System.Management.ManagementObject[]]$services = $null
    try {
        if ($script:session -ne $null) {
            DEBUG ("Using CIM to get services")
            [Microsoft.Management.Infrastructure.CimInstance[]]$services = Get-CimInstance -CimSession $script:session -ClassName "Win32_Service"
        } else {
            DEBUG ("Using WMI to get services")
            if ($script:serverName -ne "" -and
                $script:credentials -ne $null)
            {
                [System.Management.ManagementObject[]]$services = Get-WmiObject -Class "Win32_Service" -Computer $script:serverName -Credential $script:credentials -ErrorAction Stop
            }
            else
            {
                [System.Management.ManagementObject[]]$services = Get-WmiObject -Class "Win32_Service" -ErrorAction Stop
            }
        }
    } catch {
        WARNING ("Exception:  Unable to get services - " + $($_.Exception.Message))
        $services = $null
    }
    return $services
}

Function CreateCimSession() {
    DEBUG ("Entered CreateCimSession()")
    [Microsoft.Management.Infrastructure.CimSession]$session = $null
    try {
        if ($script:serverName -ne "" -and
            $script:credentials -ne $null)
        {
            DEBUG ("Creating a CIM session for remote target server " + $script:delim + $script:serverName + $script:delim)
            [Microsoft.Management.Infrastructure.CimSession]$session = New-CimSession -ComputerName $script:serverName -Credential $script:credentials -ErrorAction Stop
        } else {
            DEBUG ("CIM session not created for the local target server")
            DEBUG ("WMI will be used instead of CIM")
        }
    } catch {
        DEBUG ("Exception:  Unable to create a CIM session - " + $($_.Exception.Message))
        $session = $null
    }
    return $session
}

Function GetCredentials([string]$serverName,
                        [string]$userName,
                        [string]$password) {
    DEBUG ("Entered GetCredentials(" + $script:delim + $serverName + $script:delim + ", " + $script:delim + $userName + $script:delim + ", " + $script:delim + "*** NOT SHOWN ***" + $script:delim + ")")
    [System.Management.Automation.PSCredential]$cred = $null
    if ($serverName -ne "" -and
        $userName -ne "" -and
        $password -ne "") {
        try {
            $passwordSecure = ConvertTo-SecureString $password -AsPlainText -Force
            $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName,$passwordSecure -ErrorAction Stop
        } catch {
            WARNING ("Exception:  Unable to build a PSCredential object - " + $($_.Exception.Message))
            $cred = $null
        }
    }
    return $cred
}

Function GetServerName([string]$specifiedServerName) {
    DEBUG ("Entered GetServerName(" + $script:delim + $specifiedServerName + $script:delim + ")")
    $thisServerName = ([System.Net.Dns]::GetHostEntry("127.0.0.1")).HostName
    try {
        $serverName     = ([System.Net.Dns]::GetHostEntry($specifiedServerName)).HostName
        if ($serverName -eq $thisServerName) {
            $serverName = ""
        }
    } catch {
        $serverName = "UNRESOLVED"
    }
    return $serverName
}

Function SetUp() {
    DEBUG ("Entered SetUp()")
    # Get the server name
    $script:serverName = GetServerName $iNode
    if ($script:serverName -eq "UNRESOLVED") {
        WARNING ("ERROR:  Cannot resolve target server name " + $script:delim + $iNode + $script:delim)
        CleanUp
        Exit 101
    }

    # Determine if the target server name is not blank (remote server)
    if ($script:serverName -ne "") {
        # Get the credentials
        $script:credentials = GetCredentials $script:serverName $iUserName $iPassword
        if ($script:credentials -eq $null) {
            WARNING "ERROR:  Unable to get credentials"
            CleanUp
            Exit 102
        }
    }

    # Create a CIM session
    $script:session = CreateCimSession

    # Get the services
    $script:services = GetServices
    if ($script:services -eq $null) {
        WARNING "ERROR:  Unable to get services"
        CleanUp
        Exit 103
    }

    # Get the running processes
    $script:processes = GetProcesses
    if ($script:processes -eq $null) {
        WARNING "ERROR:  Unable to get running processes"
        CleanUp
        Exit 104
    }

    # Open the registry
    $script:registry = OpenRegistry
    if ($script:registry -eq $null) {
        WARNING "ERROR:  Unable to open the registry"
        CleanUp
        Exit 105
    }

    # Get the cluster information
    $junk = GetClusterInfo

    # Get the Commvault base registry key
    $script:cvRegistryRoot = "SOFTWARE\CommVault Systems\Galaxy"
    return
}

Function Usage() {
    DEBUG ("Entered Usage()")
    Write-Host ""
    Write-Host "This script detects software applications installed on a machine."
    Write-Host ""
    Write-Host "Usage: "
    Write-Host "   .\AutoDetectApp.ps1 -node <Windows-Node> -userName <Windows-Login-User> -passwd <Windows-Login-Password> [-appList <App1, App2, ...>]"
    Write-Host ""
    return
}

Function main() {
    DEBUG ("Entered main()")
    # Determine if help was specified
    if ($_help -eq $true) {
        Usage
    } else {
        # Remove the output file if one was specified
        if ($outFileName -and
            (Test-Path $outFileName) -eq $true) {
            Remove-Item $outFileName
        }

        # Gather the information for the target server
        SetUp

        # Get the list of applications to discover
        [string[]]$appList = GetAppList $iAppList

        # Discover the applications
        DiscoverApps $appList

        # Determine if a CS name was specified
        if ($sCSCLIENTNAME -ne "") {
            # Get the client details for the specified CS name
            GetClientDetails $sCSClientName
        } else {
            # Generate the output without the client details
            GenerateOutput
        }

        # Clean up any persistent objects
        CleanUp
    }
    Exit 0
}

################################################################################
# Script execution starts here                                                 #
################################################################################
# Create the (script) global variables
[string[]]$discoveredApps = @()
[string]$serverName = ""
[System.Management.Automation.PSCredential]$credentials = $null
[Microsoft.Management.Infrastructure.CimSession]$cimSession = $null
$services = $null
$processes = $null
$registry = $null
[uint32]$HKLM = [uint32]'0x80000002'
[hashtable]$clusterInfo = @{}
[string]$cvRegistryRoot = ""
[string]$delim = [char]34

# Call the main function
main