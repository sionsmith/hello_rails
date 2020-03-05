# Hello\_rails

This repo actually has very little to do with Ruby on Rails, I just needed a sample app to package so I wrote a "Hello World".

The real intent is to demonstrate modern methods of developping and managing apps in cloud environments. Because talk is nice, but functional code speaks louder!

More specifically, I'm using this repo to explore Kubernetes based apps

## Usage

### Prereqs

Before you can deploy the infra and everything else, you'll need to:

- provision an ECR repository and add its address to your tfvars file
- provision 2 S3 buckets:
  - A log bucket
  - A Terraform state bucket
- Directly edit `./tf_infra/main.tf` and `./tf_k8s/main.tf` to insert the state bucket information into the `terraform` configuration stanza at the top of the file.
- create workspaces as required: `terraform workspace new myworkspace`

### Spawning the infra

You're of course encouraged to issue plans and such, but the shortest path to sapwning the infra goes like this:

```
cd tf_infra
terraform init
terraform apply

cd ../tf_k8s
terraform init
terraform apply
```

The application is now deployed and the pipeline stands ready to update it. These steps are intended to be performed by pipelines too, in due time.

## Features

- TF managed, serverless Kubernetes infrastructure (./tf\_infra/)
- TF managed pod management (./tf\_k8s/)
- CircleCI based pipelines to:
  - Package the app in docker
  - Push to a private ECR registry
  - Load into a pod and deploy to Kubernetes

## Missing features for "devops completion":

- Capybara tests (or whatever's popular for Rails testing these days) for functional testing
- Rspec tests (I didn't feel like "Hello World" needed broad unit tests coverage o.O )
- Inspec tests for the TF templates
- Logging/Monitoring or K8S + Apps
  - Cloudwatch integration
- Pipeline job that tests tf\_infra and tf\_k8s with inspec-aws in kitchen when either folder is modified
  - Dependent pipeline job that run the terraform apply on manual trigger
  - CircleCI doesn't have an option to run jobs based on files modified, a new CI will be required
