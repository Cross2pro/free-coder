/**
 * First-party event logging exporter is intentionally disabled in the OSS build.
 *
 * Originally batched and sent custom telemetry events to:
 *   https://api.anthropic.com/api/event_logging/batch
 *
 * Failed events were persisted locally to ~/.config/claude/telemetry/ for
 * retry across process restarts.
 *
 * This stub preserves the exported class so any dormant import sites compile,
 * but all methods are no-ops and no network traffic is generated.
 */

import { ExportResultCode, type ExportResult } from '@opentelemetry/core'
import type {
  LogRecordExporter,
  ReadableLogRecord,
} from '@opentelemetry/sdk-logs'

export class FirstPartyEventLoggingExporter implements LogRecordExporter {
  export(
    _logs: ReadableLogRecord[],
    resultCallback: (result: ExportResult) => void,
  ): void {
    resultCallback({ code: ExportResultCode.SUCCESS })
  }

  async shutdown(): Promise<void> {}

  async forceFlush(): Promise<void> {}

  async getQueuedEventCount(): Promise<number> {
    return 0
  }
}
