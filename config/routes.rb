# frozen_string_literal: true

require 'resque/server'

Rails.application.routes.draw do
  resources :catalog, param: :druid, only: %i[create update]

  mount Resque::Server.new, at: '/resque',
                            constraints: ->(req) { Settings.resque_dashboard_hostnames.include?(req.host) }

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
