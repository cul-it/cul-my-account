require 'logger'
require 'active_support'
require 'active_support/core_ext/string'
require_relative '../../app/helpers/my_account/my_account_helper'

RSpec.describe MyAccount::MyAccountHelper do
  include MyAccount::MyAccountHelper

  describe '#cased_title_link' do
    it 'returns the titleized title from the item' do
      item = { 'item' => { 'title' => 'the lord of the rings' } }
      expect(cased_title_link(item)).to eq('The Lord of the Rings')
    end
  end

  describe '#status_display' do
    it 'returns "Overdue" if overdue is true' do
      item = { 'overdue' => 'true' }
      expect(status_display(item)).to eq('Overdue')
    end

    it 'returns nil if overdue is not true' do
      item = { 'overdue' => 'false' }
      expect(status_display(item)).to be_nil
    end

    it 'returns nil if overdue key is missing' do
      item = {}
      expect(status_display(item)).to be_nil
    end
  end

  describe '#system_tag' do
    it 'returns "illiad" if TransactionNumber is present' do
      item = { 'TransactionNumber' => '12345' }
      expect(system_tag(item)).to eq('illiad')
    end

    it 'returns "folio" if TransactionNumber is nil' do
      item = { 'TransactionNumber' => nil }
      expect(system_tag(item)).to eq('folio')
    end

    it 'returns "folio" if TransactionNumber is missing' do
      item = {}
      expect(system_tag(item)).to eq('folio')
    end
  end
end