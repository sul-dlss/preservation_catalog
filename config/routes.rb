require 'resque/server'

Rails.application.routes.draw do
  resources :catalog, param: :druid, only: %i[create update]
  resources :moab_storage, only: %i[index show]

  mount Resque::Server.new, at: '/resque', constraints: { host: /stage-02|prod-03/ }

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
