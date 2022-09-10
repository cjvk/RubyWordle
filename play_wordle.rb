#!/usr/bin/ruby -w

#   1. test
#   2. raise (-!--- response), twitter, filtering, absence-of-evidence
#   3. goofball 444

#      - ... and then do scoring
# TODO enable scoring on a per-dictionary basis?
# TODO performance test for the 3g1y filter function (create Timer class too?)
# TODO rank stats_hash based on speed of filtering function
# TODO consider allowing potential goofballs, but discarding and
#      re-running if there are no solutions... or perhaps if there are
#      no solutions above a certain threshold?

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

module Alert
  def self.alert(s)
    puts "ALERT: #{s}"
  end
  def self.warn(s)
    puts "WARN: #{s}"
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
      puts s if log_level <= THRESHOLD
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

module UI
  LEFT_PADDING_DEFAULT = 20

  def UI::padded_puts(s)
    puts "#{' ' * LEFT_PADDING_DEFAULT}#{s}"
  end

  def UI::padded_print(s)
    print "#{' ' * LEFT_PADDING_DEFAULT}#{s}"
  end

  def self.prompt_for_input(input_string, prompt_on_new_line = true)
    if prompt_on_new_line
      padded_puts input_string
      padded_print '==> '
    else
      padded_print input_string
    end
    return gets.chomp
  end

  def self.play(d)
    puts ''
    padded_puts '----------------------------------------------------------'
    padded_puts '|                                                        |'
    padded_puts '|                   Welcome to Wordle!                   |'
    padded_puts '|                                                        |'
    padded_puts '----------------------------------------------------------'
    for guess in 1..6
      padded_puts "You are on guess #{guess}/6. #{remaining_count_string(d)}"
      check_for_problematic_patterns(d) if guess >= 3
      while true do
        choice = UI.prompt_for_input("Enter a guess, or 'help':")
        case choice
        when 'c'
          UI.print_remaining_count(d)
        when 'p', 'pa'
          UI.print_remaining_words(d, choice == 'p' ? 30 : nil)
        when 'hint'
          Commands::hint(d)
        when 'q'
          puts ''
          return
        when 'penultimate'
          Commands::penultimate(d)
        when 'twitter'
          stats_hash = Twitter::twitter[:stats]
          UI.print_remaining_count(d)
          if UI.maybe_filter_twitter(d, stats_hash)
            UI.maybe_absence_of_evidence(d, stats_hash)
          end
        when 'dad'
          print_a_dad_joke
        when 'generate-fingerprints'
          puts 'running this takes a long time, ~20 minutes'
          puts 'typically it is only necessary after re-scraping of NYT'
          puts 'if you still want to run this, uncomment the code'
          # fingerprints = calculate_fingerprints
          # compressed_fingerprints = compress(fingerprints)
          # save_fingerprints_to_file compressed_fingerprints
        when 'fingerprint-analysis'
          stats_hash = Twitter::twitter[:stats]
          Fingerprint::fingerprint_analysis(d, stats_hash)
        when 'test'
          stats_hash = Twitter::twitter[:stats]
          Fingerprint::fingerprint_analysis(d, stats_hash)
        when 'performance'
          time_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          # (0...100).each {|_| Filter::filter_4g(populate_all_words, 2, 1)}
          # (0...100).each {|_| Filter::filter_3g1y(populate_all_words, 1, 2)}
          (0...100).each {|i| Filter::filter_3g2y(populate_all_words, 1, 2)}
          # (0...1).each {|_| Filter::filter_2g3y_version_3(populate_all_words, 1, 2); puts '.'}
          # (0...5).each {|_| Filter::filter_2g3y_version_2(populate_all_words, 1, 2); puts '.'}
          # (0...5).each {|_| Filter::filter_2g3y_version_1(populate_all_words, 1, 2); puts '.'}
          # (0...5).each {|_| Filter::filter_1g4y(populate_all_words, 1); puts '.'}
          # (0...3).each {|_| Filter::filter_0g5y(populate_all_words); puts '.'}
          elapsed_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - time_start
          puts "elapsed_time: #{'%.1f' % elapsed_time} seconds"
        when 'regression'
          regression_analysis(d)
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
    # TODO convert this more to a "main menu" type thing?
    puts ''
    UI::padded_puts '.----------------------------------------------.'
    UI::padded_puts '|                                              |'
    UI::padded_puts '|                     Usage                    |'
    UI::padded_puts '|                                              |'
    UI::padded_puts '\----------------------------------------------/'
    UI::padded_puts 'c               : count'
    UI::padded_puts 'p               : print'
    UI::padded_puts 'pa              : print all'
    UI::padded_puts 'hint            : hint'
    UI::padded_puts 'q               : quit'
    puts ''
    UI::padded_puts 'penultimate     : run penultimate-style analysis'
    UI::padded_puts 'twitter         : run Twitter analysis'
    puts ''
    UI::padded_puts 'dad             : print a dad joke'
    UI::padded_puts 'help, h         : print this message'
    puts ''
  end

  def self.print_remaining_count(d)
    UI::padded_puts remaining_count_string d
  end

  def self.remaining_count_string(d)
    "There #{d.length==1?'is':'are'} #{d.size} matching word#{d.length==1?'':'s'} remaining."
  end

  def UI::goofball_analysis
    wordle_number = UI.prompt_for_input("Enter daily wordle number (to check for goofballs): ==> ", false)
    Twitter::Configuration.set_wordle_number_override wordle_number

    Twitter::Configuration.set_goofball_mode true
    twitter_result = Twitter::twitter
    stats_hash = twitter_result[:stats]
    answers = twitter_result[:answers]
    Twitter::Configuration.set_goofball_mode false
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

    puts ''
    puts ''
    puts ''
    UI.padded_puts '/--------------------------------------\\'
    UI.padded_puts "|              Wordle #{wordle_number}              |"
    UI.padded_puts '|            Goofball report           |'
    UI.padded_puts '\--------------------------------------/'
    puts ''

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
      author_id = answer.author_id
      username = answer.username

      # Goofball report
      puts "Author ID #{author_id} already in denylist" if Twitter::Configuration.author_id_denylist.include?(author_id)
      puts "Author ID #{author_id} already in allowlist" if Twitter::Configuration.author_id_allowlist.include?(author_id)
      puts "- name: #{username}"
      puts "  author_id: #{author_id}"
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

  def UI::regression_analysis(d)
    six_days_ago = (today_wordle_number.to_i - 6).to_s
    range = "(#{six_days_ago}-#{today_wordle_number})"
    wordle_number = UI.prompt_for_input("Enter daily wordle number for regression #{range}:==> ", false)
    exit if wordle_number.to_i.to_s != wordle_number
    Twitter::Configuration.set_wordle_number_override wordle_number

    stats_hash = Twitter::twitter[:stats]
    a = filter_twitter(d.dup, stats_hash).keys
    b = Fingerprint::fingerprint_analysis(d.dup, stats_hash).keys

    puts ''
    UI::padded_puts '/------------------------------------------------------\\'
    UI::padded_puts "|        Regression analysis report (Wordle #{wordle_number})       |"
    UI::padded_puts '\------------------------------------------------------/'
    puts ''
    UI::padded_puts "length comparison: #{a.length == b.length ? 'OK' : 'FAIL'}"
    UI::padded_puts "remaining word comparison: #{(a.size == b.size && a&b==a) ? 'OK' : 'FAIL'}"
    puts ''
    UI::padded_puts 'Exiting because wordle_number_override was set manually...'
    puts ''

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
    # FIXME it is possible to see more matches on Twitter than mag-4gs if using
    #       a smaller dictionary (like dracos)
    new_d = {}
    d.each do |key, _value|
      matches = all_4g_matches(key, Twitter::Configuration.absence_of_evidence_filename)
      difference = [0, 0, 0, 0, 0]
      # (0...5).each {|i| difference[i] = matches[i] - max_4gs_seen[i]}
      (0...5).each {|i| difference[i] = Distances::DISTANCES_4G[[matches[i], 9].min][max_4gs_seen[i]].to_f}
      new_d[key] = [difference.sum, difference, matches, max_4gs_seen]
    end
    new_d = new_d.sort_by {|_key, value| value[0]}.to_h

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
      new_d.each_with_index do |(key, value), index|
        next if index < page_number * page_size
        break if index >= (page_number+1) * page_size
        solution_number = PreviousWordleSolutions.check_word(key)
        maybe_alert = solution_number ? " -------- Alert! Wordle #{solution_number} solution was #{key} --------" : ''
        UI::padded_puts absence_of_evidence_string.call(key, value, maybe_alert)
      end
      while true do
        more = [0, new_d.length - ((page_number+1) * page_size)].max
        user_input = UI.prompt_for_input("Enter a word to see its score, 'next', or (q)uit (#{more} more): ==> ", false)
        break if (user_input == 'q' || user_input == 'next')
        if new_d.key?(user_input)
          key = user_input
          value = new_d[key]
          solution_number = PreviousWordleSolutions.check_word(key)
          maybe_alert = solution_number ? " -------- Alert! Wordle #{solution_number} solution was #{key} --------" : ''
          UI::padded_puts absence_of_evidence_string.call(key, value, maybe_alert)
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
