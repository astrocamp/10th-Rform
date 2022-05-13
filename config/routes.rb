# frozen_string_literal: true

Rails.application.routes.draw do
  
  root 'homepage#index'
  resources :users

  get 'login' => 'user_sessions#new', :as => :login
  post 'login' => 'user_sessions#create'
  post 'logout' => 'user_sessions#destroy', :as => :logout

  resources :surveys do
    resources :responses

    member do
      patch :sort
      patch :question_sort
      post :survey_title
      post :survey_description
      post :add_question_item
      post :add_answer_item
      post :save_checkbox
      patch :update_select
      post :add_question
      post :add_answer
      delete :remove_question
      delete :remove_answer
    end

    get 'duplicate', on: :member , to: "surveys#duplicate_survey"
    patch :tag
  end

  post "oauth/callback" => "oauths#callback"
  get "oauth/callback" => "oauths#callback" # for use with Github, Facebook
  get "oauth/:provider" => "oauths#oauth", :as => :auth_at_provider

  resources :password_resets, only: [:new, :create, :edit, :update]

end
