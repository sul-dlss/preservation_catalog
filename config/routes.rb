# frozen_string_literal: true

Rails.application.routes.draw do
  require 'sidekiq/web'
  mount Sidekiq::Web => '/queues'

  get 'dashboard', to: 'dashboard#index', defaults: { format: 'html' }
  namespace :dashboard do
    # routes for turbo-frame partials
    get 'moab_storage_status', to: '/dashboard#moab_storage_status', defaults: { format: 'html' }
    get 'moab_record_versions', to: '/dashboard#moab_record_versions', defaults: { format: 'html' }
    get 'moab_record_info', to: '/dashboard#moab_record_info', defaults: { format: 'html' }
    get 'storage_root_data', to: '/dashboard#storage_root_data', defaults: { format: 'html' }
    get 'replication_status', to: '/dashboard#replication_status', defaults: { format: 'html' }
    get 'replication_endpoints', to: '/dashboard#replication_endpoints', defaults: { format: 'html' }
    get 'replicated_files', to: '/dashboard#replicated_files', defaults: { format: 'html' }
    get 'audit_status', to: '/dashboard#audit_status', defaults: { format: 'html' }
    get 'audit_info', to: '/dashboard#audit_info', defaults: { format: 'html' }
  end

  scope 'v1' do
    resources :catalog, param: :druid, only: %i[create update]

    resources :objects, only: %i[show] do
      member do
        get 'checksum'
        get 'validate_moab'
        get 'file', format: false # no need to add extension to url
        post 'content_diff'
      end
    end
  end
end
