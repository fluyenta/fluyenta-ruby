# frozen_string_literal: true

require 'sqlite3'
require 'json'
require 'fileutils'

module BrainzLab
  module Development
    # SQLite-backed store for development mode events
    class Store
      DEFAULT_PATH = 'tmp/brainzlab.sqlite3'

      def initialize(config)
        @config = config
        @db_path = config.development_db_path || DEFAULT_PATH
        @db = nil
        ensure_database!
      end

      # Insert an event into the store
      # @param service [Symbol] :recall, :reflex, :pulse, etc.
      # @param event_type [String] type of event
      # @param payload [Hash] event data
      def insert(service:, event_type:, payload:)
        db.execute(
          'INSERT INTO events (service, event_type, payload, created_at) VALUES (?, ?, ?, ?)',
          [service.to_s, event_type.to_s, JSON.generate(payload), Time.now.utc.iso8601(3)]
        )
      end

      # Query events from the store
      # @param service [Symbol, nil] filter by service
      # @param event_type [String, nil] filter by event type
      # @param since [Time, nil] filter events after this time
      # @param limit [Integer] max number of events to return
      # @return [Array<Hash>] matching events
      def query(service: nil, event_type: nil, since: nil, limit: 100)
        conditions = []
        params = []

        if service
          conditions << 'service = ?'
          params << service.to_s
        end

        if event_type
          conditions << 'event_type = ?'
          params << event_type.to_s
        end

        if since
          conditions << 'created_at >= ?'
          params << since.utc.iso8601(3)
        end

        where_clause = conditions.empty? ? '' : "WHERE #{conditions.join(' AND ')}"
        params << limit

        sql = "SELECT id, service, event_type, payload, created_at FROM events #{where_clause} ORDER BY created_at DESC LIMIT ?"

        db.execute(sql, params).map do |row|
          {
            id: row[0],
            service: row[1].to_sym,
            event_type: row[2],
            payload: JSON.parse(row[3], symbolize_names: true),
            created_at: Time.parse(row[4])
          }
        end
      end

      # Get event counts by service
      def stats
        results = db.execute('SELECT service, COUNT(*) as count FROM events GROUP BY service')
        results.to_h { |row| [row[0].to_sym, row[1]] }
      end

      # Clear all events
      def clear!
        db.execute('DELETE FROM events')
      end

      # Close the database connection
      def close
        @db&.close
        @db = nil
      end

      private

      def db
        @db ||= begin
          SQLite3::Database.new(@db_path).tap do |database|
            database.results_as_hash = false
          end
        end
      end

      def ensure_database!
        # Ensure the directory exists
        FileUtils.mkdir_p(File.dirname(@db_path))

        # Create the events table if it doesn't exist
        db.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            service TEXT NOT NULL,
            event_type TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        SQL

        # Create indexes for common queries
        db.execute('CREATE INDEX IF NOT EXISTS idx_events_service ON events(service)')
        db.execute('CREATE INDEX IF NOT EXISTS idx_events_event_type ON events(event_type)')
        db.execute('CREATE INDEX IF NOT EXISTS idx_events_created_at ON events(created_at)')
      end
    end
  end
end
