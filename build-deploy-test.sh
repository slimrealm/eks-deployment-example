#!/bin/bash

# Change to your specific Docker and AWS values as needed
DOCKER_USERNAME="slimrealm"
DOCKER_IMAGE_NAME="basic-node-app"
DOCKER_IMAGE_TAG="latest"
DOCKER_IMAGE="$DOCKER_USERNAME/$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG"
AWS_REGION="us-west-1"

# Authenticate - will need to enter username if not logged in
docker login

# Build image for both arm64 and amd64 architectures -- I am running arm64 locally,
# but this EKS deployment will provision EC2 nodes with amd64.
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t $DOCKER_IMAGE --push .
if [ $? -ne 0 ]; then
  echo "Docker build and push failed. Exiting."
  exit 1
fi

# Create cluter on EKS
eksctl create cluster \
  --name basic-node-app-cluster \
  --region $AWS_REGION \
  --nodes 3 \
  --node-type t3.small \
  --managed
if [ $? -ne 0 ]; then
  echo "Failed to create EKS cluster. Exiting."
  exit 1
fi

# Make sure kubectl has context set to the new cluster
aws eks --region $AWS_REGION update-kubeconfig --name basic-node-app-cluster

# Create deployment and service using the image we just built
kubectl apply -f ./kubernetes/deployment.yml
kubectl apply -f ./kubernetes/service.yml

# Get the ELB hostname for the service so we can test it
# Wait for external IP/hostname to appear
echo "Waiting for LoadBalancer hostname..."
while true; do
  SERVICE_ELB_HOSTNAME=$(kubectl get svc basic-node-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
  if [[ -n "$SERVICE_ELB_HOSTNAME" ]]; then
    break
  fi
  sleep 5
  echo -n "."
done

# Wait for app to respond
SERVICE_ELB_FULL_URL="http://$SERVICE_ELB_HOSTNAME"
echo "Waiting for service to respond at $SERVICE_ELB_FULL_URL..."
until curl -s --max-time 3 "$SERVICE_ELB_FULL_URL" >/dev/null; do
  echo -n "."
  sleep 5
done

echo "Service is up: $SERVICE_ELB_FULL_URL"

# Test that the endpoint is reachable, and that we see responses from all 3 pods, indicating distributed requests.
for i in {1..20}; do
  echo "Request $i:"
  RESPONSE=$(curl -s $SERVICE_ELB_FULL_URL)
  if [ $? -ne 0 ]; then
    echo "Failed to reach the service. Exiting."
    exit 1
  fi
  if [ -z "$RESPONSE" ]; then
    echo "No response from the service. Exiting."
    exit 1
  fi
  echo "$RESPONSE"
  sleep 1
done
