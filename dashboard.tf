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
            [{ expression = "SUM(SEARCH('{AWS/Lambda,FunctionName} MetricName=\"Invocations\"', 'Sum', 300))", id = "invocations", label = "Invocations", color = "#2ca02c" }],
            [{ expression = "SUM(SEARCH('{AWS/Lambda,FunctionName} MetricName=\"Errors\"', 'Sum', 300))", id = "errors", label = "Errors", color = "#d62728" }],
            [{ expression = "SUM(SEARCH('{AWS/Lambda,FunctionName} MetricName=\"Throttles\"', 'Sum', 300))", id = "throttles", label = "Throttles", color = "#ff7f0e" }]
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
            ["AWS/ApiGateway", "Count", "ApiName", "jyatesdotdev-api", "Stage", "v1", { stat = "Sum", color = "#1f77b4" }],
            [".", "4XXError", ".", ".", ".", ".", { stat = "Sum", color = "#d62728" }],
            [".", "5XXError", ".", ".", ".", ".", { stat = "Sum", color = "#9467bd" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Gateway Requests & Errors (throttle/quota 429s show as 4XX)"
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
