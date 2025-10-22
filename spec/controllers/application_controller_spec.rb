require 'rails_helper'

RSpec.describe MyAccount::ApplicationController, type: :controller do
  controller do
    def index
      flash[:notice] = "Notice message"
      render plain: "index"
    end

    def error
      flash[:error] = "Error message"
      render plain: "error"
    end

    def warning
      flash[:warning] = "Warning message"
      render plain: "warning"
    end

    def keep
      flash[:keep] = "keep"
      render plain: "keep"
    end

    def no_flash
      render plain: "no flash"
    end
  end

  before do
    routes.draw do
      get :index, to: "my_account/application#index"
      get :error, to: "my_account/application#error"
      get :warning, to: "my_account/application#warning"
      get :keep, to: "my_account/application#keep"
      get :no_flash, to: "my_account/application#no_flash"
    end
  end

  describe 'flash_to_headers after_action' do
    it 'sets X-Message and X-Message-Type headers for AJAX notice' do
      request.headers['X-Requested-With'] = 'XMLHttpRequest'
      get :index
      expect(response.headers['X-Message']).to eq("Notice message")
      expect(response.headers['X-Message-Type']).to eq("notice")
    end

    it 'sets X-Message and X-Message-Type headers for AJAX error' do
      request.headers['X-Requested-With'] = 'XMLHttpRequest'
      get :error
      expect(response.headers['X-Message']).to eq("Error message")
      expect(response.headers['X-Message-Type']).to eq("error")
    end

    it 'sets X-Message and X-Message-Type headers for AJAX warning' do
      request.headers['X-Requested-With'] = 'XMLHttpRequest'
      get :warning
      expect(response.headers['X-Message']).to eq("Warning message")
      expect(response.headers['X-Message-Type']).to eq("warning")
    end

    it 'sets X-Message-Type to keep if flash[:keep] is set' do
      request.headers['X-Requested-With'] = 'XMLHttpRequest'
      get :keep
      expect(response.headers['X-Message-Type']).to eq("keep")
    end

    it 'sets X-Message-Type to empty if no flash is set' do
      request.headers['X-Requested-With'] = 'XMLHttpRequest'
      get :no_flash
      expect(response.headers['X-Message-Type']).to eq("empty")
    end

    it 'does not set headers for non-AJAX requests' do
      get :index
      expect(response.headers['X-Message']).to be_nil
      expect(response.headers['X-Message-Type']).to be_nil
    end
  end

  describe '#flash_message' do
    it 'returns the first non-blank flash message' do
      controller.flash[:error] = ""
      controller.flash[:warning] = "Warn"
      controller.flash[:notice] = "Notice"
      expect(controller.send(:flash_message)).to eq("Warn")
    end

    it 'returns empty string if all flash messages are blank' do
      controller.flash[:error] = ""
      controller.flash[:warning] = ""
      controller.flash[:notice] = ""
      expect(controller.send(:flash_message)).to eq("")
    end
  end

  describe '#flash_type' do
    it 'returns the type of the first non-blank flash' do
      controller.flash[:error] = ""
      controller.flash[:warning] = "Warn"
      controller.flash[:notice] = ""
      expect(controller.send(:flash_type)).to eq(:warning)
    end

    it 'returns :empty if all flash types are blank' do
      controller.flash[:error] = ""
      controller.flash[:warning] = ""
      controller.flash[:notice] = ""
      controller.flash[:keep] = ""
      expect(controller.send(:flash_type)).to eq(:empty)
    end

    it 'returns :keep if flash[:keep] is set' do
      controller.flash[:keep] = "something"
      expect(controller.send(:flash_type)).to eq(:keep)
    end
  end
end