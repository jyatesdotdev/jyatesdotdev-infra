resource "aws_rum_app_monitor" "monitor" {
  name        = "jyatesdotdev"
  domain      = var.domain_name
  
  cw_log_enabled = true

  app_monitor_configuration {
    allow_cookies       = true
    enable_xray         = true
    session_sample_rate = 1.0
    telemetries         = ["errors", "performance", "http"]
  }
}

variable "domain_name" { type = string }

output "rum_id" { value = aws_rum_app_monitor.monitor.id }
output "rum_script" { value = aws_rum_app_monitor.monitor.app_monitor_configuration }
