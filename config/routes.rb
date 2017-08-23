Rails.application.routes.draw do
  get 'moab_storage/index'

  resources :moab_storage, only: [:show]
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
