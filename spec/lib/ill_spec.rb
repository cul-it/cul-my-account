require 'json'
require_relative '../../lib/ill'

RSpec.describe ILL do
  # Need a dummy class to test module methods
  let(:dummy) { Class.new { extend ILL } }

  describe '#filter_by_status' do
    it 'removes completed and cancelled transactions' do
      transactions = [
        { 'TransactionStatus' => 'Request Finished' },
        { 'TransactionStatus' => 'Cancelled by ILL Staff' },
        { 'TransactionStatus' => 'Cancelled by Customer' },
        { 'TransactionStatus' => 'Checked Out to Customer' },
        { 'TransactionStatus' => 'Cancelled by ILL Staff' }
      ]
      filtered = dummy.send(:filter_by_status, transactions)
      expect(filtered).to eq([{ 'TransactionStatus' => 'Checked Out to Customer' }])
    end
  end

  describe '#transform_fields' do
    it 'transforms book transactions correctly' do
      transactions = [
        {
          'TransactionNumber' => '123',
          'LoanTitle' => 'Test Book',
          'LoanAuthor' => 'Smith',
          'DueDate' => '2025-01-01',
          'NVTGC' => 'Library',
          'TransactionStatus' => 'Checked Out to Customer',
          'DocumentType' => 'Loan',
          'CreationDate' => '2024-01-01',
          'TransactionDate' => '2024-01-02'
        }
      ]
      result = JSON.parse(dummy.send(:transform_fields, transactions))
      item = result['items'].first
      expect(item['system']).to eq('illiad')
      expect(item['status']).to eq('chrged')
      expect(item['tl']).to include('Test Book')
      expect(item['ou_aulast']).to eq('Smith')
      expect(item['rd']).to eq('2025-01-01')
      expect(item['url']).to include('123')
    end

    it 'transforms article transactions correctly' do
      transactions = [
        {
          'TransactionNumber' => '456',
          'PhotoArticleTitle' => 'Test Article',
          'PhotoArticleAuthor' => 'Jones',
          'PhotoJournalTitle' => 'Journal',
          'PhotoJournalVolume' => '10',
          'PhotoJournalIssue' => '2',
          'PhotoJournalInclusivePages' => '100-110',
          'PhotoJournalYear' => '2023',
          'ISSN' => '1234-5678',
          'DueDate' => '2025-02-02',
          'NVTGC' => 'Library',
          'TransactionStatus' => 'Delivered to Web',
          'DocumentType' => 'Article',
          'CreationDate' => '2024-02-01',
          'TransactionDate' => '2024-02-02'
        }
      ]
      result = JSON.parse(dummy.send(:transform_fields, transactions))
      item = result['items'].first
      expect(item['system']).to eq('illiad')
      expect(item['status']).to eq('waiting')
      expect(item['tl']).to include('Test Article')
      expect(item['ou_aulast']).to eq('Jones')
      expect(item['rd']).to eq('2025-02-02')
      expect(item['url']).to include('456')
    end

    it 'transforms status and url for customer statuses' do
      transactions = [
        { 'LoanTitle' => 'Test 1', 'TransactionStatus' => 'Renewal Requested by Customer', 'TransactionNumber' => '789' },
        { 'LoanTitle' => 'Test 2', 'TransactionStatus' => 'Checked Out to Customer', 'TransactionNumber' => '790' }
      ]
      result = JSON.parse(dummy.send(:transform_fields, transactions))
      statuses = result['items'].map { |item| item['status'] }
      urls = result['items'].map { |item| item['url'] }
      expect(statuses).to all(eq('chrged'))
      expect(urls[0]).to eq("https://cornell.hosts.atlas-sys.com/illiad/illiad.dll?Action=10&Form=66&Value=789")
      expect(urls[1]).to eq("https://cornell.hosts.atlas-sys.com/illiad/illiad.dll?Action=10&Form=66&Value=790")
    end

    it 'transforms status and url for Verisign status' do
      transactions = [
        { 'LoanTitle' => 'Test Verisign', 'TransactionStatus' => 'Awaiting Verisign Payment', 'TransactionNumber' => '791' }
      ]
      result = JSON.parse(dummy.send(:transform_fields, transactions))
      item = result['items'].first
      expect(item['status']).to eq('waiting')
      expect(item['url']).to eq("https://cornell.hosts.atlas-sys.com/illiad/illiad.dll?Action=10&Form=62")
    end

    it 'transforms status and url for web delivery status' do
      transactions = [
        { 'LoanTitle' => 'Test Web', 'TransactionStatus' => 'Delivered to Web', 'TransactionNumber' => '793' }
      ]
      result = JSON.parse(dummy.send(:transform_fields, transactions))
      item = result['items'].first
      expect(item['status']).to eq('waiting')
      expect(item['url']).to eq("https://cornell.hosts.atlas-sys.com/illiad/illiad.dll?Action=10&Form=75&Value=793")
    end

    it 'transforms status for notified status' do
      transactions = [
        { 'LoanTitle' => 'Test Notified', 'TransactionStatus' => 'Customer Notified via E-Mail', 'TransactionNumber' => '794' }
      ]
      result = JSON.parse(dummy.send(:transform_fields, transactions))
      item = result['items'].first
      expect(item['status']).to eq('waiting')
      expect(item['url']).to be_nil
    end

    it 'transforms status and url for other statuses' do
      transactions = [
        { 'LoanTitle' => 'Test Other', 'TransactionStatus' => 'On Hold Shelf', 'TransactionNumber' => '792' }
      ]
      result = JSON.parse(dummy.send(:transform_fields, transactions))
      item = result['items'].first
      expect(item['status']).to eq('pahr')
      expect(item['url']).to eq("https://cornell.hosts.atlas-sys.com/illiad/illiad.dll?Action=10&Form=63&Value=792")
    end
  end
end