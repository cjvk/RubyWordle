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

def replace_with_blank(word, position)
  copy_of_word = "#{word}"
  copy_of_word[position]="_"
  copy_of_word
end

def what_is_blank(word_with_blank, word)
  i = word_with_blank.index('_')
  word[i]
end

def populate_blanks
  d = {}
  File.foreach(DICTIONARY_FILE) do |line|
    line = line.chomp
    for pos in 0..4
      with_blank = replace_with_blank(line, pos)
      l = d[with_blank]
      l = l.nil? ? [] : l
      l.append(line)
      d[with_blank] = l
    end
  end
  d
end

def analyze_blank_dictionary(d)
  # turns out max is _ills, with 13 (!) possible first letters
  # threshold, problem_threshold_from_max = 9, 5 # MPSTR BLDW # MPBDW
  # threshold, problem_threshold_from_max = 8, 12 # PMRTS DBLW
  threshold, problem_threshold_from_max = 7, 20 # MRTPD LBSFW
  printing_allowlist = ["la_er"]

  analysis_dictionary = {}
  d.each do |key, value|
    if value.length >= threshold
      analysis_dictionary[key] = value
      if printing_allowlist.include? key
        print key, value, "\n"
      end
    end
  end

  problem_character_dictionary = {}
  for c in 97..122
    problem_character_dictionary[c.chr] = 0
  end

  print "\n"
  puts "calculating problematic patterns..."
  analysis_dictionary.each do |key, value|
    if value.length >= 10
      puts "#{key} has #{value.length} matching words!"
    end
    value.each { |word|
      b = what_is_blank(key, word)
      # puts "for the pattern #{key} and the word #{word}, the blank is used as a #{b}"
      problem_character_dictionary[b] = problem_character_dictionary[b] + 1
    }
  end
  print "\n"

  sorted_problem_chars = problem_character_dictionary.sort_by { |key, val| -val }
  total_analyzed = analysis_dictionary.size()
  problem_threshold = [0, sorted_problem_chars[0][1]-problem_threshold_from_max].max
  puts "continuing to problematic pattern analysis..."
  sorted_problem_chars.each { |tuple|
    c = tuple[0]
    n = tuple[1]
    if n >= problem_threshold
      puts "out of #{total_analyzed} problematic patterns, #{c} occurred #{n} times."
    end
  }
end

# d = populate_all_words
d_with_blanks = populate_blanks
analyze_blank_dictionary d_with_blanks

