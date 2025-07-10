# frozen_string_literal: true

RSpec.describe OxTenderAbstract::Result do
  describe '.success' do
    let(:data) { { message: 'Test data' } }
    let(:result) { described_class.success(data) }

    it 'creates successful result' do
      expect(result).to be_success
      expect(result).not_to be_failure
      expect(result.data).to eq(data)
      expect(result.error).to be_nil
    end
  end

  describe '.failure' do
    let(:error_message) { 'Test error' }
    let(:result) { described_class.failure(error_message) }

    it 'creates failed result' do
      expect(result).to be_failure
      expect(result).not_to be_success
      expect(result.error).to eq(error_message)
      expect(result.data).to be_nil
    end
  end

  describe '#success?' do
    it 'returns true for successful results' do
      result = described_class.success({})
      expect(result.success?).to be true
    end

    it 'returns false for failed results' do
      result = described_class.failure('error')
      expect(result.success?).to be false
    end
  end

  describe '#failure?' do
    it 'returns false for successful results' do
      result = described_class.success({})
      expect(result.failure?).to be false
    end

    it 'returns true for failed results' do
      result = described_class.failure('error')
      expect(result.failure?).to be true
    end
  end
end
