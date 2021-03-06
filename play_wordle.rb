#!/usr/bin/ruby -w

# copied from https://github.com/charlesreid1/five-letter-words
DICTIONARY_FILE_LARGE = "sgb-words.txt"
DICTIONARY_FILE_SMALL = "sgb-words-small.txt"
DICTIONARY_FILE = DICTIONARY_FILE_LARGE

# from https://gist.github.com/dracos/dd0668f281e685bad51479e5acaadb93
VALID_WORDLE_WORDS_FILE = "valid-wordle-words.txt"

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
  d["pinot"] = "-1"
  d["ramen"] = "-1"
  d["beret"] = "-1"
  d["apage"] = "-1"
  d["stear"] = "-1"
  d["stean"] = "-1"
  d["tased"] = "-1"
  d["tsade"] = "-1"
  d
end

def play(d)
  puts "Welcome to wordle!"
  for guess in 1..6
    puts "You are on guess #{guess}/6. There are #{d.size} matching words remaining."
    check_for_problematic_patterns(d) if guess >= 3
    while true do
      print "Enter a guess, or (p)rint, (c)ount, (h)int, (q)uit: ==> "
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
      when "c"
        puts "There are #{d.size} matching words remaining."
      when "penultimate"
        penultimate(d)
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

def penultimate(d)
  puts "Choose a Twitter penultimate guess"
  puts "4 greens (4g)"
  puts "3 greens and 1 yellow (3g1y)"
  puts "3 greens and 2 yellows (3g2y)"
  puts "2 greens and 3 yellows (2g3y)"
  puts "1 green and 4 yellows (1g4y)"
  puts "0 greens and 5 yellows (0g5y)"
  print "==> "
  choice = gets.chomp
  case choice
  when "4g"
    print "Enter the position of the gray (1-5): ==> "
    gray = gets.chomp.to_i - 1
    print "Enter the count: ==> "
    count = gets.chomp.to_i
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
        puts "keeping #{key}"
        all_words.each_key {|key| puts key}
      end
    end
  when "3g1y"
    print "Enter the position of the yellow (1-5): ==> "
    yellow = gets.chomp.to_i - 1
    print "Enter the position of the gray (1-5): ==> "
    gray = gets.chomp.to_i - 1
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
        puts "keeping #{key}"
        all_words.each_key {|key| puts key}
      end
    end
  when "1g4y"
    print "Enter the position of the green (1-5): ==> "
    green = gets.chomp.to_i - 1
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
        puts "keeping #{key}"
        all_words.each_key {|key| puts key}
      end
    end
  when "0g5y"
    d.each_key do |key|
      all_words = populate_valid_wordle_words
      for i in 0...5
        # all yellows
        all_words.delete_if { |key2, value2| key2[i] == key[i] || key2.count(key2[i]) != key.count(key2[i]) }
      end
      if all_words.size == 0
        d.delete(key)
      else
        puts "keeping #{key}"
        all_words.each_key {|key| puts key}
      end
    end
  when "2g3y"
    print "Enter the positions of the two greens (1-5): ==> "
    greens = gets.chomp
    green1 = greens[0].to_i - 1
    green2 = greens[1].to_i - 1
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
        puts "keeping #{key}"
        all_words.each_key {|key| puts key}
      end
    end
  when "3g2y"
    print "Enter the positions of the two yellows (1-5): ==> "
    yellows = gets.chomp
    yellow1 = yellows[0].to_i - 1
    yellow2 = yellows[1].to_i - 1
    all_words = populate_valid_wordle_words
    d.each_key do |key|
      switched_word = key.dup
      switched_word[yellow1] = key[yellow2]
      switched_word[yellow2] = key[yellow1]
      puts "testing #{key} and #{switched_word}"
      if key != switched_word and all_words.key?(switched_word)
        puts "ALERT: found a possible word: #{key}"
      else
        d.delete(key)
      end
    end
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
  (0...5).each { |i| num_green_or_yellow += 1 if word[i] == letter && response[i] != "-" }
  return num_green_or_yellow
end

def filter(d, word, response)
  puts "d.size: #{d.size()}"
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
end

def run_tests
  fail if num_green_or_yellow("abcde", "!----", "a") != 1
  fail if num_green_or_yellow("aaaaa", "!?---", "a") != 2
  fail if num_green_or_yellow("aaaaa", "??---", "a") != 2
  fail if num_green_or_yellow("xaaxx", "!!--!", "c") != 0
  fail if num_green_or_yellow("xaaxx", "?????", "x") != 3
  fail if num_green_or_yellow("xaaxx", "?????", "a") != 2

  fail if close("aaaaa", "bbbbb")
  fail if close("aaaaa", "aaabb")
  fail if close("abcde", "abcde")
  fail unless close("abcde", "xbcde")
  fail unless close("abcde", "axcde")
  fail unless close("abcde", "abxde")
  fail unless close("abcde", "abcxe")
  fail unless close("abcde", "abcdx")
end

run_tests
d = populate_all_words
play(d)
