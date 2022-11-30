# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to CompleteMoabsComponent
  class CompleteMoabsComponent < ViewComponent::Base
    include Dashboard::MoabOnStorageService
  end
end
