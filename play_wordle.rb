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
    if guess >= 3
      check_for_problematic_patterns(d)
    end
    while true do
      print "Enter a guess, or (p)rint, (h)int, (q)uit: ==> "
      choice = gets.chomp
      case choice
      when "p"
        max_print = 30
        d.each do |key, value|
          puts key
          max_print = max_print - 1
          if max_print <= 0
            puts "skipping additional results..."
            break
          end
        end
      when "pa"
        d.each do |key, value|
          puts key
        end
      when "h"
        hint(d)
      when "q"
        return
      else # assume anything else is a guess
        word = choice
        print "Enter the response (!?-): ==> "
        response = gets.chomp
        filter(d, word, response)
        break
      end
    end
  end
end

def close(w1, w2)
  diff = 0
  for i in 0...5
    diff = diff + (w1[i]==w2[i] ? 0 : 1)
  end
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
    if !found
      pp_dict[key1] = 1
    end
  end
  puts "Checking for problematic patterns..."
  found = false
  pp_dict.each do |key, value|
    if value > 2
      found = true
      puts ""
      puts "PROBLEMATIC PATTERN ALERT: found \"#{key}\" with #{value} matching words (print for details)"
      puts ""
    end
  end
  puts "No problematic patterns found!" if found == false
end

def hint(d)
  num_remaining = d.size
  puts "remaining: #{num_remaining}"
  # character_dictionary stores, for each letter, the number of remaining words with that letter
  character_dictionary = {}
  for c in 97..122
    character_dictionary[c.chr] = 0
  end
  d.each do |word, line_num|
    character_dictionary.each do |c, num_so_far|
      if word[c]
        character_dictionary[c] = num_so_far + 1
      end
    end
  end
  top_n = 3
  # top_n_dict will contain the top N keys from character_dictionary, by count
  top_n_dict = {}
  for i in 0...top_n
    next_largest = character_dictionary.max_by{|k,v| (v==num_remaining||top_n_dict.has_key?(k)) ? 0 : v}
    top_n_dict[next_largest[0]]=next_largest[1]
  end
  puts top_n_dict
  # for all remaining words, they are a great guess if all of the "top N" characters are contained
  # and they are a "good" guess if all but one of the top N characters occur
  d.each do |word, line_num|
    count = 0
    top_n_dict.each do |c, num_occurrences|
      count = count + 1 if word[c]
    end
    puts "#{word} is a GREAT guess" if count == top_n
    puts "#{word} is a good guess" if count == (top_n - 1)
  end
end

def num_green_or_yellow(word, response, letter)
  num_green_or_yellow = 0
  for i in 0...5
    if word[i] == letter && response[i] != "-"
      num_green_or_yellow += 1
    end
  end
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
    # puts "#{response[i]} detected, i=#{i}"
    # puts "d.size: #{d.size()}"
    # puts d
  end
end

d = populate_all_words
play(d)
