#!/bin/bash

mkdir -p modules/sns modules/ssm modules/stepfunctions

cat << EOF > variables.tf
variable "KKE_SNS_TOPIC_NAME" {
  description = "Name of the SNS topic"
  type        = string
}

variable "KKE_SSM_PARAM_NAME" {
  description = "Name of the SSM parameter"
  type        = string
}

variable "KKE_STEP_FUNCTION_NAME" {
  description = "Name of the Step Function"
  type        = string
}
EOF

ln -s /home/bob/terraform/variables.tf modules/sns/variables.tf
ln -s /home/bob/terraform/variables.tf modules/ssm/variables.tf
ln -s /home/bob/terraform/variables.tf modules/stepfunctions/variables.tf

cat << EOF > terraform.tfvars
KKE_SNS_TOPIC_NAME       = "xfusion-sns-topic"
KKE_SSM_PARAM_NAME       = "xfusion-param"
KKE_STEP_FUNCTION_NAME   = "xfusion-stepfunction"
EOF

cat << EOF > outputs.tf
output "kke_sns_topic_name" {
  value = module.sns.kke_sns_topic
}

output "kke_ssm_parameter_name" {
  value = module.ssm.kke_sns_parameter_name
}

output "kke_step_function_name" {
  value = module.stepfunctions.kke_step_function_name
}
EOF

cat << EOF > main.tf
module "sns" {
  source = "./modules/sns"
  KKE_SSM_PARAM_NAME = var.KKE_SSM_PARAM_NAME
  KKE_SNS_TOPIC_NAME = var.KKE_SNS_TOPIC_NAME
  KKE_STEP_FUNCTION_NAME = var.KKE_STEP_FUNCTION_NAME
}

module "ssm" {
  source     = "./modules/ssm"
  KKE_SSM_PARAM_NAME = var.KKE_SSM_PARAM_NAME
  KKE_SNS_TOPIC_NAME = var.KKE_SNS_TOPIC_NAME
  KKE_STEP_FUNCTION_NAME = var.KKE_STEP_FUNCTION_NAME
  depends_on = [module.sns]
}

module "stepfunctions" {
  source     = "./modules/stepfunctions"
  KKE_SSM_PARAM_NAME = var.KKE_SSM_PARAM_NAME
  KKE_SNS_TOPIC_NAME = var.KKE_SNS_TOPIC_NAME
  KKE_STEP_FUNCTION_NAME = var.KKE_STEP_FUNCTION_NAME
  depends_on = [module.ssm]
}
EOF

cat << EOF > modules/sns/outputs.tf
output "kke_sns_topic" {
  value = aws_sns_topic.this.name
}
EOF

cat << EOF > modules/ssm/outputs.tf
output "kke_sns_parameter_name" {
  value = aws_ssm_parameter.this.name
}
EOF

cat << EOF > modules/stepfunctions/outputs.tf
output "kke_step_function_name" {
  value = aws_sfn_state_machine.this.name
}
EOF

cat << EOF > modules/sns/main.tf
resource "aws_sns_topic" "this" {
  name = var.KKE_SNS_TOPIC_NAME
}
EOF

cat << EOF > modules/ssm/main.tf
resource "aws_ssm_parameter" "this" {
  name  = var.KKE_SSM_PARAM_NAME
  type  = "String"
  value = "arn:aws:sns:us-east-1:000000000000:\${var.KKE_SNS_TOPIC_NAME}"
}
EOF

cat << EOF > modules/stepfunctions/main.tf
data "aws_ssm_parameter" "sns_param" {
  name = var.KKE_SSM_PARAM_NAME
}

resource "aws_iam_role" "sfn_role" {
  name = "\${var.KKE_STEP_FUNCTION_NAME}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_sfn_state_machine" "this" {
  name     = var.KKE_STEP_FUNCTION_NAME
  role_arn = aws_iam_role.sfn_role.arn
  definition = jsonencode({
    StartAt = "ReadSSM"
    States = {
      ReadSSM = {
        Type   = "Pass"
        Result = {
          SnsArn = data.aws_ssm_parameter.sns_param.value
        }
        End = true
      }
    }
  })
}
EOF

