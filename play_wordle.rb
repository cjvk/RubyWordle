#!/usr/bin/ruby -w

# copied from https://github.com/charlesreid1/five-letter-words
DICTIONARY_FILE_LARGE = "sgb-words.txt"
DICTIONARY_FILE_SMALL = "sgb-words-small.txt"
DICTIONARY_FILE = DICTIONARY_FILE_LARGE

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
