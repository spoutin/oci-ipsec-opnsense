# Opnsense Commands

## Get pppoe IP
``` bash
curl -s -k -u $(cat ~/.oci/opnsense.secret) https://10.0.0.1/api/diagnostics/interface/getInterfaceConfig | jq -r '.pppoe0.ipv4[].ipaddr'
```

# OCI CLI Commands

## Compartments
### Get Compartments
``` bash
oci iam compartment list
```

### Set ENV Variable for compartment id
``` bash
export COMP="ocid1.tenancy.oc1..aaaaaaaa5gukm2nxvfoc3kbmw67vdgkra7vttft42b4a5hts7sh3v5u4vg5a"
```
or
``` bash
export COMP=$(oci iam compartment list | jq -r '.data[0]["compartment-id"])
```

## Customer Premise Endpoints (CPE)
### Create CPE based on Opnsense Public IP
``` bash
oci network cpe create -c $COMP --ip-address $(curl -s -k -u $(cat ~/.oci/opnsense.secret) https://10.0.0.1/api/diagnostics/interface/getInterfaceConfig | jq -r '.pppoe0.ipv4[].ipaddr') --cpe-device-shape-id 942bc0db-7074-40a5-8f32-36fcde183a9e --display-name opnsense-home 
```

### Get Customer Premise Endpoints (CPE)
``` bash
oci network cpe list --compartment-id $COMP
```
or
``` bash
export CPE=$(oci network cpe list -c $COMP --raw-output --query "data[?\"display-name\"=='opnsense-home'].id|[0]")
```

### Delete CPE(s)
#### Delete ALL
``` bash
oci network cpe list --compartment-id $COMP | jq -r '.data[].id' | while read line; do oci network cpe delete --force --cpe-id $line ; done
```
#### Delete by display-name
``` bash
cpe delete --force --cpe-id $(oci network cpe list -c $COMP --raw-output --query "data[?\"display-name\"=='opnsense-home'].id|[0]")
```

## Dynamic Route Gateway (DRG)
``` bash
oci network drg list -c $COMP
```

## IP-SEC Connection / Tunnel

### List IP-SEC Connections
``` bash
oci network ip-sec-connection list -c $COMP
```
or
``` bash
oci network ip-sec-connection delete --ipsc-id $(oci network ip-sec-connection list -c $COMP --raw-output --query "data[?\"display-name\"=='Tunnel-Home'].id|[0]")
```

### Delete IP-SEC-Connection
``` bash
oci network ip-sec-connection delete --ipsc-id ocid1.ipsecconnection.oc1.ca-toronto-1.aaaaaaaag6pv7cgw7ntjseq4iaajwwqb5gl676l4j2bypp2i5szhof6dx5lq
```

### Create IP-SEC-Connection
``` bash
oci network ip-sec-connection create -c $COMP --cpe-id ocid1.cpe.oc1.ca-toronto-1.aaaaaaaas4eo22xt3lkbzlcsjmf7ghgyuxkhftbejk3dkx3ogg3vuqswuvcq --drg-id ocid1.drg.oc1.ca-toronto-1.aaaaaaaafeva6ai7cyimp5xw7ormeax2bn3dsx7jjxkbqmr3atcpqhy3vyfa --static-routes '["10.0.0.0/8", "192.168.1.0/24", "192.168.60.0/24", "192.168.24.0/24"]' --cpe-local-identifier-type HOSTNAME --cpe-local-identifier home.spoutin.org --display-name Tunnel-Home --tunnel-configuration file://tunnel-configuration.json
```

### Get IP-SEC-Tunnel List
``` bash
oci network ip-sec-tunnel list --ipsc-id ocid1.ipsecconnection.oc1.ca-toronto-1.aaaaaaaaieix4l46fqjzeiuhxxuyytikphqmk3735k7brucydcsbfmmcetrq --all
```

### Get IP-SEC-Tunnel PSK
``` bash
oci network ip-sec-psk get --ipsc-id ocid1.ipsecconnection.oc1.ca-toronto-1.aaaaaaaaieix4l46fqjzeiuhxxuyytikphqmk3735k7brucydcsbfmmcetrq  --tunnel-id ocid1.ipsectunnel.oc1.ca-toronto-1.aaaaaaaa4xdujm5nqcooqkl4m32mnevnvvnjvdgmufb4qzaaupg6dri7nzqa
```

### Update IP-SEC Connection
``` bash
oci network ip-sec-connection update --ipsc-id ocid1.ipsecconnection.oc1.ca-toronto-1.aaaaaaaag6pv7cgw7ntjseq4iaajwwqb5gl676l4j2bypp2i5szhof6dx5lq
```


### Update Opnsense ipsec.conf with new endpoint IPs
``` bash
perl -0777 -pe 's/(.+conn con1.+?right\s*=\s*)(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(.+?rightid\s*=\s*)(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(.+conn con2.+?right\s*=\s*)(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(.+?rightid\s*=\s*)(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(.+)/\1 boom1\3 boom1\5 boom2\7 boom2\9/s' ipsec.conf
```
