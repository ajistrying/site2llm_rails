require 'rails_helper'

RSpec.describe LlmsRun, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:content) }
    it { should validate_presence_of(:expires_at) }
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_run) { create(:llms_run, expires_at: 1.hour.from_now) }
      let!(:expired_run) { create(:llms_run, :expired) }

      it 'returns only runs that have not expired' do
        expect(described_class.active).to include(active_run)
        expect(described_class.active).not_to include(expired_run)
      end
    end

    describe '.expired' do
      let!(:active_run) { create(:llms_run, expires_at: 1.hour.from_now) }
      let!(:expired_run) { create(:llms_run, :expired) }

      it 'returns only runs that have expired' do
        expect(described_class.expired).to include(expired_run)
        expect(described_class.expired).not_to include(active_run)
      end
    end
  end

  describe '.create_run' do
    it 'creates a new run with 24-hour expiration' do
      content = '# Test Content'
      run = described_class.create_run(content)

      expect(run).to be_persisted
      expect(run.content).to eq(content)
      expect(run.expires_at).to be_within(1.minute).of(24.hours.from_now)
      expect(run.paid_at).to be_nil
    end
  end

  describe '.find_active' do
    let!(:active_run) { create(:llms_run) }
    let!(:expired_run) { create(:llms_run, :expired) }

    it 'returns the run if it is active' do
      expect(described_class.find_active(active_run.id)).to eq(active_run)
    end

    it 'returns nil if the run has expired' do
      expect(described_class.find_active(expired_run.id)).to be_nil
    end

    it 'returns nil if the run does not exist' do
      expect(described_class.find_active('nonexistent-id')).to be_nil
    end
  end

  describe '.delete_expired' do
    let!(:active_run) { create(:llms_run) }
    let!(:expired_run1) { create(:llms_run, :expired) }
    let!(:expired_run2) { create(:llms_run, :expired) }

    it 'deletes all expired runs' do
      expect { described_class.delete_expired }.to change { described_class.count }.by(-2)
      expect(described_class.find_by(id: active_run.id)).to eq(active_run)
      expect(described_class.find_by(id: expired_run1.id)).to be_nil
      expect(described_class.find_by(id: expired_run2.id)).to be_nil
    end
  end

  describe '#mark_paid!' do
    let(:run) { create(:llms_run) }

    it 'sets paid_at to current time' do
      freeze_time do
        run.mark_paid!
        expect(run.paid_at).to eq(Time.current)
      end
    end

    it 'extends expires_at to 30 days from now' do
      freeze_time do
        run.mark_paid!
        expect(run.expires_at).to eq(Time.current + 30.days)
      end
    end
  end

  describe '#paid?' do
    it 'returns false when paid_at is nil' do
      run = create(:llms_run)
      expect(run.paid?).to be false
    end

    it 'returns true when paid_at is set' do
      run = create(:llms_run, :paid)
      expect(run.paid?).to be true
    end
  end
end
