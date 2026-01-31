# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe BrainzLab::Development do
  let(:test_db_path) { 'tmp/test_brainzlab.sqlite3' }

  before do
    # Clean up any existing test database
    FileUtils.rm_f(test_db_path)

    BrainzLab.configure do |config|
      config.mode = :development
      config.development_db_path = test_db_path
      config.recall_enabled = true
      config.reflex_enabled = true
      config.pulse_enabled = true
    end
  end

  after do
    BrainzLab.reset_configuration!
    FileUtils.rm_f(test_db_path)
  end

  describe '.enabled?' do
    it 'returns true when mode is development' do
      expect(described_class.enabled?).to be true
    end

    it 'returns false when mode is production' do
      BrainzLab.configuration.mode = :production
      expect(described_class.enabled?).to be false
    end
  end

  describe '.record' do
    it 'stores events in the database' do
      described_class.record(
        service: :recall,
        event_type: 'log',
        payload: { message: 'Test log', level: 'info' }
      )

      events = described_class.events
      expect(events.size).to eq(1)
      expect(events.first[:service]).to eq(:recall)
      expect(events.first[:event_type]).to eq('log')
      expect(events.first[:payload][:message]).to eq('Test log')
    end
  end

  describe '.events' do
    before do
      described_class.record(service: :recall, event_type: 'log', payload: { message: 'Log 1' })
      described_class.record(service: :recall, event_type: 'log', payload: { message: 'Log 2' })
      described_class.record(service: :reflex, event_type: 'error', payload: { message: 'Error 1' })
      described_class.record(service: :pulse, event_type: 'trace', payload: { name: 'Trace 1' })
    end

    it 'returns all events' do
      events = described_class.events
      expect(events.size).to eq(4)
    end

    it 'filters by service' do
      events = described_class.events(service: :recall)
      expect(events.size).to eq(2)
      expect(events.all? { |e| e[:service] == :recall }).to be true
    end

    it 'filters by event_type' do
      events = described_class.events(event_type: 'error')
      expect(events.size).to eq(1)
      expect(events.first[:event_type]).to eq('error')
    end

    it 'limits results' do
      events = described_class.events(limit: 2)
      expect(events.size).to eq(2)
    end

    it 'filters by time' do
      # All events should be after 1 minute ago
      events = described_class.events(since: Time.now - 60)
      expect(events.size).to eq(4)

      # No events should be after 1 minute in the future
      events = described_class.events(since: Time.now + 60)
      expect(events.size).to eq(0)
    end
  end

  describe '.stats' do
    before do
      3.times { described_class.record(service: :recall, event_type: 'log', payload: {}) }
      2.times { described_class.record(service: :reflex, event_type: 'error', payload: {}) }
      1.times { described_class.record(service: :pulse, event_type: 'trace', payload: {}) }
    end

    it 'returns counts by service' do
      stats = described_class.stats
      expect(stats[:recall]).to eq(3)
      expect(stats[:reflex]).to eq(2)
      expect(stats[:pulse]).to eq(1)
    end
  end

  describe '.clear!' do
    before do
      described_class.record(service: :recall, event_type: 'log', payload: {})
      described_class.record(service: :reflex, event_type: 'error', payload: {})
    end

    it 'removes all events' do
      expect(described_class.events.size).to eq(2)
      described_class.clear!
      expect(described_class.events.size).to eq(0)
    end
  end
end

RSpec.describe 'Development mode integration' do
  let(:test_db_path) { 'tmp/test_brainzlab_integration.sqlite3' }
  let(:output) { StringIO.new }

  before do
    FileUtils.rm_f(test_db_path)

    BrainzLab.configure do |config|
      config.mode = :development
      config.development_db_path = test_db_path
      config.development_log_output = output
      config.recall_enabled = true
      config.reflex_enabled = true
      config.pulse_enabled = true
    end
  end

  after do
    BrainzLab.reset_configuration!
    FileUtils.rm_f(test_db_path)
  end

  describe 'Recall in development mode' do
    it 'stores logs locally instead of sending to server' do
      BrainzLab::Recall.info('Test message', user_id: 123)

      events = BrainzLab.development_events(service: :recall)
      expect(events.size).to eq(1)
      expect(events.first[:payload][:message]).to eq('Test message')
      expect(events.first[:payload][:level]).to eq('info')
    end
  end

  describe 'Reflex in development mode' do
    it 'stores errors locally instead of sending to server' do
      begin
        raise StandardError, 'Test error'
      rescue StandardError => e
        BrainzLab::Reflex.capture(e)
      end

      events = BrainzLab.development_events(service: :reflex)
      expect(events.size).to eq(1)
      expect(events.first[:payload][:error_class]).to eq('StandardError')
      expect(events.first[:payload][:message]).to eq('Test error')
    end
  end

  describe 'Pulse in development mode' do
    it 'stores metrics locally instead of sending to server' do
      BrainzLab::Pulse.gauge('cpu.usage', 45.5, tags: { host: 'web1' })

      events = BrainzLab.development_events(service: :pulse)
      expect(events.size).to eq(1)
      expect(events.first[:event_type]).to eq('metric')
      expect(events.first[:payload][:name]).to eq('cpu.usage')
      expect(events.first[:payload][:value]).to eq(45.5)
    end

    it 'stores traces locally instead of sending to server' do
      BrainzLab::Pulse.record_trace(
        'GET /users',
        started_at: Time.now - 0.1,
        ended_at: Time.now,
        kind: 'request',
        status: 200
      )

      events = BrainzLab.development_events(service: :pulse, event_type: 'trace')
      expect(events.size).to eq(1)
      expect(events.first[:payload][:name]).to eq('GET /users')
    end
  end

  describe 'BrainzLab.development_events' do
    it 'is a convenience method for querying events' do
      BrainzLab::Recall.info('Log 1')
      BrainzLab::Recall.warn('Log 2')

      events = BrainzLab.development_events
      expect(events.size).to eq(2)
    end
  end

  describe 'BrainzLab.development_stats' do
    it 'returns event counts by service' do
      BrainzLab::Recall.info('Log 1')
      BrainzLab::Recall.info('Log 2')

      stats = BrainzLab.development_stats
      expect(stats[:recall]).to eq(2)
    end
  end

  describe 'BrainzLab.clear_development_events!' do
    it 'clears all events' do
      BrainzLab::Recall.info('Log 1')
      expect(BrainzLab.development_events.size).to eq(1)

      BrainzLab.clear_development_events!
      expect(BrainzLab.development_events.size).to eq(0)
    end
  end
end
