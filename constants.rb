#!/usr/bin/ruby -w

# copied from https://github.com/charlesreid1/five-letter-words
# The purpose of this file is the universe of solutions
DICTIONARY_FILE_LARGE = 'sgb-words.txt'
DICTIONARY_FILE_SMALL = 'sgb-words-small.txt'
DICTIONARY_FILE_LIKELY_PLURALS = 'sgb-words-plurals-sorted.txt'

# produced via scrape_nyt.rb: the universe of legal guesses
VALID_WORDLE_WORDS_FILE = 'valid-wordle-words.txt'

# from https://gist.github.com/dracos/dd0668f281e685bad51479e5acaadb93
# The purpose of this file is a smaller legal-guesses file,
# which might perform better during absence-of-evidence analysis.
DRACOS_VALID_WORDLE_WORDS_FILE = 'dracos-valid-wordle-words.txt'

ALPHABET = [
  'a','b','c','d','e','f','g','h','i','j','k','l','m',
  'n','o','p','q','r','s','t','u','v','w','x','y','z'
].freeze
