i![ci](https://github.com/doitintl/kubeip/workflows/ci/badge.svg) [![Go Report Card](https://goreportcard.com/badge/github.com/doitintl/kubeip)](https://goreportcard.com/report/github.com/doitintl/kubeip) ![Docker Pulls](https://img.shields.io/docker/pulls/doitintl/kubeip)

# What is kubeIP?

Many applications need to be whitelisted by users based on a Source IP Address. As of today, Google Kubernetes Engine doesn't support assigning a static pool of IP addresses to the GKE cluster. Using kubeIP, this problem is solved by assigning GKE nodes external IP addresses from a predefined list. kubeIP monitors the Kubernetes API for new/removed nodes and applies the changes accordingly.

# Deploy kubeIP (without building from source)

If you just want to use kubeIP (instead of building it yourself from source), please follow the instructions in this section. You’ll need Kubernetes version 1.10 or newer.
<br>
You'll also need the Google Cloud SDK. You can install the [Google Cloud SDK](https://cloud.google.com/sdk) (which also installs kubectl).

**Prerequisite**
 * Google sdk configured correctly for targeted project
 * kubectl + you can access your cluster
 * You have admin right to your cluster

**Best place to config gcp is at 'Gcp Cloud Shell'**
# Gcp Setup | Create Nodepool/Static ips/Service Account
### With one GKE cluster in project you can use this:
```bash
export GCP_ZONE=$(gcloud container clusters list --format="value(selfLink.scope())" | cut -d/ -f1 )
export GCP_REGION=$(echo $GCP_ZONE | cut -d- -f1,2)
export GKE_CLUSTER_NAME=$(gcloud container clusters list --format="value(selfLink.basename())")
export PROJECT_ID=$(gcloud config list --format 'value(core.project)')
export KUBEIP_SECRET_SA=kubeip-sa
```

### With multiple GKE cluster :
```bash
export GCP_REGION=<region>                                      # e.x.: europe-west1
export GCP_ZONE=$GCP_REGION-<a-z>                               # e.x.: europe-west1-b
export GKE_CLUSTER_NAME=<gke-cluster-name>                      # e.x.: fafa-gke-cluster
export PROJECT_ID=<project-id>                                  # e.x.: fafa-project
export KUBEIP_SECRET_SA=<secret name of kubeip service account> # e.x.: kubeip-sa
```

### More environment variables
```bash
# nodepool name which will have static ips
export KUBEIP_NODEPOOL=<nodepool-with-static-ips>

# change self nodepool name if you have already a nodepool for kubeip
export KUBEIP_SELF_NODEPOOL=kubeip-nodepool
```

[Check env vars value](scripts/check_env_var.sh)

### Create nodepool for kubeip ( skip this step if you have already ), example only

```bash
gcloud beta container node-pools create "$KUBEIP_SELF_NODEPOOL"           \
  --project "$PROJECT_ID"                                                 \
  --cluster "$GKE_CLUSTER_NAME"                                           \
  --zone "$GCP_ZONE"                                                      \
  --machine-type "e2-medium"                                              \
  --scopes "https://www.googleapis.com/auth/devstorage.read_only",        \
           "https://www.googleapis.com/auth/logging.write",               \
           "https://www.googleapis.com/auth/monitoring",                  \
           "https://www.googleapis.com/auth/servicecontrol",              \
           "https://www.googleapis.com/auth/service.management.readonly", \
           "https://www.googleapis.com/auth/trace.append"                 \
  --num-nodes "1"                                                         \
  --max-surge-upgrade 1                                                   \
  --max-unavailable-upgrade 0
```


```bash
# Create a Service Account
gcloud iam service-accounts create kubeip-service-account --display-name "kubeIP"

# # Create and attach a custom kubeIP role to the service account
# gcloud iam roles create kubeip \
#   --project $PROJECT_ID        \
#   --file gcp/roles.yaml

# Create and attach a custom kubeIP role to the service account
gcloud iam roles create kubeip \
  --project $PROJECT_ID        \
  --file <( cat <<EOF
title: "kubeip"
description: "Required permissions to run KubeIP"
stage: "GA"
includedPermissions:
- compute.addresses.list
- compute.instances.addAccessConfig
- compute.instances.deleteAccessConfig
- compute.instances.get
- compute.instances.list
- compute.projects.get
- container.clusters.get
- container.clusters.list
- resourcemanager.projects.get
- compute.networks.useExternalIp
- compute.subnetworks.useExternalIp
- compute.addresses.use
EOF
)

sa_name=kubeip-service-account@$PROJECT_ID.iam.gserviceaccount.com
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member serviceAccount:$sa_name                 \
  --role projects/$PROJECT_ID/roles/kubeip

# Generate SA key
gcloud iam service-accounts keys create key.json --iam-account $sa_name

```

**Create Static, Reserved IP Addresses:**

```bash
# Create as many static IP addresses for the number of nodes in your GKE cluster so you will have enough addresses when your cluster scales up (manually or automatically):
number_of_vm=10
for i in $(seq 1 $number_of_vm);
do
  gcloud compute addresses create kubeip-ip$i --project=$PROJECT_ID --region=$GCP_REGION;
done

# Add labels to reserved IP addresses. A common practice is to assign a unique value per cluster (for example cluster name):
for i in $(seq 1 $number_of_vm);
do
  gcloud beta compute addresses update kubeip-ip$i --update-labels kubeip=$GKE_CLUSTER_NAME --region $GCP_REGION;
done
```

# Kubectl & Helm

```bash
# create namespace for kubeip
kubectl create ns kubeip
# Create a k8s kubeip-sa-key secret
kubectl -n kubeip create secret generic $KUBEIP_SECRET_SA --from-file=key.json

helm upgrade -i -n kubeip kubeip .            \
  --set kubeip.labelvalue=$GKE_CLUSTER_NAME   \
  --set nodeSelector."cloud\\.google\\.com/gke-nodepool"=$KUBEIP_SELF_NODEPOOL   \
  --set kubeip.nodepool=$KUBEIP_NODEPOOL
```
# Notes
 - The `KUBEIP_LABELVALUE` should be your GKE's cluster name
 - The `KUBEIP_NODEPOOL` should match the name of your GKE node-pool on which kubeIP will operate
 - The `KUBEIP_FORCEASSIGNMENT` - controls whether kubeIP should assign static IPs to existing nodes in the node-pool and defaults to true

  - If you would like to assign addresses to other node pools, then `KUBEIP_NODEPOOL` can be added to this nodepool `KUBEIP_ADDITIONALNODEPOOLS` as a comma separated list.
  - You should tag the addresses for this pool with the `KUBEIP_LABELKEY` value + `-node-pool` and assign the value of the node pool a name i.e.,  `kubeip-node-pool=my-node-pool`

# Deploy & Build From Source

You can find here: https://github.com/doitintl/kubeip
