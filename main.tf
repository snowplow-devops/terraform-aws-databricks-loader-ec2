locals {
  module_name    = "databricks-loader-ec2"
  module_version = "0.2.0"

  app_name    = "rdb-loader-databricks"
  app_version = var.app_version

  local_tags = {
    Name           = var.name
    app_name       = local.app_name
    app_version    = local.app_version
    module_name    = local.module_name
    module_version = local.module_version
  }

  tags = merge(
    var.tags,
    local.local_tags
  )

  cloudwatch_log_group_name = "/aws/ec2/${var.name}"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  is_aws_global = replace(data.aws_region.current.name, "cn-", "") == data.aws_region.current.name
  iam_partition = local.is_aws_global ? "aws" : "aws-cn"

  is_private_ecr_registry = var.private_ecr_registry != ""
  private_ecr_registry_statement = [{
    Action = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]
    Effect = "Allow"
    Resource = [
      "*"
    ]
  }]
  private_ecr_registry_statement_final = local.is_private_ecr_registry ? local.private_ecr_registry_statement : []
}

module "telemetry" {
  source  = "snowplow-devops/telemetry/snowplow"
  version = "0.5.0"

  count = var.telemetry_enabled ? 1 : 0

  user_provided_id = var.user_provided_id
  cloud            = "AWS"
  region           = data.aws_region.current.name
  app_name         = local.app_name
  app_version      = local.app_version
  module_name      = local.module_name
  module_version   = local.module_version
}

# --- CloudWatch: Logging

resource "aws_cloudwatch_log_group" "log_group" {
  count = var.cloudwatch_logs_enabled ? 1 : 0

  name              = local.cloudwatch_log_group_name
  retention_in_days = var.cloudwatch_logs_retention_days

  tags = local.tags
}

# --- IAM: Roles & Permissions

resource "aws_iam_role" "iam_role" {
  name        = var.name
  description = "Allows the Databricks Loader nodes to access required services"
  tags        = local.tags

  assume_role_policy = <<EOF
{
  "Version" : "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": [ "ec2.amazonaws.com" ]},
      "Action": [ "sts:AssumeRole" ]
    }
  ]
}
EOF

  permissions_boundary = var.iam_permissions_boundary
}

resource "aws_iam_policy" "iam_policy" {
  name = var.name
  tags = local.tags

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat(
      local.private_ecr_registry_statement_final,
      [
        {
          Effect = "Allow",
          Action = [
            "s3:ListBucket",
            "s3:PutObject",
            "s3:GetObject"
          ],
          Resource = [
            "arn:${local.iam_partition}:s3:::${var.databricks_aws_s3_bucket_name}/",
            "arn:${local.iam_partition}:s3:::${var.databricks_aws_s3_bucket_name}/*"
          ]
        },
        {
          Effect = "Allow",
          Action = ["s3:GetObject"],
          Resource = [
            "arn:${local.iam_partition}:s3:::${var.databricks_aws_s3_bucket_name}/*/shredding_complete.json"
          ]
        },
        {
          Effect = "Allow",
          Action = [
            "sqs:DeleteMessage",
            "sqs:GetQueueUrl",
            "sqs:ListQueues",
            "sqs:ChangeMessageVisibility",
            "sqs:ReceiveMessage",
            "sqs:SendMessage"
          ],
          Resource = [
            "arn:${local.iam_partition}:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.sqs_queue_name}"
          ]
        },
        {
          Effect = "Allow",
          Action = [
            "logs:PutLogEvents",
            "logs:CreateLogStream",
            "logs:DescribeLogStreams"
          ],
          Resource = [
            "arn:${local.iam_partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:${local.cloudwatch_log_group_name}:*"
          ]
        },
        {
          Effect = "Allow",
          Action = [
            "sts:AssumeRole"
          ],
          Resource = [
            aws_iam_role.sts_credentials_role.arn
          ]
        }
      ]
    )
  })
}

resource "aws_iam_role_policy_attachment" "policy_attachment" {
  role       = aws_iam_role.iam_role.name
  policy_arn = aws_iam_policy.iam_policy.arn
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = var.name
  role = aws_iam_role.iam_role.name
}

resource "aws_iam_role" "sts_credentials_role" {
  name        = "${var.name}-sts-credentials"
  description = "Allows the Databricks Loader to access the S3 buckets to perform loading"
  tags        = local.tags

  permissions_boundary = var.iam_permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.sts_credentials_role.json
}

data "aws_iam_policy_document" "sts_credentials_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.iam_role.arn
      ]
    }
  }
}

resource "aws_iam_policy" "sts_credentials_policy" {
  name = "${var.name}-sts-credentials"
  tags = local.tags

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:GetObjectVersion"
        ],
        Resource = [
          "arn:${local.iam_partition}:s3:::${var.databricks_aws_s3_bucket_name}",
          "arn:${local.iam_partition}:s3:::${var.databricks_aws_s3_bucket_name}/",
          "arn:${local.iam_partition}:s3:::${var.databricks_aws_s3_bucket_name}/*"
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sts_credentials_policy_attachment" {
  role       = aws_iam_role.sts_credentials_role.name
  policy_arn = aws_iam_policy.sts_credentials_policy.arn
}

# --- EC2: Security Group Rules

resource "aws_security_group" "sg" {
  name   = var.name
  vpc_id = var.vpc_id
  tags   = local.tags
}

resource "aws_security_group_rule" "ingress_tcp_22" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.ssh_ip_allowlist
  security_group_id = aws_security_group.sg.id
}

resource "aws_security_group_rule" "egress_tcp_80" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg.id
}

resource "aws_security_group_rule" "egress_tcp_443" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg.id
}

resource "aws_security_group_rule" "egress_tcp_databricks" {
  count = var.deltalake_port != 443 ? 1 : 0

  type              = "egress"
  from_port         = var.deltalake_port
  to_port           = var.deltalake_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg.id
}

# Needed for clock synchronization
resource "aws_security_group_rule" "egress_udp_123" {
  type              = "egress"
  from_port         = 123
  to_port           = 123
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg.id
}

# Needed for statsd
resource "aws_security_group_rule" "egress_udp_statsd" {
  count = var.statsd_enabled ? 1 : 0

  type              = "egress"
  from_port         = var.statsd_port
  to_port           = var.statsd_port
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg.id
}

# --- EC2: Auto-scaling group & Launch Configurations

module "instance_type_metrics" {
  source  = "snowplow-devops/ec2-instance-type-metrics/aws"
  version = "0.1.2"

  instance_type = var.instance_type
}

locals {
  resolvers_raw = concat(var.default_iglu_resolvers, var.custom_iglu_resolvers)

  resolvers_open = [
    for resolver in local.resolvers_raw : merge(
      {
        name           = resolver["name"],
        priority       = resolver["priority"],
        vendorPrefixes = resolver["vendor_prefixes"],
        connection = {
          http = {
            uri = resolver["uri"]
          }
        }
      }
    ) if resolver["api_key"] == ""
  ]

  resolvers_closed = [
    for resolver in local.resolvers_raw : merge(
      {
        name           = resolver["name"],
        priority       = resolver["priority"],
        vendorPrefixes = resolver["vendor_prefixes"],
        connection = {
          http = {
            uri    = resolver["uri"]
            apikey = resolver["api_key"]
          }
        }
      }
    ) if resolver["api_key"] != ""
  ]

  resolvers = flatten([
    local.resolvers_open,
    local.resolvers_closed
  ])

  iglu_resolver = templatefile("${path.module}/templates/iglu_resolver.json.tmpl", {
    resolvers = jsonencode(local.resolvers)
  })

  config = templatefile("${path.module}/templates/config.json.tmpl", {
    region                               = data.aws_region.current.name
    message_queue                        = var.sqs_queue_name
    db_catalog                           = var.deltalake_catalog
    db_schema                            = var.deltalake_schema
    db_host                              = var.deltalake_host
    db_port                              = var.deltalake_port
    db_http_path                         = var.deltalake_http_path
    db_auth_token                        = var.deltalake_auth_token
    temp_credentials_role_arn            = aws_iam_role.sts_credentials_role.arn
    sp_tracking_enabled                  = var.sp_tracking_enabled
    sp_tracking_app_id                   = var.sp_tracking_app_id
    sp_tracking_collector_url            = var.sp_tracking_collector_url
    sentry_enabled                       = var.sentry_enabled
    sentry_dsn                           = var.sentry_dsn
    statsd_enabled                       = var.statsd_enabled
    statsd_host                          = var.statsd_host
    statsd_port                          = var.statsd_port
    stdout_metrics_enabled               = var.stdout_metrics_enabled
    webhook_enabled                      = var.webhook_enabled
    webhook_collector                    = var.webhook_collector
    folder_monitoring_enabled            = var.folder_monitoring_enabled
    folder_monitoring_staging            = var.databricks_aws_s3_folder_monitoring_stage_url
    folder_monitoring_transformer_output = var.databricks_aws_s3_folder_monitoring_transformer_output_stage_url
    folder_monitoring_period             = var.folder_monitoring_period
    folder_monitoring_since              = var.folder_monitoring_since
    folder_monitoring_until              = var.folder_monitoring_until
    health_check_enabled                 = var.health_check_enabled
    health_check_freq                    = var.health_check_freq
    health_check_timeout                 = var.health_check_timeout
    retry_queue_enabled                  = var.retry_queue_enabled
    retry_period                         = var.retry_period
    retry_queue_size                     = var.retry_queue_size
    retry_queue_max_attempt              = var.retry_queue_max_attempt
    retry_queue_interval                 = var.retry_queue_interval
    telemetry_disable                    = !var.telemetry_enabled
    telemetry_collector_uri              = join("", module.telemetry.*.collector_uri)
    telemetry_collector_port             = 443
    telemetry_secure                     = true
    telemetry_user_provided_id           = var.user_provided_id
    telemetry_auto_gen_id                = join("", module.telemetry.*.auto_generated_id)
    telemetry_module_name                = local.module_name
    telemetry_module_version             = local.module_version
  })

  user_data = templatefile("${path.module}/templates/user-data.sh.tmpl", {
    accept_limited_use_license = var.accept_limited_use_license

    config_b64        = var.config_override_b64 == "" ? base64encode(local.config) : var.config_override_b64
    iglu_resolver_b64 = base64encode(local.iglu_resolver)
    version           = local.app_version

    telemetry_script = join("", module.telemetry.*.amazon_linux_2_user_data)

    cloudwatch_logs_enabled   = var.cloudwatch_logs_enabled
    cloudwatch_log_group_name = local.cloudwatch_log_group_name

    container_memory = "${module.instance_type_metrics.memory_application_mb}m"
    java_opts        = var.java_opts

    is_private_ecr_registry = local.is_private_ecr_registry
    private_ecr_registry    = var.private_ecr_registry
    region                  = data.aws_region.current.name
  })
}

module "service" {
  source  = "snowplow-devops/service-ec2/aws"
  version = "0.2.1"

  user_supplied_script = local.user_data
  name                 = var.name
  tags                 = local.tags

  amazon_linux_2_ami_id       = var.amazon_linux_2_ami_id
  instance_type               = var.instance_type
  ssh_key_name                = var.ssh_key_name
  iam_instance_profile_name   = aws_iam_instance_profile.instance_profile.name
  associate_public_ip_address = var.associate_public_ip_address
  security_groups             = [aws_security_group.sg.id]

  min_size   = 1
  max_size   = 1
  subnet_ids = var.subnet_ids

  enable_auto_scaling = false
}
