require 'rails_helper'

RSpec.describe MyAccount::AccountController, type: :controller do
  render_views
  before do
    routes.draw do
      get :intro, to: "my_account/account#intro"
      get :index, to: "my_account/account#index"
      post :ajax_renew, to: "my_account/account#ajax_renew"
      post :ajax_cancel, to: "my_account/account#ajax_cancel"
      post :get_user_record, to: "my_account/account#get_user_record"
      post :get_folio_data, to: "my_account/account#get_folio_data"
      post :get_illiad_data, to: "my_account/account#get_illiad_data"
      post :ajax_checkouts, to: "my_account/account#ajax_checkouts"
      post :ajax_service_point, to: "my_account/account#ajax_service_point"
      post :ajax_catalog_link_and_source, to: "my_account/account#ajax_catalog_link_and_source"
      post :ajax_fines, to: "my_account/account#ajax_fines"
      post :ajax_illiad_available, to: "my_account/account#ajax_illiad_available"
      post :ajax_illiad_pending, to: "my_account/account#ajax_illiad_pending"
      post :get_bd_requests, to: "my_account/account#get_bd_requests"
    end
    allow(controller).to receive(:authenticate_user).and_return(true)
    allow(controller).to receive(:render_to_string).and_return("stubbed")
    allow(XmlSimple).to receive(:xml_in).and_return({
      'GetRecord' => [{
          'record' => [{
            'metadata' => [{
              'record' => [{
                'datafield' => [
                  {
                    'tag' => '245',
                    'subfield' => [
                      { 'code' => 'a', 'content' => 'Test Title' },
                      { 'code' => 'b', 'content' => 'Subtitle' }
                    ]
                  }
                ]
              }]
            }]
          }]
        }]
      })
  end

  describe 'GET #intro' do
    it 'renders the intro template' do
      puts controller.view_paths.map(&:to_s)
      get :intro
      expect(response).to be_successful
    end
  end

  describe 'GET #index' do
    it 'renders successfully if not disabled' do
      allow(controller).to receive(:user).and_return('testuser')
      get :index
      expect(response).to be_successful
      expect(assigns(:netid)).to eq('testuser')
    end

    it 'redirects if DISABLE_MY_ACCOUNT is set' do
      stub_const('ENV', ENV.to_hash.merge('DISABLE_MY_ACCOUNT' => '1'))
      get :index
      expect(response).to redirect_to('/catalog#index')
    end
  end

  describe 'POST #ajax_renew' do
    it 'returns JSON from FOLIO Edge renew_item' do
      allow(controller).to receive(:folio_token).and_return('token')
      allow(CUL::FOLIO::Edge).to receive(:renew_item).and_return({ success: true })
      post :ajax_renew, params: { netid: 'testuser', itemId: 'item123' }
      expect(response.content_type).to start_with('application/json')
      expect(JSON.parse(response.body)['success']).to be true
    end
  end

  describe 'POST #ajax_cancel' do
    it 'returns JSON from FOLIO Edge cancel_request' do
      allow(controller).to receive(:folio_token).and_return('token')
      allow(CUL::FOLIO::Edge).to receive(:cancel_request).and_return({ cancelled: true })
      post :ajax_cancel, params: { requestId: 'req123' }
      expect(response.content_type).to start_with('application/json')
      expect(JSON.parse(response.body)['cancelled']).to be true
    end
  end

  describe 'POST #get_user_record' do
    it 'returns JSON user record' do
      allow(controller).to receive(:folio_token).and_return('token')
      allow(CUL::FOLIO::Edge).to receive(:patron_record).and_return({ netid: 'testuser' })
      post :get_user_record, params: { netid: 'testuser' }
      expect(response.content_type).to start_with('application/json')
      expect(JSON.parse(response.body)['netid']).to eq('testuser')
    end
  end

  describe 'POST #get_folio_data' do
    it 'returns JSON account data' do
      allow(controller).to receive(:folio_token).and_return('token')
      allow(CUL::FOLIO::Edge).to receive(:patron_account).and_return({ account: 'data' })
      post :get_folio_data, params: { netid: 'testuser' }
      expect(response.content_type).to start_with('application/json')
      expect(JSON.parse(response.body)['account']).to eq('data')
    end
  end

  describe 'POST #ajax_checkouts' do
    it 'renders JSON with checkouts partial' do
      post :ajax_checkouts, params: { checkouts: [{ 'dueDate' => '2025-01-01' }] }
      expect(response.content_type).to start_with('application/json')
      expect(JSON.parse(response.body)).to have_key('record')
    end
  end

  describe 'POST #ajax_service_point' do
    it 'returns JSON service point' do
      allow(controller).to receive(:folio_token).and_return('token')
      allow(CUL::FOLIO::Edge).to receive(:service_point).and_return({ sp: 'data' })
      post :ajax_service_point, params: { sp_id: 'sp123' }
      expect(response.content_type).to start_with('application/json')
      expect(JSON.parse(response.body)['sp']).to eq('data')
    end
  end

  describe 'POST #ajax_catalog_link_and_source' do
    it 'returns JSON with link and source' do
      allow(controller).to receive(:folio_token).and_return('token')
      allow(CUL::FOLIO::Edge).to receive(:instance_record).and_return({ code: 200, instance: { 'hrid' => '123', 'source' => 'MARC' } })
      post :ajax_catalog_link_and_source, params: { instanceId: 'inst123' }
      expect(response.content_type).to start_with('application/json')
      expect(JSON.parse(response.body)).to have_key('link')
      expect(JSON.parse(response.body)).to have_key('source')
    end
  end

  describe 'POST #ajax_fines' do
    it 'renders JSON with fines partial' do
      post :ajax_fines, params: { fines: { '1' => { amount: 5 } } }
      expect(response.content_type).to start_with('application/json')
      expect(JSON.parse(response.body)).to have_key('record')
    end
  end

  describe 'POST #ajax_illiad_available' do
    it 'renders JSON with available_requests partial' do
      post :ajax_illiad_available, params: { requests: { '1' => { status: 'waiting' } } }
      expect(response.content_type).to start_with('application/json')
      expect(JSON.parse(response.body)).to have_key('record')
    end
  end

  describe 'POST #ajax_illiad_pending' do
    it 'renders JSON with pending_requests partial' do
      post :ajax_illiad_pending, params: { requests: { '1' => { status: 'pending' } } }
      expect(response.content_type).to start_with('application/json')
      expect(JSON.parse(response.body)).to have_key('record')
    end
  end

  describe 'POST #get_bd_requests' do
    it 'returns JSON BD requests' do
      allow(CUL::FOLIO::Edge).to receive(:authenticate).and_return({ code: 200, token: 'token' })
      allow(RestClient).to receive(:get).and_return('[{"patronIdentifier":"testuser","state":{"code":"REQ_CREATED"},"hrid":"hrid1","pickupLocation":"loc1","bibRecord":"<xml></xml>"}]')
      post :get_bd_requests, params: { netid: 'testuser' }
      expect(response.content_type).to start_with('application/json')
      expect(JSON.parse(response.body)).to be_an(Array)
    end
  end
end