# Certified Kubernetes Security Specialist Stuffs
---
My terraform, ansible, and kubeadm scripts for CKS exam (K8S v1.20.0)

## Prerequsites (Mac):
- terraform (brew install terraform)
- ansible (brew install ansible)
- git (brew install git)
- kubectl (brew install kubectl)
- GCP Project with a Google cloud managed dns (publilc_zone)

## Installation:
1. Clone this repo
```
git %git clone https://github.com/ssung-yugabyte/cks-kubeadm.git
git %cd cks-kubeadm
cks-kubeadm % 
```
2. Prepare variables.tf
```
cks-kubeadm %mv variables.tf.example variables.tf
```
3. Review and modify the variables.tf
```
cks-kubeadm % cat variables.tf
variable "gcp_profile" {
  description = "GCP Configuration"
  type = map
  default = {
    project = "XXXXXXX"                  <== Your GCP Project
    region = "us-central1"               <== Your Preferred GCP Region
    zone = "us-central1-c"               <== Your Preferred GCP Zone
    credentials = "~/.ssh/XXXXXXX.json"  <== Your GCP Service Account Credential
  }
  sensitive = true
}

variable "gce_vm" {
  description = "GCE Instance Configuration"
  type = map
  default = {
    instance_type = "n2-standard-2"
    os_project = "ubuntu-os-cloud"
    os_family = "ubuntu-2004-lts"
    boot_disk_size = 200
    ssh_user = "XXXX"                    <== Your local user_name
    ssh_pub = "~/.ssh/id_rsa.pub"        <== Your ssh public key
  }
}

variable "master_count" {
  description = "K8s Master instances"
  type = number
  default = 1
}

variable "worker_count" {
  description = "K8s worker instances"
  type          = number
  default       = 3
}

variable "k8s_version" {
  type		= string
  default	= "1.20.0"
}

variable "gcp_private_dns_zone" {
  description = "Google Managed DNS zone - private zone name"
  type = map
  default = {
    zone_name = "XXXXX-private"            <== Your Google Cloud Managed Zone (private)
    dns_name = "cks.yugabyte.lab."           <== Your Google Cloud Managed Zone DNS Name (private)
  } 
}

variable "gcp_public_dns_zone" {
  description = "Google Managed DNS zone - public (preconfig required). If no public zone, external api uses public IP"
  type = map
  default = {
    enabled = false   <== OPTIOINAL: google domain resource requires 24hrs to be affected. You need to pre config a google domain in advance, then create a public DNS zone.
    zone_name = "ysung-public-ats-zone"
  }

}

variable "vpc_subnet_cidr" {
  description  = "VPC custom subnet CIDR"
  type          = string
  default       = "192.168.20.0/24"
}

variable "k8s_pod_cidr" {
  description = "K8s pod subnet CIDR"
  type          = string
  default       = "10.244.0.0/16"
}

variable "k8s_service_cidr" {
  description = "K8s service CIDR"
  type		= string
  default	= "10.96.0.0/12"
}

```
4. Init Terraform plugins
```
cks-kubeadm %terraform init
```
5. Reivew Terraform plan
```
cks-kubeadm %terraform plan
```
6. Apply Terraform plan
```
cks-kubeadm %terraform apply --auto-approve
```
7. Check the k8s cluster
```
cks-kubeadm %kubectl get nodes
```
8. Kubectl away...
```
cks-kubeadm %cd kubectl/deployments
deployments %
```

## Reset:
1. Destroy the terraform plan
  K8S will use gce to create legacy gce disks (pvc) /firewall rules/health-check/load-balancer/target-pool. When destory, those will be ignored as they are defined outside of terraform. In order to clean up those google cloud resources, you will need gcloud cmd. 

```
cks-kubeamd %terraform destroy --auto-approve
```

## ToDo:
- [] Instance groups
- [] Kubeadm upgrade
- [x] Control plane HA
  - GCP LoadBalancer: Layer4 TCP Load Balancer
  - GCP SSL health check (haproxy + keepalived)
  - GCP target pool
  - kubeadm join --control-plane
