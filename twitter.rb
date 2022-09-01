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

  # Goofball processing: down to 423


  # "Goofball mode", where denylist and allowlist is disabled, and singletons are not eliminated
  @@goofball_mode = false
  # username/author ID conversion sites: https://tweeterid.com/, https://commentpicker.com/twitter-id.php
  # TODO move denylist and allowlists to a separate file?
  @@author_id_denylist = [
    # https://twitter.com/chryo29t/status/1563129697382195200: Definite Goofball!
    ['140922619', 'chryo29t'], # Wordle 433 (irony), 4g.3.1: []
    # https://twitter.com/FergalSweeney/status/1563808124817100801
    ['2742981849', 'FergalSweeney'], # Wordle 435 (GAUZE), 4g.4.3: only 2 matches: gauje/gauge
    # https://twitter.com/filafresh/status/1562290346259783680
    ['23026561', 'filafresh'], # Wordle 430 (woven), 4g.5.1: []
    # https://twitter.com/LoveSkate_Love/status/1564238522487574529: Definite Goofball!
    ['799098238548643841', 'LoveSkate_Love'], # Wordle 436 (chief), 3g1y.yellow5.white2: []
    # https://twitter.com/polterguyst/status/1563945348355473411: Definite Goofball!
    ['1346120687233077249', 'polterguyst'], # Wordle 434 (ruder), 4g.4.1: []
    # https://twitter.com/RepublicanDalek/status/1565005705727410178: Definite Goofball!
    ['308900763', 'RepublicanDalek'], # Wordle 438 (prize), 4g.3.1: ()
    # https://twitter.com/toon_mikwee/status/1564239878971424771: Possible Goofball
    ['2267620176', 'toon_mikwee'], # Wordle 436 (chief), 4g.1.3: ["thief"]
    # https://twitter.com/toukxa/status/1563677960917229568: Definite Goofball!
    ['702337186893410304', 'toukxa'], # Wordle 433 (irony), 3g2y.yellow13: []
    # https://twitter.com/Vat_of_useless/status/1554551230864560128
    # I asked, they said 'lobby', I replied "wouldn't that be YGWWG", then they blocked me (!)
    ['911760502333743104', 'Vat_of_useless'], # Wordle 409 (COYLY), YGWGG (impossible)
    # https://twitter.com/visakrish/status/1563814700462514176
    ['122248029', 'visakrish'], # Wordle 435 (GAUZE), 4g.2.1: impossible (only gauze matches "g.uze")
    # https://twitter.com/6Wordle/status/1558951610197258241
    # The account description says "I do wordle in 6/6 every day so even the 5/6 friends can be proud"
    ['1487026288682418180', '6wordle'], # Wordle 421 (KHAKI), YGGYY (impossible).
  ].to_h

  @@author_id_allowlist = [
    # https://twitter.com/anamayzubiria/status/1564715923390472197: Not a Goofball
    ['OK', '60993797', 'anamayzubiria'], # Wordle 437 (onset), 3g1y.yellow5.white2: (owsen)
    # https://twitter.com/awlgae_mm/status/1563899715347169281
    ['OK', '1533447006', 'awlgae_mm'], # Wordle 435 (GAUZE), 4g.5.1: gauzy
    # https://twitter.com/Backstreetsmac/status/1564730691841101824: Not a Goofball
    ['OK', '38323083', 'Backstreetsmac'], # Wordle 437 (onset), 3g1y.yellow5.white3: (onces)
    # https://twitter.com/C_Muteba/status/1565472253705392131: Not a Goofball
    ['OK', '198585104', 'C_Muteba'], # Wordle 439 (fungi), 4g.1.2: (lungi/mungi/pungi)
    # https://twitter.com/Dave_DSilent/status/1564758254193848320: Not a Goofball
    ['OK', '1056203598', 'Dave_DSilent'], # Wordle 437 (onset), 4g.5.1: (onsen)
    # https://twitter.com/Dope_Dan/status/1565393035139194882: Not a Goofball
    ['OK', '166221335', 'Dope_Dan'], # Wordle 439 (fungi), 3g1y.yellow1.white4: (gundi)
    # https://twitter.com/FeelUnusual/status/1565062742402293765: Not a Goofball
    ['OK', '1337774146655293443', 'FeelUnusual'], # Wordle 438 (prize), 4g.1.1: (brize/frize/grize)
    # https://twitter.com/FergalSweeney/status/1562375685892603904
    ['OK', '2742981849', 'FergalSweeney'], # Wordle 431 (NEEDY), 3g1y.yellow1.white4, deedy/deely
    # https://twitter.com/gortex2/status/1565101262735130625: Not a Goofball
    ['OK', '242823233', 'gortex2'], # Wordle 438 (prize), 3g1y.yellow4.white2: (paire)
    # https://twitter.com/HughRoberts05/status/1562385965490081792
    ['OK', '315843621', 'HughRoberts05'], # Wordle 431 (NEEDY), 4g.3.2, neddy/nerdy
    # https://twitter.com/inamy45/status/1564983467946811399: Not a Goofball
    ['OK', '4728764066', 'inamy45'], # Wordle 438 (prize), 4g.2.1: (peize)
    # https://twitter.com/inosffirehs/status/1563208536179351552
    ['OK', '140688018', 'inosffirehs'], # Wordle 433 (IRONY), 4g.5.2: irons/irone
    # https://twitter.com/jf_scapes/status/1564236330401398784: Not a Goofball
    ['OK', '946614010077523968', 'jf_scapes'], # Wordle 436 (chief), 0g5y.: ["fiche"]
    # https://twitter.com/JoshRey100/status/1562543624012713985
    ['OK', '2168411925', 'JoshRey100'], # Wordle 431 was NEEDY, 3g1y.yellow5.white4, (neeld)
    # https://twitter.com/kitchen38jp/status/1562701812947623936: Not a Goofball
    ['OK', '265368603', 'kitchen38jp'], # Wordle 426 (shrug), 4g.5.1: (shrub)
    # https://twitter.com/LysanderTheLion/status/1564586413538033664: Not a Goofball
    ['OK', '1406775085264998402', 'LysanderTheLion'], # Wordle 437 (onset), 4g.5.1: (onsen)
    # https://twitter.com/Madly_Total/status/1562238786037219328: Not a Goofball
    ['OK', '1235603239598542848', 'Madly_Total'], # Wordle 428 (waste), 4g.1.4: (baste/caste/haste/paste/taste)
    # https://twitter.com/MankyPanky8D/status/1562318621757476866
    ['OK', '1558549097673412609', 'MankyPanky8D'], # Wordle 430 (woven), 4g.3.3: ["woken", "women", "woxen"]
    # https://twitter.com/michelle4mmkh4/status/1562452851711811584
    ['OK', '468854236', 'michelle4mmkh4'], # Wordle 431 (NEEDY), 4g.1.3, many -EEDY options
    # https://twitter.com/moore_hype/status/1563595600880619520: Not a Goofball
    ['OK', '989297528419078144', 'moore_hype'], # Wordle 424 (twice), 4g.4.1: (twine/twire/twite)
    # https://twitter.com/mXaw7zyRa7ARsFL/status/1562130977576865792
    ['OK', '1301656879102218240', 'mXaw7zyRa7ARsFL'], # Wordle 430 (WOVEN), 4g.1.3: coven/doven/hoven/roven
    # https://twitter.com/pawadokai/status/1562675094094487553: Not a Goofball
    ['OK', '53636369', 'pawadokai'], # Wordle 431 (needy), 3g1y.yellow5.white4: ["neeld"]
    # https://twitter.com/RachelWLoewen/status/1564725419999363073: Not a Goofball
    ['OK', '26732424', 'RachelWLoewen'], # Wordle 437 (onset), 4g.3.1: (oncet)
    # https://twitter.com/rnkellystclair/status/1565415427643023360: Not a Goofball
    ['OK', '17948846', 'rnkellystclair'], # Wordle 439 (fungi), 3g1y.yellow1.white4: (gundi)
    # https://twitter.com/StormBlast2014/status/1562287971025375233
    ['OK', '2153111274', 'StormBlast2014'], # Wordle 430 (WOVEN), 3g1y.yellow3.white1: "rowen"
    # https://twitter.com/zoeloveswordle/status/1562295852831772672
    ['OK', '1297960675923222529', 'zoeloveswordle'], # Wordle 430 (WOVEN), 4g.1.2: coven/doven/hoven/roven
  ].map { |x| raise "allowlist length error" if x.length != 3; [x[1], x[2]] }.to_h

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
  def self.set_goofball_mode b
    @@goofball_mode = b
  end
  def self.goofball_mode?
    @@goofball_mode
  end
  def self.author_id_denylist
    @@goofball_mode ? {} : @@author_id_denylist
  end
  def self.author_id_allowlist
    @@goofball_mode ? {} : @@author_id_allowlist
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
          if Configuration.author_id_allowlist.include?(answer.author_id)
            author_allowlisted = true
            Debug.log "keeping key #{key} with value 1. (#{answer.generic_tweet_url}) (author_id=#{answer.author_id})"
          else
            Alert.alert "deleting key #{key} with value 1! (#{answer.generic_tweet_url}) (author_id=#{answer.author_id})"
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
