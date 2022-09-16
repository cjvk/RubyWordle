#!/usr/bin/ruby -w

require 'faraday'
require 'json'
require 'date'
require_relative 'constants'

def print_a_dad_joke
  url = 'https://icanhazdadjoke.com/'
  response = Faraday.get(url, {a: 1}, {'Accept' => 'application/json'})
  joke_object = JSON.parse(response.body, symbolize_names: true)
  puts joke_object[:joke]
end

module Twitter
  module Configuration
    # Twitter API capacity
    # My project is at "Essential access" level, which gives 500k tweets/month (~16.7k/day)
    #   - https://developer.twitter.com/en/docs/twitter-api/tweet-caps
    #   - https://developer.twitter.com/en/portal/dashboard
    #   - My usage resets on 28th of the month
    #   - After adding caching, I have less need to track quota

    # Twitter API calls
    @@results = 100
    @@pages = 5

    # Set to true to skip "long" functions
    @@instrumentation_only = false

    #         dracos has ~2k fewer words than NYT, could perform better
    @@absence_of_evidence_filename = DRACOS_VALID_WORDLE_WORDS_FILE

    #         Uncomment this to query a specific wordle number
    # @@wordle_number_override = 451

    #         Uncomment this to enable debug printing for a specific tweet_id
    # @@debug_print_tweet_id = '1559163924548915201'

    #         Uncomment to enable printing of ALL penultimate which match this pattern
    # @@print_this_penultimate_pattern = 'wgggw' # use normalized colors (g/y/w)

    #         Uncomment to enable printing of ALL answers which match this key
    # @@print_answers_matching_this_key = '4g.5.5'

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
    def self.absence_of_evidence_filename
      @@absence_of_evidence_filename
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
    def self.author_id_denylist
      YAML.load_file('author_id_denylist.yaml')
        .map{|el| raise "problem!" if el['verdict'] != 'deny'; el}
        .map{|el| [el['author_id'].to_s, el['name']]}
        .to_h
    end
    def self.author_id_allowlist
      YAML.load_file('author_id_allowlist.yaml')
        .map{|el| raise "problem!" if el['verdict'] != 'allow'; el}
        .map{|el| [el['author_id'].to_s, el['name']]}
        .to_h
    end
  end

  class Answer
    # array of "Normal-mode" squares
    def initialize(guess_array, id, author_id, username)
      @guess_array = guess_array
      @id = id
      @author_id = author_id
      @username = username
      @is_interesting = nil
      @key = nil
    end
    def self.tweet_url(tweet_id, username)
      "https://twitter.com/#{username}/status/#{tweet_id}"
    end
    def tweet_url
      Answer.tweet_url(@id, @username)
    end
    def author_id
      @author_id
    end
    def username
      @username
    end
    def pp
      UI::padded_puts "tweet: #{tweet_url}"
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

  module Query
    def Query::goofball
      ProcessedResult.new(
        Internal::post_process(
          Internal::make_call,
          delete_stats_hash_singletons: false,
          check_denylist: false))
    end

    def Query::regular
      ProcessedResult.new(Internal::post_process(Internal::make_call))
    end

    def Query::regular_with_singletons
      ProcessedResult.new(
        Internal::post_process(
          Internal::make_call,
          delete_stats_hash_singletons: false))
    end

    class ProcessedResult
      def initialize(post_process_result)
        @answers = post_process_result[:answers]
        @call_stats = post_process_result[:call_stats]
        @stats_hash = post_process_result[:stats_hash]
      end

      def answers
        @answers
      end

      def stats_hash
        @stats_hash
      end

      def call_stats
        @call_stats
      end

      def print_report
        wordle_number = user_specified_wordle_number_or_default
        total_guesses_histogram = [0, 0, 0, 0, 0, 0]
        @answers.each{|answer| total_guesses_histogram[answer.num_guesses-1] += 1}
        mean = @answers.map{|answer| answer.num_guesses}.sum.to_f / @answers.length
        mode_value = total_guesses_histogram.max
        mode = total_guesses_histogram.find_index(mode_value) + 1
        num_interesting = @stats_hash.map{|_, value| value}.sum
        num_skipped = @call_stats[:denylisted] + @call_stats[:retweets]
        incorrect_percentage = @call_stats[:failures]*100/(@answers.length.to_f+@call_stats[:failures])

        # print the report
        [
          '',
          '/--------------------------------------\\',
          "|              Wordle #{wordle_number}              |",
          '|            Twitter report            |',
          "|              #{wordle_number_to_date(wordle_number)}              |",
          '\--------------------------------------/',
          "#{@call_stats[:tweets_seen]} Twitter posts seen",
          "#{@call_stats[:tweets_seen]-@call_stats[:duplicates]} Unique Twitter posts seen",
          "#{num_skipped} skipped",
          "#{@answers.length()+@call_stats[:failures]} total answers",
          "#{@answers.length} correct answers",
          "#{@call_stats[:failures]} incorrect (#{'%.2f' % incorrect_percentage}% failure)",
          "#{'%.2f' % mean}: Average number of guesses",
          "#{mode}: Most common number of guesses (#{mode_value} times)",
          "#{num_interesting}/#{@answers.length()} are interesting",
          '',
        ].each{|s| UI.padded_puts(s)}

        @stats_hash.each {|key, value| UI.padded_puts "#{key} = #{value}"}
        puts ''
        UI.padded_puts '----------------------------------------'
        puts ''

        if Configuration.print_answers_matching_this_key != nil
          matching_key = Configuration.print_answers_matching_this_key
          UI::padded_puts "Printing all answers matching key #{matching_key}"
          puts ''
          @answers.each {|answer| answer.pp if answer.matches_key(matching_key)}
          UI.padded_puts '----------------------------------------'
          UI::padded_puts ''
        end
      end
    end
  end

  module Internal
    # The idea is to have a module-Twitter call which invokes make_call() and post_process()
    # It would seem with post-processing-options that one could make goofball-mode, current
    # twitter(), plus others (e.g. twitter() w/o single-person filtering). And having all of
    # these available at the Twitter-module level, named appropriately, is good.

    def Internal::cache_filename(wordle_number)
      "saved_twitter_results/saved_twitter_result_wordle#{wordle_number}.yaml"
    end

    def Internal::post_process(
      make_call_return_value,
      delete_stats_hash_singletons: true,
      check_denylist: true)

      # Make a shallow copy, so filtering will not affect make_call_return_value
      # Note that any modification to the answers will be reflected in both places
      answers = make_call_return_value[:answers].dup
      call_stats = make_call_return_value[:call_stats].dup

      # check the denylist if so instructed
      answers = answers.delete_if{|ans| Configuration.author_id_denylist.include?(ans.author_id)} if check_denylist

      # construct stats hash
      stats_hash = {}
      answers.each{ |answer| answer.is_interesting(stats_hash)}

      # delete non-allowlisted singletons if so instructed
      if delete_stats_hash_singletons
        stats_hash.delete_if do |key, value|
          value == 1 && answers.dup
            .delete_if{|answer| !answer.matches_key(key)}
            .map{|answer| [answer, Configuration.author_id_allowlist.include?(answer.author_id)]}
            .map{|answer, is_allowlisted| is_allowlisted ? Debug.log("keeping key #{key} with value 1 (author allowlisted). (#{answer.tweet_url}) (author_id=#{answer.author_id})") : Alert.alert("deleting key #{key} with value 1! (#{answer.tweet_url}) (author_id=#{answer.author_id})"); [answer, is_allowlisted]}
            .delete_if{|answer, is_allowlisted| is_allowlisted}
            .length > 0
        end
      end

      # sort stats, '4g' to the top
      # Could have a hash giving a total ordering based on profiling,
      # but isn't this less relevant with the fingerprint-style?
      stats_hash = stats_hash.sort_by {|key, value| [key.split('.', 2)[0] == '4g' ? 0 : 1, key]}.to_h

      # save number of denylisted
      call_stats[:denylisted] = make_call_return_value[:answers].length - answers.length

      {
        :answers => answers,
        :call_stats => call_stats, # now includes :denylisted!
        :stats_hash => stats_hash,
      }
    end

    def Internal::make_call
      wordle_number = user_specified_wordle_number_or_default

      # check for previously-cached result
      return YAML.load_file(cache_filename(wordle_number)) if File.exist?(cache_filename(wordle_number))

      answers = []
      unique_twitter_posts = {}
      call_stats = {
        :tweets_seen => 0,
        :duplicates => 0,
        :retweets => 0,
        :failures => 0,
      }

      file = File.open('auth_token_twitter')
      file_data = file.read
      file.close
      auth_token = file_data.chomp
      search_queries = [
        "wordle%20#{wordle_number}",   # "wordle 420"
        "%23wordle%20#{wordle_number}", # "#wordle 420"
      ]

      search_queries.each do |search_query|
        next_token = ''
        (0...Configuration.pages).each do |page_num|
          # https://developer.twitter.com/en/docs/twitter-api/tweets/search/api-reference/get-tweets-search-recent

          # quit early if nothing remaining
          next if page_num != 0 && next_token == ''

          # handle next token
          next_token_get_parameter = page_num == 0 ? "" : "&next_token=#{next_token}"

          # recent/ is available for "anyone", but /2/tweets/search/all is only for academic research
          # recent is from the last seven days
          url = "https://api.twitter.com/2/tweets/search/recent?query=#{search_query}&tweet.fields=author_id,referenced_tweets&user.fields=id,username&expansions=author_id&max_results=#{Configuration.results}#{next_token_get_parameter}"

          response = Faraday.get(url, nil, {'Accept' => 'application/json', 'Authorization' => "Bearer #{auth_token}"})
          parsed_json = JSON.parse(response.body)

          # create hash for author_id to username
          author_id_to_username = {}
          for user in parsed_json['includes']['users']
            author_id = user['id']
            username = user['username']
            author_id_to_username[author_id] = username
          end

          next_token = parsed_json['meta'].key?('next_token') ? parsed_json['meta']['next_token'] : ''

          # transform into array of Answer objects
          # (w)hite, (y)ellow, (g)reen
          # puts "-------- id=#{parsed_json['data'][0]['id']}, author_id=#{parsed_json['data'][0]['author_id']}"
          for result in parsed_json['data']
            text = result['text']
            id = result['id']
            author_id = result['author_id']
            username = author_id_to_username[author_id]
            is_retweet = result['referenced_tweets'] != nil && result['referenced_tweets'][0]['type'] == 'retweeted'

            Debug.set_maybe (Configuration.debug_print_tweet_id != nil && Configuration.debug_print_tweet_id == id)
            Debug.maybe_log "result=#{result}"

            # skip duplicates
            call_stats[:tweets_seen] += 1
            if unique_twitter_posts.key?(id)
              call_stats[:duplicates] += 1
              next
            end
            unique_twitter_posts[id] = '1'

            # skip retweets
            # example tweet  : https://twitter.com/ilikep4pp4roni/status/1565602075337187328
            # example retweet: https://twitter.com/JohnnyDee62/status/1565637313287307267
            if is_retweet
              Debug.log_verbose "skipping tweet (retweet) (#{Answer.tweet_url id, username}) (author_id=#{author_id})"
              call_stats[:retweets] += 1
              next
            end

            next if !Twitter::is_probably_a_wordle_post?(text, wordle_number)
            Debug.maybe_log 'is probably a wordle post!'

            # determine how many guesses they took
            # because text is "probably a wordle post", it should match
            num_guesses = text.match(/Wordle #{wordle_number} ([1-6X])\/6/)
            next if !num_guesses # equivalent of Unknown mode above
            # get the first match
            num_guesses = num_guesses[1]
            if num_guesses == 'X'
              # no solution found - record if a failure and skip
              call_stats[:failures] += 1
              next
            end
            # convert
            num_guesses = num_guesses.to_i

            # before determining mode, only determine based on the wordle answer
            # some users do Wordle in regular mode and Worldle in dark mode
            # e.g. https://twitter.com/fire__girl/status/1555234404812857344
            # so restrict only to looking at the wordle answer
            wordle_begin_pattern = /Wordle #{wordle_number} [123456]\/6/
            wordle_begin_index = text.index(wordle_begin_pattern)
            wordle_begin_pattern_length = wordle_number.to_i < 1000 ? 14 : 15
            # typically 2 newline characters
            wordle_squares_begin = wordle_begin_index + wordle_begin_pattern_length + 2
            Debug.maybe_log "wordle_squares_begin = #{wordle_squares_begin}"
            first_non_wordle_character = text.index(WordleShareColors::NON_WORDLE_CHARACTERS, wordle_squares_begin)
            Debug.maybe_log "wordle_begin_index=#{wordle_begin_index}"
            Debug.maybe_log "first_non_wordle_character=#{first_non_wordle_character}"
            if first_non_wordle_character != nil
              text = text[wordle_begin_index..first_non_wordle_character - 1]
            end

            # determine mode
            mode = WordleModes.determine_mode(text)
            next if mode == WordleModes::UNKNOWN_MODE
            Debug.maybe_log_terse "mode = #{mode}"

            # construct the normalized guess_array
            current_index = 0
            guess_array = []
            pattern = WordleModes.mode_to_pattern(mode)
            for _ in 0...num_guesses
              matching_index = text.index(pattern, current_index)
              next if matching_index == nil
              guess_string = ''
              for j in 0...5
                guess_string += WordleModes.unicode_to_normalized_string(text[matching_index+j], mode)
              end
              current_index = matching_index + 1
              guess_array.append(guess_string)
            end

            # This is why we need the number of guesses
            # (I suppose we could make 'X' guesses = 6 expected... leave for a WIBNI)
            if guess_array.length() != num_guesses
              Alert.alert "guess array not correct length! (#{Answer.tweet_url id, username}) (author_id=#{author_id})"
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

            answers.append(Twitter::Answer.new(guess_array, id, author_id, username))
          end
          Debug.set_maybe_false
        end
      end

      return_value = {
        :answers => answers,
        :call_stats => call_stats,
      }

      File.write(cache_filename(wordle_number), return_value.to_yaml)

      return_value
    end
  end

  # mark all this for deprecation
  @@memoized_twitter_result = nil
  def Twitter::twitter_deprecated
    @@memoized_twitter_result = twitter_internal_deprecated if @@memoized_twitter_result == nil
    @@memoized_twitter_result
  end

  # If we are going to separate "make the query to twitter" from "do filtering", first take inventory
  #
  # Current behavior
  # - use user-specified wordle number, with today's wordle number as default
  # - if a cached result exists, use it, except in goofball mode
  #   - But with this redesign, this could be removed!
  # - get the auth token: keep
  # - two search queries: keep
  # - create hash for author_id to username (probably move this to post-processing or something)
  #   - no, keep this here, because of the structure of the response
  # - transform into array of Answer objects: keep
  # - de-dup by unique_twitter_posts: keep
  # - check the denylist: move out
  # - skip retweets: keep
  # - num_failures: move out
  #   - implication is would have to keep answers for incorrect also
  # - still skip if mode is unknown
  # - Basically: if I have enough info to construct an Answer object, do it

  def Twitter::twitter_internal_deprecated
    wordle_number = today_wordle_number
    if Configuration.wordle_number_override != nil
      wordle_number = Configuration.wordle_number_override.to_s
      Debug.log_terse "using user-specified wordle number: #{wordle_number}"
    end

    # check for previously-cached result
    filename = "saved_deprecated_twitter_result_wordle#{wordle_number}.yaml"
    if File.exist?(filename)
      return YAML.load_file(filename)
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
      "%23wordle%20#{wordle_number}", # "#wordle 420"
    ]

    search_queries.each do |search_query|
      next_token = ''
      (0...Configuration.pages).each do |page_num|
        # https://developer.twitter.com/en/docs/twitter-api/tweets/search/api-reference/get-tweets-search-recent

        # quit early if nothing remaining
        next if page_num != 0 && next_token == ''

        # handle next token
        next_token_get_parameter = page_num == 0 ? "" : "&next_token=#{next_token}"

        # recent/ is available for "anyone", but /2/tweets/search/all is only for academic research
        # recent is from the last seven days
        url = "https://api.twitter.com/2/tweets/search/recent?query=#{search_query}&tweet.fields=author_id,referenced_tweets&user.fields=id,username&expansions=author_id&max_results=#{Configuration.results}#{next_token_get_parameter}"

        response = Faraday.get(url, nil, {'Accept' => 'application/json', 'Authorization' => "Bearer #{auth_token}"})
        parsed_json = JSON.parse(response.body)

        # create hash for author_id to username
        author_id_to_username = {}
        for user in parsed_json['includes']['users']
          author_id = user['id']
          username = user['username']
          author_id_to_username[author_id] = username
        end

        next_token = parsed_json['meta'].key?('next_token') ? parsed_json['meta']['next_token'] : ''

        # transform into array of Answer objects
        # (w)hite, (y)ellow, (g)reen
        # puts "-------- id=#{parsed_json['data'][0]['id']}, author_id=#{parsed_json['data'][0]['author_id']}"
        for result in parsed_json['data']
          text = result['text']
          id = result['id']
          author_id = result['author_id']
          username = author_id_to_username[author_id]
          is_retweet = result['referenced_tweets'] != nil && result['referenced_tweets'][0]['type'] == 'retweeted'

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
            Debug.log "skipping tweet (denylist) (#{Twitter::Answer.tweet_url id, username}) (author_id=#{author_id})#{al_str}"
            skipped_twitter_posts += 1
            next
          end
          # skip retweets
          # example tweet  : https://twitter.com/ilikep4pp4roni/status/1565602075337187328
          # example retweet: https://twitter.com/JohnnyDee62/status/1565637313287307267
          if is_retweet
            Debug.log_verbose "skipping tweet (retweet) (#{Twitter::Answer.tweet_url id, username}) (author_id=#{author_id})"
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
            first_non_wordle_character = text.index(WordleShareColors::NON_WORDLE_CHARACTERS, wordle_squares_begin)
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
              Alert.alert "guess array not correct length! (#{Twitter::Answer.tweet_url id, username}) (author_id=#{author_id})"
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

            answers.append(Twitter::Answer.new(guess_array, id, author_id, username))

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
            url = answer.tweet_url
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

    [
      '',
      '/--------------------------------------\\',
      "|              Wordle #{wordle_number}              |",
      '|            Twitter report            |',
      '\--------------------------------------/',
      "#{total_twitter_posts} Twitter posts seen",
      "#{unique_twitter_posts.size} Unique Twitter posts seen",
      "#{skipped_twitter_posts} skipped",
      "#{answers.length()+num_failures} total answers",
      "#{answers.length} correct answers",
      "#{num_failures} incorrect (#{'%.2f' % incorrect_percentage}% failure)",
      "#{'%.2f' % avg_number_of_guesses}: Average number of guesses",
      "#{mode_index+1}: Most common number of guesses (#{mode_value} times)",
      "#{num_interesting}/#{answers.length()} are interesting",
      '',
    ].each{|s| UI.padded_puts(s)}

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

    return_value = {
      stats: stats,
      answers: answers
    }

    # cache result, except in goofball mode
    if !Configuration.goofball_mode?
      filename = "saved_deprecated_twitter_result_wordle#{wordle_number}.yaml"
      File.write(filename, return_value.to_yaml)
    end

    return_value
  end

  def Twitter::is_probably_a_wordle_post?(text, wordle_number)
    !! (text =~ /Wordle #{wordle_number} [123456X]\/6/)
  end
end
