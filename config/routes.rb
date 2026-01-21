# frozen_string_literal: true

Rails.application.routes.draw do
  require 'sidekiq/web'
  mount Sidekiq::Web => '/queues'

  root to: redirect('/dashboard')

  namespace :dashboard do
    root to: 'dashboard#index' # Preservation System Status Overview page

    resources :objects, only: [:show] # show -> Object show page
    resources :moab_records, only: [:index] do # index -> Files in moabs on local storage page
      collection do
        get 'with_errors' # MoabRecords in error statuses list page
        get 'stuck' # Stuck MoabRecords list page
      end
    end
    resources :zipped_moab_versions, only: [:index] do # Replication of zip part files to cloud endpoints page
      collection do
        get 'with_errors' # ZipppedMoabVersion in failed status list page
        get 'stuck' # Stuck ZippedMoabVersions list page
      end
    end
  end

  scope 'v1' do
    resources :catalog, param: :druid, only: %i[create update]

    resources :objects, only: %i[show] do
      member do
        get 'ok'
        get 'checksum'
        get 'validate_moab'
        get 'file', format: false # no need to add extension to url
        post 'content_diff'
      end
    end
  end
end
