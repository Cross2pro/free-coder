/**
 * BigQuery metrics exporter is intentionally disabled in the OSS build.
 *
 * Originally sent OpenTelemetry metrics to:
 *   https://api.anthropic.com/api/claude_code/metrics
 *
 * This stub preserves the exported class so any dormant import sites compile,
 * but all methods are no-ops and no network traffic is generated.
 */

import {
  AggregationTemporality,
  type PushMetricExporter,
  type ResourceMetrics,
} from '@opentelemetry/sdk-metrics'
import { ExportResultCode, type ExportResult } from '@opentelemetry/core'

export class BigQueryMetricsExporter implements PushMetricExporter {
  async export(
    _metrics: ResourceMetrics,
    resultCallback: (result: ExportResult) => void,
  ): Promise<void> {
    resultCallback({ code: ExportResultCode.SUCCESS })
  }

  async shutdown(): Promise<void> {}

  async forceFlush(): Promise<void> {}

  selectAggregationTemporality(): AggregationTemporality {
    return AggregationTemporality.DELTA
  }
}
