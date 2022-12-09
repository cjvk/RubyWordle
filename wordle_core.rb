#!/usr/bin/ruby -w

require 'date'

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
# Got words_alpha.txt from https://github.com/dwyl/english-words, transform & sort:
# cat words_alpha.txt | grep '^\([a-z]\{5\}\)[^a-z]$' | sed 's/^\(.....\).$/\1/' > words_alpha.txt.grep.sed
# copy valid-wordle-words.txt, remove comments, and sort: valid-wordle-words-words-only.txt.sort
# comm -13 words_alpha.txt.grep.sed.sort valid-wordle-words-words-only.txt.sort > non-word-valid-wordle-words.txt
# Verified first five words (aapas, aarti, abacs, abaht, abaya) are in valid-wordle-words but not in words_alpha
# % wc -l non-word-valid-wordle-words.txt
#     4228 non-word-valid-wordle-words.txt

module Wekele
  DOWN_ARROW = "\u{2B07}"
  UP_ARROW = "\u{2B06}"
  SEPARATOR = "\u{FE0F}"
  SPACE = " "

  FIVE_DOWN_ARROWS = /(#{DOWN_ARROW}#{SEPARATOR}#{SPACE}){4}#{DOWN_ARROW}/
  FIVE_UP_ARROWS = /(#{UP_ARROW}#{SEPARATOR}#{SPACE}){4}#{UP_ARROW}/
end

module WordleShareColors
  # Normal mode
  # e.g. https://twitter.com/mobanwar/status/1552908148696129536
  GREEN = "\u{1F7E9}"
  YELLOW = "\u{1F7E8}"
  WHITE = "\u{2B1C}"
  NORMAL_MODE_PATTERN = /[#{GREEN}#{YELLOW}#{WHITE}][#{GREEN}#{YELLOW}#{WHITE}][#{GREEN}#{YELLOW}#{WHITE}][#{GREEN}#{YELLOW}#{WHITE}][#{GREEN}#{YELLOW}#{WHITE}]/

  # Dark mode
  # https://twitter.com/SLW551505/status/1552871344680886278
  # green and yellow as before, but black instead of white
  BLACK = "\u{2B1B}"
  DARK_MODE_PATTERN = /[#{GREEN}#{YELLOW}#{BLACK}][#{GREEN}#{YELLOW}#{BLACK}][#{GREEN}#{YELLOW}#{BLACK}][#{GREEN}#{YELLOW}#{BLACK}][#{GREEN}#{YELLOW}#{BLACK}]/

  # name: Decided on "Deborah mode"
  # https://twitter.com/DeborahDtfpress/status/1552860375602778112
  # white   => white
  # yellow  => blue
  # green   => orange
  BLUE = "\u{1F7E6}"
  ORANGE = "\u{1F7E7}"
  DEBORAH_MODE_PATTERN = /[#{WHITE}#{BLUE}#{ORANGE}][#{WHITE}#{BLUE}#{ORANGE}][#{WHITE}#{BLUE}#{ORANGE}][#{WHITE}#{BLUE}#{ORANGE}][#{WHITE}#{BLUE}#{ORANGE}]/

  # "Deborah-dark" mode
  # https://twitter.com/sandraschulze/status/1552673827766689792
  # white   => black
  # yellow  => blue
  # green   => orange
  DEBORAH_DARK_MODE_PATTERN = /[#{BLACK}#{BLUE}#{ORANGE}][#{BLACK}#{BLUE}#{ORANGE}][#{BLACK}#{BLUE}#{ORANGE}][#{BLACK}#{BLUE}#{ORANGE}][#{BLACK}#{BLUE}#{ORANGE}]/

  # Other useful patterns
  ANY_WORDLE_SQUARE = /[#{GREEN}#{YELLOW}#{WHITE}#{BLACK}#{BLUE}#{ORANGE}]/
  ANY_WORDLE_SQUARE_PLUS_NEWLINE = /[#{GREEN}#{YELLOW}#{WHITE}#{BLACK}#{BLUE}#{ORANGE}\n]/
  NON_WORDLE_CHARACTERS = /[^#{GREEN}#{YELLOW}#{WHITE}#{BLACK}#{BLUE}#{ORANGE}\n]/
end

module WordleModes
  NORMAL_MODE = 'Normal'
  DARK_MODE = 'Dark'
  DEBORAH_MODE = 'Deborah'
  DEBORAH_DARK_MODE = 'DeborahDark'
  UNKNOWN_MODE = 'Unknown'

  def self.determine_mode(text)
    # This would typically be called if text is "probably a wordle post"
    if text.include?(WordleShareColors::ORANGE) || text.include?(WordleShareColors::BLUE)
      if text.include? WordleShareColors::BLACK
        mode = DEBORAH_DARK_MODE
      else
        mode = DEBORAH_MODE
      end
    elsif text.include?(WordleShareColors::GREEN) || text.include?(WordleShareColors::YELLOW)
      if text.include? WordleShareColors::BLACK
        mode = DARK_MODE
      else
        mode = NORMAL_MODE
      end
    else
      mode = UNKNOWN_MODE
    end
    mode
  end

  MODES_TO_PATTERNS = [
    [NORMAL_MODE, WordleShareColors::NORMAL_MODE_PATTERN],
    [DARK_MODE, WordleShareColors::DARK_MODE_PATTERN],
    [DEBORAH_MODE, WordleShareColors::DEBORAH_MODE_PATTERN],
    [DEBORAH_DARK_MODE, WordleShareColors::DEBORAH_DARK_MODE_PATTERN],
  ].to_h
  def self.mode_to_pattern(mode)
    MODES_TO_PATTERNS[mode]
  end

  UNICODES_TO_NORMALIZED_STRINGS = {
    NORMAL_MODE => { # not sure why but '=>' works, but ':' does not
      WordleShareColors::WHITE => 'w',
      WordleShareColors::YELLOW => 'y',
      WordleShareColors::GREEN => 'g',
    },
    DARK_MODE => {
      WordleShareColors::BLACK => 'w',
      WordleShareColors::YELLOW => 'y',
      WordleShareColors::GREEN => 'g',
    },
    DEBORAH_MODE => {
      WordleShareColors::WHITE => 'w',
      WordleShareColors::BLUE => 'y',
      WordleShareColors::ORANGE => 'g',
    },
    DEBORAH_DARK_MODE => {
      WordleShareColors::BLACK => 'w',
      WordleShareColors::BLUE => 'y',
      WordleShareColors::ORANGE => 'g',
    },
  }
  def self.unicode_to_normalized_string(unicode_string, mode)
    UNICODES_TO_NORMALIZED_STRINGS[mode][unicode_string]
  end
end

module InterestingWordleResponses
  WORDLE_4G   = 1
  WORDLE_3G1Y = 2
  WORDLE_3G2Y = 3
  WORDLE_2G3Y = 4
  WORDLE_1G4Y = 5
  WORDLE_0G5Y = 6
  NOT_INTERESTING = 7

  def InterestingWordleResponses::num_with_color(color, word)
    num_with_color = 0
    (0...5).each { |i| num_with_color += 1 if word[i] == color }
    num_with_color
  end

  def InterestingWordleResponses::determine_interestingness(wordle_response)
    # wordle_response is a 5-character string normalized to g/y/w
    # e.g. "ygwyy" for a guess of saner and a wordle of raise
    num_g = num_with_color('g', wordle_response)
    num_y = num_with_color('y', wordle_response)
    num_w = num_with_color('w', wordle_response)
    return InterestingWordleResponses::WORDLE_4G if num_g == 4 && num_w == 1
    return InterestingWordleResponses::WORDLE_3G1Y if num_g == 3 && num_y == 1
    return InterestingWordleResponses::WORDLE_3G2Y if num_g == 3 && num_y == 2
    return InterestingWordleResponses::WORDLE_2G3Y if num_g == 2 && num_y == 3
    return InterestingWordleResponses::WORDLE_1G4Y if num_g == 1 && num_y == 4
    return InterestingWordleResponses::WORDLE_0G5Y if num_g == 0 && num_y == 5
    return InterestingWordleResponses::NOT_INTERESTING
  end

  def InterestingWordleResponses::calculate_name_subname_key(wordle_response, interestingness, count=0)
    case interestingness
    when InterestingWordleResponses::WORDLE_4G
      name = '4g'
      subname = "#{wordle_response.index('w')+1}.#{count}"
    when InterestingWordleResponses::WORDLE_3G1Y
      name = '3g1y'
      subname = "yellow#{wordle_response.index('y')+1}.white#{wordle_response.index('w')+1}"
    when InterestingWordleResponses::WORDLE_3G2Y
      name = '3g2y'
      y1 = wordle_response.index('y')
      y2 = wordle_response.index('y', y1+1)
      subname = "yellow#{y1+1}#{y2+1}"
    when InterestingWordleResponses::WORDLE_2G3Y
      name = '2g3y'
      g1 = wordle_response.index('g')
      g2 = wordle_response.index('g', g1+1)
      subname = "green#{g1+1}#{g2+1}"
    when InterestingWordleResponses::WORDLE_1G4Y
      name = '1g4y'
      g = wordle_response.index('g')
      subname = "green#{g+1}"
    when InterestingWordleResponses::WORDLE_0G5Y
      name = '0g5y'
      subname = ''
    when InterestingWordleResponses::NOT_INTERESTING
      raise "Error: NOT_INTERESTING sent to calculate_name_subname_key"
    else
      raise "Error: unknown interestingness"
    end
    key = "#{name}.#{subname}"
    return name, subname, key
  end
end

WORDLE_DAY_0 = Date.civil(2021, 6, 19).freeze

def today_wordle_number
  now = Date.today
  difference_in_days = (now - WORDLE_DAY_0).to_i
  wordle_number = difference_in_days.to_s
  wordle_number
end

def wordle_number_or_default(suppress_output: false)
  [Twitter::Configuration.wordle_number_override]
    .map{|ovr| (!ovr || suppress_output) || Debug.log_terse("user-specified wordle number: #{ovr}"); ovr}
    .map{|override| override or today_wordle_number}[0].to_s
end

def wordle_number_to_date(wordle_number)
  (WORDLE_DAY_0 + wordle_number.to_i).strftime('%m/%d/%Y')
end

def close(w1, w2)
  diff = 0
  (0...5).each {|i| diff += (w1[i]==w2[i] ? 0 : 1)}
  diff == 1
end

def check_for_problematic_patterns(d)
  # e.g. Wordle 265 ("watch"), after raise-clout (-!---, ?---?)
  # legal words remaining: watch, match, hatch, patch, batch, natch, tacky
  # 6 words with _atch, plus tacky
  pp_dict = {}
  d.each do |key1, _value1|
    break if Twitter::Configuration.instrumentation_only
    found = false
    pp_dict.each do |key2, value2|
      if close(key1, key2)
        found = true
        pp_dict[key2] = value2 + 1
      end
    end
    pp_dict[key1] = 1 if !found
  end
  if Twitter::Configuration.instrumentation_only
    Debug.log 'skipped problematic pattern loop, using hardcoded result'
    pp_dict = {'hilly': 3, 'floss': 10} if Twitter::Configuration.instrumentation_only
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

def num_green_or_yellow(word, response, letter)
  num_green_or_yellow = 0
  (0...5).each { |i| num_green_or_yellow += 1 if word[i] == letter && response[i] != '-' }
  return num_green_or_yellow
end

def scrabble_score_old(word)
  scrabble_letter_scores = [
    ['a', 1], ['f', 4], ['k', 5], ['p', 3], ['u', 1],
    ['b', 3], ['g', 2], ['l', 1], ['q', 10], ['v', 4],
    ['c', 3], ['h', 4], ['m', 3], ['r', 1], ['w', 4],
    ['d', 2], ['i', 1], ['n', 1], ['s', 1], ['x', 8],
    ['e', 1], ['j', 8], ['o', 1], ['t', 1], ['y', 4], ['z', 10],
  ].to_h
  word.chars.map{|c| scrabble_letter_scores[c]}.sum
end

def scrabble_score(word)
  scrabble_letter_scores = [
    [1, 'aeioulnstr'],
    [2, 'dg'],
    [3, 'bcmp'],
    [4, 'fhvwy'],
    [5, 'k'],
    [8, 'jx'],
    [10, 'qz'],
  ]
    .map{|score, letters| letters.chars.map{|letter| [letter, score]}}
    .flatten(1)
    .to_h
  word.chars.map{|c| scrabble_letter_scores[c]}.sum
end

PROBABLE_PLURALS = {}
def plural?(word)
  if PROBABLE_PLURALS.empty?
    File.foreach(DICTIONARY_FILE_LIKELY_PLURALS).with_index do |line, line_num|
      PROBABLE_PLURALS[line.chomp] = line_num
    end
    PROBABLE_PLURALS.freeze
  end
  PROBABLE_PLURALS.key? word
end

module PreviousWordleSolutions
  @@previous_wordle_solutions = nil

  def self.all_solutions
    if @@previous_wordle_solutions == nil
      @@previous_wordle_solutions = {}
      line_num = 0
      File.foreach('previous_wordle_solutions.txt') do |line|
        next if line.start_with?('#')
        @@previous_wordle_solutions[line[0..4]] = line_num
        line_num += 1
      end

      @@previous_wordle_solutions.freeze
    end

    @@previous_wordle_solutions
  end

  def self.check_word(word)
    PreviousWordleSolutions.all_solutions[word]
  end

  def self.occurred_before(word)
    PreviousWordleSolutions.all_solutions[word] != nil &&
      PreviousWordleSolutions.all_solutions[word] < wordle_number_or_default(suppress_output: true).to_i
  end

  def self.lookup_by_number(n)
    PreviousWordleSolutions.all_solutions.key n
  end

  def self.maybe_alert_string(word)
    [word]
      .map{|word| PreviousWordleSolutions.check_word(word)}
      .map{|maybe_number| maybe_number ?
           " -------- Alert! Wordle #{maybe_number} solution was #{word} --------" : ''}[0]
  end
end

module Filter
  def Filter::filter(d, word, response)
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

  def Filter::replace_ith_letter(word, i, letter)
    word_copy = word.dup
    word_copy[i] = letter
    word_copy
  end

  def Filter::filter_4g(d, gray, count)
    # filter_4g(populate_all_words, 2, 1) 100 times: 6.7s
    all_words = populate_valid_wordle_words

    d.each_key do |key|
      remaining_words = []
      num_valid_alternatives = ALPHABET
        .map{|c| replace_ith_letter(key, gray, c)}
        .delete_if{|word_to_check| word_to_check == key || !all_words.key?(word_to_check)}
        .map{|remaining_word| remaining_words.append(remaining_word); 1}
        .to_a
        .sum

      if num_valid_alternatives < count
        d.delete(key)
      else
        Debug.maybe_log "keeping #{key} (" + remaining_words.join(', ') + ')'
      end
    end
    d
  end

  def Filter::filter_3g1y(d, yellow, gray)
    # filter_3g1y(populate_all_words, 1, 2) 100 times: 7.1s
    # yellow and grey are 0-indexed
    all_words = populate_valid_wordle_words
    d.each_key do |key|
      remaining_words = []
      # ensure yellow and gray are different
      d.delete(key) if key[yellow] == key[gray]

      # make a copy, save the yellow, and copy over the gray
      key_copy = key.dup
      letter_at_yellow = key_copy[yellow]
      letter_at_gray = key_copy[gray]
      key_copy[yellow] = key_copy[gray] # moving the letter makes it get a yellow

      num_valid_alternatives = ALPHABET.dup
        .delete_if{|c| c == letter_at_yellow || c == letter_at_gray}
        .map{|c| replace_ith_letter(key_copy, gray, c)}
        .delete_if{|word_to_check| !all_words.key?(word_to_check)}
        .map{|remaining_word| remaining_words.append(remaining_word); 1}
        .to_a
        .sum

      if num_valid_alternatives == 0
        d.delete(key)
      else
        Debug.maybe_log "keeping #{key} (" + remaining_words.join(', ') + ')'
      end
    end
    d
  end

  def Filter::filter_3g2y(d, yellow1, yellow2)
    # filter_3g2y(populate_all_words, 1, 2) 100 times: 0.6s
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
    d
  end

  def Filter::filter_2g3y(d, green1, green2)
    filter_2g3y_v2(d, green1, green2)
  end
  def Filter::filter_2g3y_v3(d, green1, green2)
    # filter_2g3y_v3(populate_all_words, 1, 2) ONE time: 691s (0:11:31)
    d.delete_if do |word, _|
      matches = populate_valid_wordle_words.dup
        .map{|guess, _| [guess, wordle_response(guess, word)]}
        .map{|guess, wordle_response| [guess, InterestingWordleResponses::determine_interestingness(wordle_response)]}
        .delete_if{|guess, interestingness| interestingness != InterestingWordleResponses::WORDLE_2G3Y}
        .map{|guess, interestingness| guess}

      Debug.maybe_log "keeping #{word} (" + matches.map { |k, v| "#{k}" }.join(', ') + ')' if matches.size > 0
      matches.size == 0
    end
  end
  def Filter::filter_2g3y_v2(d, green1, green2)
    # filter_2g3y_v2(populate_all_words, 1, 2) 5 times: 132.9s (26.6s)
    yellows = (0...5).to_a.delete_if{|i| i==green1 || i==green2}
    d.delete_if do |key, _|
      # [1, 3, 4]
      matches = populate_valid_wordle_words.dup
        .delete_if{|key2, _| key[green1] != key2[green1] || key[green2] != key2[green2]}
        .delete_if{|key2, _| yellows.map{|y| (key[y]==key2[y]||key2.count(key2[y])!=key.count(key2[y]))?1:0}.max==1}
        .map{|key2, _| key2}

      Debug.maybe_log "keeping #{key} (" + matches.map { |k, v| "#{k}" }.join(', ') + ')' if matches.size > 0
      matches.size == 0
    end
  end
  def Filter::filter_2g3y_v1(d, green1, green2)
    # filter_2g3y_v1(populate_all_words, 1, 2) 5 times: 242.2s (48.4s)
    d.each_key do |key|
      all_words = populate_valid_wordle_words.dup
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
    d
  end

  def Filter::filter_1g4y(d, green)
    # filter_1g4y(populate_all_words, 1) 5 times: 244.1s (48.8s)
    d.each_key do |key|
      all_words = populate_valid_wordle_words.dup
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
    d
  end

  def Filter::filter_0g5y(d)
    # filter_0g5y(populate_all_words) 3 times: 155.8s (51.9s)
    d.each_key do |key|
      all_words = populate_valid_wordle_words.dup
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
    d
  end
end
