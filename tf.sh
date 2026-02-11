#!/bin/bash

mkdir -p modules/sns modules/ssm modules/stepfunctions

cat << EOF > variables.tf
variable "KKE_SNS_TOPIC_NAME" {
  type = string
}

variable "KKE_SSM_PARAM_NAME" {
  type = string
}

variable "KKE_STEP_FUNCTION_NAME" {
  type = string
}
EOF

ln -s /home/bob/terraform/variables.tf modules/sns/variables.tf
ln -s /home/bob/terraform/variables.tf modules/ssm/variables.tf
ln -s /home/bob/terraform/variables.tf modules/stepfunctions/variables.tf

cat << EOF > terraform.tfvars
KKE_SNS_TOPIC_NAME = "xfusion-sns-topic"
KKE_SSM_PARAM_NAME = "xfusion-param"
KKE_STEP_FUNCTION_NAME = "xfusion-stepfunction"
EOF

cat << EOF > outputs.tf
output "kke_sns_topic_name" {
  value = module.sns.kke_sns_topic_name
}

output "kke_ssm_parameter_name" {
  value = module.ssm.kke_ssm_parameter_name
}

output "kke_step_function_name" {
  value = module.stepfunctions.kke_step_function_name
}
EOF

cat << EOF > main.tf
module "sns" {
  source = "./modules/sns"

  KKE_SNS_TOPIC_NAME = var.KKE_SNS_TOPIC_NAME
  KKE_SSM_PARAM_NAME = var.KKE_SSM_PARAM_NAME
  KKE_STEP_FUNCTION_NAME = var.KKE_STEP_FUNCTION_NAME
}

module "ssm" {
  source = "./modules/ssm"

  KKE_SNS_TOPIC_NAME = var.KKE_SNS_TOPIC_NAME
  KKE_SSM_PARAM_NAME = var.KKE_SSM_PARAM_NAME
  KKE_STEP_FUNCTION_NAME = var.KKE_STEP_FUNCTION_NAME

  depends_on = [module.sns]
}

module "stepfunctions" {
  source = "./modules/stepfunctions"

  KKE_SNS_TOPIC_NAME = var.KKE_SNS_TOPIC_NAME
  KKE_SSM_PARAM_NAME = var.KKE_SSM_PARAM_NAME
  KKE_STEP_FUNCTION_NAME = var.KKE_STEP_FUNCTION_NAME

  depends_on = [module.ssm]
}
EOF

cat << EOF > modules/sns/outputs.tf
output "kke_sns_topic_name" {
  value = aws_sns_topic.KKE_SNS_TOPIC_NAME.name
}
EOF

cat << EOF > modules/ssm/outputs.tf
output "kke_ssm_parameter_name" {
  value = aws_ssm_parameter.KKE_SSM_PARAM_NAME.name
}
EOF

cat << EOF > modules/stepfunctions/outputs.tf
output "kke_step_function_name" {
  value = aws_sfn_state_machine.KKE_STEP_FUNCTION_NAME.name
}
EOF

cat << EOF > modules/sns/main.tf
resource "aws_sns_topic" "KKE_SNS_TOPIC_NAME" {
  name = var.KKE_SNS_TOPIC_NAME
}
EOF

cat << EOF > modules/ssm/main.tf
resource "aws_ssm_parameter" "KKE_SSM_PARAM_NAME" {
  name  = var.KKE_SSM_PARAM_NAME
  type  = "String"
  value = "arn:aws:sns:us-east-1:000000000000:\${var.KKE_SNS_TOPIC_NAME}"
}
EOF

cat << EOF > modules/stepfunctions/main.tf
data "aws_ssm_parameter" "sns_param" {
  name = var.KKE_SSM_PARAM_NAME
}

resource "aws_iam_role" "KKE_STEP_FUNCTION_NAME" {
  name = var.KKE_STEP_FUNCTION_NAME

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
      },
    ]
  })
}

# resource "aws_iam_policy" "KKE_STEP_FUNCTION_NAME" {
#   name = var.KKE_STEP_FUNCTION_NAME
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "ssm:GetParameter"
#         Effect = "Allow"
#         Resource = "*"
#       },
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "KKE_STEP_FUNCTION_NAME" {
#   role       = aws_iam_role.KKE_STEP_FUNCTION_NAME.name
#   policy_arn = aws_iam_policy.KKE_STEP_FUNCTION_NAME.arn
# }

resource "aws_sfn_state_machine" "KKE_STEP_FUNCTION_NAME" {
  name     = var.KKE_STEP_FUNCTION_NAME
  role_arn = aws_iam_role.KKE_STEP_FUNCTION_NAME.arn

  definition = <<EOOF
{
  "Comment": "Step Function using SSM parameter",
  "StartAt": "Start",
  "States": {
    "Start": {
      "Type": "Task",
      "Resource": "arn:aws:states:::aws-sdk:ssm:getParameter",
      "Parameters": {
        "Name": "\${var.KKE_SSM_PARAM_NAME}"
      },
      "ResultSelector": {
        "SnsArn.\$": "\$.Parameter.Value"
      },
      "End": true
    }
  }
}
EOOF
}
EOF

