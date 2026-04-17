resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "jyatesdotdev-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", "jyatesdotdev-api", { stat = "Sum", color = "#1f77b4" }],
            [".", "4XXError", ".", ".", { stat = "Sum", color = "#ff7f0e" }],
            [".", "5XXError", ".", ".", { stat = "Sum", color = "#d62728" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Requests & Errors"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", color = "#2ca02c" }],
            [".", "Errors", { stat = "Sum", color = "#d62728" }],
            [".", "Throttles", { stat = "Sum", color = "#ff7f0e" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Executions (All Functions)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/CloudFront", "Requests", "DistributionId", module.cloudfront.distribution_id, "Region", "Global", { stat = "Sum" }],
            [".", "4xxErrorRate", ".", ".", ".", ".", { stat = "Average", yAxis = "right" }],
            [".", "5xxErrorRate", ".", ".", ".", ".", { stat = "Average", yAxis = "right" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "CloudFront Traffic & Error Rates"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/WAFV2", "AllowedRequests", "Rule", "ALL", "WebACL", "jyatesdotdev-waf", "Region", "Global", { stat = "Sum", color = "#2ca02c" }],
            [".", "BlockedRequests", ".", ".", ".", ".", ".", ".", { stat = "Sum", color = "#d62728" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "WAF Allowed vs Blocked (DDoS Protection)"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", module.dynamodb.table_name, { stat = "Sum", color = "#1f77b4" }],
            [".", "ConsumedWriteCapacityUnits", ".", ".", { stat = "Sum", color = "#ff7f0e" }],
            [".", "ThrottledRequests", ".", ".", { stat = "Sum", color = "#d62728" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "DynamoDB Capacity & Throttling"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Billing", "EstimatedCharges", "Currency", "USD", { stat = "Maximum", color = "#d62728" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Estimated AWS Charges (USD)"
          period  = 21600
        }
      }
    ]
  })
}
