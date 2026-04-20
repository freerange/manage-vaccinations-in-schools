# frozen_string_literal: true

module Import
  class RowsUniqueAcrossAllImmunisationAttributesValidator < ActiveModel::Validator
    def validate(record)
      check_rows(record)
      add_row_errors_to_record(record)
    end

    private

    def check_rows(record)
      row_offset = record.csv_data_object.has_instruction_row? ? 3 : 2

      record
        .rows
        .map(&:full_row_deduplication_attributes)
        .tally
        .each do |full_row_deduplication_attributes, count|
          next if count <= 1

          matching_rows =
            record.rows.each_with_index.select do |row, _index|
              row.full_row_deduplication_attributes ==
                full_row_deduplication_attributes
            end
          matching_rows = matching_rows.to_h

          matching_rows.each_key do |row|
            other_row_numbers =
              matching_rows
                .reject { |other_row, _| other_row.equal?(row) }
                .map { |_, other_index| other_index + row_offset }

            other_rows_text =
              "#{"row".pluralize(other_row_numbers.size)} #{other_row_numbers.to_sentence(last_word_connector: " and ")}"

            row.errors.add(
              :base,
              "The record on this row appears to be a duplicate of #{other_rows_text}."
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
