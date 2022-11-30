# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to ObjectVersionsComponent
  class ObjectVersionsComponent < ViewComponent::Base
    include Dashboard::MoabOnStorageService
  end
end
