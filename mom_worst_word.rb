#!/usr/bin/ruby -w

# copied from https://github.com/charlesreid1/five-letter-words
DICTIONARY_FILE_LARGE = "sgb-words.txt"
DICTIONARY_FILE_SMALL = "sgb-words-small.txt"
DICTIONARY_FILE_NO_PLURALS = "sgb-words-without-plurals-sorted.txt"
DICTIONARY_FILE = DICTIONARY_FILE_NO_PLURALS

def response(word_const, guess)
  guess = guess.dup # defensive copying
  # puts "response() ENTER: word=#{word_const}, guess=#{guess}"
  word = String.new(word_const)
  # Calculate all greens. Clear values in word and guess.
  response = "-----"
  for i in 0...5
    if guess[i] == word[i]
      response[i] = '!'
      guess[i] = '-'
      word[i] = '-'
    end
  end

  # Calculate all yellows. Clear out matching letters.
  for i in 0...5
    if guess[i] != '-'
      for j in 0...5
        if word[j] != '-' and i != j and guess[i] == word[j]
          response[i] = '?'
          guess[i] = '-'
          word[j] = '-'
          break
        end
      end
    end
  end
  # puts "response() EXIT: response=#{response}"
  response
end

def num_remaining_after_five_guesses(word)
  d = populate_all_words
  # puts "d.size=#{d.size}"
  # https://www.cbs8.com/article/news/local/zevely-zone/five-magic-words-that-will-solve-wordle/509-fec2b387-5202-4d74-8c47-fde9221a82c1
  all_guesses = {
    :mom => ['raise', 'clout', 'windy', 'blimp', 'fight'], # J K Q V X Z (stave-state-stake-skate)
    :me1 => ['raise', 'clout', 'nymph', 'befog', 'dowak'], # J Q V X Z (jaunt-taunt-vaunt) + 11 other groups
    :myles_mellor => ['derby', 'flank', 'ghost', 'winch', 'jumps'], # Q V X Z (addle-axled-laded-ladle-laved-lazed)
    :rick_canedo => ['fight', 'clomp', 'brand', 'jukes', 'woozy'], # Q V X (eater-rater-tater-taxer)
    :me2 => ['raise', 'clout', 'nymph', 'befog', 'vowed'], # J K Q X Z (eater-taker-tater-taxer)
    :me3 => ['fight', 'clomp', 'brand', 'jukes', 'viewy'], # Q X Z (eater-rater-tater-taxer)
    :me4 => ['fight', 'clomp', 'brand', 'jukes', 'wavey'], # Q X Z (eater-rater-tater-taxer)
    :me5 => ['fight', 'clomp', 'brand', 'juves', 'wonky'], # Q X Z (eater-rater-tater-taxer)
    :me6 => ['fight', 'clomp', 'brand', 'juves', 'risky'], # Q W X Z (eater-tater-taxer-water)
    :me7 => ['fight', 'clomp', 'brand', 'juves', 'tryke'], # Q W X Z (added-dazed-waded-waxed)
  }
  # best so far: me1, 36 words at 3-level, nothing at 4-level
  # agree/grave/graze, coded/codex/coxed, diddy/divvy/dizzy, eater/tater/taxer
  # faded/faxed/fazed, firer/fiver/fixer, jaunt/taunt/vaunt, laded/laved/lazed
  # paper/parer/paver, rarer/raver/razer, sided/sized/vised, waded/waved/waxed

  guesses = all_guesses[:me1]
  guesses.each{|guess| filter(d, guess, response(word, guess))}
  if ['agree', 'coded', 'diddy'].include? word
    puts "Found #{word}!, d.size=#{d.size}, (#{d.map{|w,_| w}.join(',')})"
  end
  d.size
end

# for raise-clout-windy-blimp-fight, the worst words have 8 possibilities remaining
# 8-level (8 words): lakes, sales, easel, vales, kales, laves, lazes, lases
# 7-level (21 words, 0 non-S-terminating):
# 6-level (30 words, 4 non-S-terminating): steak, sized, sided, vised
# 5-level (20 words, 4 non-S-terminating): sever, sorer, servo, asker
# 4-level (104 words, 49 non-S-terminating)
# 3-level (228 words, 116 non-S-terminating)
# 2-level (708 words, 395 non-S-terminating)
#
# easel has 8 words remaining (including easel) but the other 7 all end in S.
#
# Repeat above analysis, but using DICTIONARY_FILE_NO_PLURALS
# 4-level (36 words, 0 S-terminating)
# 3-level (96 words, 1 S-terminating)
# 2-level (360 words, 12 S-terminating)
#
# Looks like the worst is: stave/state/stake/skate
def mom_worst_words
  # Note: this function takes ~80 seconds to run
  # for raise-clout-windy-blimp-fight, the worst words have 8 possibilities remaining
  worst_word_lists = [[], [], [], [], [], [], [], [], []]
  threshold = 3
  all_words = populate_all_words_array
  for word in all_words
  # for i in 0...all_words.length
  #   if i >= 1000
  #     break
  #   end
  #   word = all_words[i]
    num_remaining = num_remaining_after_five_guesses(word)
    if num_remaining >= threshold
      # puts "#{word} has #{num_remaining} remaining"
      worst_word_lists[num_remaining] << word
    end
  end
  # for l in worst_word_lists
  for i in 0...worst_word_lists.length
    l = worst_word_lists[i]
    if l.length == 0
      next
    end
    non_s_final_count = 0
    for word in l
      if word[4] != 's'
        non_s_final_count += 1
      end
    end
    puts "The #{i}-level has #{l.count} words. #{non_s_final_count} do not end in S."
    # l.each { |word| puts "#{word}" if word[4] != 's' }
    l.each { |word| puts "#{word}" }
  end
end

def populate_all_words_array
  a = []
  File.foreach(DICTIONARY_FILE) do |line|
    a << line.chomp
  end
  a
end

def populate_all_words
  d = {}
  File.foreach(DICTIONARY_FILE).with_index do |line, line_num|
    d[line.chomp] = line_num
  end
  d
end

def play(d)
  puts "Welcome to wordle!"
  for guess in 1..6
    puts "You are on guess #{guess}/6. There are #{d.size} matching words remaining."
    check_for_problematic_patterns(d) if guess >= 3
    while true do
      print "Enter a guess, or (p)rint, (h)int, (q)uit: ==> "
      choice = gets.chomp
      case choice
      when "p"
        max_print = 30
        d.each_with_index {|(key, _value), index| break if index >= max_print; puts key }
        puts "skipping #{d.size-max_print} additional results..." if d.size > max_print
      when "pa"
        d.each {|key, value| puts key}
      when "h"
        hint(d)
      when "q"
        return
      else # assume anything else is a guess
        print "Enter the response (!?-): ==> "
        response = gets.chomp
        filter(d, choice, response)
        break
      end
    end
  end
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
  puts "Checking for problematic patterns..."
  pp_dict.each do |key, value|
    puts "\nPROBLEMATIC PATTERN ALERT: found \"#{key}\" with #{value} matching words (print for details)\n\n" if value > 2
  end
  puts "No problematic patterns found!" if pp_dict.values.max <= 2
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
  (0...5).each { |i| num_green_or_yellow += 1 if word[i] == letter && response[i] != "-" }
  return num_green_or_yellow
end

def filter(d, word, response)
  # puts "filter(): enter, d.size=#{d.size}, word=#{word}, response=#{response}"
  for i in 0...5
    letter = word[i]
    case response[i]
    when "!"
      d.delete_if { |key, value| key[i] != letter }
    when "?"
      d.delete_if { |key, value| key[i] == letter || key.count(letter) < num_green_or_yellow(word, response, letter) }
    when "-"
      d.delete_if { |key, value| key[i] == letter || key.count(letter) != num_green_or_yellow(word, response, letter) }
    else
      raise "unrecognized response character"
    end
  end
  # puts "d.size(filter end): #{d.size()}"
end

def run_tests
  fail if response('aaaaa', 'aaaaa') != '!!!!!'
  fail if response('raise', 'saner') != '?!-??'
  fail if response('aabbc', 'abbaa') != '!?!?-'

  fail if num_remaining_after_five_guesses('agree') != 3
end

run_tests
# d = populate_all_words
# play(d)
mom_worst_words
