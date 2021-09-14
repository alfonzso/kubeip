nodepools="$(gcloud container node-pools list --project "$PROJECT_ID" --zone "$GCP_ZONE" --cluster "$GKE_CLUSTER_NAME")"
cat <<EOF
            GCP_ZONE: $GCP_ZONE
          GCP_REGION: $GCP_REGION
    GKE_CLUSTER_NAME: $GKE_CLUSTER_NAME
          PROJECT_ID: $PROJECT_ID
    KUBEIP_SECRET_SA: $KUBEIP_SECRET_SA
     KUBEIP_NODEPOOL: $KUBEIP_NODEPOOL       $( echo "$nodepools" | grep $KUBEIP_NODEPOOL      -q  && printf "   \u2714 FOUND \u2714 " || echo "\u274c MISSING \u274c" )
KUBEIP_SELF_NODEPOOL: $KUBEIP_SELF_NODEPOOL  $( echo "$nodepools" | grep $KUBEIP_SELF_NODEPOOL -q  && printf " \u2714 FOUND \u2714 "   || echo "\u274c MISSING \u274c" )
EOF