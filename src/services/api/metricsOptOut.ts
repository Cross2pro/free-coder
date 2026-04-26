/**
 * Metrics opt-out check is intentionally disabled in the OSS build.
 *
 * Originally called https://api.anthropic.com/api/claude_code/organizations/metrics_enabled
 * to determine whether an organization had opted out of metrics collection.
 *
 * This stub always returns enabled:false so that the BigQuery exporter (also
 * stubbed) would never attempt to send data even if somehow reactivated.
 */

type MetricsStatus = {
  enabled: boolean
  hasError: boolean
}

export async function checkMetricsEnabled(): Promise<MetricsStatus> {
  return { enabled: false, hasError: false }
}

// Export for testing purposes only
export const _clearMetricsEnabledCacheForTesting = (): void => {}
