## ky13 (kritchie@redhat.com

echo " "
echo -e "########################################\n### Create Hawkular Infrastructure (Hawkular/Heapster/Cassandra DB) ###\n########################################"
echo " "

## Prompt user for requisite variables
echo "Please enter the PV name (ex. myvolume):"
read volName

echo "Please enter the volume size (ex. 10Gi):"
read volSize

echo "Please enter the path to the nfs mounted share (ex. /mnt/nfs):"
read nfsPath

echo "Please enter the nfs server IP or FQDN (ex. the OSE Master IP):"
read nfsServerIP

# Ensure you're in the openshift-infra project
oc project openshift-infra

# Create the metrics-deployer service account
echo "Creating metrics-deployer service account"
echo -e "{
 \"apiVersion\": \"v1\",
 \"kind\": \"ServiceAccount\",
 \"metadata\": {
 \"name\": \"metrics-deployer\",
 \"secrets\":  
 \"name\": \"metrics-deployer\"
 }
}"  > /tmp/metrics-sa-deployer.json

oc create -f /tmp/metrics-sa-deployer.json

# metrics-deployer needs to be able to edit the openshift-infra project
oadm policy add-role-to-user edit system:serviceaccount:openshift-infra:metrics-deployer

# heaptser needs the cluster-reader role in order to access /stats endpoint for each node
oadm policy add-cluster-role-to-user cluster-reader system:serviceaccount:openshift-infra:heapster

# if using self-signed certs; see documentation to use other certs (https://docs.openshift.com/enterprise/3.1/install_config/cluster_metrics.html)
oc secrets new metrics-deployer nothing=/dev/null

# Create PV that will be used by Cassandra 
echo "Creating PersistentVolume" 
echo -e "{
 \"apiVersion\": \"v1\",
 \"kind\": \"PersistentVolume\",
 \"metadata\": {
 \"name\": \""$volName"\"
},
\"spec\": {
   \"capacity\": {
   \"storage\": \""$volSize"Gi\"
   },
   \"accessModes\": [ \"ReadWriteOnce\" ],
   \"nfs\": {
      \"path\": \""$nfsPath"\",
      \"server\": \""$nfsServerIP"\"
   },
   \"persistentVolumeReclaimPolicy\": \"Recycle\"
   }
}" > /tmp/$volName.json

oc create -f /tmp/$volName.json

# Copy example template
cp /usr/share/openshift/examples/infrastructure-templates/enterprise/metrics-deployer.yaml .

if [ $volSize != 10 ]
  # Cassandra db is expecting a 10G persistent volume; if using a larger volume, you need to specify with the following:
  oc process -f metrics-deployer.yaml -v HAWKULAR_METRICS_HOSTNAME=hawkular-metrics-openshift-infra.apps.yourDomain.com, CASSANDRA_PV_SIZE="$volSize"Gi | oc create -f -
else
 oc process -f metrics-deployer.yaml -v HAWKULAR_METRICS_HOSTNAME=hawkular-metrics-openshift-infra.apps.yourDomain.com | oc create -f -
fi 
# add the following line to the /etc/origin/master/master-config.yaml under 'assetConfig'
#metricsPublicURL: "https://hawkular-metrics-openshift-infra.apps.yourDomain.com/hawkular/metrics"

# Bounce the master/nodes
#echo "Restarting atomic-openshift-master"
#systemctl restart atomic-openshift-master
