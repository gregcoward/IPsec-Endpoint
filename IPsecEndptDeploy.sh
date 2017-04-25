#!/bin/bash
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin/"

function passwd() {
  echo | awk '{print $1}' /config/mypass
}

while getopts k:i:p:s:e:c:f:y:o:u:t:d: option
do	case "$option" in
     k) localIP=$OPTARG;;
     i) tunnelType=$OPTARG;;
     p) remoteEndPt=$OPTARG;;
     s) presharedKey=$OPTARG;;
     e) authStrength1=$OPTARG;;
     c) encryptStrength1=$OPTARG;;
     f) authStrength2=$OPTARG;;
     y) encryptStrength2=$OPTARG;;
     o) destNet=$OPTARG;;
	 u) destMask=$OPTARG;;
     t) intTunnelAddr=$OPTARG;;
     d) intTunnelMask=$OPTARG;;
	 x) subnetMask=$OPTARG;;
    esac 
done

user="admin"

# download iApp templates
template_location="/var/lib/waagent/custom-script/download/0"

for template in f5.ipsec.endpoint.tmpl
do
     cp $template_location/$template /config/$template
     response_code=$(curl -sku $user:$(passwd) -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/config -d '{"command": "load","name": "merge","options": [ { "file": "/config/'"$template"'" } ] }' -o /dev/null)
     if [[ $response_code != 200  ]]; then
          echo "Failed to install iApp template; exiting with response code '"$response_code"'"
          exit
     else
          echo "iApp template installation complete."
     fi
     sleep 10
done

# deploy application
response_code=$(curl -sku $user:$(passwd) -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/application/service/ -d '{"name":"azure2prem","partition":"Common","deviceGroup":"none","strictUpdates":"disabled","template":"/Common/F5-IPsec-Endpoint","trafficGroup":"traffic-group-local-only","tables":[{"name":"protsubs__rsubs","columnNames":["rdestaddr","rdestmask"],"rows":[{"row":["'"$destNet"'","'"$destMask"'"]}]}],"variables":[{"name":"basic__AzureDeploy","encrypted":"no","value":"Yes"},{"name":"basic__TG_selection","encrypted":"no","value":"/Common/traffic-group-local-only"},{"name":"basic__forwardvs","encrypted":"no","value":"Yes"},{"name":"basic__local__localendpt","encrypted":"no","value":"'"$localIP"'"},{"name":"basic__local__localendptmask","encrypted":"no","value":"'"$subnetMask"'"},{"name":"basic__vlan__selection","encrypted":"no","value":"internal"},{"name":"initial__tunneltype","encrypted":"no","value":"'"$tunnelType"'"},{"name":"protsubs__p1__auth","encrypted":"no","value":"'"$authStrength1"'"},{"name":"protsubs__p1__encrypt","encrypted":"no","value":"'"$encryptStrength1"'"},{"name":"protsubs__p2__auth","encrypted":"no","value":"'"$authStrength2"'"},{"name":"protsubs__p2__encrypt","encrypted":"no","value":"'"$encryptStrength2"'"},{"name":"protsubs__presharekey","encrypted":"no","value":"'"$presharedKey"'"},{"name":"protsubs__remoteendpt","encrypted":"no","value":"'"$remoteEndPt"'"},{"name":"protsubs__tsub__tunnelendpt","encrypted":"no","value":"'"$intTunnelAddr"'"},{"name":"protsubs__tsub__tunnelmask","encrypted":"no","value":"'"$intTunnelMask"'"}]}' -o /dev/null)

if [[ $response_code != 200  ]]; then
     echo "Failed to deploy iApp template; exiting with response code '"$response_code"'"
     exit
else 
     echo "Deployment complete."
fi
exit
