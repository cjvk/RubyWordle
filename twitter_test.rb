#!/usr/bin/ruby -w

# require 'twitter'
require 'faraday'
require 'json'
require 'date'

module Configuration
  # Twitter API calls
  @@results = 100
  @@pages = 5

  #         Uncomment this to query a specific wordle number
  # @@wordle_number_override = 422

  #         Uncomment this to enable debug printing for a specific tweet_id
  # @@debug_print_tweet_id = '1559163924548915201'

  #         Uncomment to enable printing of ALL penultimate which match this pattern
  # @@print_this_penultimate_pattern = 'wgggw' # use normalized colors (g/y/w)

  # author_id denylist: If this gets too large, use a hash instead?
  @@author_id_denylist = [
    ['1487026288682418180', '@6wordle'],
    ['911760502333743104', '@Vat_of_useless'],
  ].map { |x| [x[0], x[1]] }.to_h
  # @@author_id_denylist_hash = @@author_id_denylist.map { |x| [x, 0] }.to_h

  # interesting Twitter handles and author IDs
  # https://tweeterid.com/
  # https://commentpicker.com/twitter-id.php
  #
  # habanerohiker / 45384296
  #         appears to have authored a bot (https://twitter.com/habanerohiker/status/1559163924548915201)
  # 6Wordle / 1487026288682418180
  #         Wordle 421 was KHAKI, and his penultimate was YGGYY (!) which is impossible
  #         https://twitter.com/6Wordle/status/1558951610197258241
  #         The account description says "I do wordle in 6/6 every day so even the 5/6 friends can be proud"
  # Vat_of_useless / 911760502333743104
  #         https://twitter.com/Vat_of_useless/status/1554551230864560128
  #         The answer was "coyly", and the penultimate guess was ygwgg.
  #         I asked what their second-to-last guess was, they said "lobby".
  #         I followed up with "wouldn't that be ygwwg", and now I'm blocked (!)
  #         Follow-up: Appears to be no way for "yo?ly" to be a word

  def self.results
    @@results
  end
  def self.pages
    @@pages
  end
  def self.wordle_number_override
    defined?(@@wordle_number_override) ? @@wordle_number_override : nil
  end
  def self.debug_print_tweet_id
    defined?(@@debug_print_tweet_id) ? @@debug_print_tweet_id : nil
  end
  def self.print_this_penultimate_pattern
    defined?(@@print_this_penultimate_pattern) ? @@print_this_penultimate_pattern : nil
  end
  def self.author_id_denylist
    @@author_id_denylist
  end
end

#############################################################################
#
#      Wordles solved in 1
#
#      Wordle 423 (GRUEL): first one
#      Wordle 426 (SHRUG): Enema/sugar eliminated b/c previous solutions
#      Wordle 427 (TREAT)
#      Wordle 428 (WASTE): Sonic eliminated b/c previous solution
#      Wordle 429 (MERIT)
#
#############################################################################

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

module InterestingWordleResponses
  # TODO Is it possible to nest modules? Can this help with separating logic from Answer.is_interesting()?
  WORDLE_4G   = 1
  WORDLE_3G1Y = 2
  WORDLE_3G2Y = 3
  WORDLE_2G3Y = 4
  WORDLE_1G4Y = 5
  WORDLE_0G5Y = 6
  NOT_INTERESTING = 7

  def InterestingWordleResponses::determine_interestingness(wordle_response)
    # wordle_response is a 5-character string normalized to g/y/w
    # e.g. "ygwyy" for a guess of saner and a wordle of raise
    num_g = num_with_color('g', wordle_response)
    num_y = num_with_color('y', wordle_response)
    num_w = num_with_color('w', wordle_response)
    # puts "wordle_response=#{wordle_response}, g/y/w=#{num_g}/#{num_y}/#{num_w}"
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

def num_with_color(color, word)
  num_with_color = 0
  (0...5).each { |i| num_with_color += 1 if word[i] == color }
  num_with_color
end

class Answer
  # array of "Normal-mode" squares
  def initialize(guess_array, id, author_id)
    @guess_array = guess_array
    @id = id
    @author_id = author_id
    @is_interesting = nil
    @key = nil
  end
  def generic_tweet_url
    "https://twitter.com/anyuser/status/#{@id}"
  end
  def author_id
    @author_id
  end
  def matches_key(key)
    @is_interesting != nil && @is_interesting && @key == key
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
    interestingness = InterestingWordleResponses::determine_interestingness(penultimate)
    case interestingness
    when InterestingWordleResponses::WORDLE_4G
      # count how many of these occurred
      count = 1
      (num_guesses-2).downto(1) { |i| count+= 1 if get_guess(i) == penultimate }
      _name, _subname, @key = InterestingWordleResponses::calculate_name_subname_key(penultimate, InterestingWordleResponses::WORDLE_4G, count)
      # name = '4g'
      # subname = "#{penultimate.index('w')+1}.#{count}"
      create_or_increment("#{@key}", stats)
      @is_interesting = true
      return true
    when InterestingWordleResponses::WORDLE_3G1Y, InterestingWordleResponses::WORDLE_3G2Y, InterestingWordleResponses::WORDLE_2G3Y, InterestingWordleResponses::WORDLE_1G4Y, InterestingWordleResponses::WORDLE_0G5Y
      _name, _subname, @key = InterestingWordleResponses::calculate_name_subname_key(penultimate, interestingness)
      create_or_increment("#{@key}", stats)
      @is_interesting = true
      return true
    when InterestingWordleResponses::NOT_INTERESTING
      @is_interesting = false
      return false
    else
      raise "unknown interestingness"
    end
  end
  def create_or_increment(name, hash)
    if hash.key?(name)
      hash[name] = hash[name] + 1
    else
      hash[name] = 1
    end
  end
end

def twitter
  now = Date.today
  wordle_day_0 = Date.civil(2021, 6, 19)
  difference_in_days = (now - wordle_day_0).to_i
  wordle_number = difference_in_days.to_s
  if Configuration.wordle_number_override != nil
    wordle_number = Configuration.wordle_number_override
    puts "using user-specified wordle number: #{wordle_number}"
  end
  answers = []
  total_twitter_posts = 0
  unique_twitter_posts = {}
  skipped_twitter_posts = 0
  num_failures = 0

  # get the auth token
  file = File.open('twitter_auth_token')
  file_data = file.read
  file.close
  auth_token = file_data.chomp
  search_queries = [
    "wordle%20#{wordle_number}",   # "wordle 420"
    "%23wordle%20#{wordle_number}" # "#wordle 420"
  ]

  search_queries.each do |search_query|
    next_token = ''
    (0...Configuration.pages).each do |page_num|
      # https://developer.twitter.com/en/docs/twitter-api/tweets/search/api-reference/get-tweets-search-recent

      # quit early if nothing remaining
      next if page_num != 0 && next_token == ''

      # handle next token
      next_token_get_parameter = page_num == 0 ? "" : "&next_token=#{next_token}"

      url = "https://api.twitter.com/2/tweets/search/recent?query=#{search_query}&tweet.fields=created_at,author_id&max_results=#{Configuration.results}#{next_token_get_parameter}"

      response = Faraday.get(url, nil, {'Accept' => 'application/json', 'Authorization' => "Bearer #{auth_token}"})
      parsed_json = JSON.parse(response.body)

      next_token = parsed_json['meta'].key?('next_token') ? parsed_json['meta']['next_token'] : ''

      # transform into array of Answer objects
      # (w)hite, (y)ellow, (g)reen
      # puts "-------- id=#{parsed_json['data'][0]['id']}, author_id=#{parsed_json['data'][0]['author_id']}"
      for result in parsed_json['data']
        text = result['text']
        id = result['id']
        author_id = result['author_id']
        debug_print_it = Configuration.debug_print_tweet_id != nil && Configuration.debug_print_tweet_id == id
        puts "result=#{result}" if debug_print_it
        total_twitter_posts += 1
        # skip those we've already seen
        if unique_twitter_posts.key?(id)
          next
        else
          unique_twitter_posts[id] = '1'
        end
        # check the denylist
        if Configuration.author_id_denylist.include?(author_id)
          skipped_twitter_posts += 1
          next
        end
        if is_probably_a_wordle_post?(text, wordle_number)
          puts 'is probably a wordle post!' if debug_print_it

          # determine how many guesses they took
          # because text is "probably a wordle post", it should match
          num_guesses = text.match(/Wordle #{wordle_number} ([1-6X])\/6/)

          if !num_guesses
            # equivalent of Unknown mode above
            next
          end

          # get the first match
          num_guesses = num_guesses[1]

          if num_guesses == 'X'
            # no solution found - record if a failure and skip
            num_failures += 1
            next
          end

          # convert
          num_guesses = num_guesses.to_i

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

          # if mode is unknown, skip
          if mode == 'Unknown'
            next
          end
          puts "mode = #{mode}" if debug_print_it

          # construct the normalized guess_array
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

          if guess_array[guess_array.length()-2] == Configuration.print_this_penultimate_pattern
            puts '-------- TEXT: BEGIN     --------'
            puts text
            puts '-------- TEXT: END       --------'
            puts '-------- RESULT: BEGIN   --------'
            puts result
            puts '-------- RESULT: END     --------'
          end

          answers.append(Answer.new(guess_array, id, author_id))

        end
      end
    end
  end

  # post-processing
  stats = {}
  num_interesting = 0
  for answer in answers
    if answer.is_interesting(stats)
      num_interesting += 1
    end
  end

  # remove entries if they have exactly one occurrence (possible goofballs)
  # stats.delete_if { |key, value| value == 1 }
  stats.delete_if do |key, value|
    if value == 1
      for answer in answers
        if answer.matches_key(key)
          puts "Alert: deleting key #{key} with value 1! (#{answer.generic_tweet_url}) (author_id=#{answer.author_id})"
          break
        end
      end
    end
    value == 1
  end

  # sort stats, '4g' to the top
  stats = stats.sort_by {|key, value| [key.split('.', 2)[0] == '4g' ? 0 : 1, key]}.to_h

  # print the report
  # TODO add average number of guesses, or a histogram, or something
  puts ''
  puts '/--------------------------------------\\'
  puts "|              Wordle #{wordle_number}              |"
  puts '|            Twitter report            |'
  puts '\--------------------------------------/'
  puts "#{total_twitter_posts} Twitter posts seen"
  puts "#{unique_twitter_posts.size} Unique Twitter posts seen"
  puts "#{skipped_twitter_posts} skipped"
  puts "#{answers.length()+num_failures} total answers"
  puts "#{answers.length} correct"
  puts "#{num_failures} incorrect (#{'%.2f' % (num_failures*100/(answers.length().to_f+num_failures))}% failure)"
  puts "#{num_interesting}/#{answers.length()} are interesting"
  puts ''

  stats.each {|key, value| puts "#{key} = #{value}"}
  puts ''
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

def is_probably_a_wordle_post?(text, wordle_number)
  !! (text =~ /Wordle #{wordle_number} [123456X]\/6/)
end
