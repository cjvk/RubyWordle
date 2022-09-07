#!/usr/bin/ruby -w

module Tests
  def Tests::run_tests
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

    # wordle_response(guess, word)
    fail unless wordle_response('saner', 'raise') == 'ygwyy'
    fail unless wordle_response('sanee', 'raise') == 'ygwwg'
    fail unless wordle_response('saaer', 'raise') == 'ygwyy'
    fail unless wordle_response('saaer', 'raisa') == 'ygywy'
    fail unless wordle_response('saaar', 'raisa') == 'ygywy'

    fail unless InterestingWordleResponses::determine_interestingness('ggggg') == InterestingWordleResponses::NOT_INTERESTING
    fail unless InterestingWordleResponses::determine_interestingness('ggggw') == InterestingWordleResponses::WORDLE_4G
    fail unless InterestingWordleResponses::determine_interestingness('ggwgg') == InterestingWordleResponses::WORDLE_4G
    fail unless InterestingWordleResponses::determine_interestingness('wgggg') == InterestingWordleResponses::WORDLE_4G
    fail unless InterestingWordleResponses::determine_interestingness('gggwy') == InterestingWordleResponses::WORDLE_3G1Y
    fail unless InterestingWordleResponses::determine_interestingness('gggyy') == InterestingWordleResponses::WORDLE_3G2Y
    fail unless InterestingWordleResponses::determine_interestingness('ggyyy') == InterestingWordleResponses::WORDLE_2G3Y
    fail unless InterestingWordleResponses::determine_interestingness('gyyyy') == InterestingWordleResponses::WORDLE_1G4Y
    fail unless InterestingWordleResponses::determine_interestingness('yyyyy') == InterestingWordleResponses::WORDLE_0G5Y

    fail unless all_4g_matches('hilly', VALID_WORDLE_WORDS_FILE) == [9, 3, 1, 0, 2]
    fail unless all_4g_matches('hills', VALID_WORDLE_WORDS_FILE) == [18, 3, 0, 2, 2]
    fail unless all_4g_matches('hilly', DRACOS_VALID_WORDLE_WORDS_FILE) == [7, 2, 1, 0, 2]
    fail unless all_4g_matches('hills', DRACOS_VALID_WORDLE_WORDS_FILE) == [18, 3, 0, 2, 2]

    fail unless WordleModes.determine_mode("#{WordleShareColors::GREEN}#{WordleShareColors::WHITE}") == 'Normal'
    fail unless WordleModes.determine_mode("#{WordleShareColors::YELLOW}#{WordleShareColors::WHITE}") == 'Normal'
    fail unless WordleModes.determine_mode("#{WordleShareColors::GREEN}#{WordleShareColors::BLACK}") == 'Dark'
    fail unless WordleModes.determine_mode("#{WordleShareColors::YELLOW}#{WordleShareColors::BLACK}") == 'Dark'
    fail unless WordleModes.determine_mode("#{WordleShareColors::ORANGE}#{WordleShareColors::WHITE}") == 'Deborah'
    fail unless WordleModes.determine_mode("#{WordleShareColors::BLUE}#{WordleShareColors::WHITE}") == 'Deborah'
    fail unless WordleModes.determine_mode("#{WordleShareColors::ORANGE}#{WordleShareColors::BLACK}") == 'DeborahDark'
    fail unless WordleModes.determine_mode("#{WordleShareColors::BLUE}#{WordleShareColors::BLACK}") == 'DeborahDark'

    fail unless WordleModes.unicode_to_normalized_string(WordleShareColors::WHITE, 'Normal') == 'w'
    fail unless WordleModes.unicode_to_normalized_string(WordleShareColors::YELLOW, 'Normal') == 'y'
    fail unless WordleModes.unicode_to_normalized_string(WordleShareColors::GREEN, 'Normal') == 'g'
    fail unless WordleModes.unicode_to_normalized_string(WordleShareColors::BLACK, 'Dark') == 'w'
    fail unless WordleModes.unicode_to_normalized_string(WordleShareColors::YELLOW, 'Dark') == 'y'
    fail unless WordleModes.unicode_to_normalized_string(WordleShareColors::GREEN, 'Dark') == 'g'
    fail unless WordleModes.unicode_to_normalized_string(WordleShareColors::WHITE, 'Deborah') == 'w'
    fail unless WordleModes.unicode_to_normalized_string(WordleShareColors::BLUE, 'Deborah') == 'y'
    fail unless WordleModes.unicode_to_normalized_string(WordleShareColors::ORANGE, 'Deborah') == 'g'
    fail unless WordleModes.unicode_to_normalized_string(WordleShareColors::BLACK, 'DeborahDark') == 'w'
    fail unless WordleModes.unicode_to_normalized_string(WordleShareColors::BLUE, 'DeborahDark') == 'y'
    fail unless WordleModes.unicode_to_normalized_string(WordleShareColors::ORANGE, 'DeborahDark') == 'g'

    kdh = CompactKeys::KEY_COMPRESSION_HASH
    max_compact_keys_value = kdh.values.max
    min_compact_keys_value = kdh.values.min
    fail unless kdh['4g.1'] == 0
    fail unless min_compact_keys_value == 0
    # this also guarantees that all keys are unique
    (min_compact_keys_value..max_compact_keys_value).each {|v| fail unless kdh.has_value?(v)}
  end
end
