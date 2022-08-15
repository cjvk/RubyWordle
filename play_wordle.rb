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

def play(d)
  # TODO Consider having a warning on previously-used Wordle answers? (And how would it be maintained?)
  puts 'Welcome to Wordle!'
  for guess in 1..6
    print "You are on guess #{guess}/6. "
    print_remaining_count(d)
    check_for_problematic_patterns(d) if guess >= 3
    while true do
      print 'Enter a guess, or (p)rint, (c)ount, (h)int, (q)uit: ==> '
      choice = gets.chomp
      case choice
      when 'p'
        max_print = 30
        # d.each_with_index {|(key, _value), index| break if index >= max_print; puts key }
        d.each_with_index do |(key, _value), index|
          break if index >= max_print
          if PreviousWordleSolutions.check_word(key)
            puts "#{key} (Alert! Wordle #{PreviousWordleSolutions.check_word(key)} answer!)"
          else
            puts key
          end
        end
        puts "skipping #{d.size-max_print} additional results..." if d.size > max_print
      when 'pa'
        # d.each {|key, value| puts key}
        d.each do |key, value|
          if PreviousWordleSolutions.check_word(key)
            puts "#{key} (Alert! Wordle #{PreviousWordleSolutions.check_word(key)} answer!)"
          else
            puts key
          end
        end
      when 'h'
        hint(d)
      when 'q'
        return
      when 'c'
        print_remaining_count(d)
      when 'penultimate'
        penultimate(d)
      # when 'pws'
      #   print 'testing previous wordle solutions.. enter a word: ==> '
      #   user_word = gets.chomp
      #   puts "#{user_word} apparently was in Wordle #{PreviousWordleSolutions.check_word(user_word)}."
      when 'twitter'
        stats_hash = twitter
        print_remaining_count(d)
        if maybe_filter_twitter(d, stats_hash)
          maybe_absence_of_evidence(d, stats_hash)
        end
      when 'dad'
        print_a_dad_joke
      when 'help'
        puts ''
        puts '.----------------------------------------------.'
        puts '|                                              |'
        puts '|                     Usage                    |'
        puts '|                                              |'
        puts '\----------------------------------------------/'
        puts 'c               : count'
        puts 'p               : print'
        puts 'pa              : print all'
        puts 'h               : hint'
        puts 'q               : quit'
        puts 'dad             : print a dad joke'
        puts 'penultimate     : run penultimate-style analysis'
        puts 'twitter         : run Twitter analysis'
        puts ''
      when ''
      else # assume anything else is a guess
        if choice.length == 5
          print 'Enter the response (!?-): ==> '
          response = gets.chomp
          filter(d, choice, response)
          break
        else
          puts "unrecognized input (#{choice})"
        end
      end
    end
  end
end

def print_remaining_count(d)
  puts "There #{d.length==1?'is':'are'} #{d.size} matching word#{d.length==1?'':'s'} remaining."
end

def maybe_absence_of_evidence(d, stats_hash)
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

def maybe_filter_twitter(d, stats_hash)
  print 'Would you like to proceed with filtering? (y/n) ==> '
  choice = gets.chomp
  case choice
  when 'y'
    print "There are #{d.size} words remaining. Would you like to see filtering output? (y/n) ==> "
    choice2 = gets.chomp
    verbose = choice2 == 'y'
    stats_hash.each do |key, _value|
      key_array = key.split('.', 2)
      penultimate_twitter(d, key_array[0], key_array[1], verbose)
    end
    print_remaining_count(d) # this is useful regardless of verbose, since filtering occurred
  when 'n'
  else
    puts "unrecognized input (#{choice}), skipping"
  end
  # caller needs to know whether filtering was done
  choice == 'y'
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
  d.each do |key1, value1|
    found = false
    pp_dict.each do |key2, value2|
      if close(key1, key2)
        found = true
        pp_dict[key2] = value2 + 1
      end
    end
    pp_dict[key1] = 1 if !found
  end
  puts 'Checking for problematic patterns...'
  pp_dict.each do |key, value|
    puts "\nPROBLEMATIC PATTERN ALERT: found \"#{key}\" with #{value} matching words (print for details)\n\n" if value > 2
  end
  puts 'No problematic patterns found!' if pp_dict.values.max <= 2
end

def penultimate_twitter_absence_of_evidence(d, stats_hash)
  # TODO (big feature) do offline calculations for each word and constraint type (not only 4g)
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
  # new_d.each_with_index {|(key, value), index| break if index >= max_print; puts "key=#{key}, difference=#{value[0]}, all-4g-matches=#{value[2]}, seen-on-twitter=#{value[3]}" }
  new_d.each_with_index do |(key, value), index|
    break if index >= max_print
    puts "key=#{key}, difference=#{value[0]}, all-4g-matches=#{value[2]}, seen-on-twitter=#{value[3]}"
    if PreviousWordleSolutions.check_word(key)
      puts "    -------- Alert! Wordle #{PreviousWordleSolutions.check_word(key)} solution was #{key} --------"
    end
  end
  puts "skipping #{new_d.size-max_print} additional results..." if d.size > max_print
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
  # https://www.rockpapershotgun.com/wordle-past-answers
  # note: Wordle 0 was on 6/19/2021
  @@previous_wordle_solutions = [
    'cigar', 'rebut', 'sissy', 'humph', 'awake', 'blush', 'focal', 'evade', 'naval', 'serve', # 0-9
    'heath', 'dwarf', 'model', 'karma', 'stink', 'grade', 'quiet', 'bench', 'abate', 'feign', # 10-19
    'major', 'death', 'fresh', 'crust', 'stool', 'colon', 'abase', 'marry', 'react', 'batty', # 20-29
    'pride', 'floss', 'helix', 'croak', 'staff', 'paper', 'unfed', 'whelp', 'trawl', 'outdo', # 30-39
    'adobe', 'crazy', 'sower', 'repay', 'digit', 'crate', 'cluck', 'spike', 'mimic', 'pound', # 40-49
    'maxim', 'linen', 'unmet', 'flesh', 'booby', 'forth', 'first', 'stand', 'belly', 'ivory', # 50-59
    'seedy', 'print', 'yearn', 'drain', 'bribe', 'stout', 'panel', 'crass', 'flume', 'offal', # 60-69
    'agree', 'error', 'swirl', 'argue', 'bleed', 'delta', 'flick', 'totem', 'wooer', 'front', # 70-79
    'shrub', 'parry', 'biome', 'lapel', 'start', 'greet', 'goner', 'golem', 'lusty', 'loopy', # 80-89
    'round', 'audit', 'lying', 'gamma', 'labor', 'islet', 'civic', 'forge', 'corny', 'moult', # 90-99
    'basic', 'salad', 'agate', 'spicy', 'spray', 'essay', 'fjord', 'spend', 'kebab', 'guild', # 100-109
    'aback', 'motor', 'alone', 'hatch', 'hyper', 'thumb', 'dowry', 'ought', 'belch', 'dutch', # 110-119
    'pilot', 'tweed', 'comet', 'jaunt', 'enema', 'steed', 'abyss', 'growl', 'fling', 'dozen', # 120-129
    'boozy', 'erode', 'world', 'gouge', 'click', 'briar', 'great', 'altar', 'pulpy', 'blurt', # 130-139
    'coast', 'duchy', 'groin', 'fixer', 'group', 'rogue', 'badly', 'smart', 'pithy', 'gaudy', # 140-149
    'chill', 'heron', 'vodka', 'finer', 'surer', 'radio', 'rouge', 'perch', 'retch', 'wrote', # 150-159
    'clock', 'tilde', 'store', 'prove', 'bring', 'solve', 'cheat', 'grime', 'exult', 'usher', # 160-169
    'epoch', 'triad', 'break', 'rhino', 'viral', 'conic', 'masse', 'sonic', 'vital', 'trace', # 170-179
    'using', 'peach', 'champ', 'baton', 'brake', 'pluck', 'craze', 'gripe', 'weary', 'picky', # 180-189
    'acute', 'ferry', 'aside', 'tapir', 'troll', 'unify', 'rebus', 'boost', 'truss', 'siege', # 190-199
    'tiger', 'banal', 'slump', 'crank', 'gorge', 'query', 'drink', 'favor', 'abbey', 'tangy', # 200-209
    'panic', 'solar', 'shire', 'proxy', 'point', 'robot', 'prick', 'wince', 'crimp', 'knoll', # 210-219
    'sugar', 'whack', 'mount', 'perky', 'could', 'wrung', 'light', 'those', 'moist', 'shard', # 220-229
    'pleat', 'aloft', 'skill', 'elder', 'frame', 'humor', 'pause', 'ulcer', 'ultra', 'robin', # 230-239
    'cynic', 'aroma', 'caulk', 'shake', 'dodge', 'swill', 'tacit', 'other', 'thorn', 'trove', # 240-249
    'bloke', 'vivid', 'spill', 'chant', 'choke', 'rupee', 'nasty', 'mourn', 'ahead', 'brine', # 250-259
    'cloth', 'hoard', 'sweet', 'month', 'lapse', 'watch', 'today', 'focus', 'smelt', 'tease', # 260-269
    'cater', 'movie', 'saute', 'allow', 'renew', 'their', 'slosh', 'purge', 'chest', 'depot', # 270-279
    'epoxy', 'nymph', 'found', 'shall', 'stove', 'lowly', 'snout', 'trope', 'fewer', 'shawl', # 280-289
    'natal', 'comma', 'foray', 'scare', 'stair', 'black', 'squad', 'royal', 'chunk', 'mince', # 290-299
    'shame', 'cheek', 'ample', 'flair', 'foyer', 'cargo', 'oxide', 'plant', 'olive', 'inert', # 300-309
    'askew', 'heist', 'shown', 'zesty', 'trash', 'larva', 'forgo', 'hairy', 'story', 'train', # 310-319
    'homer', 'badge', 'midst', 'canny', 'shine', 'gecko', 'farce', 'slung', 'tipsy', 'metal', # 320-329
    'yield', 'delve', 'being', 'scour', 'glass', 'gamer', 'scrap', 'money', 'hinge', 'album', # 330-339
    'vouch', 'asset', 'tiara', 'crept', 'bayou', 'atoll', 'manor', 'creak', 'showy', 'phase', # 340-349
    'froth', 'depth', 'gloom', 'flood', 'trait', 'girth', 'piety', 'goose', 'float', 'donor', # 350-359
    'atone', 'primo', 'apron', 'blown', 'cacao', 'loser', 'input', 'gloat', 'awful', 'brink', # 360-369
    'smite', 'beady', 'rusty', 'retro', 'droll', 'gawky', 'hutch', 'pinto', 'egret', 'lilac', # 370-379
    'sever', 'field', 'fluff', 'agape', 'voice', 'stead', 'berth', 'madam', 'night', 'bland', # 380-389
    'liver', 'wedge', 'roomy', 'wacky', 'flock', 'angry', 'trite', 'aphid', 'tryst', 'midge', # 390-399
    'power', 'elope', 'cinch', 'motto', 'stomp', 'upset', 'bluff', 'cramp', 'quart', 'coyly', # 400-409
    'youth', 'rhyme', 'buggy', 'alien', 'smear', 'unfit', 'patty', 'cling', 'glean', 'label', # 410-419
    'hunky', 'khaki', 'poker', '', '', '', '', '', '', '',
    # '', '', '', '', '', '', '', '', '', '',
  ]
  @@previous_wordle_solutions_hash = @@previous_wordle_solutions.map.with_index { |x, i| [x, i] }.to_h

  def self.all_solutions
    @@previous_wordle_solutions_hash
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
  puts "remaining: #{d.size}"

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
  puts top_n_dict

  # for all remaining words, they are a great guess if all of the "top N" characters are contained
  # and they are a "good" guess if all but one of the top N characters occur
  d.each do |word, line_num|
    count = 0
    top_n_dict.each {|c, num_occurrences| count = count + 1 if word[c]}
    puts "#{word} is a GREAT guess" if count == top_n
    puts "#{word} is a good guess" if count == (top_n - 1)
  end
end

def num_green_or_yellow(word, response, letter)
  num_green_or_yellow = 0
  (0...5).each { |i| num_green_or_yellow += 1 if word[i] == letter && response[i] != '-' }
  return num_green_or_yellow
end

def filter(d, word, response)
  puts "d.size: #{d.size()}"
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
end

run_tests
d = populate_all_words
play(d)
