module Audit
  # Catalog to cloud archive provider (what ZipEndpoint, ZippedMoabVersion etc represent) audit code
  class CatalogToArchive
    # TODO: should we be capturing/reporting via AuditResults instance instead of just logging?  would be
    # consistent with other audit checks.
    def self.logger
      @logger ||= Logger.new(Rails.root.join('log', 'c2a.log'))
    end

    # @return [boolean] true if we have a list of child parts to check in the cloud, false otherwise
    def self.check_child_zip_part_attributes(zmv)
      unless zmv.zip_parts.count > 0
        logger.error("#{zmv.inspect}: no zip_parts exist yet for this ZippedMoabVersion")
        # everything else relies on checking parts, nothing left to do
        return false
      end

      child_parts_counts = zmv.child_parts_counts
      if child_parts_counts.length > 1
        logger.error("#{zmv.inspect}: there's variation in child part counts: #{child_parts_counts.to_a}")
      elsif child_parts_counts.length == 1 && child_parts_counts.first.first != zmv.zip_parts.length
        logger.error(
          "#{zmv.inspect}: stated parts count (#{child_parts_counts.first.first}) "\
          "doesn't match actual parts count (#{zmv.zip_parts.length})"
        )
      end

      unreplicated_parts = zmv.zip_parts.where(status: :unreplicated)
      if unreplicated_parts.count > 0
        msg = "#{zmv.inspect}: all parts should be replicated, but at least one is not: #{unreplicated_parts.to_a}"
        logger.error(msg)
      end

      true
    end
  end
end
