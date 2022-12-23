#!/usr/bin/env bash
set -euxo pipefail

OCI_CONFIG_FILE=./.oci/config

: Checking if config file is present
if [ ! -f "$OCI_CONFIG_FILE" ]
then
    echo "Missing .oci directory.\n It should be mounted in the application root directory /app/.oci"
    exit 1
fi

: Retrieving Compartment id
comp_id=$(oci iam compartment list --raw-output --query "data[0].\"compartment-id\"")
if [ -z "$comp_id" ]
then
    echo "No compartments found";
    exit 1
fi

: Retrieving DRG
drg_id=$(oci network drg list -c $comp_id --raw-output --query "data[0].id")
if [ -z "$drg_id" ]
then
    echo "No Dynamic Route Gateway (DRG) found"
    exit 1
fi

: Deleting ip-sec Connection 'Tunnel-Home'
ipsec_id=$(oci network ip-sec-connection list -c $comp_id --raw-output --query "data[?\"display-name\"=='Tunnel-Home'].id|[0]")
if [ ! -z "$ipsec_id" ]
then
    oci network ip-sec-connection delete --ipsc-id $ipsec_id --force --wait-for-state TERMINATED
fi

cpe_id_old=$(oci network cpe list -c $comp_id --raw-output --query "data[?\"display-name\"=='opnsense-home1'].id|[0]")
if [ ! -z "$cpe_id_old" ]
then
    : Deleting Customer Premise Endpoint
    oci network cpe delete --force --cpe-id $cpe_id_old
fi

: Creating Customer Premise Endpoint
cpe_id=$(oci network cpe create -c $comp_id \
    --ip-address $(curl -s -k \
        -u $(cat ~/.oci/opnsense.secret) \
        https://10.0.0.1/api/diagnostics/interface/getInterfaceConfig | jq -r '.pppoe0.ipv4[].ipaddr') \
    --cpe-device-shape-id 942bc0db-7074-40a5-8f32-36fcde183a9e --display-name opnsense-home1 \
    --raw-output --query data.id) 
if [ -z "$cpe_id" ]
then
    echo "Unable to create CPE"
    exit 1
fi

: Creating IPSEC Connection
ipsec_connection=$(oci network ip-sec-connection create -c $comp_id \
    --cpe-id $cpe_id --drg-id $drg_id --wait-for-state AVAILABLE \
    --static-routes '["10.0.0.0/8", "192.168.1.0/24", "192.168.60.0/24", "192.168.24.0/24"]' \
    --cpe-local-identifier-type HOSTNAME --cpe-local-identifier home.spoutin.org \
    --display-name Tunnel-Home --tunnel-configuration file://tunnel-configuration.json)
if [ -z "$ipsec_connection" ]
then
    echo "Error with command creating ips-sec conneciton."
    exit 1
fi

: Getting New IPSEC Endpoint IPs
ips_json=$(oci network ip-sec-tunnel list \
    --ipsc-id $(oci network ip-sec-connection list \
    -c $comp_id --raw-output --query "data[0].id") --all \
    --query "data[].{\"name\": \"display-name\", \"ip\": \"vpn-ip\"}")
if [ -z "$ips_json" ]
then
    echo "Unable to retrieve IPS from tunnel configuration"
    exit 1
fi

echo $ips_json

