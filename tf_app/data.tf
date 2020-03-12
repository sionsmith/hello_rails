data "terraform_remote_state" "k8s_cluster" {
  backend = "s3"
  config = {
    # The bucket is managed by the bootstrapping infra, which uses static names
    bucket = "bobs-tfstates-bucket"
    key = "demo_projects/hello_rails/tf_infra/"
    workspace = ${terraform.workspace}
    region = "us-east-1"
  }
}

data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.k8s_cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.terraform_remote_state.k8s_cluster.cluster_id
}
