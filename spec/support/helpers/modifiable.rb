# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module Helpers::Modifiable
  extend RSpec::Matchers::DSL

  Context = Struct.new(:name, :content) do
    def line_numbers
      @line_numbers ||= 1.upto(content.length).to_a
    end

    def entries
      line_numbers.map do |line_number|
        esearch.output.find_entry(name, line_number)
      rescue API::ESearch::Window::MissingEntryError
        nil
      end
    end
  end

  def editor_lines_except(line)
    editor.lines(..line - 1).to_a +
      editor.lines(line + 1..).to_a
  end

  define_negated_matcher :not_to_change, :change

  shared_context 'delete everything up until' do |line_above:, context_index:|
    let(:i) { context_index }

    include_context 'setup modifiable testing'

    context 'entries 0..1' do
      shared_examples 'removes entries' do |motion|
        it 'removes entries 0..1' do
          contexts[i].entries[1].locate!
          motion.call(line_above)

          expect(output)
            .to  have_missing_entries(contexts[...i].map(&:entries).flatten)
            .and have_missing_entries(contexts[i].entries[..1])
            .and have_valid_entries(contexts[i].entries[2..])
            .and have_valid_entries((contexts - contexts[..i]).map(&:entries).flatten)
        end
      end

      include_examples 'removes entries', ->(line) { editor.send_keys "V#{line}ggd" }
      include_examples 'removes entries', ->(line) { editor.send_keys "d#{line}gg" }
    end

    context 'entries 0..2' do
      shared_examples 'removes entries' do |motion|
        it 'removes entries 0..2' do
          contexts[i].entries[2].locate!
          motion.call(line_above)

          expect(output)
            .to  have_missing_entries(contexts[...i].map(&:entries).flatten)
            .and have_missing_entries(contexts[i].entries[..2])
            .and have_valid_entries(contexts[i].entries[3..])
            .and have_valid_entries((contexts - contexts[..i]).map(&:entries).flatten)
        end
      end

      include_examples 'removes entries', ->(line) { editor.send_keys "V#{line}ggd" }
      include_examples 'removes entries', ->(line) { editor.send_keys "d#{line}gg" }
    end

    context 'entries 0..-1' do
      shared_examples 'removes entries' do |motion|
        it 'removes entries 0..-1' do
          contexts[i].entries[-1].locate!
          motion.call(line_above)

          expect(output)
            .to  have_missing_entries(contexts[..i].map(&:entries).flatten)
            .and have_valid_entries((contexts - contexts[..i]).map(&:entries).flatten)
        end
      end

      include_examples 'removes entries', ->(line) { editor.send_keys "V#{line}ggd" }
      include_examples 'removes entries', ->(line) { editor.send_keys "d#{line}gg" }
    end
  end

  shared_examples "doesn't have effect after motion" do |motion|
    it 'removes entries 0..-1' do
      entry.locate!
      expect { instance_exec(&motion) }
        .not_to change { editor.lines.to_a }
    end
  end

  shared_context 'setup modifiable testing' do
    let(:contexts) do
      [Context.new('context1.txt', 1.upto(5).map { |i| "aa#{i}" }),
       Context.new('context2.txt', 1.upto(5).map { |i| "bb#{i}" }),
       Context.new('context3.txt', 1.upto(5).map { |i| "cc#{i}" })]
    end
    let(:sample_context) { contexts.sample }
    let(:sample_line_number) { sample_context.line_numbers.sample }
    let(:entry) { output.find_entry(sample_context.name, sample_line_number) }
    let(:line_number_text) { entry.line_number_text }
    let(:files) { contexts.map { |c| file(c.content, c.name) } }
    let!(:test_directory) { directory(files).persist! }
    let(:entries) { contexts.map(&:entries).flatten }
    let(:output) { esearch.output }

    before do
      esearch.configure!(adapter: 'ag', out: 'win', backend: 'system', regex: 1, use: [])
      editor.command! <<~SETUP
        let g:esearch#adapter#ag#bin = '#{Configuration.root}/spec/support/scripts/sort_search_results.sh ag'
        let g:esearch_win_disable_context_highlights_on_files_count = 0
        set backspace=indent,eol,start
        cd #{test_directory}
        call esearch#init({'exp': {'pcre': '^'}})
        call esearch#out#win#edit()
        call feedkeys("\\<C-\\>\\<C-n>")
      SETUP
    end

    after do
      editor.command <<~TEARDOWN
        let g:esearch_win_disable_context_highlights_on_files_count = 100
      TEARDOWN

      messages = Debug.messages.join
      errors = editor.echo(var('v:errors'))
      lines = editor.lines

      expect(messages).not_to include('Error')
      expect(errors).to be_empty

      # TODO: extract this logic to the parser
      if esearch.output.inside_search_window?
        expect(lines.first).to match(API::ESearch::Window::HeaderParser::HEADER_REGEXP)
        expect(lines.to_a[1]).to be_blank
        expect(lines.to_a.last).not_to be_blank if lines.to_a.count > 2
      end
      editor.cleanup!
    end
  end

  # Isn't good from SRP perspective, but good enough in terms of natural way of
  # thinking abount verification of present and missing elements. So instead of
  # checking:
  # all_entries == (entries - other_entries) &&
  #   (entries - other_entries).all?(:present?) &&
  #   other_entries.all?(&:emtpy?)
  # we have a single matcher have_entries(entries).except(other_entries)
  # Could be splitted into 3 matchers if it'd be possible to combine other
  # matchers within a custom one without hacks.
  matcher :have_entries do |entries|
    match do
      @except ||= []
      @expected = esearch.output.reloaded_entries!(entries - @except)
      @actual = esearch.output.entries.to_a
      @except = esearch.output.reloaded_entries!(@except)

      @expected_present = @expected.all?(&:present?)
      return false unless @expected_present

      @actual_matches_expected = @actual == @expected
      return false unless @actual_matches_expected

      @except_missing = @except.all?(&:blank?)
      return false unless @except_missing

      true
    end

    chain :except do |except|
      @except = except
    end

    failure_message do
      if !@except_missing
        "expected #{@except.inspect} to be missing"
      elsif !@actual_matches_expected
        "expected to have entries #{@expected.inspect}, got #{@actual.inspect}"
      else
        "expected #{@expected.inspect} to be present"
      end
    end
  end

  matcher :have_valid_entries do |entries|
    match do
      @actual = esearch.output.reloaded_entries!(entries)
      @actual.all?(&:present?)
    end

    failure_message do
      "expected to have valid entries, got #{@actual.inspect}"
    end
  end

  matcher :have_missing_entries do |entries|
    attr_reader :expected

    match do
      @actual = esearch.output.reloaded_entries!(entries)
      @actual.all?(&:blank?)
    end

    failure_message do
      "expected to have missing entries, got #{@actual.inspect}"
    end
  end
end
# rubocop:enable Metrics/ModuleLength