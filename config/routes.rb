# frozen_string_literal: true

require 'resque/server'

Rails.application.routes.draw do
  mount Resque::Server.new,
        at: '/resque',
        constraints: ->(req) { Settings.resque_dashboard_hostnames.include?(req.host) }

  get 'dashboard', to: 'dashboard#index', defaults: { format: 'html' }
  get 'dashboard2', to: 'dashboard#index2', defaults: { format: 'html' }

  scope 'v1' do
    resources :catalog, param: :druid, only: %i[create update]

    resources :objects, only: %i[show] do
      member do
        get 'checksum'
        get 'validate_moab'
        get 'file', format: false # no need to add extension to url
        post 'content_diff'
      end
      collection do
        match 'checksums', via: %i[get post]
      end
    end
  end
end
