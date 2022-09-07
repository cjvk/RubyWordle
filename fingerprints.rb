#!/usr/bin/ruby -w

# Sample fingerprint (clout)
# {"4g.2"=>2, "4g.3"=>1, "4g.4"=>1, "3g1y.yellow4.white5"=>3, "4g.5"=>3, "4g.1"=>3, "3g1y.yellow2.white1"=>1}
module Fingerprint
  def Fingerprint::max_4gs fingerprint
    (0...5).map{|i| fingerprint["4g.#{i+1}"] || 0}
  end
end

module StatsHash
  def StatsHash::max_4gs stats_hash
    (0...5)
      .map{|i| "4g.#{i+1}"}
      .map{|short_key|
      stats_hash
        .dup
        .delete_if{|key, _| !key.start_with?(short_key)}
        .map{|key, _| key[5].to_i}
        .max || 0}
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
