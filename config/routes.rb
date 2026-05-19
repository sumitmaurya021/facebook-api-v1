Rails.application.routes.draw do
  namespace :admin do
    get "overview", to: "dashboard#show"
  end

  use_doorkeeper do
    skip_controllers :authorizations, :applications, :authorized_applications
  end
  devise_for :users
  namespace :api do
    resources :users, only: [:create]
  end
end
