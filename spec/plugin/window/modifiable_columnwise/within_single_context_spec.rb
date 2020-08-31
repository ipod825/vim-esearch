# frozen_string_literal: true

require 'spec_helper'

describe 'Modify linewise', :window do
  include Helpers::FileSystem
  include VimlValue::SerializationHelpers
  include Helpers::Modifiable
  include Helpers::Modifiable::Linewise
  include Helpers::Modifiable::Columnwise

  include_context 'setup modifiable testing'

  shared_examples 'name -> entry' do |from:, to:|
    include_context 'setup columnwise testing', from, to

    shared_examples 'it modifies entries using anchors' do |anchor1, anchor2|
      shared_examples 'modify in mode' do |motion|
        it "modifies entry text before #{anchor2} and entries above" do
          locate_anchor(from, anchor1)

          expect { motion.call(anchor_char(anchor2, to)) }
            .to change { output.reload(entry2).line_content }
            .to(entry2.line_number_text + entry2.text_after(anchor2))
            .and not_to_change { output.reloaded_entries!(unaffected_entries).map(&:line_content) }

          expect(output).to have_entries(entries).except(affected_entries[...-1])
        end
      end

      describe 'delete' do
        include_examples 'modify in mode', ->(anchor) { editor.send_keys_separately "df#{anchor}" }
        include_examples 'modify in mode', ->(anchor) { editor.send_keys_separately "vf#{anchor}x" }
      end

      describe 'change' do
        let(:expected_location) { [entry2.line_in_window, entry2.line_number_text.length + 1] }
        after { expect(editor.location).to eq(expected_location) }

        include_examples 'modify in mode', ->(anchor) { editor.send_keys_separately "cf#{anchor}" }
        include_examples 'modify in mode', ->(anchor) { editor.send_keys_separately "vf#{anchor}c" }
      end
    end

    it_behaves_like 'it modifies entries using anchors', :begin,  :begin
    it_behaves_like 'it modifies entries using anchors', :begin,  :middle
    it_behaves_like 'it modifies entries using anchors', :middle, :middle
    it_behaves_like 'it modifies entries using anchors', :end,    :middle
  end

  shared_examples 'ctx1.entry1 -> ctx1.entry2' do |from:, to:|
    include_context 'setup columnwise testing', from, to

    context 'when deleting from ctx entry to another ctx entry' do
      shared_examples 'it modifies entries using anchors' do |anchor1, anchor2|
        let(:anchor2_char) { anchor_char(anchor2, to) }
        let(:joined_text) do
          [entry1.line_number_text,
           entry1.text_before(anchor1),
           entry2.text_after(anchor2),].join
        end

        shared_examples 'modify in mode' do |motion|
          it 'modifies entries between and merges texts' do
            locate_anchor(from, anchor1)

            expect { motion.call(anchor2_char) }
              .to change { output.reload(entry1).line_content }
              .to(joined_text)
              .and not_to_change { output.reloaded_entries!(unaffected_entries).map(&:line_content) }

            expect(output).to have_entries(entries).except(affected_entries[1..])
          end
        end

        describe 'delete' do
          include_examples 'modify in mode', ->(anchor) { editor.send_keys_separately "df#{anchor}" }
          include_examples 'modify in mode', ->(anchor) { editor.send_keys_separately "vf#{anchor}x" }
        end

        describe 'change' do
          let(:expected_location) { [entry1.line_in_window, entry1.anchor_column(anchor1)] }
          after { expect(editor.location).to eq(expected_location) }

          include_examples 'modify in mode', ->(anchor) { editor.send_keys_separately "cf#{anchor}" }
          include_examples 'modify in mode', ->(anchor) { editor.send_keys_separately "vf#{anchor}c" }
        end
      end

      it_behaves_like 'it modifies entries using anchors', :begin,  :begin
      it_behaves_like 'it modifies entries using anchors', :begin,  :middle
      it_behaves_like 'it modifies entries using anchors', :middle, :middle
      it_behaves_like 'it modifies entries using anchors', :end,    :middle

      context 'when begin and end are within LineNr' do
        let(:columns_testing_matrix) do
          1.upto(entry1.line_number_text.length - 1) .to_a
           .product(1.upto(entry2.line_number_text.length - 1).to_a)
           .sample(4)
        end

        it 'removes entries between and sets entry1.content := entry2.content' do
          columns_testing_matrix.each do |column1, column2|
            editor.locate_cursor! entry1.line_in_window, column1
            editor.send_keys_separately 'v'
            editor.locate_cursor! entry2.line_in_window, column2

            expect { editor.send_keys 'x' }
              .to change { output.reload(entry1).line_content }
              .to(entry1.line_number_text + entry2.content)
            expect(output)
              .to have_entries(entries)
              .except(ctx1.entries[from_entry + 1...to_entry + 1])

            editor.command 'undo 0'
          end
        end
      end
    end
  end

  context 'when within a context' do
    context 'when ctx1.name -> ctx1.entry' do
      it_behaves_like 'name -> entry', from: {ctx: 0, ui: :name}, to: {ctx: 0, entry: 0}
      it_behaves_like 'name -> entry', from: {ctx: 0, ui: :name}, to: {ctx: 0, entry: 1}
      it_behaves_like 'name -> entry', from: {ctx: 0, ui: :name}, to: {ctx: 0, entry: -1}

      it_behaves_like 'name -> entry', from: {ctx: 1, ui: :name}, to: {ctx: 1, entry: 0}
      it_behaves_like 'name -> entry', from: {ctx: 1, ui: :name}, to: {ctx: 1, entry: 1}
      it_behaves_like 'name -> entry', from: {ctx: 1, ui: :name}, to: {ctx: 1, entry: -1}

      it_behaves_like 'name -> entry', from: {ctx: -1, ui: :name}, to: {ctx: -1, entry: 0}
      it_behaves_like 'name -> entry', from: {ctx: -1, ui: :name}, to: {ctx: -1, entry: 1}
      it_behaves_like 'name -> entry', from: {ctx: -1, ui: :name}, to: {ctx: -1, entry: -1}
    end

    context 'when ctx1.entry1 -> ctx1.entry2' do
      it_behaves_like 'ctx1.entry1 -> ctx1.entry2', from: {ctx: 0,  entry: 0}, to: {ctx: 0,  entry: 1}
      it_behaves_like 'ctx1.entry1 -> ctx1.entry2', from: {ctx: 0,  entry: 1}, to: {ctx: 0,  entry: 2}
      it_behaves_like 'ctx1.entry1 -> ctx1.entry2', from: {ctx: 0,  entry: 1}, to: {ctx: 0,  entry: -1}

      it_behaves_like 'ctx1.entry1 -> ctx1.entry2', from: {ctx: 1,  entry: 0}, to: {ctx: 1,  entry: 1}
      it_behaves_like 'ctx1.entry1 -> ctx1.entry2', from: {ctx: 1,  entry: 1}, to: {ctx: 1,  entry: 2}
      it_behaves_like 'ctx1.entry1 -> ctx1.entry2', from: {ctx: 1,  entry: 1}, to: {ctx: 1,  entry: -1}

      it_behaves_like 'ctx1.entry1 -> ctx1.entry2', from: {ctx: -1, entry: 0}, to: {ctx: -1, entry: 1}
      it_behaves_like 'ctx1.entry1 -> ctx1.entry2', from: {ctx: -1, entry: 1}, to: {ctx: -1, entry: 2}
      it_behaves_like 'ctx1.entry1 -> ctx1.entry2', from: {ctx: -1, entry: 1}, to: {ctx: -1, entry: -1}
    end
  end
end