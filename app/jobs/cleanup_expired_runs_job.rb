class CleanupExpiredRunsJob < ApplicationJob
  queue_as :default

  def perform
    deleted = LlmsRun.delete_expired
    Rails.logger.info "CleanupExpiredRunsJob: Deleted #{deleted} expired runs"
  end
end
