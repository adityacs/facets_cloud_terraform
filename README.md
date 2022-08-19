# Kubernetes Deployment with Terraform

This terraform script performs the following actions.

1. Installs `nginx ingress controller`.
2. Creates deployment for `blue` and `green` apps.
3. Creates service for `blue` and `green` apps.
4. Creates ingress for `blue` and `green` apps.

**Note:** Couldn't find official terraform module for `minikube`. So, `minikube` setup is not automated. 

## Repo structure
.
├── README.md
├── application.json -- app related image, port, image values
├── k8s.tf -- terraform script which includes `nginx ingress controller` installation and app deployment
├── modules -- contains `nginx-ingress` module
│   └── ingress-nginx
│       ├── main.tf -- terraform script
|       └── variables.tf -- variables required to run the script
├── terraform.tfvars -- define variable values
└── variables.tf -- variables required to run the script
 
## Deployment steps

### Pre-requistes

1. Kubernetes cluster
2. terraform cli
3. git

### Clone the repo

```bash
git clone https://github.com/adityacs/facets_cloud_terraform
cd facets_cloud_terraform
```

### Add the required variables

Add the `kube config path` and `kube context` to `terraform.tfvars` file. You can get `kube context` from below command

```bash
kubectl config current-context
```

### Install nginx ingress controller and deploy app

```bash
terraform apply
```

This will install `nginx ingress controller` and then deploy the app. Once the script run is successful, run the following command to verify the output.

```bash
$ for i in {1..10};do curl https://<host_name>;  done
"I am blue"
"I am blue"
"I am blue"
"I am green"
"I am blue"
"I am blue"
"I am blue"
"I am blue"
"I am green"
"I am blue"
```
