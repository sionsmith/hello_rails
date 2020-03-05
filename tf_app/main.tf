# Pipeline shtuff
resource "aws_iam_role" "codebuild" {
  name_prefix = "${var.name_prefix}-codebuild"

    assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

}

resource "aws_iam_role_policy_attachment" "codebuild_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser" # This is an Amazon managed policy
  role       = aws_iam_role.codebuild.name
}

# The buildspec is gitignored so TF can manage it
resource "local_file" {
  content = local.buildspec
  filename = "${path.module}/../buildspec.yml"
}

# code build project to assemble Docker image; This will be triggered by codepipeline
resource "aws_codebuild_project" "docker_image" {
  
}

resource "aws_iam_role" "codedeploy" {

}

resource "aws_codepipeline" "hello_rails_docker_build" {
  name = "hello_rails"
  role_arn = aws_iam_role.codedeploy.arn

  stage {
    name = "${var.name_prefix}_fetch_source"
    action {
      category = "Source"
      owner = "ThirdParty"
      name = "fetch_source"
      provider = "GitHub"
      version = 1
      configuration {
        Owner = "bobchaos"
        Repo = "hello_k8s"
        Branch = "master"
        PollSourceForChanges = false
      }
      role_arn = aws_iam_role.codebuild.arn
    }
  }

  stage{
    name = "${var.name_prefix}_build_container"
    action {
      category = "Build"
      owner = "AWS"
      name = "fetch_source"
      provider = "CodeBuild"
      version = 1
      configuration {
        
      }
    }
  }
}
