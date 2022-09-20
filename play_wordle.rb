#!/usr/bin/ruby -w

require 'yaml'
require_relative 'constants'
require_relative 'wordle_core'
require_relative 'twitter'
require_relative 'fingerprints'
require_relative 'tests'

DICTIONARY_FILE = DICTIONARY_FILE_LARGE

VALID_WORDLE_WORDS = {}
def populate_valid_wordle_words(filename=VALID_WORDLE_WORDS_FILE)
  if !VALID_WORDLE_WORDS.key?(filename)
    VALID_WORDLE_WORDS[filename] = populate_valid_wordle_words_internal(filename)
    VALID_WORDLE_WORDS[filename].freeze
  end
  VALID_WORDLE_WORDS[filename]
end

def populate_valid_wordle_words_internal(filename)
  d = {}
  File.foreach(filename).with_index do |line, line_num|
    next if line.start_with?('#')
    d[line.chomp] = line_num
  end
  d
end

def populate_all_words
  d = {}
  File.foreach(DICTIONARY_FILE).with_index do |line, line_num|
    d[line.chomp] = line_num
  end
  ['pinot', 'ramen', 'apage', 'stear', 'stean', 'tased', 'tsade'].each { |word| d[word] = '-1' }
  d
end

# A note on "wordle words" that are not "words"
# I went here: https://github.com/dwyl/english-words, got words_alpha.txt,
# which _should_ be what I want. Transform and sort the data:
# cat words_alpha.txt | grep '^\([a-z]\{5\}\)[^a-z]$' | sed 's/^\(.....\).$/\1/' > words_alpha.txt.grep.sed
# copy valid-wordle-words.txt, remove comments, and sort: valid-wordle-words-words-only.txt.sort
# comm -13 words_alpha.txt.grep.sed.sort valid-wordle-words-words-only.txt.sort > non-word-valid-wordle-words.txt
# % head -n 5 non-word-valid-wordle-words.txt
# aapas
# aarti
# abacs
# abaht
# abaya
# Verified many of these are in valid-wordle-words but not in words_alpha
# % wc -l non-word-valid-wordle-words.txt
#     4228 non-word-valid-wordle-words.txt

module Alert
  def self.alert(s)
    puts "ALERT: #{s}" if !UI::suppress_all_output?
  end
  def self.warn(s)
    puts "WARN: #{s}" if !UI::suppress_all_output?
  end
end

module Debug
  LOG_LEVEL_NONE = 0
  LOG_LEVEL_TERSE = 1
  LOG_LEVEL_NORMAL = 2
  LOG_LEVEL_VERBOSE = 3

  THRESHOLD = LOG_LEVEL_NORMAL

  module Internal
    @@log_level_to_string = {
      LOG_LEVEL_NONE => 'none',
      LOG_LEVEL_TERSE => 'TERSE',
      LOG_LEVEL_NORMAL => 'NORMAL',
      LOG_LEVEL_VERBOSE => 'VERBOSE',
    }
    def Internal::println(s, log_level)
      puts s if log_level <= THRESHOLD && !UI::suppress_all_output?
    end
    def Internal::decorate(s, log_level)
      "debug(#{@@log_level_to_string[log_level]}): #{s}"
    end
    def Internal::decorate_and_print(s, log_level)
      Internal::println(Debug::Internal::decorate(s, log_level), log_level)
    end
  end

  def self.log_terse(s)
    Debug::Internal::decorate_and_print(s, LOG_LEVEL_TERSE)
  end
  def self.log(s)
    Debug::Internal::decorate_and_print(s, LOG_LEVEL_NORMAL)
  end
  def self.log_verbose(s)
    Debug::Internal::decorate_and_print(s, LOG_LEVEL_VERBOSE)
  end

  @@maybe_log = false

  def self.set_maybe(b)
    @@maybe_log = b
  end
  def self.maybe?
    @@maybe_log
  end
  def self.set_maybe_false
    @@maybe_log = false
  end
  def self.maybe_log_terse(s)
    Debug.log_terse s if @@maybe_log
  end
  def self.maybe_log(s)
    Debug.log s if @@maybe_log
  end
  def self.maybe_log_verbose(s)
    Debug.log_verbose s if @@maybe_log
  end
end

class String
  def pad_right_to_length(desired_length, termination_character: ' ')
    termination_character = ' ' if termination_character.length != 1
    self + ' ' * [(desired_length-self.length-1), 0].max + termination_character
  end
end

module UI
  @@suppress_all_output = false
  def UI::set_suppress_all_output(b)
    @@suppress_all_output = b
  end
  def UI::suppress_all_output?
    @@suppress_all_output
  end
  SUPPRESS_ALL_OUTPUT = false
  LEFT_PADDING_DEFAULT = 20

  def UI::padded_puts(s)
    print ' ' * LEFT_PADDING_DEFAULT if s.length > 0
    puts s
  end

  def UI::padded_print(s)
    print "#{' ' * LEFT_PADDING_DEFAULT}#{s}"
  end

  def UI::pad_right_deprecated(s, desired_length, termination_character: ' ')
    # use String.pad_right_to_length instead
    termination_character = ' ' if termination_character.length != 1
    s + ' ' * (desired_length-s.length-1) + termination_character
    # ' ' * 100
  end

  class UI::Stopwatch
    def initialize
      @time_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
    def lap
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - @time_start
    end
    def elapsed_time
      "elapsed_time: #{'%.1f' % lap} seconds"
    end
  end

  def self.prompt_for_input(input_string, prompt_on_new_line = true)
    if prompt_on_new_line
      padded_puts input_string
      padded_print '==> '
    else
      padded_print input_string
    end
    [gets.chomp].map{|user_input| exit if user_input == 'exit' || user_input == 'quit'; user_input}[0]
  end

  def self.main_menu(guess, d, show_menu: true)
    main_menu_array = [
      ' ----------------------------------------------------------.',
      '|                        Main Menu                         |',
      '|                                                          |',
      "|   You are on guess #{guess}/6. #{remaining_count_string(d)}",
      '|                                                          |',
      "|   Enter a guess, or 'help' for more commands             |",
      ' ----------------------------------------------------------/',
    ].map{|s| s.length<60 ? s.pad_right_to_length(60, termination_character: '|') : s}
    if show_menu
      puts ''
      main_menu_array.each{|s| padded_puts s}
    end
    UI.prompt_for_input(' ==> ', false)
  end

  def self.play(d)
    [
      '',
      '----------------------------------------------------------',
      '|                                                        |',
      '|                   Welcome to Wordle!                   |',
      '|                                                        |',
      '----------------------------------------------------------',
    ].each{|s| UI.padded_puts(s)}
    for guess in 1..6
      check_for_problematic_patterns(d) if guess >= 3
      show_main_menu = true
      while true do
        choice = UI.main_menu(guess, d, show_menu: show_main_menu)
        show_main_menu = false
        case choice
        when 'c'
          UI.print_remaining_count(d)
        when 'p', 'pa'
          UI.print_remaining_words(d, choice == 'p' ? 30 : nil)
        when 'hint'
          Commands::hint(d)
          show_main_menu = true
        when 'q'
          puts ''
          return
        when 'penultimate'
          Commands::penultimate(d)
          show_main_menu = true
        when 'twitter'
          query_result = Twitter::Query::regular
          query_result.print_report
          stats_hash = query_result.stats_hash
          UI.print_remaining_count(d)
          if UI.maybe_filter_twitter(d, stats_hash)
            UI.maybe_absence_of_evidence(d, stats_hash)
          end
          show_main_menu = true
        when 'test'
          dictionary_dot_com_level
        when 'dad'
          print_a_dad_joke
        when 'generate-fingerprints'
          puts 'Generating fingerprints takes a long time (~20 min).'
          puts 'Typically it is only necessary after re-scraping of NYT,'
          puts 'or if building support for a new fingerprint file.'
          if UI.prompt_for_input("Type 'I understand' to proceed ==> ", false) == 'I understand'
            Fingerprint::regenerate_compress_and_save('REPLACE_ME')
          else
            puts 'Fingerprint generation skipped'
          end
          show_main_menu = true
        when 'fingerprint-analysis'
          query_result = Twitter::Query::regular
          query_result.print_report
          stats_hash = query_result.stats_hash
          Fingerprint::fingerprint_analysis(d, stats_hash)
          show_main_menu = true
        when 'fingerprint-analysis --verbose'
          verbose_number = UI.prompt_for_input("Enter number to show in verbose mode: ==> ", false).to_i
          query_result = Twitter::Query::regular
          query_result.print_report
          stats_hash = query_result.stats_hash
          Fingerprint::fingerprint_analysis(d, stats_hash, verbose: verbose_number)
          show_main_menu = true
        when 'solver'
          full_solver(d)
          show_main_menu = true
        when 'give me the answer'
          give_me_the_answer(d)
        when 'performance'
          sw = UI::Stopwatch.new
          # time_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          # (0...100).each {|_| Filter::filter_4g(populate_all_words, 2, 1)}
          # (0...100).each {|_| Filter::filter_3g1y(populate_all_words, 1, 2)}
          # (0...100).each {|i| Filter::filter_3g2y(populate_all_words, 1, 2)}
          # (0...1).each {|_| Filter::filter_2g3y_v3(populate_all_words, 1, 2)}
          (0...5).each {|_| Filter::filter_2g3y_v2(populate_all_words, 1, 2); puts "#{i}: #{sw.elapsed_time}"}
          # (0...5).each {|i| Filter::filter_2g3y_v1(populate_all_words, 1, 2); puts "#{i}: #{sw.elapsed_time}"}
          # (0...5).each {|_| Filter::filter_1g4y(populate_all_words, 1); puts "#{i}: #{sw.elapsed_time}"}
          # (0...3).each {|_| Filter::filter_0g5y(populate_all_words); puts "#{i}: #{sw.elapsed_time}"}
          puts sw.elapsed_time
          show_main_menu = true
        when 'regression'
          regression_analysis(d)
          show_main_menu = true
        when 'goofball'
          goofball_analysis
        when 'help', 'h'
          UI.print_usage
        when '' # pressing enter shouldn't cause "unrecognized input"
        else
          if choice.length == 5
            response = UI.prompt_for_input('Enter the response (!?-): ==> ', false)
            Filter::filter(d, choice, response)
            break
          else
            Alert.alert "unrecognized input (#{choice})"
          end
        end
      end
    end
  end

  def self.maybe_absence_of_evidence(d, stats_hash)
    puts ''
    choice = UI.prompt_for_input('Would you like to make deductions based on absence of evidence? (y/n) ==> ', false)
    case choice
    when 'y'
      Commands::penultimate_twitter_absence_of_evidence(d, stats_hash)
    when 'n'
    else
      Alert.alert "unrecognized input (#{choice}), skipping"
    end
  end

  def self.filter_twitter(d, stats_hash)
    # Idea is to only filter on the max 4g seen
    max_4gs_seen = StatsHash.max_4gs(stats_hash)

    stats_hash.each do |key, _value|
      if Twitter::Configuration.instrumentation_only
        Debug.log "instrumentation_only mode, skipping penultimate_twitter() call for key #{key}..."
        next
      end
      key_array = key.split('.', 2)

      # doesn't make sense to filter first on 4g.3.1 if 4g.3.2 is coming next
      if key_array[0] == '4g'
        key_array2 = key_array[1].split('.')
        array_position = key_array2[0].to_i - 1
        count = key_array2[1].to_i
        if max_4gs_seen[array_position] != count
          UI::padded_puts "skipping filtering for key #{key} due to higher count still to come..."
          next
        end
      end

      Commands::penultimate_twitter(d, key_array[0], key_array[1])
      UI.print_remaining_count(d) # moving this here, to show filtering as it goes
    end
    d
  end

  def self.maybe_filter_twitter(d, stats_hash)
    choice = UI.prompt_for_input 'Would you like to proceed with filtering? (y/n)'
    case choice
    when 'y'
      choice2 = UI.prompt_for_input "There are #{d.size} words remaining. Would you like to see filtering output? (y/n)"
      previous_maybe = Debug.maybe?
      Debug.set_maybe(choice2 == 'y')

      filter_twitter(d, stats_hash)
    when 'n'
    else
      Alert.alert "unrecognized input (#{choice}), skipping"
    end
    Debug.set_maybe(previous_maybe)
    # caller needs to know whether filtering was done
    choice == 'y'
  end

  def self.print_remaining_words(d, max_print = nil)
    # route
    # pride (Alert! Wordle 30 answer!)
    # prize
    d.each_with_index do |(key, _value), index|
      break if max_print && index >= max_print
      if PreviousWordleSolutions.check_word(key)
        UI::padded_puts "#{key} (Alert! Wordle #{PreviousWordleSolutions.check_word(key)} answer!)"
      else
        UI::padded_puts key
      end
    end
    UI::padded_puts "skipping #{d.size-max_print} additional results..." if max_print && d.size > max_print
  end

  def self.print_usage
    [
      '',
      '.----------------------------------------------.',
      '|                                              |',
      '|                     Usage                    |',
      '|                                              |',
      '\----------------------------------------------/',
      'c               : count',
      'p               : print',
      'pa              : print all',
      'hint            : hint',
      'q               : quit',
      '',
      'penultimate     : run penultimate-style analysis',
      'twitter         : run Twitter analysis',
      '',
      'dad             : print a dad joke',
      'help, h         : print this message',
      '',
    ].each{|s| UI::padded_puts(s)}
  end

  def self.print_remaining_count(d)
    UI::padded_puts remaining_count_string d
  end

  def self.remaining_count_string(d)
    "There #{d.length==1?'is':'are'} #{d.size} word#{d.length==1?'':'s'} remaining."
  end

  def UI::goofball_analysis
    wordle_number = UI.prompt_for_input("Enter daily wordle number (to check for goofballs): ==> ", false)
    Twitter::Configuration.set_wordle_number_override wordle_number
    query_result = Twitter::Query::goofball
    stats_hash = query_result.stats_hash
    answers = query_result.answers
    wordle_number_solution = PreviousWordleSolutions.lookup_by_number(wordle_number.to_i)

    singleton_keys = []
    stats_hash.each do |key, value|
      # look for matching answer
      if value == 1
        answers.each do |answer|
          if answer.matches_key(key)
            singleton_keys.append([key, answer])
            break
          end
        end
      elsif value == 2 # disable this if it gets too chatty
        answers.each do |answer|
          if answer.matches_key(key)
            singleton_keys.append([key, answer])
          end
        end
      end
      if key == '4g.5.1' && false
        answers.each do |answer|
          if answer.matches_key(key)
            puts "(#{answer.tweet_url} (#{answer.author_id}))"
          end
        end
      end
    end

    [
      '',
      '',
      '',
      '/--------------------------------------\\',
      "|              Wordle #{wordle_number}              |",
      '|            Goofball report           |',
      '\--------------------------------------/',
      '',
    ].each{|s| UI::padded_puts(s)}

    answers_and_verdicts = [] # [answer, key, reasoning, verdict, title]

    singleton_keys.each do |el|
      key = el[0]
      answer = el[1]
      penultimate = answer.penultimate
      interestingness = InterestingWordleResponses::determine_interestingness(penultimate)
      name, subname, _key = InterestingWordleResponses::calculate_name_subname_key(penultimate, interestingness)
      count = name == '4g' ? key[5].to_i : 0
      all_words = populate_valid_wordle_words
      if interestingness == InterestingWordleResponses::WORDLE_4G
        # special handling for 4g: Find actual high-water-mark, see if the reported
        # count is reasonable. Will need to know the words too.
        gray_index = subname[0].to_i - 1
        valid_alternatives = ALPHABET
          .map{|c| Filter::replace_ith_letter(wordle_number_solution, gray_index, c)}
          .delete_if {|word_to_check| word_to_check == wordle_number_solution || !all_words.key?(word_to_check)}
        is_goofball = (count > valid_alternatives.length)

        if is_goofball
          title = valid_alternatives.length == 0 ? 'Definite Goofball!' : 'Possible Goofball'
        else
          title = 'Not a Goofball'
        end
      else
        # Everything besides 4g: Go through all available words, see what words get that match.
        # In principle, this is very similar to Filter::filter_4g et al.
        # have: wordle_number_solution, penultimate
        # puts "non-4g analysis: wordle_number_solution=#{wordle_number_solution}, penultimate=#{penultimate}"
        valid_alternatives = []
        all_words.each do |key, _value|
          actual_wordle_response = wordle_response(key, wordle_number_solution)
          if actual_wordle_response == penultimate
            valid_alternatives.append key
          end
        end
        is_goofball = valid_alternatives.length == 0
        title = is_goofball ? 'Definite Goofball!' : 'Not a Goofball'
      end

      reasoning = "(#{valid_alternatives.join('/')})"
      verdict = is_goofball ? 'deny' : 'allow'

      answers_and_verdicts.append(
        [answer, key, reasoning, verdict, title]
      )

    end

    print_goofball_report_entry = ->(answer, key, reasoning, verdict, title) {
      nm = wordle_number
      sn = wordle_number_solution
      aid = answer.author_id

      # Goofball report
      puts "Author ID #{aid} already in denylist" if Twitter::Configuration.author_id_denylist.include?(aid)
      puts "Author ID #{aid} already in allowlist" if Twitter::Configuration.author_id_allowlist.include?(aid)
      puts "- name: #{answer.username}"
      puts "  author_id: #{aid}"
      puts "  tweet: #{answer.tweet_url}"
      puts "  analysis: Wordle #{nm} (#{sn}), #{key}, #{reasoning}"
      puts "  verdict: #{verdict} # #{title}"
      puts ''
    }

    check_lists = ->(author_id) {
      Twitter::Configuration.author_id_denylist.include?(author_id) \
      || Twitter::Configuration.author_id_allowlist.include?(author_id)
    }

    num_suppressed = 0
    answers_and_verdicts
      .map{|el| num_suppressed += 1 if check_lists.call(el[0].author_id); el}
      .delete_if{|el| check_lists.call(el[0].author_id)}
      .each{|el| print_goofball_report_entry.call(el[0], el[1], el[2], el[3], el[4])}

    if num_suppressed > 0
      if 'show' == UI::prompt_for_input("#{num_suppressed} entries suppressed ('show' to display) ==> ", false)
        puts ''
        answers_and_verdicts
          .map{|el| el} # make a copy
          .delete_if{|el| !check_lists.call(el[0].author_id)}
          .each{|el| print_goofball_report_entry.call(el[0], el[1], el[2], el[3], el[4])}
      end
    end

    puts ''
    puts 'Exiting because wordle_number_override was set manually...'
    puts ''
    puts '##################################################'
    exit
  end

  # NYT w/ singles     : always has a result
  # Dracos w/ singles  : might not
  # NYT w/o singles    : always has a result (but might be worse)
  # Dracos w/o singles : might not have a result
  # - If NYT top choice isn't very high, could be because the fingerprint is "too big"
  #   - This is the point of the Dracos result with singletons
  # - If NYT top choice isn't very high, could be because of a bad result
  #   - This is the point of querying with singletons removed
  #
  # 1. Run query with singletons
  #    1.1 If NYT top choice is high enough, that's the answer.
  #    1.2 If NYT top choice is not high enough but dracos is, that's the answer.
  # 2. If neither was high enough, and if there are singletons to remove, re-run w/o singletons
  #    2.1 If NYT top choice is high enough, that's the answer.
  #    2.2 If NYT top choice is not high enough but dracos is, that's the answer.
  # 3. If none of this ^^^ works, pick the one with the highest score.
  def UI::give_me_the_answer(d)
    UI::set_suppress_all_output(true)
    results = {:with_singletons => {}, :without_singletons => {}}
    # populate above lists with N elements
    list_length = 2
    threshold = 60.0
    print_a_winner = ->(word) { puts "\n\n"; UI::padded_puts("The answer is #{word}."); puts "\n\n"; exit }

    stats_hash1 = Twitter::Query::regular_with_singletons.stats_hash
    analysis_1 = Fingerprint::fingerprint_analysis(d, stats_hash1, suppress_output: true, dracos_override: true)
    results[:with_singletons][:nyt] =
      analysis_1[:d_nyt].map{|word, data| {:word => word, :score => data[:nyt_score]}}[0..list_length-1]
    results[:with_singletons][:dracos] =
      analysis_1[:d_dracos].map{|word, data| {:word => word, :score => data[:dracos_score]}}[0..list_length-1]

    # first choice: NYT with singletons is high enough
    print_a_winner.call(
      results[:with_singletons][:nyt][0][:word]) if results[:with_singletons][:nyt][0][:score] > threshold

    # if dracos is high enough but NYT isn't, the NYT fingerprint was "too big" (and Dracos shines!)
    print_a_winner.call(
      results[:with_singletons][:dracos][0][:word]) if results[:with_singletons][:dracos][0][:score] > threshold

    # if re-running wouldn't help, and there is no clear winner, pick the highest one
    print_a_winner.call(
      [
        [results[:with_singletons][:nyt][0][:word], results[:with_singletons][:nyt][0][:score]],
        [results[:with_singletons][:dracos][0][:word], results[:with_singletons][:dracos][0][:score]],
      ].max_by{|_word, score| score}[0]
    ) if StatsHash.num_singletons(stats_hash1) == 0

    stats_hash2 = Twitter::Query::regular.stats_hash
    analysis_2 = Fingerprint::fingerprint_analysis(d, stats_hash2, suppress_output: true, dracos_override: true)
    results[:without_singletons][:nyt] =
      analysis_2[:d_nyt].map{|word, data| {:word => word, :score => data[:nyt_score]}}[0..list_length-1]
    results[:without_singletons][:dracos] =
      analysis_2[:d_dracos].map{|word, data| {:word => word, :score => data[:dracos_score]}}[0..list_length-1]
    puts results

    # NYT
    print_a_winner.call(
      results[:without_singletons][:nyt][0][:word]) if results[:without_singletons][:nyt][0][:score] > threshold

    # Dracos
    print_a_winner.call(
      results[:without_singletons][:dracos][0][:word]) if results[:without_singletons][:dracos][0][:score] > threshold

    # nothing was high enough (sigh!) - pick the highest one
    print_a_winner.call(
      [
        [results[:with_singletons][:nyt][0][:word], results[:with_singletons][:nyt][0][:score]],
        [results[:with_singletons][:dracos][0][:word], results[:with_singletons][:dracos][0][:score]],
        [results[:without_singletons][:nyt][0][:word], results[:without_singletons][:nyt][0][:score]],
        [results[:without_singletons][:dracos][0][:word], results[:without_singletons][:dracos][0][:score]],
      ].max_by{|_word, score| score}[0]
    )
  end

  def UI::full_solver(d)
    # TODO add some intelligence to this, so it only returns a single word
    # - account for plurals
    # - possible to grade levels of words (based on dictionary dot com?)
    # - when finished, measure it (without modifying allow or denylists)
    # Only then can it start to be measured
    max_to_print = [UI.prompt_for_input('Enter max to print (default 10): ==> ', false)]
      .map{|user_input| user_input!='' && user_input==user_input.to_i.to_s ? user_input.to_i : 10}[0]
    verbose = [UI.prompt_for_input('Enter number to print verbose (default 0): ==> ', false)]
      .map{|user_input| user_input!='' && user_input==user_input.to_i.to_s ? user_input.to_i : 0}[0]

    query1 = Twitter::Query::regular_with_singletons
    stats_hash1 = query1.stats_hash
    analysis_1 =
      Fingerprint::fingerprint_analysis(d, stats_hash1, max_to_print: max_to_print, verbose: verbose)[:d_nyt]
    max_score_analysis_1 = analysis_1.max_by{|word, data_hash| data_hash[:nyt_score]}[1][:nyt_score]

    if max_score_analysis_1 < 60
      puts ''
      UI::padded_puts(
        "****** Query with singletons produced a max score of only #{'%.1f' % max_score_analysis_1}!")
      puts ''
      puts ''
    end

    num_singletons = StatsHash.num_singletons(stats_hash1)
    proceed = UI.prompt_for_input(
      "Re-run with singleton filtering on? (#{num_singletons} singletons) ('y' to proceed) ==> ", false
    ) == 'y'
    if proceed
      query2 = Twitter::Query::regular
      stats_hash2 = query2.stats_hash
      Fingerprint::fingerprint_analysis(d, stats_hash2, max_to_print: max_to_print, verbose: verbose)
    end
  end

  def UI::regression_analysis(d)
    six_days_ago = (today_wordle_number.to_i - 6).to_s
    range = "(#{six_days_ago}-#{today_wordle_number})"
    wordle_number = UI.prompt_for_input("Enter daily wordle number for regression #{range}:==> ", false)
    exit if wordle_number.to_i.to_s != wordle_number
    Twitter::Configuration.set_wordle_number_override wordle_number

    query_result = Twitter::Query::regular
    stats_hash = query_result.stats_hash
    a = filter_twitter(d.dup, stats_hash).keys
    b = Fingerprint::fingerprint_analysis(
      d.dup, stats_hash, suppress_output: true, dracos_override: false)[:d_nyt].keys

    [
      '',
      '/------------------------------------------------------\\',
      "|        Regression analysis report (Wordle #{wordle_number})       |",
      '\------------------------------------------------------/',
      '',
      "length comparison: #{a.length == b.length ? 'OK' : 'FAIL'}",
      "remaining word comparison: #{(a.size == b.size && a&b==a) ? 'OK' : 'FAIL'}",
      '',
      'Exiting because wordle_number_override was set manually...',
      '',
    ].each{|s| UI::padded_puts s}

    exit
  end
end

module Commands
  def Commands::penultimate_twitter_absence_of_evidence(d, stats_hash)
    UI::padded_puts 'Absence of evidence is not evidence of absence!'

    # 4g-based analysis
    # sample entry in stash_hash: key=4g.3.1, value=7
    # Translation: The 3rd letter was white one time, for seven people
    # Plan
    #   1. Normalize the knowledge in stats_hash
    #   2. For remaining words in d, find how many matching words there are in valid-wordle-words.txt
    #   3. Do a text-based comparison (for now)

    # get max 4gs seen
    max_4gs_seen = StatsHash.max_4gs stats_hash

    # calculate how many actual 4g matches there are per key
    # key=laved, all_4g_matches=[6, 2, 10, 0, 2]
    # defined distances between ith all-4g-matches and possible observed Twitter values
    # Question: it is possible to see more matches on Twitter than mag-4gs if using
    #           a smaller dictionary (like dracos)
    # Answer: The scoring should _always_ use NYT when eliminating words,
    #         but could change it up when doing the subsequent scoring
    new_d = {}
    d.each do |word, _value|
      matches = all_4g_matches(word, Twitter::Configuration.absence_of_evidence_filename)
      difference = [0, 0, 0, 0, 0]
      (0...5).each {|i| difference[i] = Fingerprint::Distance::individual_distance(matches[i], max_4gs_seen[i])}
      new_d[word] = [difference.sum, difference, matches, max_4gs_seen]
    end
    new_d = new_d.sort_by {|_, value| value[0]}.to_h

    puts ''
    UI::padded_puts '/------------------------------------------------------\\'
    UI::padded_puts "|              Absence of Evidence report              |"
    UI::padded_puts '\------------------------------------------------------/'
    UI::padded_puts ''
    UI::padded_puts "max 4gs seen on Twitter: #{max_4gs_seen}"
    puts ''

    page_size = 10
    absence_of_evidence_string = ->(key, value, maybe_alert) {
      maybe_word_details = Debug::THRESHOLD >= Debug::LOG_LEVEL_VERBOSE ? " (#{value[2]})" : ''
      "#{key} has a distance of #{'%.1f' % value[0]}#{maybe_word_details}#{maybe_alert}"
    }
    (0...10).each do |page_number|
      break if (page_number * page_size) > new_d.length
      new_d.each_with_index do |(word, value), index|
        next if index < page_number * page_size
        break if index >= (page_number+1) * page_size
        maybe_alert = PreviousWordleSolutions.maybe_alert_string(word)
        UI::padded_puts absence_of_evidence_string.call(word, value, maybe_alert)
      end
      while true do
        more = [0, new_d.length - ((page_number+1) * page_size)].max
        user_input = UI.prompt_for_input("Enter a word to see its score, 'next', or (q)uit (#{more} more): ==> ", false)
        break if (user_input == 'q' || user_input == 'next')
        if new_d.key?(user_input)
          UI::padded_puts(absence_of_evidence_string.call(
            user_input,
            new_d[user_input],
            PreviousWordleSolutions.maybe_alert_string(user_input)))
        end
      end
      break if user_input == 'q'
    end

    puts ''
    UI::padded_puts 'Exiting absence-of-evidence...'
    puts ''
  end

  def Commands::penultimate_twitter(d, pattern, subpattern)
    UI::padded_puts "penultimate_twitter called, pattern=#{pattern}, subpattern=#{subpattern}"
    case pattern
    when '4g' # 4g.3.2 = 8
      subpattern_array = subpattern.split('.')
      raise 'Error: unexpected length (4g subpattern)' if subpattern_array.length() != 2
      gray = subpattern_array[0].to_i - 1
      count = subpattern_array[1].to_i
      Filter::filter_4g(d, gray, count)
    when '3g1y' # 3g1y.yellow3.white4 = 3
      subpattern_array = subpattern.split('.')
      raise 'unexpected length (3g1y subpattern)' if subpattern_array.length() != 2
      yellow = subpattern_array[0][6].to_i - 1
      gray = subpattern_array[1][5].to_i - 1
      Filter::filter_3g1y(d, yellow, gray)
    when '3g2y' # 3g2y.yellow24
      yellow1 = subpattern[6].to_i - 1
      yellow2 = subpattern[7].to_i - 1
      Filter::filter_3g2y(d, yellow1, yellow2)
    when '2g3y' # 2g3y.green24
      green1 = subpattern[5].to_i - 1
      green2 = subpattern[6].to_i - 1
      Filter::filter_2g3y(d, green1, green2)
    when '1g4y' # 1g4y.green3
      green = subpattern[5].to_i - 1
      Filter::filter_1g4y(d, green)
    when '0g5y' # 0g5y.
      Filter::filter_0g5y(d)
    else
      UI::padded_puts "#{pattern} not yet supported"
    end
  end

  def Commands::penultimate(d)
    UI::padded_puts 'Choose a Twitter penultimate guess'
    UI::padded_puts '4 greens (4g)'
    UI::padded_puts '3 greens and 1 yellow (3g1y)'
    UI::padded_puts '3 greens and 2 yellows (3g2y)'
    UI::padded_puts '2 greens and 3 yellows (2g3y)'
    UI::padded_puts '1 green and 4 yellows (1g4y)'
    UI::padded_puts '0 greens and 5 yellows (0g5y)'
    choice = UI.prompt_for_input('==> ', false)
    case choice
    when '4g'
      gray = UI.prompt_for_input('Enter the position of the gray (1-5): ==> ', false).to_i - 1
      count = UI.prompt_for_input('Enter the count: ==> ', false).to_i
      Filter::filter_4g(d, gray, count)
    when '3g1y'
      yellow = UI.prompt_for_input('Enter the position of the yellow (1-5): ==> ', false).to_i - 1
      gray = UI.prompt_for_input('Enter the position of the gray (1-5): ==> ', false).to_i - 1
      Filter::filter_3g1y(d, yellow, gray)
    when '3g2y'
      yellows = UI.prompt_for_input('Enter the positions of the two yellows (1-5): ==> ', false)
      yellow1 = yellows[0].to_i - 1
      yellow2 = yellows[1].to_i - 1
      Filter::filter_3g2y(d, yellow1, yellow2)
    when '2g3y'
      greens = UI.prompt_for_input('Enter the positions of the two greens (1-5): ==> ', false)
      green1 = greens[0].to_i - 1
      green2 = greens[1].to_i - 1
      Filter::filter_2g3y(d, green1, green2)
    when '1g4y'
      green = UI.prompt_for_input('Enter the position of the green (1-5): ==> ', false).to_i - 1
      Filter::filter_1g4y(d, green)
    when '0g5y'
      Filter::filter_0g5y(d)
    end
  end

  def Commands::hint(d)
    UI::padded_puts "remaining: #{d.size}"

    # letter_usage stores, for each letter, the number of remaining words with that letter
    letter_usage = {}
    (97..122).each { |c| letter_usage[c.chr] = 0 }
    d.each {|word, line_num| letter_usage.each {|c, num_so_far| letter_usage[c] = num_so_far + 1 if word[c] } }

    # top_n_dict will contain the top N keys from letter_usage, by count
    top_n = 3
    top_n_dict = {}
    for _i in 0...top_n
      next_largest = letter_usage.max_by{|k,v| (v==d.size||top_n_dict.has_key?(k)) ? 0 : v}
      top_n_dict[next_largest[0]]=next_largest[1]
    end
    UI::padded_puts top_n_dict

    # for all remaining words, they are a great guess if all of the "top N" characters are contained
    # and they are a "good" guess if all but one of the top N characters occur
    d.each do |word, line_num|
      count = 0
      top_n_dict.each {|c, num_occurrences| count = count + 1 if word[c]}
      UI::padded_puts "#{word} is a GREAT guess" if count == top_n
      UI::padded_puts "#{word} is a good guess" if count == (top_n - 1)
    end
  end
end

Tests::run_tests
d = populate_all_words
UI.play(d)
