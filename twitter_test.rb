#!/usr/bin/ruby -w

# require 'twitter'
require 'faraday'
require 'json'
require 'date'

# standard (confirmed working)
# e.g. https://twitter.com/mobanwar/status/1552908148696129536
GREEN = "\u{1F7E9}"
YELLOW = "\u{1F7E8}"
WHITE = "\u{2B1C}"
NORMAL_MODE_PATTERN = /[#{GREEN}#{YELLOW}#{WHITE}][#{GREEN}#{YELLOW}#{WHITE}][#{GREEN}#{YELLOW}#{WHITE}][#{GREEN}#{YELLOW}#{WHITE}][#{GREEN}#{YELLOW}#{WHITE}]/

# dark mode?
# https://twitter.com/SLW551505/status/1552871344680886278
# green and yellow as before, but black instead of white
BLACK = "\u{2B1B}"
DARK_MODE_PATTERN = /[#{GREEN}#{YELLOW}#{BLACK}][#{GREEN}#{YELLOW}#{BLACK}][#{GREEN}#{YELLOW}#{BLACK}][#{GREEN}#{YELLOW}#{BLACK}][#{GREEN}#{YELLOW}#{BLACK}]/

# name: ???
# https://twitter.com/DeborahDtfpress/status/1552860375602778112
# white   => white
# yellow  => blue
# green   => orange
BLUE = "\u{1F7E6}"
ORANGE = "\u{1F7E7}"
DEBORAH_MODE_PATTERN = /[#{WHITE}#{BLUE}#{ORANGE}][#{WHITE}#{BLUE}#{ORANGE}][#{WHITE}#{BLUE}#{ORANGE}][#{WHITE}#{BLUE}#{ORANGE}][#{WHITE}#{BLUE}#{ORANGE}]/

# "Deborah-dark" mode
# https://twitter.com/sandraschulze/status/1552673827766689792
DEBORAH_DARK_MODE_PATTERN = /[#{BLACK}#{BLUE}#{ORANGE}][#{BLACK}#{BLUE}#{ORANGE}][#{BLACK}#{BLUE}#{ORANGE}][#{BLACK}#{BLUE}#{ORANGE}][#{BLACK}#{BLUE}#{ORANGE}]/

ANY_WORDLE_SQUARE = /[#{GREEN}#{YELLOW}#{WHITE}#{BLACK}#{BLUE}#{ORANGE}]/
ANY_WORDLE_SQUARE_PLUS_NEWLINE = /[#{GREEN}#{YELLOW}#{WHITE}#{BLACK}#{BLUE}#{ORANGE}\n]/
NON_WORDLE_CHARACTERS = /[^#{GREEN}#{YELLOW}#{WHITE}#{BLACK}#{BLUE}#{ORANGE}\n]/

def print_a_dad_joke
  url = 'https://icanhazdadjoke.com/'
  response = Faraday.get(url, {a: 1}, {'Accept' => 'application/json'})
  joke_object = JSON.parse(response.body, symbolize_names: true)
  puts joke_object[:joke]
end

class Answer
  # array of "Normal-mode" squares
  def initialize(guess_array)
    @guess_array = guess_array
  end
  def num_guesses
    @guess_array.length()
  end
  def get_guess(guess_number)
    @guess_array[guess_number-1]
  end
  def penultimate
    get_guess(num_guesses-1)
  end
  def is_interesting(stats)
    penultimate = penultimate()
    if num_with_color('g', penultimate) == 4
      # count how many of these occurred
      count = 1
      (num_guesses-2).downto(1) { |i| count+= 1 if get_guess(i) == penultimate }
      # puts 'count = #{count}'
      name = '4g'
      subname = "#{penultimate.index('w')+1}.#{count}"
      # subname = (penultimate.index('w') + 1).to_s
      create_or_increment("#{name}.#{subname}", stats)
      return true
    end
    if num_with_color('g', penultimate) == 3 && num_with_color('y', penultimate) == 1
      name = '3g1y'
      subname = "yellow#{penultimate.index('y')+1}.white#{penultimate.index('w')+1}"
      create_or_increment("#{name}.#{subname}", stats)
      return true
    end
    if num_with_color('g', penultimate) == 3 && num_with_color('y', penultimate) == 2
      name = '3g2y'
      y1 = penultimate.index('y')
      y2 = penultimate.index('y', y1+1)
      subname = "yellow#{y1+1}#{y2+1}"
      create_or_increment("#{name}.#{subname}", stats)
      return true
    end
    if num_with_color('g', penultimate) == 2 && num_with_color('y', penultimate) == 3
      name = '2g3y'
      g1 = penultimate.index('g')
      g2 = penultimate.index('g', g1+1)
      subname = "green#{g1+1}#{g2+1}"
      # y1 = penultimate.index('y')
      # y2 = penultimate.index('y', y1+1)
      # y3 = penultimate.index('y', y2+1)
      # subname = "yellow#{y1+1}#{y2+1}#{y3+1}"
      create_or_increment("#{name}.#{subname}", stats)
      return true
    end
    if num_with_color('g', penultimate) == 1 && num_with_color('y', penultimate) == 4
      name = '1g4y'
      g = penultimate.index('g')
      subname = "green#{g+1}"
      create_or_increment("#{name}.#{subname}", stats)
      return true
    end
    if num_with_color('y', penultimate) == 5
      name = '0g5y'
      subname = ''
      create_or_increment("#{name}.#{subname}", stats)
      return true
    end
    false
  end
  def num_with_color(color, word)
    num_with_color = 0
    (0...5).each { |i| num_with_color += 1 if word[i] == color }
    num_with_color
  end
  def create_or_increment(name, hash)
    if hash.key?(name)
      hash[name] = hash[name] + 1
    else
      hash[name] = 1
    end
  end
end

module UrlSpecifier
  WITH_HASHTAG = 1
  WITHOUT_HASHTAG = 2
end

def twitter(url_specifier=UrlSpecifier::WITHOUT_HASHTAG)
  # print 'Enter Wordle number: ==> '
  # wordle_number = gets.chomp
  now = Date.today
  wordle_day_0 = Date.civil(2021, 6, 19)
  difference_in_days = (now - wordle_day_0).to_i
  wordle_number = difference_in_days.to_s
  results = 100
  pages = 10

  answers = []
  num_failures = 0
  next_token = ''

  # get the auth token
  file = File.open('twitter_auth_token')
  file_data = file.read
  file.close
  auth_token = file_data.chomp

  (0...pages).each do |page_num|
    # https://developer.twitter.com/en/docs/twitter-api/tweets/search/api-reference/get-tweets-search-recent

    # handle next token
    next_token_get_parameter = page_num == 0 ? "" : "&next_token=#{next_token}"

    case url_specifier
    when UrlSpecifier::WITHOUT_HASHTAG
      url = "https://api.twitter.com/2/tweets/search/recent?query=wordle%20#{wordle_number}&tweet.fields=created_at&max_results=#{results}#{next_token_get_parameter}"
    when UrlSpecifier::WITH_HASHTAG
      url = "https://api.twitter.com/2/tweets/search/recent?query=%23wordle%20#{wordle_number}&tweet.fields=created_at&max_results=#{results}#{next_token_get_parameter}"
    else
      # shouldn't happen
      url = ''
    end

    response = Faraday.get(url, nil, {'Accept' => 'application/json', 'Authorization' => "Bearer #{auth_token}"})
    parsed_json = JSON.parse(response.body)

    # puts '-------- next token: start'
    # puts parsed_json['meta']['next_token']
    # puts '-------- next token: end'
    next_token = parsed_json['meta']['next_token']

    # transform into array of Answer objects
    # (w)hite, (y)ellow, (g)reen
    # Answer.guess_array = ['wwwwy', 'ywwww', 'yywyw', 'wwwwy', 'yyyww', 'ggggg']
    # https://twitter.com/Thousandkoban/status/1553269881952681985
    for result in parsed_json['data']
      text = result['text']
      id = result['id']
      debug_print_it = (id == '1555234404812857344') && false
      if is_probably_a_wordle_post?(text, wordle_number)
        puts 'is probably a wordle post!' if debug_print_it

        # determine how many guesses they took
        if text.include? "Wordle #{wordle_number} 1/6"
          num_guesses = 1
        elsif text.include? "Wordle #{wordle_number} 2/6"
          num_guesses = 2
        elsif text.include? "Wordle #{wordle_number} 3/6"
          num_guesses = 3
        elsif text.include? "Wordle #{wordle_number} 4/6"
          num_guesses = 4
        elsif text.include? "Wordle #{wordle_number} 5/6"
          num_guesses = 5
        elsif text.include? "Wordle #{wordle_number} 6/6"
          num_guesses = 6
        elsif text.include? "Wordle #{wordle_number} X/6"
          num_guesses = 'X'
        else
          num_guesses = 'Unknown'
        end

        if num_guesses == 'X' || num_guesses == 'Unknown'
          # puts 'not a solution, skipping'
          if num_guesses == 'X'
            num_failures += 1
          end
          next
        end

        # before determining mode, only determine based on the wordle answer
        # some goofballs do Wordle in regular mode and Worldle in dark mode
        # e.g. https://twitter.com/fire__girl/status/1555234404812857344
        # so restrict only to looking at the wordle answer
        wordle_begin_pattern = /Wordle #{wordle_number} [123456]\/6/
        wordle_begin_index = text.index(wordle_begin_pattern)
        wordle_begin_pattern_length = wordle_number.to_i < 1000 ? 14 : 15
        # typically 2 newline characters
        wordle_squares_begin = wordle_begin_index + wordle_begin_pattern_length + 2
        puts "wordle_squares_begin = #{wordle_squares_begin}" if debug_print_it
        first_non_wordle_character = text.index(NON_WORDLE_CHARACTERS, wordle_squares_begin)
        puts "wordle_begin_index=#{wordle_begin_index}" if debug_print_it
        puts "first_non_wordle_character=#{first_non_wordle_character}" if debug_print_it
        if first_non_wordle_character != nil
          text = text[wordle_begin_index..first_non_wordle_character - 1]
        end

        # determine mode
        if text.include? "#{ORANGE}"
          if text.include? "#{BLACK}"
            mode = 'Deborah-dark'
          else
            mode = 'Deborah'
          end
        elsif text.include? "#{BLACK}"
          mode = 'Dark'
        elsif text.include? "#{WHITE}"
          mode = 'Normal'
        else
          mode = 'Unknown'
        end

        if mode == 'Unknown'
          # puts 'unknown mode, skipping'
          next
        end
        puts "mode = #{mode}" if debug_print_it

        current_index = 0
        guess_array = []
        for _ in 0...num_guesses
          case mode
          when 'Normal'
            pattern = NORMAL_MODE_PATTERN
          when 'Dark'
            pattern = DARK_MODE_PATTERN
          when 'Deborah'
            pattern = DEBORAH_MODE_PATTERN
          when 'Deborah-dark'
            pattern = DEBORAH_DARK_MODE_PATTERN
          end
          matching_index = text.index(pattern, current_index)
          if matching_index == nil
            next
          end
          guess_string = ''
          for j in 0...5
            guess_string += unicode_to_normalized_string(text[matching_index+j], mode)
          end
          current_index = matching_index + 1
          guess_array.append(guess_string)

        end

        if guess_array.length() != num_guesses
          generic_tweet_url = "https://twitter.com/anyuser/status/#{id}"
          puts "Alert: guess array not correct length! (#{generic_tweet_url})"
          next
        end

        if guess_array[guess_array.length()-1] == 'ggggy'
          # Suppose you find a result to dig further on
          # https://www.bram.us/2017/11/22/accessing-a-tweet-using-only-its-id-and-without-the-twitter-api/
          # above just redirects to this:
          # https://twitter.com/anyuser/status/1554551230864560128
          # which redirects to this:
          # https://twitter.com/Vat_of_useless/status/1554551230864560128
          #
          # https://twitter.com/Vat_of_useless/status/1554551230864560128
          # The answer was "coyly", and the penultimate guess was ygwgg.
          # I asked what their second-to-last guess was, they said "lobby".
          # I followed up with "wouldn't that be ygwwg", and now I'm blocked (!)
          # Follow-up: Appears to be no way for "yo?ly" to be a word
          #
          # https://twitter.com/NerizArielle/status/1555215699152211969
          # Answer: "rhyme"
          # Penultimate guess: gggwg
          # Same as above for https://twitter.com/katheryn_avila/status/1555210731603247104
          # Solved: Wordle considers "rhyne" to be a word
          if false
            puts '-------- TEXT: BEGIN     --------'
            puts text
            puts '-------- TEXT: END       --------'
            puts '-------- RESULT: BEGIN   --------'
            puts result
            puts '-------- RESULT: END     --------'
          end
        end

        answers.append(Answer.new(guess_array))

      end

    end

  end

  puts ''
  puts '/--------------------------------------\\'
  puts "|              Wordle #{wordle_number}              |"
  puts '|            Twitter report            |'
  puts '\--------------------------------------/'
  puts "collected #{answers.length()} answers from #{results*pages} Twitter results"

  stats = {}
  num_interesting = 0
  for answer in answers
    if answer.is_interesting(stats)
      num_interesting += 1
    end
  end

  # sort stats
  stats = stats.sort.to_h

  puts "#{num_interesting}/#{answers.length()} are interesting"
  puts ''
  # first pass: '4g'
  stats.each do |key, value|
    key_array = key.split('.', 2)
    puts "#{key} = #{value}" if key_array[0] == '4g'
  end
  # second pass: everything else
  stats.each do |key, value|
    key_array = key.split('.', 2)
    puts "#{key} = #{value}" if key_array[0] != '4g'
  end
  puts ''
  puts "#{num_failures}/#{results*pages} did not solve"
  puts '----------------------------------------'
  puts ''

  stats
end

def unicode_to_normalized_string(unicode_string, mode)
  case mode
  when 'Normal'
    case unicode_string
    when WHITE
      return 'w'
    when YELLOW
      return 'y'
    when GREEN
      return 'g'
    else
      return -1
    end
  when 'Dark'
    case unicode_string
    when BLACK
      return 'w'
    when YELLOW
      return 'y'
    when GREEN
      return 'g'
    end
  when 'Deborah'
    case unicode_string
    when WHITE
      return 'w'
    when BLUE
      return 'y'
    when ORANGE
      return 'g'
    end
  when 'Deborah-dark'
    case unicode_string
    when BLACK
      return 'w'
    when BLUE
      return 'y'
    when ORANGE
      return 'g'
    end
  end
end

def is_a_wordle_post_old?(text, wordle_number)
  text.include? "Wordle #{wordle_number} 2/6"
end

def is_probably_a_wordle_post?(text, wordle_number)
  !! (text =~ /Wordle #{wordle_number} [123456X]\/6/)
end

# print_a_dad_joke

# twitter

