#!/usr/bin/ruby -w

# Sample fingerprint (clout)
# {"4g.2"=>2, "4g.3"=>1, "4g.4"=>1, "3g1y.yellow4.white5"=>3, "4g.5"=>3, "4g.1"=>3, "3g1y.yellow2.white1"=>1}

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

module Fingerprint
  def Fingerprint::max_4gs fingerprint
    (0...5).map{|i| fingerprint["4g.#{i+1}"] || 0}
  end

  def Fingerprint::fingerprint_analysis(d, stats_hash, verbose: 0, max_to_print: 30, suppress_output: false)
    fingerprints = reconstitute_fingerprints

    d = d
      .map{|word, line_num| [word, [[:word, word], [:line_num, line_num]].to_h]}
      .map{|word, data_hash| data_hash[:fingerprint] = fingerprints[word]; [word, data_hash]}
      .map{|word, data_hash| data_hash[:score] = score(word, stats_hash, data_hash[:fingerprint]); [word, data_hash]}
      .delete_if{|word, data_hash| data_hash[:score] == -1}
      .sort_by {|word, data_hash| -1 * data_hash[:score]}

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

      d.each.with_index do |(word, data_hash), index|
        break if index >= max_to_print
        maybe_solution_number = PreviousWordleSolutions.check_word(word)
        maybe_alert = maybe_solution_number ?
          " -------- Alert! Wordle #{maybe_solution_number} solution was #{word} --------" :
          ''
        UI::padded_puts "#{index+1}: #{word} has a score of #{'%.1f' % data_hash[:score]}#{maybe_alert}"
        if index < verbose
          UI::padded_puts "         #{word} fingerprint: #{data_hash[:fingerprint]}"
        end
      end

      puts ''
      puts ''

    end

    d.to_h
  end

  # Wordle 447 (theme): 1/1
  # Wordle 446 (class): 1/20
  # Wordle 445 (leery): 1/24
  # Wordle 444 (taunt): 1/123 (but pretty close)
  # Wordle 443 (whoop): 1/50
  # Wordle 442 (inter): 1/1

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
        puts "score(): Hello World from #{candidate_word}, #{twitter_value}>#{count}" if twitter_value > count
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
    Debug.set_maybe previous_maybe

    # 100 * pct_keys
    weights.map{|k, weight| scores[k] * weight}.sum
  end
end

class StatsHash
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
  def StatsHash::max_4gs_old stats_hash
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
  File.write('compressed_fingerprints.yaml', compressed_fingerprints.to_yaml)
end

def read_fingerprints_from_file
  YAML.load_file('compressed_fingerprints.yaml')
end

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
