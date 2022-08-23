#!/usr/bin/ruby -w

require_relative 'twitter_test'

# copied from https://github.com/charlesreid1/five-letter-words
DICTIONARY_FILE_LARGE = 'sgb-words.txt'
DICTIONARY_FILE_SMALL = 'sgb-words-small.txt'
DICTIONARY_FILE = DICTIONARY_FILE_LARGE

# from https://gist.github.com/dracos/dd0668f281e685bad51479e5acaadb93
VALID_WORDLE_WORDS_FILE = 'valid-wordle-words.txt'

def populate_valid_wordle_words
  d = {}
  File.foreach(VALID_WORDLE_WORDS_FILE).with_index do |line, line_num|
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

INSTRUMENTATION_ONLY = true

def close(w1, w2)
  diff = 0
  (0...5).each {|i| diff += (w1[i]==w2[i] ? 0 : 1)}
  diff == 1
end

module UI
  LEFT_PADDING_DEFAULT = 20

  def UI::padded_puts(s)
    puts "#{' ' * LEFT_PADDING_DEFAULT}#{s}"
  end

  def UI::padded_print(s)
    print "#{' ' * LEFT_PADDING_DEFAULT}#{s}"
  end

  # What should the UI guidelines be?
  # - prompt_for_input should itself have guidelines... should prompts be grouped?
  # - should the "Enter a guess" line be changed to "Enter a guess (h for help)"?
  # What about having a UI.puts and UI.print, along with UI.debug and UI.prompt_for_input
  # - Do I really need UI.prompt_for_input?
  # - How about this: regular print/puts have a fixed left-padding, but prompt-for-input is right-aligned
  def self.play(d)
    puts ''
    UI::padded_puts '----------------------------------------------------------'
    UI::padded_puts '|                                                        |'
    UI::padded_puts '|                   Welcome to Wordle!                   |'
    UI::padded_puts '|                                                        |'
    UI::padded_puts '----------------------------------------------------------'
    for guess in 1..6
      UI::padded_puts "You are on guess #{guess}/6. #{remaining_count_string(d)}"
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
          stats_hash = twitter
          UI.print_remaining_count(d)
          if UI.maybe_filter_twitter(d, stats_hash)
            UI.maybe_absence_of_evidence(d, stats_hash)
          end
        when 'dad'
          print_a_dad_joke
        when 'test'
          calculate_constraint_cardinality
        when 'help', 'h'
          UI.print_usage
        when '' # pressing enter shouldn't cause "unrecognized input"
        else
          if choice.length == 5
            response = UI.prompt_for_input('Enter the response (!?-): ==> ', false)
            # print 'Enter the response (!?-): ==> '
            # response = gets.chomp
            filter(d, choice, response)
            break
          else
            puts "unrecognized input (#{choice})"
          end
        end
      end
    end
  end

  def self.maybe_absence_of_evidence(d, stats_hash)
    print 'Would you like to make deductions based on absence of evidence? (y/n) ==> '
    choice = gets.chomp
    case choice
    when 'y'
      penultimate_twitter_absence_of_evidence(d, stats_hash)
    when 'n'
    else
      puts "unrecognized input (#{choice}), skipping"
    end
  end

  # INPUT_RIGHT_ALIGNMENT = LEFT_PADDING_DEFAULT + 30

  # def self.prompt_for_input_old(input_string)
  #   padding = ' ' * [0, INPUT_RIGHT_ALIGNMENT - input_string.length].max
  #   # Print.just_print "#{padding}#{input_string}"
  #   print "#{padding}#{input_string}"
  #   return gets.chomp
  # end

  def self.prompt_for_input(input_string, prompt_on_new_line = true)
    if prompt_on_new_line
      padded_puts input_string
      padded_print '==> '
    else
      padded_print input_string
    end
    return gets.chomp
  end

  # def self.padding(s)
  #   max_padding = 50
  #   ' ' * [0, max_padding - s.length].max
  # end

  def self.maybe_filter_twitter(d, stats_hash)
    choice = self.prompt_for_input 'Would you like to proceed with filtering? (y/n) ==> '
    # print 'Would you like to proceed with filtering? (y/n) ==> '
    # choice = gets.chomp
    case choice
    when 'y'
      print "There are #{d.size} words remaining. Would you like to see filtering output? (y/n) ==> "
      choice2 = gets.chomp
      verbose = choice2 == 'y'
      stats_hash.each do |key, _value|
        key_array = key.split('.', 2)
        penultimate_twitter(d, key_array[0], key_array[1], verbose) if !INSTRUMENTATION_ONLY
        UI.print_remaining_count(d) # moving this here, to show filtering as it goes
      end
    when 'n'
    else
      puts "unrecognized input (#{choice}), skipping"
    end
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
    puts ''
    puts '.----------------------------------------------.'
    puts '|                                              |'
    puts '|                     Usage                    |'
    puts '|                                              |'
    puts '\----------------------------------------------/'
    puts 'c               : count'
    puts 'p               : print'
    puts 'pa              : print all'
    puts 'hint            : hint'
    puts 'q               : quit'
    puts ''
    puts 'penultimate     : run penultimate-style analysis'
    puts 'twitter         : run Twitter analysis'
    puts ''
    puts 'dad             : print a dad joke'
    puts 'help, h         : print this message'
    puts ''
  end

  def self.print_remaining_count(d)
    UI::padded_puts remaining_count_string(d)
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
    break if INSTRUMENTATION_ONLY
    found = false
    pp_dict.each do |key2, value2|
      if close(key1, key2)
        found = true
        pp_dict[key2] = value2 + 1
      end
    end
    pp_dict[key1] = 1 if !found
  end
  pp_dict = {'hilly': 3} if INSTRUMENTATION_ONLY
  UI::padded_puts 'Checking for problematic patterns...'
  pp_dict.each do |key, value|
    puts "\nPROBLEMATIC PATTERN ALERT: found \"#{key}\" with #{value} matching words (print for details)\n\n" if value > 2
  end
  puts 'No problematic patterns found!' if pp_dict.values.max <= 2
end

def calculate_constraint_cardinality
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

def penultimate_twitter_absence_of_evidence(d, stats_hash)
  #
  # Wordle 422 Twitter report below (great for implementing the "big feature").
  #/--------------------------------------\
  #|              Wordle 422              |
  #|            Twitter report            |
  #\--------------------------------------/
  #2918 Twitter posts seen
  #2852 Unique Twitter posts seen
  #2476 total answers
  #2331 correct
  #145 incorrect (5.86% failure)
  #1367/2331 are interesting
  #
  #4g.1.1 = 211
  #4g.1.2 = 9
  #4g.2.1 = 19
  #4g.3.1 = 787
  #4g.3.2 = 151
  #4g.3.3 = 9
  #4g.3.4 = 2
  #4g.5.1 = 37
  #4g.5.2 = 7
  #4g.5.3 = 3
  #1g4y.green1 = 2
  #3g1y.yellow3.white1 = 77
  #3g1y.yellow3.white5 = 49
  #
  #
  #
  #Would you like to make deductions based on absence of evidence? (y/n) ==> y
  #Absence of evidence is not evidence of absence!
  #max 4gs seen on Twitter: [2, 1, 4, 0, 3]
  #-------- new-d: start
  #key=gamer, difference=2, all-4g-matches=[3, 1, 5, 0, 3], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=poker, difference=5, all-4g-matches=[6, 2, 4, 0, 3], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=toker, difference=5, all-4g-matches=[6, 1, 5, 0, 3], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=toper, difference=6, all-4g-matches=[6, 1, 5, 0, 4], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=caper, difference=6, all-4g-matches=[6, 1, 6, 0, 3], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=toner, difference=6, all-4g-matches=[7, 1, 5, 0, 3], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=carer, difference=8, all-4g-matches=[6, 2, 6, 0, 4], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=paler, difference=9, all-4g-matches=[4, 3, 8, 0, 4], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=baker, difference=9, all-4g-matches=[11, 1, 4, 0, 3], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=taper, difference=11, all-4g-matches=[6, 1, 9, 1, 4], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=waker, difference=12, all-4g-matches=[11, 1, 7, 0, 3], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=pater, difference=13, all-4g-matches=[11, 1, 8, 0, 3], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=cures, difference=14, all-4g-matches=[7, 4, 4, 6, 3], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=cared, difference=16, all-4g-matches=[11, 3, 8, 0, 4], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=rates, difference=22, all-4g-matches=[12, 2, 11, 4, 3], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=motes, difference=23, all-4g-matches=[9, 4, 11, 4, 5], seen-on-twitter=[2, 1, 4, 0, 3]
  #key=pares, difference=29, all-4g-matches=[13, 4, 9, 7, 6], seen-on-twitter=[2, 1, 4, 0, 3]
  #-------- new-d: end
  #
  puts 'Absence of evidence is not evidence of absence!'
  # 4g-based analysis
  # sample entry in stash_hash: key=4g.3.1, value=7
  # Translation: The 3rd letter was white one time, for seven people
  # Plan
  #   1. Normalize the knowledge in stats_hash
  #   2. For remaining words in d, find how many matching words there are in valid-wordle-words.txt
  #   3. Do a text-based comparison (for now)

  # calculate the max 4g's seen per letter
  # [1, 0, 1, 0, 0] means the first and third letters had 4g matches, and only 4g.1.1 and 4g.3.1
  max_4gs_seen_on_twitter = [0, 0, 0, 0, 0]
  stats_hash.each do |key, value|
    key_array = key.split('.', 2)
    if key_array[0] == '4g'
      letter_position = key_array[1][0].to_i
      num_incorrect_4gs = key_array[1][2].to_i
      _num_people = value
      if num_incorrect_4gs > max_4gs_seen_on_twitter[letter_position-1]
        max_4gs_seen_on_twitter[letter_position-1] = num_incorrect_4gs
      end
    end
  end
  puts "max 4gs seen on Twitter: #{max_4gs_seen_on_twitter}"

  # puts '-------- stats_hash: begin'
  # stats_hash.each do |key, value|
  #   puts "key=#{key}, value=#{value}"
  # end
  # puts '-------- stats_hash: end'
  new_d = {}
  d.each do |key, _value|
    # key=laved, all_4g_matches=[6, 2, 10, 0, 2]
    matches = all_4g_matches(key)
    difference = [0, 0, 0, 0, 0]
    (0...5).each {|i| difference[i] = matches[i] - max_4gs_seen_on_twitter[i]}
    # difference = matches - max_4gs_seen_on_twitter
    # puts "key=#{key}, 4g_matches=#{matches}, difference=#{difference}"
    new_d[key] = [difference.sum, difference, matches, max_4gs_seen_on_twitter]
  end
  new_d = new_d.sort_by {|_key, value| value[0]}.to_h
  puts '-------- new-d: start'
  max_print = 50
  current_difference = -1
  # new_d.each_with_index {|(key, value), index| break if index >= max_print; puts "key=#{key}, difference=#{value[0]}, all-4g-matches=#{value[2]}, seen-on-twitter=#{value[3]}" }
  new_d.each_with_index do |(key, value), index|
    break if index >= max_print
    solution_number = PreviousWordleSolutions.check_word(key)
    maybe_alert = solution_number ? " -------- Alert! Wordle #{solution_number} solution was #{key} --------" : ''
    if value[0] != current_difference
      puts "-------- Difference #{value[0]} --------"
      current_difference = value[0]
    end
    puts "key=#{key}, difference=#{value[0]}, all-4g-matches=#{value[2]}, seen-on-twitter=#{value[3]}#{maybe_alert}"
  end
  puts "skipping #{new_d.size-max_print} additional results..." if d.size > max_print
  while true do
    print 'Enter a word to see its analysis line, or (q)uit: ==> '
    user_entered_word = gets.chomp
    break if user_entered_word == 'q'
    if new_d.key?(user_entered_word)
      key = user_entered_word
      value = new_d[key]
      solution_number = PreviousWordleSolutions.check_word(key)
      maybe_alert = solution_number ? " -------- Alert! Wordle #{solution_number} solution was #{key} --------" : ''
      puts "key=#{key}, difference=#{value[0]}, all-4g-matches=#{value[2]}, seen-on-twitter=#{value[3]}#{maybe_alert}"
    end
  end
  # new_d.each do |key, value|
  #   puts "key=#{key}, value=#{value}"
  #   total_printed += 1
  #   break if total_printed == max_print
  # end
  puts '-------- new-d: end'
end

def penultimate_twitter(d, pattern, subpattern, verbose)
  puts "penultimate_twitter called, pattern=#{pattern}, subpattern=#{subpattern}"
  case pattern
  when '4g'
    # 4g.3.1 = 25
    # 4g.3.2 = 8
    # 4g.3.3 = 1
    subpattern_array = subpattern.split('.')
    if subpattern_array.length() != 2
      puts 'unexpected length (4g subpattern)'
      return
    end
    gray = subpattern_array[0].to_i - 1
    count = subpattern_array[1].to_i
    Filter::filter_4g(d, gray, count, verbose)
  when '3g1y'
    # 3g1y.yellow3.white4 = 3
    subpattern_array = subpattern.split('.')
    if subpattern_array.length() != 2
      puts 'unexpected length (3g1y subpattern)'
      return
    end
    yellow = subpattern_array[0][6].to_i - 1
    gray = subpattern_array[1][5].to_i - 1
    Filter::filter_3g1y(d, yellow, gray, verbose)
  when '3g2y'
    # 3g2y.yellow24
    yellow1 = subpattern[6].to_i - 1
    yellow2 = subpattern[7].to_i - 1
    Filter::filter_3g2y(d, yellow1, yellow2, verbose)
  when '2g3y'
    # 2g3y.green24
    green1 = subpattern[5].to_i - 1
    green2 = subpattern[6].to_i - 1
    Filter::filter_2g3y(d, green1, green2, verbose)
  when '1g4y'
    # 1g4y.green3
    green = subpattern[5].to_i - 1
    Filter::filter_1g4y(d, green, verbose)
  when '0g5y'
    # 0g5y.
    Filter::filter_0g5y(d, verbose)
  else
    puts "#{pattern} not yet supported"
  end
end

def all_4g_matches(word)
  return_array = [0, 0, 0, 0, 0]
  alphabet = [
    'a','b','c','d','e','f','g','h','i','j','k','l','m',
    'n','o','p','q','r','s','t','u','v','w','x','y','z'
  ]
  all_words = populate_valid_wordle_words
  (0...5).each do |i|
    ith_sum = 0
    temp_word = word.dup
    alphabet.each do |letter|
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
end

module Filter
  def Filter::filter_4g(d, gray, count, verbose)
    d.each_key do |key|
      all_words = populate_valid_wordle_words
      for i in 0...5
        if i == gray
          all_words.delete_if { |key2, value2| key2[i] == key[i] }
        else
          all_words.delete_if { |key2, value2| key2[i] != key[i] }
        end
      end

      if all_words.size < count
        d.delete(key)
      else
        # print_string = "keeping #{key} ("
        # all_words.each_key {|key| print_string += "#{key}, "}
        # puts print_string[0..-3] + ')'
        puts "keeping #{key} (" + all_words.map { |k, v| "#{k}" }.join(', ') + ')' if verbose
      end
    end
  end

  def Filter::filter_3g1y(d, yellow, gray, verbose)
    d.each_key do |key|
      all_words = populate_valid_wordle_words
      for i in 0...5
        if i == yellow
          all_words.delete_if { |key2, value2| key2[i] != key[gray] }
        elsif i == gray
          all_words.delete_if { |key2, value2| key2[i] == key[gray] }
        else # green
          all_words.delete_if { |key2, value2| key2[i] != key[i] }
        end
      end
      if all_words.size == 0
        d.delete(key)
      else
        puts "keeping #{key} (" + all_words.map { |k, v| "#{k}" }.join(', ') + ')' if verbose
      end
    end
  end

  def Filter::filter_3g2y(d, yellow1, yellow2, verbose)
    all_words = populate_valid_wordle_words
    d.each_key do |key|
      switched_word = key.dup
      switched_word[yellow1] = key[yellow2]
      switched_word[yellow2] = key[yellow1]
      if key != switched_word and all_words.key?(switched_word)
        puts "keeping #{key} (#{switched_word})" if verbose
      else
        d.delete(key)
      end
    end
  end

  def Filter::filter_2g3y(d, green1, green2, verbose)
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
        puts "keeping #{key} (" + all_words.map { |k, v| "#{k}" }.join(', ') + ')' if verbose
      end
    end
  end

  def Filter::filter_1g4y(d, green, verbose)
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
        puts "keeping #{key} (" + all_words.map { |k, v| "#{k}" }.join(', ') + ')' if verbose
      end
    end
  end

  def Filter::filter_0g5y(d, verbose)
    d.each_key do |key|
      all_words = populate_valid_wordle_words
      for i in 0...5
        # all yellows
        all_words.delete_if { |key2, value2| key2[i] == key[i] || key2.count(key2[i]) != key.count(key2[i]) }
      end
      if all_words.size == 0
        d.delete(key)
      else
        puts "keeping #{key} (" + all_words.map { |k, v| "#{k}" }.join(', ') + ')' if verbose
      end
    end
  end
end

def penultimate(d)
  puts 'Choose a Twitter penultimate guess'
  puts '4 greens (4g)'
  puts '3 greens and 1 yellow (3g1y)'
  puts '3 greens and 2 yellows (3g2y)'
  puts '2 greens and 3 yellows (2g3y)'
  puts '1 green and 4 yellows (1g4y)'
  puts '0 greens and 5 yellows (0g5y)'
  print '==> '
  choice = gets.chomp
  case choice
  when '4g'
    print 'Enter the position of the gray (1-5): ==> '
    gray = gets.chomp.to_i - 1
    print 'Enter the count: ==> '
    count = gets.chomp.to_i
    Filter::filter_4g(d, gray, count)
  when '3g1y'
    print 'Enter the position of the yellow (1-5): ==> '
    yellow = gets.chomp.to_i - 1
    print 'Enter the position of the gray (1-5): ==> '
    gray = gets.chomp.to_i - 1
    Filter::filter_3g1y(d, yellow, gray)
  when '3g2y'
    print 'Enter the positions of the two yellows (1-5): ==> '
    yellows = gets.chomp
    yellow1 = yellows[0].to_i - 1
    yellow2 = yellows[1].to_i - 1
    Filter::filter_3g2y(d, yellow1, yellow2)
  when '2g3y'
    print 'Enter the positions of the two greens (1-5): ==> '
    greens = gets.chomp
    green1 = greens[0].to_i - 1
    green2 = greens[1].to_i - 1
    Filter::filter_2g3y(d, green1, green2)
  when '1g4y'
    print 'Enter the position of the green (1-5): ==> '
    green = gets.chomp.to_i - 1
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
  # puts "d.size: #{d.size()}"
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
end

run_tests
d = populate_all_words
UI.play(d)
