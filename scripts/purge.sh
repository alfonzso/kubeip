gcloud iam roles delete kubeip --project $PROJECT_ID
gcloud iam service-accounts delete kubeip-service-account@$PROJECT_ID.iam.gserviceaccount.com

number_of_vm=10
for i in $(seq 1 $number_of_vm);
do
  gcloud compute addresses delete kubeip-ip$i --project=$PROJECT_ID --region=$GCP_REGION --quiet
done
