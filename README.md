# Bookinfo DevOps Project

## Overview
A hands-on DevOps engineering project using the Istio
Bookinfo microservices application.

## Technologies
- Linux (Ubuntu)
- Git and GitHub
- Docker
- Kubernetes (K3s)
- Jenkins CI/CD (planned)
- Trivy Security Scanning (planned)
- Prometheus and Grafana (planned)
- Istio Service Mesh (planned)
- Terraform and AWS (planned)

## Microservices
1. Productpage - Web frontend
2. Details - Book information
3. Reviews - Book reviews (v1, v2, v3)
4. Ratings - Book ratings

## Current Deployment
- Environment: Ubuntu VMware
- Kubernetes distribution: K3s
- Namespace: bookinfo
- Application port: 9080

## Deploy

kubectl create namespace bookinfo

kubectl apply -n bookinfo -f kubernetes/bookinfo.yaml

## Verify

kubectl get pods -n bookinfo

kubectl get services -n bookinfo

## Access

kubectl port-forward -n bookinfo svc/productpage 9080:9080

Open http://127.0.0.1:9080/productpage

## Project Progress
- [x] Kubernetes cluster setup
- [x] Bookinfo application deployment
- [x] Six application pods running
- [x] HTTP 200 response verified
- [ ] GitHub repository publication
- [ ] Jenkins CI/CD pipeline
- [ ] Automated security scanning
- [ ] Monitoring and observability
- [ ] AWS infrastructure provisioning
