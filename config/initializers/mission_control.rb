# frozen_string_literal: true

# Use ActionController::Base so the jobs dashboard does not require JWT auth.
MissionControl::Jobs.base_controller_class = 'ActionController::Base'
MissionControl::Jobs.http_basic_auth_enabled = false
