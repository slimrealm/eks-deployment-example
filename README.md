## Example Amazon EKS Deployment: Node.js + Express Server
This repository demonstrates a simple deployment of a Node.js + Express server to Amazon EKS using Docker, Kubernetes, and Bash scripting.

### Overview
The application is a basic Node.js/Express server that returns the hostname of the Kubernetes pod that handled the request. This is useful for demonstrating load balancing across multiple pods in a cluster.

### Key Components
- #### Dockerized Application
  A lightweight Node.js server containerized with Docker and published to Docker Hub.

- #### Kubernetes Configuration

  - ```deployment.yml```
  - Defines a deployment with 3 replicas. Each pod pulls the Docker image and sets the default platform to ```linux/amd64```, which is required for out-of-the-box compatibility with EC2-based EKS worker nodes. (Attempting to run on ```linux/arm64``` will result in a failed image pull.)

  - ```service.yml```
  - Configures a LoadBalancer service that distributes incoming traffic to the Node.js pods and exposes the application on port 80.

- #### Automation Script
  A Bash script automates the following:

  - Builds and pushes the Docker image to Docker Hub
  - Provisions the EKS cluster and applies the Kubernetes manifests
  - Waits for the LoadBalancer service to become available
  - Sends 20 consecutive HTTP requests to the exposed endpoint to demonstrate load balancing across the 3 pods (evidenced by different hostnames in the response)

- #### IMPORTANT: EKS is not free tier in AWS, so don't forget to tear down when done
  ```eksctl delete cluster --name basic-node-app-cluster --region <AWS_REGION>```
