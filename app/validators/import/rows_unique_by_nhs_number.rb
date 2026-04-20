# frozen_string_literal: true

module Import
  class RowsUniqueByNHSNumber < ActiveModel::Validator
    def validate(record)
      check_rows(record)
      add_row_errors_to_record(record)
    end

    private

    def check_rows(record)
      record
        .rows
        .map(&:nhs_number_value)
        .tally
        .each do |nhs_number, count|
          next if nhs_number.nil? || count <= 1

          record
            .rows
            .select { _1.nhs_number_value == nhs_number }
            .each do |row|
              row.errors.add(
                :base,
                "The same NHS number appears multiple times in this file."
              )
            end
        end
    end

    def add_row_errors_to_record(record)
      row_offset = record.csv_data_object.has_instruction_row? ? 3 : 2

      record.rows.each.with_index do |row, index|
        next if row.errors.empty?

        # The first row is the header and the index is 0-based, so we add two
        # to match what the user sees in the spreadsheet

        formatted_errors =
          row.errors.map do |error|
            if error.attribute == :base
              error.message
            else
              "<code>#{error.attribute}</code>: #{error.message}"
            end
          end

        record.errors.add("row_#{index + row_offset}".to_sym, formatted_errors)
      end
    end
  end
end
