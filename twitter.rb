#!/usr/bin/ruby -w

# require 'twitter'
require 'faraday'
require 'json'
require 'date'

module Configuration
  # Twitter API calls
  @@results = 100
  @@pages = 5

  # Set to true to skip "long" functions
  @@instrumentation_only = false

  #         Uncomment this to query a specific wordle number
  # @@wordle_number_override = 433

  #         Uncomment this to enable debug printing for a specific tweet_id
  # @@debug_print_tweet_id = '1559163924548915201'

  #         Uncomment to enable printing of ALL penultimate which match this pattern
  # @@print_this_penultimate_pattern = 'wgggw' # use normalized colors (g/y/w)

  #         Uncomment to enable printing of ALL answers which match this key
  # @@print_answers_matching_this_key = '4g.5.5'

  # Goofball processing: down to 423


  # "Goofball mode", where denylist and allowlist is disabled, and singletons are not eliminated
  @@goofball_mode = false

  # username/author ID conversion sites: https://tweeterid.com/, https://commentpicker.com/twitter-id.php
  # interesting Twitter handles and author IDs
  # habanerohiker / 45384296
  #         appears to have authored a bot (https://twitter.com/habanerohiker/status/1559163924548915201)

  def self.results
    @@results
  end
  def self.pages
    @@pages
  end
  def self.instrumentation_only
    @@instrumentation_only
  end
  def self.wordle_number_override
    defined?(@@wordle_number_override) ? @@wordle_number_override : nil
  end
  def self.set_wordle_number_override new_wordle_number
    Debug.log "Setting wordle_number_override to: #{new_wordle_number}"
    @@wordle_number_override = new_wordle_number
  end
  def self.debug_print_tweet_id
    defined?(@@debug_print_tweet_id) ? @@debug_print_tweet_id : nil
  end
  def self.print_this_penultimate_pattern
    defined?(@@print_this_penultimate_pattern) ? @@print_this_penultimate_pattern : nil
  end
  def self.print_answers_matching_this_key
    defined?(@@print_answers_matching_this_key) ? @@print_answers_matching_this_key : nil
  end
  def self.set_goofball_mode b
    @@goofball_mode = b
  end
  def self.goofball_mode?
    @@goofball_mode
  end
  def self.author_id_denylist
    return {} if @@goofball_mode
    YAML.load_file('author_id_denylist.yaml')
      .map{|el| raise "problem!" if el['verdict'] != 'deny'; el}
      .map{|el| [el['author_id'].to_s, el['name']]}
      .to_h
  end
  def self.author_id_allowlist
    return {} if @@goofball_mode
    YAML.load_file('author_id_allowlist.yaml')
      .map{|el| raise "problem!" if el['verdict'] != 'allow'; el}
      .map{|el| [el['author_id'].to_s, el['name']]}
      .to_h
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
#      Wordle 433 (IRONY)
#
#############################################################################

module WordleTweetColors
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

def print_a_dad_joke
  url = 'https://icanhazdadjoke.com/'
  response = Faraday.get(url, {a: 1}, {'Accept' => 'application/json'})
  joke_object = JSON.parse(response.body, symbolize_names: true)
  puts joke_object[:joke]
end

module InterestingWordleResponses
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
  def self.generic_tweet_url id
    "https://twitter.com/anyuser/status/#{id}"
  end
  def generic_tweet_url
    Answer.generic_tweet_url @id
  end
  def author_id
    @author_id
  end
  def pp
    UI::padded_puts "tweet: #{generic_tweet_url}"
    UI::padded_puts "author_id: #{author_id}"
    UI::padded_puts "key: #{@key}"
    puts ''
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
    wordle_number = Configuration.wordle_number_override.to_s
    Debug.log_terse "using user-specified wordle number: #{wordle_number}"
  end
  answers = []
  total_twitter_posts = 0
  unique_twitter_posts = {}
  skipped_twitter_posts = 0
  num_failures = 0

  # get the auth token
  file = File.open('auth_token_twitter')
  file_data = file.read
  file.close
  auth_token = file_data.chomp
  search_queries = [
    "wordle%20#{wordle_number}",   # "wordle 420"
    "%23wordle%20#{wordle_number}" # "#wordle 420"
  ]

  # TODO is there a way to eliminate retweets?
  # example original tweet: https://twitter.com/ilikep4pp4roni/status/1565602075337187328
  # example retweet: https://twitter.com/JohnnyDee62/status/1565637313287307267

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
        Debug.set_maybe (Configuration.debug_print_tweet_id != nil && Configuration.debug_print_tweet_id == id)
        Debug.maybe_log "result=#{result}"
        total_twitter_posts += 1
        # skip those we've already seen
        if unique_twitter_posts.key?(id)
          next
        else
          unique_twitter_posts[id] = '1'
        end
        # check the denylist
        if Configuration.author_id_denylist.include?(author_id)
          allowlisted_too = Configuration.author_id_allowlist.include?(author_id)
          al_str = allowlisted_too ? ' (author allowlisted too!)' : ''
          Debug.log "skipping tweet, denylist (#{Answer.generic_tweet_url id}) (author_id=#{author_id})#{al_str}"
          skipped_twitter_posts += 1
          next
        end
        if is_probably_a_wordle_post?(text, wordle_number)
          Debug.maybe_log 'is probably a wordle post!'

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
          Debug.maybe_log "wordle_squares_begin = #{wordle_squares_begin}"
          first_non_wordle_character = text.index(WordleTweetColors::NON_WORDLE_CHARACTERS, wordle_squares_begin)
          Debug.maybe_log "wordle_begin_index=#{wordle_begin_index}"
          Debug.maybe_log "first_non_wordle_character=#{first_non_wordle_character}"
          if first_non_wordle_character != nil
            text = text[wordle_begin_index..first_non_wordle_character - 1]
          end

          # determine mode
          mode = WordleModes.determine_mode(text)

          # if mode is unknown, skip
          if mode == WordleModes::UNKNOWN_MODE
            next
          end
          Debug.maybe_log_terse "mode = #{mode}"

          # construct the normalized guess_array
          current_index = 0
          guess_array = []
          pattern = WordleModes.mode_to_pattern(mode)
          for _ in 0...num_guesses
            matching_index = text.index(pattern, current_index)
            if matching_index == nil
              next
            end
            guess_string = ''
            for j in 0...5
              guess_string += WordleModes.unicode_to_normalized_string(text[matching_index+j], mode)
            end
            current_index = matching_index + 1
            guess_array.append(guess_string)

          end

          if guess_array.length() != num_guesses
            Alert.alert "guess array not correct length! (#{Answer.generic_tweet_url id}) (author_id=#{author_id})"
            next
          end

          if guess_array[guess_array.length()-2] == Configuration.print_this_penultimate_pattern
            Debug.log '-------- TEXT: BEGIN     --------'
            Debug.log text
            Debug.log '-------- TEXT: END       --------'
            Debug.log '-------- RESULT: BEGIN   --------'
            Debug.log result
            Debug.log '-------- RESULT: END     --------'
          end

          answers.append(Answer.new(guess_array, id, author_id))

        end
      end
      Debug.set_maybe_false
    end
  end

  # post-processing
  stats = {}
  num_interesting = 0
  total_guesses_histogram = [0, 0, 0, 0, 0, 0]
  for answer in answers
    if answer.is_interesting(stats)
      num_interesting += 1
    end
    total_guesses_histogram[answer.num_guesses - 1] = total_guesses_histogram[answer.num_guesses - 1] + 1
  end

  # calculate mean and mode
  total_guesses = 0
  mode_index = -1
  mode_value = -1
  total_guesses_histogram.each_with_index do |val, i|
    total_guesses += (i+1) * val
    if val > mode_value
      mode_value = val
      mode_index = i
    end
  end
  Debug.log_verbose "average number of guesses: #{'%.2f' % (total_guesses/(answers.length.to_f+num_failures))}"
  Debug.log_verbose "the most common number of guesses was #{mode_index+1} (#{mode_value} times)"

  # remove entries if they have exactly one occurrence (possible goofballs)
  # stats.delete_if { |key, value| value == 1 }
  stats.delete_if do |key, value|
    break if Configuration.goofball_mode?
    author_allowlisted = false
    if value == 1
      for answer in answers
        if answer.matches_key(key)
          url = answer.generic_tweet_url
          author_id = answer.author_id
          if Configuration.author_id_allowlist.include?(answer.author_id)
            author_allowlisted = true
            Debug.log "keeping key #{key} with value 1 (author allowlisted). (#{url}) (author_id=#{author_id})"
          else
            Alert.alert "deleting key #{key} with value 1! (#{url}) (author_id=#{author_id})"
          end
          break
        end
      end
    end
    value == 1 && !author_allowlisted
  end

  # sort stats, '4g' to the top
  stats = stats.sort_by {|key, value| [key.split('.', 2)[0] == '4g' ? 0 : 1, key]}.to_h

  # print the report
  incorrect_percentage = num_failures*100/(answers.length().to_f+num_failures)
  avg_number_of_guesses = total_guesses/(answers.length.to_f+num_failures)
  puts ''
  UI.padded_puts '/--------------------------------------\\'
  UI.padded_puts "|              Wordle #{wordle_number}              |"
  UI.padded_puts '|            Twitter report            |'
  UI.padded_puts '\--------------------------------------/'
  UI.padded_puts "#{total_twitter_posts} Twitter posts seen"
  UI.padded_puts "#{unique_twitter_posts.size} Unique Twitter posts seen"
  UI.padded_puts "#{skipped_twitter_posts} skipped"
  UI.padded_puts "#{answers.length()+num_failures} total answers"
  UI.padded_puts "#{answers.length} correct answers"
  UI.padded_puts "#{num_failures} incorrect (#{'%.2f' % incorrect_percentage}% failure)"
  UI.padded_puts "#{'%.2f' % avg_number_of_guesses}: Average number of guesses"
  UI.padded_puts "#{mode_index+1}: Most common number of guesses (#{mode_value} times)"
  UI.padded_puts "#{num_interesting}/#{answers.length()} are interesting"
  puts ''

  stats.each {|key, value| UI.padded_puts "#{key} = #{value}"}
  puts ''
  UI.padded_puts '----------------------------------------'
  puts ''

  if Configuration.print_answers_matching_this_key != nil
    matching_key = Configuration.print_answers_matching_this_key
    UI::padded_puts "Printing all answers matching key #{matching_key}"
    puts ''
    answers.each {|answer| answer.pp if answer.matches_key(matching_key)}
    UI.padded_puts '----------------------------------------'
    UI::padded_puts ''
  end

  {
    stats: stats,
    answers: answers
  }
end

module WordleModes
  NORMAL_MODE = 'Normal'
  DARK_MODE = 'Dark'
  DEBORAH_MODE = 'Deborah'
  DEBORAH_DARK_MODE = 'DeborahDark'
  UNKNOWN_MODE = 'Unknown'

  def self.determine_mode(text)
    # This would typically be called if text is "probably a wordle post"
    if text.include?(WordleTweetColors::ORANGE) || text.include?(WordleTweetColors::BLUE)
      if text.include? WordleTweetColors::BLACK
        mode = DEBORAH_DARK_MODE
      else
        mode = DEBORAH_MODE
      end
    elsif text.include?(WordleTweetColors::GREEN) || text.include?(WordleTweetColors::YELLOW)
      if text.include? WordleTweetColors::BLACK
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
    [NORMAL_MODE, WordleTweetColors::NORMAL_MODE_PATTERN],
    [DARK_MODE, WordleTweetColors::DARK_MODE_PATTERN],
    [DEBORAH_MODE, WordleTweetColors::DEBORAH_MODE_PATTERN],
    [DEBORAH_DARK_MODE, WordleTweetColors::DEBORAH_DARK_MODE_PATTERN],
  ].to_h
  def self.mode_to_pattern(mode)
    MODES_TO_PATTERNS[mode]
  end

  UNICODES_TO_NORMALIZED_STRINGS = {
    NORMAL_MODE => { # not sure why but '=>' works, but ':' does not
      WordleTweetColors::WHITE => 'w',
      WordleTweetColors::YELLOW => 'y',
      WordleTweetColors::GREEN => 'g',
    },
    DARK_MODE => {
      WordleTweetColors::BLACK => 'w',
      WordleTweetColors::YELLOW => 'y',
      WordleTweetColors::GREEN => 'g',
    },
    DEBORAH_MODE => {
      WordleTweetColors::WHITE => 'w',
      WordleTweetColors::BLUE => 'y',
      WordleTweetColors::ORANGE => 'g',
    },
    DEBORAH_DARK_MODE => {
      WordleTweetColors::BLACK => 'w',
      WordleTweetColors::BLUE => 'y',
      WordleTweetColors::ORANGE => 'g',
    },
  }
  def self.unicode_to_normalized_string(unicode_string, mode)
    UNICODES_TO_NORMALIZED_STRINGS[mode][unicode_string]
  end
end

def is_probably_a_wordle_post?(text, wordle_number)
  !! (text =~ /Wordle #{wordle_number} [123456X]\/6/)
end
