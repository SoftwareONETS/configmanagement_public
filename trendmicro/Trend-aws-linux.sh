#!/bin/bash
Trend_TenantID=$1;
Trend_TokenID=$2;
process=`ps -elf | grep -i /var/opt/ds_agent | grep -v grep | awk {'print $15'}`;
if [ -x /etc/init.d/ds_agent ]; then
        if [ -z "$process" ]; then
                echo  "Agent is installed but not in Running mode !";
                echo "Starting the agent";
                /opt/ds_agent/ds_agent -w /var/opt/ds_agent -b -i -e /opt/ds_agent/ext;
        else
                echo "Agent is installed and in Running Mode !";
        fi;
else
echo "Agent is not installed on the Virtual machine";
ACTIVATIONURL='dsm://tmds-heartbeat.softwareone.cloud:443/';
MANAGERURL='https://tmds-console-waf.softwareone.cloud:443';
CURLOPTIONS='--silent --tlsv1.2';
linuxPlatform='';
isRPM='';
if type curl >/dev/null 2>&1; then
  curl $MANAGERURL/software/deploymentscript/platform/linuxdetectscriptv1/ -o /tmp/PlatformDetection $CURLOPTIONS --insecure;
  if [ -s /tmp/PlatformDetection ]; then
      . /tmp/PlatformDetection;
      platform_detect;

      if [[ -z "${linuxPlatform}" ]] || [[ -z "${isRPM}" ]]; then
         echo Unsupported platform is detected;
         logger -t Unsupported platform is detected;
         false;
      else
         echo Downloading agent package...;
         if [[ $isRPM == 1 ]]; then package='agent.rpm';
         else package='agent.deb';
         fi;
         curl $MANAGERURL/software/agent/$linuxPlatform -o /tmp/$package $CURLOPTIONS --insecure;
         echo Installing agent package...;
         rc=1;
         if [[ $isRPM == 1 && -s /tmp/agent.rpm ]]; then
           rpm -ihv /tmp/agent.rpm;
           rc=$?;
         elif [[ -s /tmp/agent.deb ]]; then
           dpkg -i /tmp/agent.deb;
           rc=$?;
         else
           echo Failed to download the agent package. Please make sure the package is imported in the Deep Security Manager;
           logger -t Failed to download the agent package. Please make sure the package is imported in the Deep Security Manager;
           false;
         fi;
         if [[ ${rc} == 0 ]]; then
           echo Install the agent package successfully;
            sleep 15;
            /opt/ds_agent/dsa_control -r;
            /opt/ds_agent/dsa_control -a $ACTIVATIONURL "tenantID:$Trend_TenantID" "token:$Trend_TokenID";
       else
           echo Failed to install the agent package;
           logger -t Failed to install the agent package;
           false;
         fi;
      fi;
  else
     echo "Failed to download the agent installation support script.";
     logger -t Failed to download the Deep Security Agent installation support script;
     false;
  fi;
else 
  echo "Please install CURL before running this script.";
  logger -t Please install CURL before running this script;
  false;
fi;
fi;