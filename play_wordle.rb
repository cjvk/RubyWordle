#!/usr/bin/ruby -w

# TODO Add more tests. When I change things, I only know when the code is run.
#   1. test
#   2. raise (-!--- response), twitter, filtering, absence-of-evidence
#   3. goofball 444
# TODO class StatsHash
# TODO class Fingerprint? FingerprintHash?
# TODO Move things to different files?
# TODO constants.rb?

# copied from https://github.com/charlesreid1/five-letter-words
# The purpose of this file is the universe of solutions
DICTIONARY_FILE_LARGE = 'sgb-words.txt'
DICTIONARY_FILE_SMALL = 'sgb-words-small.txt'
DICTIONARY_FILE = DICTIONARY_FILE_LARGE
# produced via scrape_nyt.rb: the universe of legal guesses
VALID_WORDLE_WORDS_FILE = 'valid-wordle-words.txt'
# from https://gist.github.com/dracos/dd0668f281e685bad51479e5acaadb93
# The purpose of this file is a smaller legal-guesses file,
# which might perform better during absence-of-evidence analysis.
DRACOS_VALID_WORDLE_WORDS_FILE = 'dracos-valid-wordle-words.txt'

# moving this after the file declarations because Configuration needs it
require_relative 'twitter'
require 'yaml'

def populate_valid_wordle_words(filename=VALID_WORDLE_WORDS_FILE)
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
        when 'generate-fingerprints'
          fingerprints = calculate_fingerprints
          _compressed_fingerprints = compress(fingerprints)
          # save_fingerprints_to_file compressed_fingerprints
        when 'full-precalculation'
          stats_hash = twitter[:stats]
          full_precalculation(d, stats_hash)
        when 'test'
          stats_hash = twitter[:stats]
          full_precalculation(d, stats_hash)
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

  # TODO
  # Precalculate compact constraint cardinalities for all words in the 5757 dictionary
  # (plus the stragglers I suppose). The cardinalities are computed against the NYT
  # dictionary. I suppose when it is re-scraped, it must be re-generated. (Wonder how
  # long it takes). After calling twitter(), instead of doing filtering as it is now,
  # iterate through the remaining words (e.g. could be all 5757 + stragglers), and
  # calculate a "distance" or "score". The calculate_score() function would first
  # look for keys in the twitter response which are not in the precalculated
  # fingerprint. If it finds any, can exit early with "NO_MATCH" or something. If
  # it does not find any, then twitter.keys.length / fingerprint.keys.length is
  # the first pass of how well it matches. Additional passes can weight this based
  # on counts. Counts for the 4gs can be handled differently than for the others.
  # But for example, if there are 3 words which yield 0g5y, and _nobody_ finds them,
  # this seems quite a good signal.
  #
  # Precalculation: Have a class which does the precalculation, then convert to compact
  #                 format for storage. When created from the file, take out of compact
  #                 format.

end

module CompactKeys
  # examples for: key, name, subname
  # 4g.3.1, 4g, 3.1
  # 3g1y.yellow3.white2, 3g1y, yellow3.white2
  # 3g2y.yellow23, 3g2y, yellow23
  # 2g3y.green23, 2g3y, green23
  # 1g4y.green3, 1g4y, green3
  # 0g5y., 0g5y, ''
  #
  # Going to be storing counts
  KEY_COMPRESSION_HASH = [
    # long form, compact form
    ['4g.1', 0], ['4g.2', 1], ['4g.3', 2], ['4g.4', 3], ['4g.5', 4],
    ['3g1y.yellow1.white2', 5], ['3g1y.yellow1.white3', 6], ['3g1y.yellow1.white4', 7], ['3g1y.yellow1.white5', 8],
    ['3g1y.yellow2.white1', 9], ['3g1y.yellow2.white3',10], ['3g1y.yellow2.white4',11], ['3g1y.yellow2.white5',12],
    ['3g1y.yellow3.white1',13], ['3g1y.yellow3.white2',14], ['3g1y.yellow3.white4',15], ['3g1y.yellow3.white5',16],
    ['3g1y.yellow4.white1',17], ['3g1y.yellow4.white2',18], ['3g1y.yellow4.white3',19], ['3g1y.yellow4.white5',20],
    ['3g1y.yellow5.white1',21], ['3g1y.yellow5.white2',22], ['3g1y.yellow5.white3',23], ['3g1y.yellow5.white4',24],
    ['3g2y.yellow12', 25], ['3g2y.yellow13', 26], ['3g2y.yellow14', 27], ['3g2y.yellow15', 28],
    ['3g2y.yellow23', 29], ['3g2y.yellow24', 30], ['3g2y.yellow25', 31],
    ['3g2y.yellow34', 32], ['3g2y.yellow35', 33],
    ['3g2y.yellow45', 34],
    ['2g3y.green12', 35], ['2g3y.green13', 36], ['2g3y.green14', 37], ['2g3y.green15', 38],
    ['2g3y.green23', 39], ['2g3y.green24', 40], ['2g3y.green25', 41],
    ['2g3y.green34', 42], ['2g3y.green35', 43],
    ['2g3y.green45', 44],
    ['1g4y.green1', 45], ['1g4y.green2', 46], ['1g4y.green3', 47], ['1g4y.green4', 48], ['1g4y.green5', 49],
    ['0g5y.', 50]
  ].to_h

  def CompactKeys::compact_key(key, interestingness)
    # This may be a useless function
    case interestingness
    when InterestingWordleResponses::WORDLE_4G

    when InterestingWordleResponses::WORDLE_3G1Y, InterestingWordleResponses::WORDLE_3G2Y, InterestingWordleResponses::WORDLE_2G3Y, InterestingWordleResponses::WORDLE_1G4Y, InterestingWordleResponses::WORDLE_0G5Y
    when InterestingWordleResponses::NOT_INTERESTING
      raise "compact_key should not be called when not interesting"
    else
      raise "compact_key called with unknown interestingness"
    end
  end
end

DEFAULT_CONSTRAINT_CARDINALITY_WORD_LIST = [
  # 'khaki', # Wordle 421
  # 'gruel', # Wordle 423
  # 'twice', # Wordle 424
  # 'charm', # Wordle 440
  # 'gully', # Wordle 441
  'whoop', # Wordle 442
]

def compress(fingerprints)
  fingerprints.map{ |word, fingerprint|
    [word, fingerprint.map{|k,v| [CompactKeys::KEY_COMPRESSION_HASH[k], v]}.to_h]
  }.to_h
end

def decompress(compressed_fingerprints)
  compressed_fingerprints.map{ |word, compressed_fingerprint| [
    word, compressed_fingerprint.map { |compressed_key, v| [
      CompactKeys::KEY_COMPRESSION_HASH.key(compressed_key), v
    ]}.to_h
  ]}.to_h
end

def save_fingerprints_to_file(compressed_fingerprints)
  puts "uncomment in code to re-generate the file (this will overwrite!)"
  # File.write('compressed_fingerprints.yaml', compressed_fingerprints.to_yaml)
end

def read_fingerprints_from_file
  YAML.load_file('compressed_fingerprints.yaml')
end

# Sample fingerprint (clout)
# {"4g.2"=>2, "4g.3"=>1, "4g.4"=>1, "3g1y.yellow4.white5"=>3, "4g.5"=>3, "4g.1"=>3, "3g1y.yellow2.white1"=>1}
def reconstitute_fingerprints
  decompress(read_fingerprints_from_file)
end

def calculate_fingerprints
  # This function takes about 10 minutes to run. Unless there is a new type of
  # interestingness, or unless the dictionary changes, it should not need to be run.
  valid_wordle_words = populate_valid_wordle_words
  fingerprints = {}
  source_words = populate_all_words
  num_processed = 0
  source_words.each do |word, _|
    temp = {}
    valid_wordle_words.each do |guess, _|
      # convert wordle response (wgggg) to '4g.1'
      wordle_response = wordle_response(guess, word)
      interestingness = InterestingWordleResponses::determine_interestingness(wordle_response)
      case interestingness
      when InterestingWordleResponses::WORDLE_4G, InterestingWordleResponses::WORDLE_3G1Y, InterestingWordleResponses::WORDLE_3G2Y, InterestingWordleResponses::WORDLE_2G3Y, InterestingWordleResponses::WORDLE_1G4Y, InterestingWordleResponses::WORDLE_0G5Y
        _, _, key = InterestingWordleResponses::calculate_name_subname_key(wordle_response, interestingness, 1)
        key = key[0,4] if interestingness == InterestingWordleResponses::WORDLE_4G
        temp[key] = 0 if !temp.key?(key)
        temp[key] = temp[key] + 1
      when InterestingWordleResponses::NOT_INTERESTING
      else
        raise "unknown interestingness"
      end
    end
    fingerprints[word] = temp
    num_processed += 1
    # can do ~90 in 10 seconds (5400 in 10 minutes)
    # break if num_processed >= 575
    if num_processed % 575 == 0
      print 'sleeping for a minute every so often... '
      sleep 60
      puts 'resuming!'
    end
    break if num_processed >= 50 # comment this line if you want to run "for real"
  end
  fingerprints
end

# def score(stats_hash, fingerprint)
def score(candidate_word, stats_hash, fingerprint)
  Debug.set_maybe(candidate_word == 'prawn')
  Debug.maybe_log 'score: ENTER'
  # transform stats hash - map automatically makes a copy
  max_4gs_from_twitter = max_4gs_seen_on_twitter(stats_hash) # [1, 2, 0, 0, 1]
  max_4gs_info = {
    :keys => max_4gs_from_twitter
      .map.with_index{ |ith_max, i| "4g.#{i+1}.#{ith_max}" }
      .delete_if{ |key| key.end_with?('.0')},
    :max_by_short_key => max_4gs_from_twitter
      .map.with_index{ |ith_max, i| ["4g.#{i+1}", ith_max]}
      .delete_if{ |_, ith_max| ith_max == 0}
      .to_h
  }
  # keep_these_4gs_keys_plus = max_4gs_from_twitter
  #   .map.with_index {|ith_max, i| ["4g.#{i+1}.#{ith_max}", "4g.#{i+1}", ith_max]}
  #   .delete_if{|el| el[0].end_with?('.0')}
  # keep_these_4gs_keys = keep_these_4gs_keys_plus.map{|el| el[0]}
  tsh = stats_hash
    .map{|k,v| [k, [[:key, k], [:value, v]].to_h]}
    .map{|k,data_hash| data_hash[:is4g] = k.start_with?('4g'); [k, data_hash]}
    .map{|k,data_hash| data_hash[:short_key] = data_hash[:is4g] ? k[0,4] : k; [k, data_hash]}
    .delete_if{|k,data_hash| data_hash[:is4g] && !max_4gs_info[:keys].include?(k)}
  # .delete_if{|k,data_hash| data_hash[:is4g] && !keep_these_4gs_keys.include?(k)}

  (0...5).each do |i|
    next if max_4gs_from_twitter[i] == 0
    pos = i+1
    short_key = "4g.#{pos}"
    key = "#{short_key}.#{max_4gs_from_twitter[i]}"

  end
  tsh = tsh

  # Note: It may be possible to do first and second pass at the same time

  # First pass:
  #   Anything seen on Twitter _not_ in the fingerprint eliminates that word.
  #   (This is, I believe, equivalent to the current processing).
  tsh.each{|k,data_hash| return -1 if !fingerprint.key?(data_hash[:short_key])}

  # TODO Delete if max-4gs-seen is higher than the fingerprint
  # (start with alerting)
  fingerprint.each do |short_key, value|
    next if !short_key.start_with?('4g')
    next if !max_4gs_info[:max_by_short_key].key?(short_key)
    twitter_value = max_4gs_info[:max_by_short_key][short_key]

    if ['whirl','taunt','chugs','witch','pooch','drown','drawn','tramp','heerd','amber','plunk','haunt','clock','whims','amble','knitx','sonic'].include?(candidate_word)
      puts "Hello World from #{candidate_word}, #{twitter_value}>#{value}" if twitter_value > value
    end

    if twitter_value > value
      return -1
    end


    # tsh.each do |key, data_hash|
    #   next if data_hash[:short_key] != short_key
    #   twitter_value = 0
    #   keep_these_4gs_keys_plus.each do |el|
    #     short_key = el[1]
    #     if short_key == data_hash[:short_key]
    #       twitter_value = el[2]
    #       break
    #     end
    #   end
    #   puts "Hello World from #{candidate_word}, #{twitter_value}>#{value}" if twitter_value > value
    # end
  end


  # At this point, all keys (short keys) from transformed-stats-hash (tsm)
  # are also in fingerprint - otherwise would have exited early.

  # Second pass
  #   Calculate variables, normalized from 0-100, and weight them appropriately
  scores = {}

  # pct_keys
  # pct_keys = stats_hash.length.to_f / fingerprint.length.to_f
  Debug.maybe_log ''
  Debug.maybe_log 'stats_hash'
  Debug.maybe_log stats_hash
  Debug.maybe_log ''
  Debug.maybe_log 'tsh'
  Debug.maybe_log tsh
  Debug.maybe_log ''
  # pct_keys = stats_hash.length.to_f / fingerprint.length.to_f
  pct_keys = tsh.length.to_f / fingerprint.length.to_f
  pct_keys_score = pct_keys * 100
  scores[:pct_keys] = pct_keys_score
  # cjvk

  # distance_4g
  # - worse to get 0/1 than 1/2
  # - worse still to get 0/2 than either 0/1 or 1/2
  # - Are we "double-counting"? If someone misses entirely (0/1), they get dinged here _and_ in pct
  max_4gs_from_fingerprint = [0, 0, 0, 0, 0]
  (0...5).each do |i|
    ith_4g_key = "4g.#{i+1}"
    max_4gs_from_fingerprint[i] = fingerprint[ith_4g_key] if fingerprint.key?(ith_4g_key)
  end
  distance_4g = Distances::calc_4g_distance(max_4gs_from_twitter, max_4gs_from_fingerprint)
  # simple conversion (for now) to a 0-100 score
  arbitrary_max = 5.0
  distance_4g_score = ([arbitrary_max-distance_4g, 0].max.to_f / arbitrary_max) * 100
  scores[:distance_4g] = distance_4g_score

  # distance_non_4g
  # - Either they got it or didn't. This should penalize them extra for missing 0/2, 0/3, etc.
  distance_non_4g = Distances::calc_non_4g_distance(stats_hash, fingerprint)
  arbitrary_max = 5.0
  distance_non_4g_score = ([arbitrary_max-distance_non_4g, 0].max.to_f / arbitrary_max) * 100
  scores[:distance_non_4g] = distance_non_4g_score

  weights = {
    :pct_keys => 0.4,
    :distance_4g => 0.4,
    :distance_non_4g => 0.2,
  }

  Debug.maybe_log 'scores'
  Debug.maybe_log scores
  Debug.maybe_log ''
  Debug.maybe_log 'score: EXIT'
  Debug.set_maybe_false

  # 100 * pct_keys
  weights.map{|k, weight| scores[k] * weight}.sum
end

def full_precalculation(d, stats_hash)
  # First pass
  #   Anything seen on Twitter _not_ in the ith word's precalculated entry
  #   eliminates that word. (This is, I believe, equivalent to the current
  #   processing).
  # Second pass
  #   Rank based on absence of evidence. Consider holistically, not just
  #   the current max-4gs-seen array. How to include the count from the
  #   dictionary properly? Seems like the count will be different between
  #   the 4g and everything else. But maybe not (at least for the non-count
  #   ranking).
  #
  # It is likely possible to do both "first pass" and "second pass" at the
  # same time, from the same ranking function. Consider the remaining
  # dictionary of letters: {word1 => line_num1, word2 => line_num2}.
  # Perform a map where the word

  compressed_fingerprints = read_fingerprints_from_file
  fingerprints = decompress(compressed_fingerprints)

  # set d for now
  # d = {
  #   'whoop' => 'unused',
  #   'about' => 'unused',
  #   'above' => 'unused',
  #   'after' => 'unused',
  #   'along' => 'unused',
  #   'among' => 'unused',
  #   'raise' => 'unused',
  #   'clout' => 'unused',
  #   'windy' => 'unused',
  #   'blimp' => 'unused',
  #   'fight' => 'unused',
  #   'taunt' => 'unused',
  #   'sonic' => 'unused', # good alternative for Wordle 444 (taunt)
  # }

  # puts ''
  # puts 'd:'
  # puts d

  d = d
    .map{|word, line_num| [word, [[:word, word], [:line_num, line_num]].to_h]}
    .map{|word, data_hash| data_hash[:fingerprints] = fingerprints[word]; [word, data_hash]}
    .map{|word, data_hash| data_hash[:score] = score(word, stats_hash, data_hash[:fingerprints]); [word, data_hash]}
  # puts ''
  # puts 'd:'
  # puts d

  puts ''
  puts 'stats_hash:'
  puts stats_hash

  d.delete_if{|word, data_hash| data_hash[:score] == -1}
  d.delete_if{|word, data_hash| data_hash[:score] <= 50.0} # FIXME remove this
  d = d.sort_by {|word, data_hash| -1 * data_hash[:score]}

  puts ''
  puts 'd:'
  puts d

  puts ''
  puts ''
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

module Distances
  # i: Number of 4g matches from the fingerprint or 9, whichever is less
  # j: Array[i]: distance if Twitter high-water-mark is i
  DISTANCES_4G = [
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

  def Distances::calc_4g_distance(max_4gs_from_twitter, max_4gs_from_fingerprint)
    difference = [0, 0, 0, 0, 0]
    (0...5).each {|i|
      difference[i] = Distances::DISTANCES_4G[
        [max_4gs_from_fingerprint[i], 9].min][max_4gs_from_twitter[i]
      ].to_f}
    difference.sum
  end

  # Array[i]: Penalty for key-not-present given i matching words in the dictionary
  DISTANCES_NON_4G = [
    0, # shouldn't occur
    1, # by definition
    1.75,
    2.25,
    2.5, # cap it at 4
  ]

  def Distances::calc_non_4g_distance(stats_hash, fingerprint)
    fingerprint.dup
      .delete_if{|k,v| k.start_with?('4g')}
      .delete_if{|k,v| stats_hash.key?(k)}
      .map{|k,v| Distances::DISTANCES_NON_4G[[v,4].min]}
      .sum.to_f
  end
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
  # FIXME it is possible to see more matches on Twitter than mag-4gs if using
  #       a smaller dictionary (like dracos)
  # distances = [
  #   [0, [0]],
  #   [1, [1, 0]], # one valid word and nobody found it: defined as 1
  #   [2, [1.5, 0.75, 0]],
  #   [3, [2, 1, 0.5, 0]],
  #   [4, [2.5, 1.25, 0.6, 0.3, 0]],
  #   [5, [3, 1.5, 0.75, 0.37, 0.18, 0]],
  #   [6, [3.5, 1.75, 0.85, 0.42, 0.21, 0, 0]],
  #   [7, [4, 2, 1, 0.5, 0.25, 0, 0, 0]],
  #   [8, [4.5, 2.25, 1.12, 0.56, 0.28, 0, 0, 0, 0]],
  #   [9, [5, 2.5, 1.25, 0.6, 0.3, 0, 0, 0, 0, 0]],
  # ].to_h
  new_d = {}
  d.each do |key, _value|
    matches = all_4g_matches(key, Configuration.absence_of_evidence_filename)
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

def all_4g_matches(word, filename)
  return_array = [0, 0, 0, 0, 0]
  all_words = populate_valid_wordle_words(filename)
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

def calculate_constraint_cardinality(word_list_to_check=DEFAULT_CONSTRAINT_CARDINALITY_WORD_LIST)
  # The idea here is to precompute how many of each constraint there is
  # for each word, to pattern-match later based on twitter

  puts ''
  puts 'UNDER CONSTRUCTION'
  puts ''

  valid_wordle_words = populate_valid_wordle_words
  result_hash = {}
  word_list_to_check.each do |word|
    d = {}
    valid_wordle_words.each do |guess, _line_num|
      wordle_response = wordle_response(guess, word)
      interestingness = InterestingWordleResponses::determine_interestingness(wordle_response)
      case interestingness
      when InterestingWordleResponses::WORDLE_4G, InterestingWordleResponses::WORDLE_3G1Y, InterestingWordleResponses::WORDLE_3G2Y, InterestingWordleResponses::WORDLE_2G3Y, InterestingWordleResponses::WORDLE_1G4Y, InterestingWordleResponses::WORDLE_0G5Y
        _name, _subname, key = InterestingWordleResponses::calculate_name_subname_key(wordle_response, interestingness, 1)
        key = key[0,4] if interestingness == InterestingWordleResponses::WORDLE_4G
        d[key] = 0 if !d.key?(key)
        d[key] = d[key] + 1
      when InterestingWordleResponses::NOT_INTERESTING
      else
        raise "unknown interestingness"
      end
    end

    result_hash[word] = d
  end

  word_of_interest = 'whoop'

  result_hash[word_of_interest] = result_hash[word_of_interest].sort.to_h

  stats_hash = twitter[:stats]
  stats_hash = stats_hash.sort.to_h # make it look like others

  compact_result_hash = result_hash.map{|k,v| [k, v.map{|k2,v2| [CompactKeys::KEY_COMPRESSION_HASH[k2], v2]}.to_h]}
  puts "result_hash=#{result_hash}"
  puts ''
  puts "compact_result_hash=#{compact_result_hash}"
  puts ''
  puts "stats_hash=#{stats_hash}"
  puts ''

  # transform stats_hash to be more "result-hashy"
  # '4g.1.1 => 143, 4g.1.2 => 111, 4g.1.3'
  # =>
  # '4g.1 => 3'

  max_4gs_seen = max_4gs_seen_on_twitter(stats_hash)
  transformed_stats_hash = stats_hash
    .map{|k,v| [k,v]}.to_h # copy
    .delete_if {|k,v| k.start_with?('4g')}
  max_4gs_seen.each_with_index do |el, i|
    key = "4g.#{i+1}"
    value = el
    transformed_stats_hash[key]=value if value != 0
  end
  transformed_stats_hash = transformed_stats_hash.sort.to_h

  puts "transformed_stats_hash=#{transformed_stats_hash}"
  puts ''

  puts 'calculating delta from observed (Twitter) to actual (dictionary)'
  num_keys_twitter = transformed_stats_hash.keys.length
  num_keys_dictionary = result_hash[word_of_interest].keys.length
  num_in_twitter_only = 0
  transformed_stats_hash.keys.each{|k| num_in_twitter_only += 1 if !result_hash[word_of_interest].key?(k)}
  num_in_dictionary_only = 0
  result_hash[word_of_interest].keys.each{|k| num_in_dictionary_only += 1 if !transformed_stats_hash.key?(k)}
  puts "num_keys_twitter=#{num_keys_twitter}, num_keys_dictionary=#{num_keys_dictionary}"
  puts "num_in_twitter_only=#{num_in_twitter_only}, num_in_dictionary_only=#{num_in_dictionary_only}"
  puts ''
  puts "#{num_keys_twitter}/#{num_keys_dictionary} found on Twitter"
  puts ''

  # result_hash={"gully"=>{"3g1y.yellow4.white1"=>1, "4g.1"=>9, "3g1y.yellow3.white1"=>1, "4g.2"=>4, "4g.4"=>2, "4g.5"=>1, "4g.3"=>1, "3g1y.yellow3.white5"=>1}}
  # result_hash: '4g.1' has 9 words
  #
  # stats_hash={"4g.1.1"=>143, "4g.1.2"=>111, "4g.1.3"=>24, "4g.2.1"=>8, "4g.2.2"=>3, "4g.3.1"=>8, "4g.4.1"=>21, "4g.4.2"=>7, "4g.5.1"=>5, "3g1y.yellow3.white1"=>22, "3g1y.yellow4.white1"=>16}
  # note: ALERT: deleting key 4g.1.4 with value 1!
  # stats_hash: '4g.1.1' had 143 users, 4g.1.2 had 111 users, 4g.1.3 had 24 users
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

  fail unless all_4g_matches('hilly', VALID_WORDLE_WORDS_FILE) == [9, 3, 1, 0, 2]
  fail unless all_4g_matches('hills', VALID_WORDLE_WORDS_FILE) == [18, 3, 0, 2, 2]
  fail unless all_4g_matches('hilly', DRACOS_VALID_WORDLE_WORDS_FILE) == [7, 2, 1, 0, 2]
  fail unless all_4g_matches('hills', DRACOS_VALID_WORDLE_WORDS_FILE) == [18, 3, 0, 2, 2]

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

  kdh = CompactKeys::KEY_COMPRESSION_HASH
  max_compact_keys_value = kdh.values.max
  min_compact_keys_value = kdh.values.min
  fail unless kdh['4g.1'] == 0
  fail unless min_compact_keys_value == 0
  # this also guarantees that all keys are unique
  (min_compact_keys_value..max_compact_keys_value).each {|v| fail unless kdh.has_value?(v)}
end

run_tests
d = populate_all_words
UI.play(d)
