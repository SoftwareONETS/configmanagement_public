#!/bin/sh
Url=$1
Code=$2
SERVICE_cvd="cvd"
SERVICE_cvlaunched="cvlaunchd"
SERVICE_cvfwd="cvfwd"


if [[ -z $Url || -z $Code ]]; then
  echo 'Please Check if Package Url & Auth Code for Commvault is missing!'
  exit 1
fi

echo "Variables found $Url for Package & $Code for Commvault Auth Code"


for ServiceCheck in $SERVICE_cvd $SERVICE_cvlaunched $SERVICE_cvfwd
do
if pgrep -x "$ServiceCheck" >/dev/null
then
    echo "$ServiceCheck is already running which means No Action Required On This Machine"
        exit 00
else
    echo "$ServiceCheck is stopped"
        sleep 05
fi
done
#Author : GIRISH RAO - 4/14/2016

#Input : -cs <CommServe name> or -inst <Commvault Instance Name> -appList <Comma seperate list of apps to discover> -output <xml - for XML output, Default is list> -includeClusterInfo
#What apps to discover:  DB2, MSSQL, MySQL, Oracle, PostgreSQL, SAPHana, Sybase

#Output:
# Client Name , Product Version
# List of apps discovered
# List of Commvault Packages installed on client.

#List by default, provide -output xml parameter to get XML output.

#CvClientName=graoLinuxSyb_2
#CvProdVersion=11.80.32.0
#<CV_APP_LIST_START>
#Oracle
#DB2
#<CV_APP_LIST_END>
#<CV_CLUSTER_INFO_START>
#isCluster="0"
#isNode="0"
#clusterName=""
#nodeOrVirtualServerName=""
#hostableVirtualServerNames=""
#<CV_CLUSTER_INFO_END>
#<CV_PKG_LIST_START>
#1002
#1003
#<CV_PKG_LIST_END>

#######XML#############
#<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
#<ClientInfo ClientName="graoLinuxSyb_2" ProductVersion="11.80.32.0">
#<Applications>
#<AppInfo AppName=Oracle/>
#</Applications>
#<ClusterInfo isCluster="0" isNode="0" clusterName="" nodeOrVirtualServerName="" hostableVirtualServerNames="" />
#<Packages>
#<PkgInfo PkgId=1002/>
#</Packages>
#</ClientInfo>

#VARIABLES
#LogFile="/tmp/CvAutoDetectApp.log"
LogFile="null"
Applications="DB2 MSSQL MySQL Oracle PostgreSQL SAPHana Sybase"
CvPackages=""
CvRegistryPath=""
CvInstanceName=""
CvClientName=""
CvProdVersion=""
OutputFormat=""
iCommServ=""
iCvInstance=""
func_output=""
includeClusterInfo="N"

#******************************COMMON FUNCTIONS***************************************#

Usage()
{
   echo "AutoDetectApp.sh -cs <CommServe name> or -inst <Commvault Instance Name> -appList <Comma seperate list of apps to discover> -output <xml - for XML output, Default is list> -includeClusterInfo"
   echo "Examples:"
   echo "AutoDetectApp.sh"
   echo "AutoDetectApp.sh -output xml"
   echo "AutoDetectApp.sh -cs myCS"
   echo "AutoDetectApp.sh -cs myCS -output xml"
   echo "AutoDetectApp.sh -cs myCS -appList Oracle,MySQL,DB2 -output xml"
   echo "AutoDetectApp.sh -appList Oracle,MySQL,DB2 -includeClusterInfo"
}

Log()
{
   echo `date` " :: " "$1" >> $LogFile
}

Exec()
{
   Log "`$1`"
}

IsEmptyString()
{
   if [ -z "$1" ]; then
      func_output="true"
   else
      func_output="false"
   fi
}

ExtractDirName()
{
   var=$1
   func_output=`echo $var | awk -F"/" '{print \$NF}'`
}

IsProcessRunning()
{
   ret=0
   osname=`uname -s`
   if [ "$osname" = "SunOS" ]; then
      ret=`ps -ef|grep -v grep|awk '{print \$9}'|grep $1|wc -l`
   else
      ret=`ps -e|awk '{print \$4}'|grep $1|wc -l`
   fi

   if [ $ret -gt 0 ]; then
      func_output="true"
   else
      func_output="false"
   fi
}

GenerateOutputXml()
{
   xmlOutput=""
   xmlBuf=""
   echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>"
   echo "<ClientInfo ClientName=\"$CvClientName\" ProductVersion=\"$CvProdVersion\">"
   echo "<Applications>"
   for app in $Applications
   do
      echo "<AppInfo AppName=$app/>"
   done
   echo "</Applications>"
   if [ $includeClusterInfo = "Y" ]; then
      echo "<ClusterInfo isCluster=\"0\" isNode=\"0\" clusterName=\"\" nodeOrVirtualServerName=\"\" hostableVirtualServerNames=\"\" />"
   fi
   echo "<Packages>"
   for pkg in $CvPackages
   do
      echo "<PkgInfo PkgId=$pkg/>"
   done
   echo "</Packages>"
   echo "</ClientInfo>"

}

GenerateOutput()
{
   IsEmptyString $CvClientName
   if [ $func_output = "false" ]; then
      echo "CvClientName=$CvClientName"
   fi

   IsEmptyString $CvProdVersion
   if [ $func_output = "false" ]; then
      echo "CvProdVersion=$CvProdVersion"
   fi

   echo "<CV_APP_LIST_START>"
   for app in $Applications
   do
      echo "$app"
        if [ ! -z "$app" ]
          then
        echo "Linux Core Agent Needs to be Installed"
        filetoRemove="/tmp/LinuxCore.tar"
        DirtoRemove="/tmp/pkg"

                if [ -f $file ] ; then
                echo "Removing File $file"
                rm -rf $filetoRemove $DirtoRemove
                fi
        curl -o /tmp/LinuxCore.tar "$Url" > /dev/null
		  #wget "$Url" -O /tmp/LinuxCore.tar
        tar -xf /tmp/LinuxCore.tar -C /tmp/
		  cd /tmp/pkg
        ./silent_install -p default.xml -authcode $Code
        echo "Blobl Url $1"
        fi

   done
   echo "<CV_APP_LIST_END>"

   if [ $includeClusterInfo = "Y" ]; then
      echo "<CV_CLUSTER_INFO_START>"
      echo "isCluster=\"0\""
      echo "isNode=\"0\""
      echo "clusterName=\"\""
      echo "nodeOrVirtualServerName=\"\""
      echo "hostableVirtualServerNames=\"\""
      echo "<CV_CLUSTER_INFO_END>"
   fi

   echo "<CV_PKG_LIST_START>"
   for pkg in $CvPackages
        do
                echo "$pkg"
        done
   echo "<CV_PKG_LIST_END>"
}

#*********************************COMMVAULT REGISTRY FUNCTIONS******************************************#
FindCvInstance()
{
   strBuf=""
   cvInstances=`ls -d /etc/CommVaultRegistry/Galaxy/Instance*`
   for cvInst in $cvInstances
   do
      strBuf=`grep "sCSCLIENTNAME" $cvInst"/CommServe/.properties"`
      if [ "$strBuf" = "sCSCLIENTNAME $iCommServ" ]; then
         ExtractDirName $cvInst
         return
      fi
   done

}

GetCvRegistryPath()
{
   IsEmptyString $CvInstanceName
   if [ $func_output = "false" ]; then
      func_output="/etc/CommVaultRegistry/Galaxy/"$CvInstanceName
   else
      func_output=""
   fi
}

GetCvClientName()
{
   func_output=`grep sPhysicalNodeName $CvRegistryPath"/.properties" | awk -F" " '{print \$2}'`
}

GetCvProdVersion()
{
   func_output=`grep sProductVersion $CvRegistryPath"/.properties" | awk -F" " '{print \$2}'`
}

GetCvPkgs()
{
   #array[${#array[@]}]
   strBuf=""
   pkgName=""
   cvSubSystems=`ls -d $CvRegistryPath/Installer/Subsystems/*`

   for entry in $cvSubSystems
   do
      strBuf=`grep "nINSTALL" "$entry/.properties"`
      if [ "$strBuf" = "nINSTALL 1" ]; then
         ExtractDirName $entry
         pkgName=$func_output
         if [ "$pkgName" != "CVGxNull"   ]; then
            CvPackages=$CvPackages" $pkgName"
         fi
      fi
   done
}

InitCvClientInfo()
{
   IsEmptyString $iCvInstance
   if [ $func_output = "true" ]; then
      FindCvInstance
      CvInstanceName=$func_output
   else
      CvInstanceName=$iCvInstance
   fi

   Log "CvInstanceName: $CvInstanceName"
   GetCvRegistryPath
   CvRegistryPath=$func_output
   Log "CvRegistryPath: $CvRegistryPath"
   GetCvClientName
   CvClientName=$func_output
   Log "CvClientName: $CvClientName"
   GetCvProdVersion
   CvProdVersion=$func_output
   Log "CvProdVersion: $CvProdVersion"
}

#****************************APPLICATION DISCOVERY FUNCTIONS*******************************************#
IsOracleInstalled()
{
   if [ -f "/etc/oratab" ]; then
      func_output="true"
   elif [ -f "/var/opt/oracle/oratab" ]; then
      func_output="true"
   else
      func_output="false"
   fi
}

IsDB2Installed()
{
   IsProcessRunning "db2sysc"
}

IsSybaseInstalled()
{
   IsProcessRunning "dataserver"
}

IsPostgreSQLInstalled()
{
   IsProcessRunning "postgres"
}

IsMSSQLInstalled()
{
   IsProcessRunning "sqlservr"
}

IsMySQLInstalled()
{
   IsProcessRunning "mysqld"
}

IsSAPHanaInstalled()
{
   IsProcessRunning "sapstartsrv"
}

DiscoverApps()
{
   iDAName=""
   AppList="$Applications"

   for app in $AppList
   do
      case $app in

      "Oracle")
         IsOracleInstalled
         if [ $func_output = "true" ]; then
                     Log "$app application is installed on this machine."
            else
                     Log "$app application is not installed on this machine."
            Applications=`echo $Applications|sed "s/$app//g"`
            fi
      ;;

      "DB2")
         iDAName="Db2Agent"
         IsDB2Installed
         if [ $func_output = "true" ]; then
                     Log "$app application is installed on this machine."
            else
                     Log "$app application is not installed on this machine."
            Applications=`echo $Applications|sed "s/$app//g"`
            fi
      ;;

      "Sybase")
         iDAName="SybaseAgent"
         IsSybaseInstalled
         if [ $func_output = "true" ]; then
                     Log "$app application is installed on this machine."
            else
                     Log "$app application is not installed on this machine."
            Applications=`echo $Applications|sed "s/$app//g"`
            fi
      ;;

      "PostgreSQL")
         iDAName="PostGres"
         IsPostgreSQLInstalled
         if [ $func_output = "true" ]; then
                     Log "$app application is installed on this machine."
            else
                     Log "$app application is not installed on this machine."
            Applications=`echo $Applications|sed "s/$app//g"`
            fi
      ;;

      "MSSQL")
         iDAName="SQLiDA"
         IsMSSQLInstalled
         if [ $func_output = "true" ]; then
            Log "$app application is installed on this machine."
         else
            Log "$spp application is not installed on this machine."
            Applications=`echo $Applications|sed "s/$app//g"`
         fi
      ;;

      "MySQL")
         iDAName="MySQL"
         IsMySQLInstalled
         if [ $func_output = "true" ]; then
                     Log "$app application is installed on this machine."
            else
                     Log "$app application is not installed on this machine."
            Applications=`echo $Applications|sed "s/$app//g"`
            fi
      ;;

      "SAPHana")
         iDAName="SAPHana"
         IsSAPHanaInstalled
         if [ $func_output = "true" ]; then
            Log "$app application is installed on this machine."
         else
            Log "$app application is not installed on this machine."
            Applications=`echo $Applications|sed "s/$app//g"`
         fi
      ;;

      *)
             Log "Unknown application $app"
             Applications=`echo $Applications|sed "s/$app//g"`
      ;;
   esac
   done
}

#--PARSE ARGS START--#
argList="$*"

   while [ $# -gt 0 ]
   do
      case $1 in
         "-cs")
         shift;
         iCommServ=$1
         ;;

         "-inst")
         shift;
         iCvInstance=$1
         ;;

         "-appList")
         shift;
         iAppList=$1
         iAppList=`echo $iAppList|sed "s/,/ /g"`
         Applications=$iAppList
         ;;

         "-output")
         shift;
         OutputFormat=$1
         ;;

         "-includeClusterInfo")
         includeClusterInfo="Y"
         ;;

         "-help")
         shift;
         Usage
         exit
      esac
      shift;
   done

#--PARSE ARGS END---#


#**************************************************MAIN STARTS***************************************************************************#
IsEmptyString $iCvInstance
InputInstEmpty=$func_output

IsEmptyString $iCommServ
InputCSEmpty=$func_output

if [ $InputInstEmpty = "false" ] || [ $InputCSEmpty = "false" ] ; then
   InitCvClientInfo
   GetCvPkgs
else
   Log "CommServ name is not set. Performing local discovery of Apps."
fi


#Call Discover Apps Module
DiscoverApps
#Log "Number of applications discovered : ${#Applications[@]}"
for app in $Applications
do
   Log $app
done

#Generate XML Output
if [ "$OutputFormat" = "xml" ] ; then
GenerateOutputXml
else
GenerateOutput
fi

#************************************************MAIN ENDS************************************************************************************#