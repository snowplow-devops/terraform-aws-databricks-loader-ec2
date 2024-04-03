variable "accept_limited_use_license" {
  description = "Acceptance of the SLULA terms (https://docs.snowplow.io/limited-use-license-1.0/)"
  type        = bool
  default     = false

  validation {
    condition     = var.accept_limited_use_license
    error_message = "Please accept the terms of the Snowplow Limited Use License Agreement to proceed."
  }
}

variable "name" {
  description = "A name which will be prepended to the resources created"
  type        = string
}

variable "app_version" {
  description = "Version of rdb loader databricks"
  type        = string
  default     = "5.6.0"
}

variable "config_override_b64" {
  description = "App config uploaded as a base64 encoded blob. This variable facilitates dev flow, if config is incorrect this can break the deployment."
  type        = string
  default     = ""
}

variable "iam_permissions_boundary" {
  description = "The permissions boundary ARN to set on IAM roles created"
  default     = ""
  type        = string
}

variable "vpc_id" {
  description = "The VPC to deploy Loader within"
  type        = string
}

variable "subnet_ids" {
  description = "The list of subnets to deploy Loader across"
  type        = list(string)
}

variable "instance_type" {
  description = "The instance type to use"
  type        = string
  default     = "t3a.micro"
}

variable "associate_public_ip_address" {
  description = "Whether to assign a public ip address to this instance"
  type        = bool
  default     = true
}

variable "ssh_key_name" {
  description = "The name of the SSH key-pair to attach to all EC2 nodes deployed"
  type        = string
}

variable "ssh_ip_allowlist" {
  description = "The list of CIDR ranges to allow SSH traffic from"
  type        = list(any)
  default     = ["0.0.0.0/0"]
}

variable "amazon_linux_2_ami_id" {
  description = "The AMI ID to use which must be based of of Amazon Linux 2; by default the latest community version is used"
  default     = ""
  type        = string
}

variable "tags" {
  description = "The tags to append to this resource"
  default     = {}
  type        = map(string)
}

variable "cloudwatch_logs_enabled" {
  description = "Whether application logs should be reported to CloudWatch"
  default     = true
  type        = bool
}

variable "cloudwatch_logs_retention_days" {
  description = "The length of time in days to retain logs for"
  default     = 7
  type        = number
}

variable "java_opts" {
  description = "Custom JAVA Options"
  default     = "-XX:InitialRAMPercentage=75 -XX:MaxRAMPercentage=75"
  type        = string
}

# --- Configuration options

variable "sqs_queue_name" {
  description = "SQS queue name"
  type        = string
}

variable "folder_monitoring_enabled" {
  description = "Whether folder monitoring should be activated or not"
  default     = false
  type        = bool
}

variable "sp_tracking_enabled" {
  description = "Whether Snowplow tracking should be activated or not"
  default     = false
  type        = bool
}

variable "sp_tracking_app_id" {
  description = "App id for Snowplow tracking"
  default     = ""
  type        = string
}

variable "sp_tracking_collector_url" {
  description = "Collector URL for Snowplow tracking"
  default     = ""
  type        = string
}

variable "sentry_enabled" {
  description = "Whether Sentry should be enabled or not"
  default     = false
  type        = bool
}

variable "sentry_dsn" {
  description = "DSN for Sentry instance"
  default     = ""
  type        = string
  sensitive   = true
}

variable "statsd_enabled" {
  description = "Whether Statsd should be enabled or not"
  default     = false
  type        = bool
}

variable "statsd_host" {
  description = "Hostname of StatsD server"
  default     = ""
  type        = string
}

variable "statsd_port" {
  description = "Port of StatsD server"
  default     = 8125
  type        = number
}

variable "stdout_metrics_enabled" {
  description = "Whether logging metrics to stdout should be activated or not"
  default     = false
  type        = bool
}

variable "webhook_enabled" {
  description = "Whether webhook should be enabled or not"
  default     = false
  type        = bool
}

variable "webhook_collector" {
  description = "URL of webhook collector"
  default     = ""
  type        = string
}

variable "folder_monitoring_period" {
  description = "How often to folder should be checked by folder monitoring"
  default     = "8 hours"
  type        = string

  validation {
    condition     = can(regex("\\d+ (ns|nano|nanos|nanosecond|nanoseconds|us|micro|micros|microsecond|microseconds|ms|milli|millis|millisecond|milliseconds|s|second|seconds|m|minute|minutes|h|hour|hours|d|day|days)", var.folder_monitoring_period))
    error_message = "Invalid period formant."
  }
}

variable "folder_monitoring_since" {
  description = "Specifies since when folder monitoring will check"
  default     = "14 days"
  type        = string

  validation {
    condition     = can(regex("\\d+ (ns|nano|nanos|nanosecond|nanoseconds|us|micro|micros|microsecond|microseconds|ms|milli|millis|millisecond|milliseconds|s|second|seconds|m|minute|minutes|h|hour|hours|d|day|days)", var.folder_monitoring_since))
    error_message = "Invalid period formant."
  }
}

variable "folder_monitoring_until" {
  description = "Specifies until when folder monitoring will check"
  default     = "6 hours"
  type        = string

  validation {
    condition     = can(regex("\\d+ (ns|nano|nanos|nanosecond|nanoseconds|us|micro|micros|microsecond|microseconds|ms|milli|millis|millisecond|milliseconds|s|second|seconds|m|minute|minutes|h|hour|hours|d|day|days)", var.folder_monitoring_until))
    error_message = "Invalid period formant."
  }
}

variable "health_check_enabled" {
  description = "Whether health check should be enabled or not"
  default     = false
  type        = bool
}

variable "health_check_freq" {
  description = "Frequency of health check"
  default     = "1 hour"
  type        = string

  validation {
    condition     = can(regex("\\d+ (ns|nano|nanos|nanosecond|nanoseconds|us|micro|micros|microsecond|microseconds|ms|milli|millis|millisecond|milliseconds|s|second|seconds|m|minute|minutes|h|hour|hours|d|day|days)", var.health_check_freq))
    error_message = "Invalid period formant."
  }
}

variable "health_check_timeout" {
  description = "How long to wait for a response for health check query"
  default     = "1 min"
  type        = string

  validation {
    condition     = can(regex("\\d+ (ns|nano|nanos|nanosecond|nanoseconds|us|micro|micros|microsecond|microseconds|ms|milli|millis|millisecond|milliseconds|s|second|seconds|m|minute|minutes|h|hour|hours|d|day|days)", var.health_check_timeout))
    error_message = "Invalid period formant."
  }
}

variable "retry_queue_enabled" {
  description = "Whether retry queue should be enabled or not"
  default     = false
  type        = bool
}

variable "retry_period" {
  description = "How often batch of failed folders should be pulled into a discovery queue"
  default     = "10 min"
  type        = string

  validation {
    condition     = can(regex("\\d+ (ns|nano|nanos|nanosecond|nanoseconds|us|micro|micros|microsecond|microseconds|ms|milli|millis|millisecond|milliseconds|s|second|seconds|m|minute|minutes|h|hour|hours|d|day|days)", var.retry_period))
    error_message = "Invalid period formant."
  }
}

variable "retry_queue_size" {
  description = "How many failures should be kept in memory"
  default     = -1
  type        = number
}

variable "retry_queue_max_attempt" {
  description = "How many attempt to make for each folder"
  default     = -1
  type        = number
}

variable "retry_queue_interval" {
  description = "Artificial pause after each failed folder being added to the queue"
  default     = "10 min"
  type        = string

  validation {
    condition     = can(regex("\\d+ (ns|nano|nanos|nanosecond|nanoseconds|us|micro|micros|microsecond|microseconds|ms|milli|millis|millisecond|milliseconds|s|second|seconds|m|minute|minutes|h|hour|hours|d|day|days)", var.retry_queue_interval))
    error_message = "Invalid period formant."
  }
}

# --- Iglu Resolver

variable "default_iglu_resolvers" {
  description = "The default Iglu Resolvers that will be used by Stream Shredder"
  default = [
    {
      name            = "Iglu Central"
      priority        = 10
      uri             = "http://iglucentral.com"
      api_key         = ""
      vendor_prefixes = []
    },
    {
      name            = "Iglu Central - Mirror 01"
      priority        = 20
      uri             = "http://mirror01.iglucentral.com"
      api_key         = ""
      vendor_prefixes = []
    }
  ]
  type = list(object({
    name            = string
    priority        = number
    uri             = string
    api_key         = string
    vendor_prefixes = list(string)
  }))
}

variable "custom_iglu_resolvers" {
  description = "The custom Iglu Resolvers that will be used by Stream Shredder"
  default     = []
  type = list(object({
    name            = string
    priority        = number
    uri             = string
    api_key         = string
    vendor_prefixes = list(string)
  }))
}

# --- Telemetry

variable "telemetry_enabled" {
  description = "Whether or not to send telemetry information back to Snowplow Analytics Ltd"
  type        = bool
  default     = true
}

variable "user_provided_id" {
  description = "An optional unique identifier to identify the telemetry events emitted by this stack"
  type        = string
  default     = ""
}

# --- Databricks parameters

variable "deltalake_catalog" {
  description = "Databricks deltalake catalog"
  type        = string
  default     = "hive_metastore"
}

variable "deltalake_schema" {
  description = "Databricks deltalake schema"
  type        = string
}

variable "deltalake_host" {
  description = "Databricks deltalake host"
  type        = string
}

variable "deltalake_port" {
  description = "Databricks deltalake port"
  type        = number
  default     = 443
}

variable "deltalake_http_path" {
  description = "Databricks deltalake http path"
  type        = string
}

variable "deltalake_auth_token" {
  description = "Databricks deltalake auth token"
  type        = string
  sensitive   = true
}

variable "databricks_aws_s3_bucket_name" {
  description = "AWS bucket name where data to load is stored"
  type        = string
}

variable "databricks_aws_s3_folder_monitoring_stage_url" {
  description = "AWS bucket URL of folder monitoring stage - must be within 'databricks_aws_s3_bucket_name' (NOTE: must be set if 'folder_monitoring_enabled' is true)"
  type        = string
  default     = ""
}

variable "databricks_aws_s3_folder_monitoring_transformer_output_stage_url" {
  description = "AWS bucket URL of transformer output stage - must be within 'databricks_aws_s3_bucket_name'  (NOTE: must be set if 'folder_monitoring_enabled' is true)"
  type        = string
  default     = ""
}

# --- Image Repositories

variable "private_ecr_registry" {
  description = "The URL of an ECR registry that the sub-account has access to (e.g. '000000000000.dkr.ecr.cn-north-1.amazonaws.com.cn/')"
  type        = string
  default     = ""
}
