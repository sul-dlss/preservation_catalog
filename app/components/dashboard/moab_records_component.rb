# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to MoabRecordsComponent
  class MoabRecordsComponent < ViewComponent::Base
    include Dashboard::MoabOnStorageService
  end
end
