#!/usr/bin/ruby -w

require_relative 'twitter'
require 'yaml'

# copied from https://github.com/charlesreid1/five-letter-words
DICTIONARY_FILE_LARGE = 'sgb-words.txt'
DICTIONARY_FILE_SMALL = 'sgb-words-small.txt'
DICTIONARY_FILE = DICTIONARY_FILE_LARGE

# from https://gist.github.com/dracos/dd0668f281e685bad51479e5acaadb93
# replaced with below file
# TODO have a better strategy for each dictionary
# Note: This "better strategy" work should be on hold until the other TODO (words
#       shall not be penalized for having "too many" matches) is completed
# sgb-words.txt: This is the universe of reasonable wordle answers
# valid-wordle-words.txt: This is the universe of valid wordle guesses (direct from NYT)
# It might make sense to have a third dictionary, for use only by absence_of_evidence().
# It is... plausible... that such a dictionary (larger than sgb-words, smaller than valid)
# would have better predictive value. But one cannot (should not) use an incomplete
# dictionary when eliminating words.

# produced via scrape_nyt.rb
VALID_WORDLE_WORDS_FILE = 'valid-wordle-words.txt'

def populate_valid_wordle_words
  d = {}
  File.foreach(VALID_WORDLE_WORDS_FILE).with_index do |line, line_num|
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
  ['pinot', 'ramen', 'beret', 'apage', 'stear', 'stean', 'tased', 'tsade'].each { |word| d[word] = '-1' }
  d
end

def close(w1, w2)
  diff = 0
  (0...5).each {|i| diff += (w1[i]==w2[i] ? 0 : 1)}
  diff == 1
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
          hint(d)
        when 'q'
          puts ''
          return
        when 'penultimate'
          penultimate(d)
        when 'twitter'
          stats_hash = twitter[:stats]
          UI.print_remaining_count(d)
          if UI.maybe_filter_twitter(d, stats_hash)
            UI.maybe_absence_of_evidence(d, stats_hash)
          end
        when 'dad'
          print_a_dad_joke
        when 'test'
          calculate_constraint_cardinality
        when 'goofball'
          goofball_analysis
        when 'help', 'h'
          UI.print_usage
        when '' # pressing enter shouldn't cause "unrecognized input"
        else
          if choice.length == 5
            response = UI.prompt_for_input('Enter the response (!?-): ==> ', false)
            filter(d, choice, response)
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
      penultimate_twitter_absence_of_evidence(d, stats_hash)
    when 'n'
    else
      Alert.alert "unrecognized input (#{choice}), skipping"
    end
  end

  def self.maybe_filter_twitter(d, stats_hash)
    choice = UI.prompt_for_input 'Would you like to proceed with filtering? (y/n)'
    case choice
    when 'y'
      choice2 = UI.prompt_for_input "There are #{d.size} words remaining. Would you like to see filtering output? (y/n)"
      previous_maybe = Debug.maybe?
      Debug.set_maybe(choice2 == 'y')

      # Idea is to only filter on the max 4g seen
      max_4gs_seen = max_4gs_seen_on_twitter(stats_hash)

      stats_hash.each do |key, _value|
        if Configuration.instrumentation_only
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

        penultimate_twitter(d, key_array[0], key_array[1])
        UI.print_remaining_count(d) # moving this here, to show filtering as it goes
      end
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
end

def check_for_problematic_patterns(d)
  # e.g. Wordle 265 ("watch"), after raise-clout (-!---, ?---?)
  # legal words remaining: watch, match, hatch, patch, batch, natch, tacky
  # 6 words with _atch, plus tacky
  pp_dict = {}
  d.each do |key1, value1|
    break if Configuration.instrumentation_only
    found = false
    pp_dict.each do |key2, value2|
      if close(key1, key2)
        found = true
        pp_dict[key2] = value2 + 1
      end
    end
    pp_dict[key1] = 1 if !found
  end
  if Configuration.instrumentation_only
    Debug.log 'skipped problematic pattern loop, using hardcoded result'
    pp_dict = {'hilly': 3, 'floss': 10} if Configuration.instrumentation_only
  end
  UI::padded_puts 'Checking for problematic patterns...'
  pp_dict.each do |key, value|
    if value > 2
      puts ''
      UI::padded_puts 'PROBLEMATIC PATTERN ALERT'
      UI::padded_puts "Found \"#{key}\" with #{value} matching words (print for details)"
      puts ''
      puts ''
    end
  end
  UI::padded_puts 'No problematic patterns found!' if pp_dict.values.max <= 2
end

def goofball_analysis
  wordle_number = UI.prompt_for_input("Enter daily wordle number (to check for goofballs): ==> ", false)
  Configuration.set_wordle_number_override wordle_number

  Configuration.set_goofball_mode true
  twitter_result = twitter
  stats_hash = twitter_result[:stats]
  answers = twitter_result[:answers]
  Configuration.set_goofball_mode false
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
    puts "Author ID #{author_id} already in denylist" if Configuration.author_id_denylist.include?(author_id)
    puts "Author ID #{author_id} already in allowlist" if Configuration.author_id_allowlist.include?(author_id)
    puts "- name: #{username}"
    puts "  author_id: #{author_id}"
    puts "  tweet: #{answer.tweet_url}"
    puts "  analysis: Wordle #{nm} (#{sn}), #{key}, #{reasoning}"
    puts "  verdict: #{verdict} # #{title}"
    puts ''
  }

  check_lists = ->(author_id) {
    Configuration.author_id_denylist.include?(author_id) || Configuration.author_id_allowlist.include?(author_id)
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
  puts '##################################################'
end

def static_analysis(d, stats_hash)
  # TODO (big feature) do offline calculations for each word and constraint type (not only 4g)
  #
  # 4g   : Can represent as below, 5-tuple [3, 1, 5, 0, 3]
  # 3g1y : This is a 2-D array. Array[i][j] = number which match ith as yellow and jth as white
  #        Array[i][i] is undefined because i != j
  #                         [
  #                          [-, 0, 0, 2, 0], # e.g. 2 words give a yggwg result
  #                          [0, -, 1, 0, 0], # and 1 word gives a gywgg result
  #                          [2, 0, -, 0, 0],
  #                          [0, 0, 1, -, 0],
  #                          [0, 0, 0, 0, -],
  #                         ]
  # 3g2y : Also a 2-D array. Elements i and j are both the yellow positions.
  # 2g3y : Also a 2-D array. Elements i and j are now the green positions.
  # 1g4y : This is a 1-D array. Element i indicates the green position.
  # 0g5y : This is just a simple count.
  #
  # So there are a total of 71 numbers on which to match.
  #
  # Thoughts: Only the 4g array includes count. So while we can measure 4g here and on
  #           Twitter, the only deduction we could make is (for example) if there are
  #           many words which result in a gggyw, and nobody on Twitter gets that
  #           pattern, then we should rank it lower.
  # Plan:     Start writing and executing the "calculate_constraint_cardinality" code.
  #           Do the first 10 in the word list, and also the most recent 10 Wordle
  #           answers. See how things look in terms of matchups.
end

def calculate_constraint_cardinality
  # The idea here is to precompute how many of each constraint there is
  # for each word, to pattern-match later based on twitter
  puts 'UNDER CONSTRUCTION'
  # {
  #   'khaki' :
  #   'gruel'
  # }
  reasonable_words = [
    'khaki', # Wordle 421
    'gruel', # Wordle 423
    'twice', # Wordle 424
  ]
  h = {}
  valid_wordle_words = populate_valid_wordle_words

  reasonable_words.each do |word|
    d = {}
    valid_wordle_words.each do |guess, _line_num|
      wordle_response = wordle_response(guess, word)
      interestingness = InterestingWordleResponses::determine_interestingness(wordle_response)
      case interestingness
      when InterestingWordleResponses::WORDLE_4G, InterestingWordleResponses::WORDLE_3G1Y, InterestingWordleResponses::WORDLE_3G2Y, InterestingWordleResponses::WORDLE_2G3Y, InterestingWordleResponses::WORDLE_1G4Y, InterestingWordleResponses::WORDLE_0G5Y
        _name, _subname, key = InterestingWordleResponses::calculate_name_subname_key(wordle_response, interestingness, 1)
        d[key] = 0 if !d.key?(key)
        d[key] = d[key] + 1
      when InterestingWordleResponses::NOT_INTERESTING
      else
        raise "unknown interestingness"
      end
    end
    h[word] = d
  end
  puts h
end

def wordle_response(guess, word)
  # defensive copying
  guess_copy = guess.dup
  word_copy = word.dup
  wordle_response = '-----'

  # first green
  (0...5).each do |i|
    if guess_copy[i] == word_copy[i]
      wordle_response[i] = 'g'
      word_copy[i] = '-'
    end
  end
  # then white
  (0...5).each do |i|
    next if wordle_response[i] != '-'
    wordle_response[i] = 'w' if !word_copy.include?(guess_copy[i])
  end
  # everything else is yellow or white
  (0...5).each do |i|
    next if wordle_response[i] != '-'
    if word_copy.include?(guess_copy[i])
      wordle_response[i] = 'y'
      index = word_copy.index(guess_copy[i])
      word_copy[index] = '-'
    else
      wordle_response[i] = 'w'
    end
  end
  wordle_response
end

def max_4gs_seen_on_twitter(stats_hash)
  # calculate the max 4g's seen per letter
  # [1, 0, 1, 0, 0] means the first and third letters had 4g matches, and only 4g.1.1 and 4g.3.1
  max_4gs_seen = [0, 0, 0, 0, 0]
  stats_hash.each do |key, value|
    # sample (key, value): ('4g.3.1', 7) indicating the 3rd letter was white 1 time, for 7 people
    key_array = key.split('.', 2)
    if key_array[0] == '4g'
      letter_position = key_array[1][0].to_i
      num_incorrect_4gs = key_array[1][2].to_i
      _num_people = value
      if num_incorrect_4gs > max_4gs_seen[letter_position-1]
        max_4gs_seen[letter_position-1] = num_incorrect_4gs
      end
    end
  end
  max_4gs_seen
end

def penultimate_twitter_absence_of_evidence(d, stats_hash)
  UI::padded_puts 'Absence of evidence is not evidence of absence!'

  # 4g-based analysis
  # sample entry in stash_hash: key=4g.3.1, value=7
  # Translation: The 3rd letter was white one time, for seven people
  # Plan
  #   1. Normalize the knowledge in stats_hash
  #   2. For remaining words in d, find how many matching words there are in valid-wordle-words.txt
  #   3. Do a text-based comparison (for now)

  # get max 4gs seen
  max_4gs_seen = max_4gs_seen_on_twitter stats_hash

  # calculate how many actual 4g matches there are per key
  # key=laved, all_4g_matches=[6, 2, 10, 0, 2]
  # defined distances between ith all-4g-matches and possible observed Twitter values
  distances = [
    [0, [0]],
    [1, [1, 0]], # one valid word and nobody found it: defined as 1
    [2, [1.5, 0.75, 0]],
    [3, [2, 1, 0.5, 0]],
    [4, [2.5, 1.25, 0.6, 0.3, 0]],
    [5, [3, 1.5, 0.75, 0.37, 0.18, 0]],
    [6, [3.5, 1.75, 0.85, 0.42, 0.21, 0, 0]],
    [7, [4, 2, 1, 0.5, 0.25, 0, 0, 0]],
    [8, [4.5, 2.25, 1.12, 0.56, 0.28, 0, 0, 0, 0]],
    [9, [5, 2.5, 1.25, 0.6, 0.3, 0, 0, 0, 0, 0]],
  ].to_h
  new_d = {}
  d.each do |key, _value|
    puts "key=#{key}"
    matches = all_4g_matches(key)
    difference = [0, 0, 0, 0, 0]
    # (0...5).each {|i| difference[i] = matches[i] - max_4gs_seen[i]}
    (0...5).each {|i| difference[i] = distances[[matches[i], 9].min][max_4gs_seen[i]].to_f}
    puts "difference=#{difference}"
    new_d[key] = [difference.sum, difference, matches, max_4gs_seen]
  end
  new_d = new_d.sort_by {|_key, value| value[0]}.to_h

  puts ''
  UI::padded_puts '/------------------------------------------------------\\'
  UI::padded_puts "|              Absence of Evidence report              |"
  UI::padded_puts '\------------------------------------------------------/'
  UI::padded_puts ''
  UI::padded_puts "max 4gs seen on Twitter: #{max_4gs_seen}"

  page_size = 10
  current_difference = -1
  absence_of_evidence_string = ->(key, value, maybe_alert) {
    "key=#{key}, difference=#{value[0]}, all-4g-matches=#{value[2]}, seen-on-twitter=#{value[3]}#{maybe_alert}"
  }
  (0...10).each do |page_number|
    current_difference = -1
    break if (page_number * page_size) > new_d.length
    new_d.each_with_index do |(key, value), index|
      next if index < page_number * page_size
      break if index >= (page_number+1) * page_size
      solution_number = PreviousWordleSolutions.check_word(key)
      maybe_alert = solution_number ? " -------- Alert! Wordle #{solution_number} solution was #{key} --------" : ''
      if value[0] != current_difference
        UI::padded_puts "-------- Difference #{value[0]} --------"
        current_difference = value[0]
      end
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

def penultimate_twitter(d, pattern, subpattern)
  UI::padded_puts "penultimate_twitter called, pattern=#{pattern}, subpattern=#{subpattern}"
  case pattern
  when '4g'
    # 4g.3.1 = 25
    # 4g.3.2 = 8
    # 4g.3.3 = 1
    subpattern_array = subpattern.split('.')
    if subpattern_array.length() != 2
      Alert.alert 'unexpected length (4g subpattern)'
      return
    end
    gray = subpattern_array[0].to_i - 1
    count = subpattern_array[1].to_i
    Filter::filter_4g(d, gray, count)
  when '3g1y'
    # 3g1y.yellow3.white4 = 3
    subpattern_array = subpattern.split('.')
    if subpattern_array.length() != 2
      Alert.alert 'unexpected length (3g1y subpattern)'
      return
    end
    yellow = subpattern_array[0][6].to_i - 1
    gray = subpattern_array[1][5].to_i - 1
    Filter::filter_3g1y(d, yellow, gray)
  when '3g2y'
    # 3g2y.yellow24
    yellow1 = subpattern[6].to_i - 1
    yellow2 = subpattern[7].to_i - 1
    Filter::filter_3g2y(d, yellow1, yellow2)
  when '2g3y'
    # 2g3y.green24
    green1 = subpattern[5].to_i - 1
    green2 = subpattern[6].to_i - 1
    Filter::filter_2g3y(d, green1, green2)
  when '1g4y'
    # 1g4y.green3
    green = subpattern[5].to_i - 1
    Filter::filter_1g4y(d, green)
  when '0g5y'
    # 0g5y.
    Filter::filter_0g5y(d)
  else
    UI::padded_puts "#{pattern} not yet supported"
  end
end

ALPHABET = [
  'a','b','c','d','e','f','g','h','i','j','k','l','m',
  'n','o','p','q','r','s','t','u','v','w','x','y','z'
]

def all_4g_matches(word)
  return_array = [0, 0, 0, 0, 0]
  all_words = populate_valid_wordle_words
  (0...5).each do |i|
    ith_sum = 0
    temp_word = word.dup
    ALPHABET.each do |letter|
      temp_word[i] = letter
      ith_sum += 1 if temp_word != word && all_words.key?(temp_word)
    end
    return_array[i] = ith_sum
  end
  return_array
end

module PreviousWordleSolutions
  @@previous_wordle_solutions = {}

  def self.all_solutions
    if @@previous_wordle_solutions.empty?
      line_num = 0
      File.foreach('previous_wordle_solutions.txt') do |line|
        next if line.start_with?('#')
        @@previous_wordle_solutions[line[0..4]] = line_num
        line_num += 1
      end
    end

    @@previous_wordle_solutions
  end

  def self.check_word(word)
    PreviousWordleSolutions.all_solutions[word]
  end

  def self.lookup_by_number(n)
    PreviousWordleSolutions.all_solutions.key n
  end
end

module Filter
  def Filter::replace_ith_letter(word, i, letter)
    word_copy = word.dup
    word_copy[i] = letter
    word_copy
  end

  def Filter::filter_4g(d, gray, count)
    all_words = populate_valid_wordle_words

    d.each_key do |key|
      num_valid_alternatives = ALPHABET
        .map{|c| replace_ith_letter(key, gray, c)}
        .map{|word_to_check| (word_to_check != key && all_words.key?(word_to_check)) ? 1 : 0}
        .to_a
        .sum

      if num_valid_alternatives < count
        d.delete(key)
      else
        Debug.maybe_log "keeping #{key} (" + all_words.map { |k, v| "#{k}" }.join(', ') + ')'
      end
    end
  end

  def Filter::filter_3g1y(d, yellow, gray)
    all_words = populate_valid_wordle_words
    d.each_key do |key|
      # ensure yellow and gray are different
      d.delete(key) if key[yellow] == key[gray]

      # make a copy, save the yellow, and copy over the gray
      key_copy = key.dup
      letter_at_yellow = key_copy[yellow]
      key_copy[yellow] = key_copy[gray] # moving the letter makes it get a yellow

      num_valid_alternatives = ALPHABET
        .map{|c| replace_ith_letter(key_copy, gray, c)}
        .map{|word_to_check| (word_to_check[gray] != letter_at_yellow && all_words.key?(word_to_check)) ? 1 : 0}
        .to_a
        .sum

      if num_valid_alternatives == 0
        d.delete(key)
      else
        Debug.maybe_log "keeping #{key} (" + all_words.map { |k, v| "#{k}" }.join(', ') + ')'
      end
    end
  end

  def Filter::filter_3g2y(d, yellow1, yellow2)
    all_words = populate_valid_wordle_words
    d.each_key do |key|
      switched_word = key.dup
      switched_word[yellow1] = key[yellow2]
      switched_word[yellow2] = key[yellow1]
      if key != switched_word and all_words.key?(switched_word)
        Debug.maybe_log "keeping #{key} (#{switched_word})"
      else
        d.delete(key)
      end
    end
  end

  def Filter::filter_2g3y(d, green1, green2)
    d.each_key do |key|
      all_words = populate_valid_wordle_words
      for i in 0...5
        if i == green1 or i == green2
          all_words.delete_if { |key2, value2| key2[i] != key[i] }
        else # yellow
          all_words.delete_if { |key2, value2| key2[i] == key[i] || key2.count(key2[i]) != key.count(key2[i]) }
        end
      end
      if all_words.size == 0
        d.delete(key)
      else
        Debug.maybe_log "keeping #{key} (" + all_words.map { |k, v| "#{k}" }.join(', ') + ')'
      end
    end
  end

  def Filter::filter_1g4y(d, green)
    d.each_key do |key|
      all_words = populate_valid_wordle_words
      for i in 0...5
        if i == green
          all_words.delete_if { |key2, value2| key2[i] != key[i] }
        else # yellow
          all_words.delete_if { |key2, value2| key2[i] == key[i] || key2.count(key2[i]) != key.count(key2[i]) }
        end
      end
      if all_words.size == 0
        d.delete(key)
      else
        Debug.maybe_log "keeping #{key} (" + all_words.map { |k, v| "#{k}" }.join(', ') + ')'
      end
    end
  end

  def Filter::filter_0g5y(d)
    d.each_key do |key|
      all_words = populate_valid_wordle_words
      for i in 0...5
        # all yellows
        all_words.delete_if { |key2, value2| key2[i] == key[i] || key2.count(key2[i]) != key.count(key2[i]) }
      end
      if all_words.size == 0
        d.delete(key)
      else
        Debug.maybe_log "keeping #{key} (" + all_words.map { |k, v| "#{k}" }.join(', ') + ')'
      end
    end
  end
end

def penultimate(d)
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

def hint(d)
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

def num_green_or_yellow(word, response, letter)
  num_green_or_yellow = 0
  (0...5).each { |i| num_green_or_yellow += 1 if word[i] == letter && response[i] != '-' }
  return num_green_or_yellow
end

def filter(d, word, response)
  Debug.log_verbose "d.size: #{d.size()}"
  for i in 0...5
    letter = word[i]
    case response[i]
    when '!'
      d.delete_if { |key, value| key[i] != letter }
    when '?'
      d.delete_if { |key, value| key[i] == letter || key.count(letter) < num_green_or_yellow(word, response, letter) }
    when '-'
      d.delete_if { |key, value| key[i] == letter || key.count(letter) != num_green_or_yellow(word, response, letter) }
    else
      raise 'unrecognized response character'
    end
  end
end

def run_tests
  fail if num_green_or_yellow('abcde', '!----', 'a') != 1
  fail if num_green_or_yellow('aaaaa', '!?---', 'a') != 2
  fail if num_green_or_yellow('aaaaa', '??---', 'a') != 2
  fail if num_green_or_yellow('xaaxx', '!!--!', 'c') != 0
  fail if num_green_or_yellow('xaaxx', '?????', 'x') != 3
  fail if num_green_or_yellow('xaaxx', '?????', 'a') != 2

  fail if close('aaaaa', 'bbbbb')
  fail if close('aaaaa', 'aaabb')
  fail if close('abcde', 'abcde')
  fail unless close('abcde', 'xbcde')
  fail unless close('abcde', 'axcde')
  fail unless close('abcde', 'abxde')
  fail unless close('abcde', 'abcxe')
  fail unless close('abcde', 'abcdx')

  # wordle_response(guess, word)
  fail unless wordle_response('saner', 'raise') == 'ygwyy'
  fail unless wordle_response('sanee', 'raise') == 'ygwwg'
  fail unless wordle_response('saaer', 'raise') == 'ygwyy'
  fail unless wordle_response('saaer', 'raisa') == 'ygywy'
  fail unless wordle_response('saaar', 'raisa') == 'ygywy'

  fail unless InterestingWordleResponses::determine_interestingness('ggggg') == InterestingWordleResponses::NOT_INTERESTING
  fail unless InterestingWordleResponses::determine_interestingness('ggggw') == InterestingWordleResponses::WORDLE_4G
  fail unless InterestingWordleResponses::determine_interestingness('ggwgg') == InterestingWordleResponses::WORDLE_4G
  fail unless InterestingWordleResponses::determine_interestingness('wgggg') == InterestingWordleResponses::WORDLE_4G
  fail unless InterestingWordleResponses::determine_interestingness('gggwy') == InterestingWordleResponses::WORDLE_3G1Y
  fail unless InterestingWordleResponses::determine_interestingness('gggyy') == InterestingWordleResponses::WORDLE_3G2Y
  fail unless InterestingWordleResponses::determine_interestingness('ggyyy') == InterestingWordleResponses::WORDLE_2G3Y
  fail unless InterestingWordleResponses::determine_interestingness('gyyyy') == InterestingWordleResponses::WORDLE_1G4Y
  fail unless InterestingWordleResponses::determine_interestingness('yyyyy') == InterestingWordleResponses::WORDLE_0G5Y

  fail unless all_4g_matches('hilly') == [9, 3, 1, 0, 2]
  fail unless all_4g_matches('hills') == [18, 3, 0, 2, 2]

  fail unless WordleModes.determine_mode("#{WordleTweetColors::GREEN}#{WordleTweetColors::WHITE}") == 'Normal'
  fail unless WordleModes.determine_mode("#{WordleTweetColors::YELLOW}#{WordleTweetColors::WHITE}") == 'Normal'
  fail unless WordleModes.determine_mode("#{WordleTweetColors::GREEN}#{WordleTweetColors::BLACK}") == 'Dark'
  fail unless WordleModes.determine_mode("#{WordleTweetColors::YELLOW}#{WordleTweetColors::BLACK}") == 'Dark'
  fail unless WordleModes.determine_mode("#{WordleTweetColors::ORANGE}#{WordleTweetColors::WHITE}") == 'Deborah'
  fail unless WordleModes.determine_mode("#{WordleTweetColors::BLUE}#{WordleTweetColors::WHITE}") == 'Deborah'
  fail unless WordleModes.determine_mode("#{WordleTweetColors::ORANGE}#{WordleTweetColors::BLACK}") == 'DeborahDark'
  fail unless WordleModes.determine_mode("#{WordleTweetColors::BLUE}#{WordleTweetColors::BLACK}") == 'DeborahDark'

  fail unless WordleModes.unicode_to_normalized_string(WordleTweetColors::WHITE, 'Normal') == 'w'
  fail unless WordleModes.unicode_to_normalized_string(WordleTweetColors::YELLOW, 'Normal') == 'y'
  fail unless WordleModes.unicode_to_normalized_string(WordleTweetColors::GREEN, 'Normal') == 'g'
  fail unless WordleModes.unicode_to_normalized_string(WordleTweetColors::BLACK, 'Dark') == 'w'
  fail unless WordleModes.unicode_to_normalized_string(WordleTweetColors::YELLOW, 'Dark') == 'y'
  fail unless WordleModes.unicode_to_normalized_string(WordleTweetColors::GREEN, 'Dark') == 'g'
  fail unless WordleModes.unicode_to_normalized_string(WordleTweetColors::WHITE, 'Deborah') == 'w'
  fail unless WordleModes.unicode_to_normalized_string(WordleTweetColors::BLUE, 'Deborah') == 'y'
  fail unless WordleModes.unicode_to_normalized_string(WordleTweetColors::ORANGE, 'Deborah') == 'g'
  fail unless WordleModes.unicode_to_normalized_string(WordleTweetColors::BLACK, 'DeborahDark') == 'w'
  fail unless WordleModes.unicode_to_normalized_string(WordleTweetColors::BLUE, 'DeborahDark') == 'y'
  fail unless WordleModes.unicode_to_normalized_string(WordleTweetColors::ORANGE, 'DeborahDark') == 'g'
end

run_tests
d = populate_all_words
UI.play(d)
