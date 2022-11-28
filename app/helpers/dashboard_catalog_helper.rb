# frozen_string_literal: true

# TODO: this will be going away in favor of Dashboard::CatalogService and ViewComponents

# helper methods for dashboard pertaining to catalog functionality
module DashboardCatalogHelper
  # used by catalog_status partials
  def catalog_ok?
    num_preserved_objects == num_complete_moabs &&
      num_object_versions_per_preserved_object == num_object_versions_per_complete_moab
  end

  # used by catalog_status partials
  def any_complete_moab_errors?
    num_complete_moab_not_ok.positive?
  end

  # used by catalog_status partials
  def num_complete_moab_not_ok
    CompleteMoab.where.not(status: 'ok').count
  end

  # used by catalog_status partials
  def num_preserved_objects
    PreservedObject.count
  end

  # used by catalog_status partials
  # total number of object versions according to PreservedObject table
  def num_object_versions_per_preserved_object
    PreservedObject.sum(:current_version)
  end

  # used by catalog_status partials
  def num_complete_moabs
    CompleteMoab.count
  end

  # used by catalog_status partials
  # total number of object versions according to CompleteMoab table
  def num_object_versions_per_complete_moab
    CompleteMoab.sum(:version)
  end
end
