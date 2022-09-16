#!/usr/bin/ruby -w

module Fingerprint
  # Sample NYT fingerprint (clout)
  # {"4g.2"=>2, "4g.3"=>1, "4g.4"=>1, "3g1y.yellow4.white5"=>3, "4g.5"=>3, "4g.1"=>3, "3g1y.yellow2.white1"=>1}

  SUPPORTED_FINGERPRINT_SOURCE_FILES = [
    ['NYT', {
      :source_filename => VALID_WORDLE_WORDS_FILE,
      :fingerprint_filename => 'compressed_fingerprints_nyt.yaml',
    }],
    ['Dracos', {
      :source_filename => DRACOS_VALID_WORDLE_WORDS_FILE,
      :fingerprint_filename => 'compressed_fingerprints_dracos.yaml',
    }],
  ].to_h

  def Fingerprint::load_by_key(filename_key: 'NYT')
    if !SUPPORTED_FINGERPRINT_SOURCE_FILES.key?(filename_key)
      Alert.alert("unsupported key: #{filename_key}")
      return
    end

    fingerprint_filename = SUPPORTED_FINGERPRINT_SOURCE_FILES[filename_key][:fingerprint_filename]

    Internal::decompress(Internal::read_fingerprints_from_file(fingerprint_filename))
  end

  def Fingerprint::regenerate_compress_and_save(filename_key)
    # This function takes about 10 minutes to run nonstop on NYT, 20 minutes with pauses.
    # Unless there is a new type of interestingness, or unless the dictionary changes,
    # it should not need to be run.
    if !SUPPORTED_FINGERPRINT_SOURCE_FILES.key?(filename_key)
      Alert.alert("unsupported key: #{filename_key}")
      return
    end

    fingerprints = Internal::calculate_fingerprints(filename_key)
    fingerprint_filename = SUPPORTED_FINGERPRINT_SOURCE_FILES[filename_key][:fingerprint_filename]
    Internal::save_fingerprints_to_file(Internal::compress(fingerprints), fingerprint_filename)
  end

  module Internal
    def Internal::score_string(i, word, score)
      maybe_alert = PreviousWordleSolutions.maybe_alert_string(word)
      i == nil ?
        "#{word} has a score of #{'%.1f' % score}#{maybe_alert}" :
        "#{i+1}: #{word} has a score of #{'%.1f' % score}#{maybe_alert}"
    end

    def Internal::fingerprint_string(word, fingerprint)
      sorted_fingerprint = fingerprint
        .sort_by{|k, v| [k.start_with?('4g') ? 0 : 1, k]}
        .to_h
      "         #{word} fingerprint: #{sorted_fingerprint}"
    end

    def Internal::save_fingerprints_to_file(compressed_fingerprints, filename)
      File.write(filename, compressed_fingerprints.to_yaml)
    end

    def Internal::read_fingerprints_from_file(filename)
      YAML.load_file(filename)
    end

    def Internal::compress(fingerprints)
      fingerprints.map{ |word, fingerprint|
        [word, fingerprint.map{|k,v| [CompactKeys::KEY_COMPRESSION_HASH[k], v]}.to_h]
      }.to_h
    end

    def Internal::decompress(compressed_fingerprints)
      compressed_fingerprints.map{ |word, compressed_fingerprint| [
        word, compressed_fingerprint.map { |compressed_key, v| [
          CompactKeys::KEY_COMPRESSION_HASH.key(compressed_key), v
        ]}.to_h
      ]}.to_h
    end

    def Internal::calculate_fingerprints(filename_key)
      source_filename = SUPPORTED_FINGERPRINT_SOURCE_FILES[filename_key][:source_filename]

      valid_wordle_words = populate_valid_wordle_words(source_filename)
      fingerprints = {}
      source_words = populate_all_words
      num_processed = 0
      total_to_process = source_words.length
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
        if num_processed % 580 == 0
          percent_complete = (num_processed.to_f*100)/total_to_process
          print "sleeping for a minute every so often... (#{'%.1f' % percent_complete}% complete) "
          sleep 60
          puts 'resuming!'
        end
        # break if num_processed >= 60 # comment this line if you want to run "for real"
      end
      fingerprints
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
    end
  end

  module Distance
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

    def Distance::individual_distance(num_matches_fingerprint, num_matches_seen)
      DISTANCES_4G[[num_matches_fingerprint, 9].min][num_matches_seen].to_f
    end

    def Distance::calc_4g_distance(max_4gs_from_twitter, max_4gs_from_fingerprint)
      difference = [0, 0, 0, 0, 0]
      (0...5).each {|i|
        difference[i] = Distance::DISTANCES_4G[
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

    def Distance::calc_non_4g_distance(stats_hash, fingerprint)
      fingerprint.dup
        .delete_if{|k,v| k.start_with?('4g')}
        .delete_if{|k,v| stats_hash.key?(k)}
        .map{|k,v| Distance::DISTANCES_NON_4G[[v,4].min]}
        .sum.to_f
    end
  end

  def Fingerprint::max_4gs fingerprint
    (0...5).map{|i| fingerprint["4g.#{i+1}"] || 0}
  end

  def Fingerprint::fingerprint_analysis(d, stats_hash, verbose: 0, max_to_print: 30, suppress_output: false)
    nyt_fingerprints = load_by_key

    d = d
      .map{|word, line_num| [word, [[:word, word], [:line_num, line_num]].to_h]}
      .map{|word, data| data[:nyt_fingerprint] = nyt_fingerprints[word]; [word, data]}
      .map{|word, data| data[:nyt_score] = score(word, stats_hash, data[:nyt_fingerprint]); [word, data]}
      .delete_if{|word, data| data[:nyt_score] == -1}
      .sort_by {|word, data| -1 * data[:nyt_score]}
      .to_h

    if !suppress_output
      puts ''
      UI::padded_puts '/------------------------------------------------------\\'
      UI::padded_puts "|              Fingerprint analysis report             |"
      UI::padded_puts '\------------------------------------------------------/'
      UI::padded_puts ''
      UI::padded_puts "stats_hash: #{stats_hash}"
      puts ''
      UI::padded_puts "There are #{d.length} words remaining. Showing score to a maximum of #{max_to_print}."
      puts ''

      d.each.with_index do |(word, data), i|
        break if i >= max_to_print
        UI::padded_puts Internal::score_string(i, word, data[:nyt_score])
        UI::padded_puts Internal::fingerprint_string(word, data[:nyt_fingerprint]) if i < verbose
      end

      puts ''
      while '' != word = UI.prompt_for_input("Enter a word to see its score, or ENTER to continue: ==> ", false) do
        UI::padded_puts Internal::score_string(nil, word, d[word][:nyt_score]) if d.key?(word)
      end

      puts ''
      puts ''

      if [UI.prompt_for_input('re-run using Dracos score? (y/n) (default n): ==> ', false)]
        .map{|user_input| ['y', 'n'].include?(user_input) ? user_input : 'n'}[0] == 'y'
        dracos_fingerprints = load_by_key(filename_key: 'Dracos')
        draco_d = d
          .map{|word, data| data[:dracos_fingerprint] = dracos_fingerprints[word]; [word, data]}
          .map{|word, data| data[:dracos_score] = score(word, stats_hash, data[:dracos_fingerprint]); [word, data]}
          .sort_by {|word, data| -1 * data[:dracos_score]}
          .to_h

        draco_d.each.with_index do |(word, data), i|
          break if i >= max_to_print
          UI::padded_puts Internal::score_string(i, word, data[:dracos_score])
          UI::padded_puts Internal::fingerprint_string(word, data[:dracos_fingerprint]) if i < verbose
        end

        puts ''
        while '' != word = UI.prompt_for_input("Enter a word to see its score, or ENTER to continue: ==> ", false) do
          UI::padded_puts Internal::score_string(nil, word, draco_d[word][:dracos_score]) if draco_d.key?(word)
        end

        puts ''
        puts ''

      end
    end

    d.to_h
  end

  # Wordle 447 (theme): 1/1
  # Wordle 446 (class): 1/20
  # Wordle 445 (leery): 1/24
  # Wordle 444 (taunt): 1/123 (but pretty close)
  # Wordle 443 (whoop): 1/50
  # Wordle 442 (inter): 1/1

  # Wordle 454 (parer)
  #   - parer has a score of 68.1
  #     - parer fingerprint: {
  #         "4g.1"=>7,
  #         "4g.2"=>2,
  #         "4g.3"=>8,
  #         "4g.5"=>6,
  #         "3g1y.yellow1.white2"=>1,
  #         "3g1y.yellow1.white3"=>8,
  #         "3g1y.yellow1.white5"=>3,
  #         "3g1y.yellow2.white3"=>2,
  #         "3g1y.yellow3.white1"=>5,
  #         "3g1y.yellow4.white5"=>3,
  #         "3g1y.yellow5.white2"=>1,
  #         "3g1y.yellow5.white4"=>6,
  #         "3g2y.yellow13"=>1
  #       }
  #   - carer has a score of 64.6
  #     - carer fingerprint: {
  #         "4g.1"=>7,
  #         "4g.2"=>2,
  #         "4g.3"=>7,
  #         "4g.5"=>4,
  #         "1g4y.green1"=>1,
  #         "3g1y.yellow1.white2"=>1,
  #         "3g1y.yellow1.white3"=>8,
  #         "3g1y.yellow1.white5"=>3,
  #         "3g1y.yellow2.white3"=>2,
  #         "3g1y.yellow3.white1"=>4,
  #         "3g1y.yellow4.white5"=>2,
  #         "3g1y.yellow5.white1"=>1,
  #         "3g1y.yellow5.white4"=>6,
  #         "3g2y.yellow13"=>1
  #       }
  #   - stats_hash (shortened): {
  #       "4g.1.3"=>4,
  #       "4g.2.2"=>2,
  #       "4g.3.5"=>2,
  #       "4g.5.4"=>4,
  #       "3g1y.yellow1.white3"=>6,
  #       "3g1y.yellow2.white3"=>1,
  #       "3g1y.yellow3.white1"=>4,
  #       "3g1y.yellow4.white5"=>2,
  #       "3g1y.yellow5.white4"=>12,
  #       "3g2y.yellow13"=>3
  #     }
  #   - stats_hash: {
  #     "4g.1.1"=>29,
  #     "4g.1.2"=>14,
  #     "4g.1.3"=>4,
  #     "4g.2.1"=>6,
  #     "4g.2.2"=>2,
  #     "4g.3.1"=>31,
  #     "4g.3.2"=>17,
  #     "4g.3.3"=>34,
  #     "4g.3.4"=>7,
  #     "4g.3.5"=>2,
  #     "4g.5.1"=>77,
  #     "4g.5.2"=>38,
  #     "4g.5.3"=>13,
  #     "4g.5.4"=>4,
  #     "3g1y.yellow1.white3"=>6,
  #     "3g1y.yellow2.white3"=>1,
  #     "3g1y.yellow3.white1"=>4,
  #     "3g1y.yellow4.white5"=>2,
  #     "3g1y.yellow5.white4"=>12,
  #     "3g2y.yellow13"=>3
  #   }

  def Fingerprint::score(candidate_word, stats_hash, fingerprint)
    previous_maybe = Debug.maybe?
    # Debug.set_maybe(candidate_word == 'corns')
    Debug.maybe_log 'score: ENTER'
    Debug.maybe_log "stats_hash=#{stats_hash}"
    statshash = StatsHash.new(stats_hash)
    max_4gs_from_twitter = statshash.max_4gs # [1, 2, 0, 0, 1]
    Debug.maybe_log "statshash.max_4gs=#{max_4gs_from_twitter}"
    # transform stats hash - map automatically makes a copy
    # delete_if is to ensure apples-to-apples comparison with the fingerprint
    tsh = stats_hash
      .map{|k,v| [k, [[:key, k], [:value, v]].to_h]}
      .map{|k,data_hash| data_hash[:is4g] = k.start_with?('4g'); [k, data_hash]}
      .map{|k,data_hash| data_hash[:short_key] = data_hash[:is4g] ? k[0,4] : k; [k, data_hash]}
      .delete_if{|k,data_hash| data_hash[:is4g] && !statshash.max_4gs_keys.include?(k)}
    Debug.maybe_log "just created transformed stats hash: #{tsh}"
    Debug.maybe_log "fingerprint=#{fingerprint}"

    # Note: It may be possible to do first and second pass at the same time

    # First pass:
    #   Anything seen on Twitter _not_ in the fingerprint eliminates that word.
    #   (This is, I believe, equivalent to the current processing).
    Debug.maybe_log ''
    Debug.maybe_log "filtering #{candidate_word} based on keys in Twitter but not in the fingerprint..."

    tsh.each{|k,data_hash| return -1 if !fingerprint.key?(data_hash[:short_key])}

    fingerprint
      .dup
      .delete_if{|short_key, count| !short_key.start_with?('4g')}
      .delete_if{|short_key, count| !statshash.max_4gs_by_short_key.key?(short_key)}
      .each do |short_key, count|

      twitter_value = statshash.max_4gs_by_short_key[short_key]
      if ['whirl','taunt','chugs','witch','pooch','drown','drawn','tramp','heerd','amber','plunk','haunt','clock','whims','amble','knitx','sonic'].include?(candidate_word)
        Debug.maybe_log("score(): Twitter>actual #{candidate_word}, #{twitter_value}>#{count}") if twitter_value > count
      end
      Debug.maybe_log 'about to filter based on 4g Twitter count'
      return -1 if twitter_value > count
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
    max_4gs_from_fingerprint = Fingerprint::max_4gs(fingerprint)
    distance_4g = Distance::calc_4g_distance(max_4gs_from_twitter, max_4gs_from_fingerprint)
    # simple conversion (for now) to a 0-100 score
    arbitrary_max = 5.0
    distance_4g_score = ([arbitrary_max-distance_4g, 0].max.to_f / arbitrary_max) * 100
    scores[:distance_4g] = distance_4g_score

    # distance_non_4g
    # - Either they got it or didn't. This should penalize them extra for missing 0/2, 0/3, etc.
    distance_non_4g = Distance::calc_non_4g_distance(stats_hash, fingerprint)
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
    Debug.set_maybe previous_maybe

    # 100 * pct_keys
    weights.map{|k, weight| scores[k] * weight}.sum
  end
end

class StatsHash
  # This doesn't really belong in fingerprints.rb
  def initialize(stats_hash)
    @stats_hash = stats_hash
    # [0, 1, 2, 0, 1]
    @max_4gs = StatsHash.max_4gs @stats_hash
    # ['4g.2.1', '4g.3.2', '4g.5.1']
    @max_4gs_keys = StatsHash.max_4gs_keys @max_4gs
    # {'4g.2' => 1, '4g.3' => 2, '4g.5' => 1}
    @max_4gs_by_short_key = StatsHash.max_4gs_by_short_key @max_4gs
  end
  def max_4gs
    @max_4gs
  end
  def self.num_singletons stats_hash
    stats_hash
      .map{|_key, value| value}
      .delete_if{|count| count != 1}
      .length
  end
  def self.max_4gs stats_hash
    (0...5)
      .map{|i| "4g.#{i+1}"}
      .map{|short_key|
      stats_hash
        .dup
        .delete_if{|key, _| !key.start_with?(short_key)}
        .map{|key, _| key[5].to_i} # "4g.5.2"[5] is the count
        .max || 0}
  end
  def max_4gs_keys
    @max_4gs_keys
  end
  def self.max_4gs_keys max_4gs
    max_4gs
      .map.with_index{ |ith_max, i| "4g.#{i+1}.#{ith_max}" }
      .delete_if{ |key| key.end_with?('.0')}
  end
  def max_4gs_by_short_key
    @max_4gs_by_short_key
  end
  def self.max_4gs_by_short_key max_4gs
    max_4gs
      .map.with_index{ |ith_max, i| ["4g.#{i+1}", ith_max]}
      .delete_if{ |_, ith_max| ith_max == 0}
      .to_h
  end

  # This was formerly known as "def max_4gs_seen_on_twitter"
  def StatsHash::max_4gs_deprecated stats_hash
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
end


