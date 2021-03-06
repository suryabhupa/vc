require 'csv'
require 'open-uri'

module Importers::External
  class Investors < Importers::Base
    HEADER_DEFAULTS = {
      first_name: 'First Name',
      last_name: 'Last Name',
      full_name: 'Name',
      fund: 'Fund',
      email: 'Email',
      role: 'Position',
      industry: 'Industries',
      funding_size: 'Cheque Size',
    }

    def initialize(filename, headers, featured: false)
      @filename = url?(filename) ? save(filename) : filename
      @headers = headers.with_indifferent_access.slice(*HEADER_DEFAULTS.keys).reverse_merge(HEADER_DEFAULTS)
      @featured = featured
    end

    def process!(row)
      if row[:full_name].present?
        parts = row.delete(:full_name).split(' ')
        row[:first_name] ||= parts.first
        row[:last_name] ||= parts.drop(1).join(' ')
      end
      row[:email] = row[:email].try(:downcase)
      row[:role] = row[:role].try(:titleize)

      fund = row.delete(:fund)
      row[:competitor] = if row[:email].present?
        Competitor.create_from_domain!(row[:email].split('@').last)
      end || Competitor.create_from_name!(fund)

      row[:featured] = @featured
    end

    def import!(row)
      Rails.logger.info row
      investor = Investor.where(
        first_name: row.delete(:first_name),
        last_name: row.delete(:last_name),
        competitor: row.delete(:competitor)
      ).first_or_create!
      investor.update! row.select {|k,v| v.present? }
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.info e
    end

    def sync!
      ::CSV.foreach(@filename, headers: true) do |row|
        parsed = @headers.map { |h,s| [h, row[s].try(:strip)] }.to_h.compact.with_indifferent_access
        process! parsed
        import! parsed
      end
    end
  end
end
