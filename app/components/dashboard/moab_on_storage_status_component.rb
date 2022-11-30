# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to MoabOnStorageStatusComponent
  class MoabOnStorageStatusComponent < ViewComponent::Base
    include Dashboard::MoabOnStorageService
  end
end
