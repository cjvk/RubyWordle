#!/usr/bin/ruby -w

module Commands
  def Commands::regression_analysis(d)
    six_days_ago = (today_wordle_number.to_i - 6).to_s
    range = "(#{six_days_ago}-#{today_wordle_number})"
    wordle_number = UI.prompt_for_input("Enter daily wordle number for regression #{range}:")
    exit if wordle_number.to_i.to_s != wordle_number
    Twitter::Configuration.set_wordle_number_override wordle_number

    query_result = Twitter::Query::regular
    stats_hash = query_result.stats_hash
    a = Commands::filter_twitter(d.dup, stats_hash).keys
    b = Fingerprint::fingerprint_analysis(
      d.dup, stats_hash, suppress_output: true, dracos_override: false)[:d_nyt].keys

    [
      '',
      '/------------------------------------------------------\\',
      "|        Regression analysis report (Wordle #{wordle_number})       |",
      '\------------------------------------------------------/',
      '',
      "length comparison: #{a.length == b.length ? 'OK' : 'FAIL'}",
      "remaining word comparison: #{(a.size == b.size && a&b==a) ? 'OK' : 'FAIL'}",
      '',
      'Exiting because wordle_number_override was set manually...',
      '',
    ].each{|s| UI::padded_puts s}

    exit
  end

  def Commands::full_solver(d)
    max_to_print = UI.prompt_for_numeric_input('Enter max to print (default 10):', default_value: 10)
    verbose = UI.prompt_for_numeric_input('Enter number to print verbose (default 0):', default_value: 0)

    stats_hash1 = Twitter::Query::regular_with_singletons.stats_hash
    analysis_1 =
      Fingerprint::fingerprint_analysis(d, stats_hash1, max_to_print: max_to_print, verbose: verbose)[:d_nyt]
    max_score = analysis_1.map{|word, data_hash| data_hash[:nyt_score]}.max || 0

    if max_score < 80
      UI::padded_puts ''
      UI::padded_puts "****** Query with singletons produced a max score of only #{'%.1f' % max_score}!"
      UI::padded_puts ''
      UI::padded_puts ''
    end

    if UI.prompt_for_input(
      "Re-run with singleton filtering on? (#{StatsHash.num_singletons(stats_hash1)} singletons) ('y' to proceed)"
    ) == 'y'
      Fingerprint::fingerprint_analysis(
        d,
        Twitter::Query::regular.stats_hash,
        max_to_print: max_to_print,
        verbose: verbose)
    end
  end

  # Consider further: previous solution, repeated letters, "grade level", lower scrabble score
  def Commands::give_me_the_answer(d)
    wordle_number_default_value = today_wordle_number
    wordle_number = UI.prompt_for_numeric_input(
      "Enter daily wordle number (default #{wordle_number_default_value}):",
      default_value: wordle_number_default_value
    )
    Twitter::Configuration.set_wordle_number_override wordle_number
    give_me_the_answer_1(d, wordle_number)
  end

  def Commands::give_me_the_answer_1(d, wordle_number)
    _give_me_the_answer(
      d,
      wordle_number_or_default(suppress_output: true),
      list_length: 2,
      terse_printing: true,
      threshold: 60.0)
  end

  def Commands::give_me_the_answer_2(d, wordle_number)
    _give_me_the_answer(
      d,
      wordle_number_or_default(suppress_output: true),
      list_length: 5,
      terse_printing: true,
      discount_duplicates: true,
      eliminate_previous_solutions: true,
      discount_plurals: true,
      scrabble_sort: true,
      interactive: false)
  end

  def Commands::_give_me_the_answer(d, wordle_number,
                                   list_length: 2,
                                   terse_printing: false,
                                   threshold: nil,
                                   discount_duplicates: false,
                                   eliminate_previous_solutions: false,
                                   discount_plurals: false,
                                   scrabble_sort: false,
                                   interactive: false)
    UI::suppress_on
    print_a_winner = ->(word) {
      UI::suppress_off
      puts "\n\n" if !terse_printing
      UI::padded_puts("The answer to Wordle #{wordle_number} is #{word}.")
      puts "\n\n" if !terse_printing
      true
    }
    maybe_print_a_winner = ->(word, score) {
      return false if threshold.nil? || score < threshold
      # return false if (!threshold.nil? && (score < threshold));
      print_a_winner.call(word)
    }

    stats_hash1 = Twitter::Query::regular_with_singletons.stats_hash
    analysis1 = Fingerprint::fingerprint_analysis(d, stats_hash1, suppress_output: true, dracos_override: true)

    if discount_duplicates
      dup_discount = ->(word, score) {
        score * [0.2, 0.4, 0.6, 1.0, 1.0][word.chars.uniq.length-1]
      }
    else
      dup_discount = ->(word, score) { score }
    end

    results = {
      :with_singletons => {
        :nyt => analysis1[:d_nyt]
          .delete_if{|word, _| eliminate_previous_solutions && PreviousWordleSolutions.occurred_before(word)}
          .map{|word, data| data[:modified_nyt_score] = dup_discount.call(word, data[:nyt_score]); [word, data]}
          .map{|word, data| data[:modified_nyt_score] *= 0.5 if discount_plurals && plural?(word); [word, data]}
          .sort_by.with_index{|(word, data), i| [-1 * data[:modified_nyt_score], scrabble_sort ? scrabble_score(word) : 0, i]}
          .map{|word, data| [word, data[:modified_nyt_score]]}[0..list_length-1],
        :dracos => analysis1[:d_dracos]
          .delete_if{|word, _| eliminate_previous_solutions && PreviousWordleSolutions.occurred_before(word)}
          .map{|word, data| data[:modified_dracos_score] = dup_discount.call(word, data[:dracos_score]); [word, data]}
          .map{|word, data| data[:modified_dracos_score] *= 0.5 if discount_plurals && plural?(word); [word, data]}
          .sort_by.with_index{|(word, data), i| [-1 * data[:modified_dracos_score], scrabble_sort ? scrabble_score(word) : 0, i]}
          .map{|word, data| [word, data[:modified_dracos_score]]}[0..list_length-1],
      },
    }

    # threshold is checked inside maybe
    return if analysis1[:d_nyt].size > 0 && maybe_print_a_winner.call(*results[:with_singletons][:nyt][0])
    return if analysis1[:d_dracos].size > 0 && maybe_print_a_winner.call(*results[:with_singletons][:dracos][0])

    # save choices
    append_first_element_if_positive_score = ->(array_to_append, data_array) {
      if data_array.size > 0 && data_array[0][1] > 0
        array_to_append.append(data_array[0])
      end
    }
    choices = []
    append_first_element_if_positive_score.call(choices, results[:with_singletons][:nyt])
    append_first_element_if_positive_score.call(choices, results[:with_singletons][:dracos])

    # Remove potential bad tweets and re-run
    if StatsHash.num_singletons(stats_hash1) > 0
      analysis2 = Fingerprint::fingerprint_analysis(
        d, stats_hash2 = Twitter::Query::regular.stats_hash, suppress_output: true, dracos_override: true)

      results[:without_singletons] = {
        :nyt => analysis2[:d_nyt]
          .delete_if{|word, _| eliminate_previous_solutions && PreviousWordleSolutions.occurred_before(word)}
          .map{|word, data| data[:modified_nyt_score] = dup_discount.call(word, data[:nyt_score]); [word, data]}
          .map{|word, data| data[:modified_nyt_score] *= 0.5 if discount_plurals && plural?(word); [word, data]}
          .sort_by.with_index{|(word, data), i| [-1 * data[:modified_nyt_score], scrabble_sort ? scrabble_score(word) : 0, i]}
          .map{|word, data| [word, data[:modified_nyt_score]]}[0..list_length-1],
        :dracos => analysis2[:d_dracos]
          .delete_if{|word, _| eliminate_previous_solutions && PreviousWordleSolutions.occurred_before(word)}
          .map{|word, data| data[:modified_dracos_score] = dup_discount.call(word, data[:dracos_score]); [word, data]}
          .map{|word, data| data[:modified_dracos_score] *= 0.5 if discount_plurals && plural?(word); [word, data]}
          .sort_by.with_index{|(word, data), i| [-1 * data[:modified_dracos_score], scrabble_sort ? scrabble_score(word) : 0, i]}
          .map{|word, data| [word, data[:modified_dracos_score]]}[0..list_length-1],
      }

      return if maybe_print_a_winner.call(*results[:without_singletons][:nyt][0])
      return if maybe_print_a_winner.call(*results[:without_singletons][:dracos][0])

      choices.append(*[results[:without_singletons][:nyt][0], results[:without_singletons][:dracos][0]])
    end

    if interactive
      while true do
        puts ''
        print 'Enter a word to see its score, or ENTER to continue: ==> '
        user_input_word = gets.chomp
        break if '' == user_input_word
        exit if 'quit' == user_input_word || 'exit' == user_input_word
        puts ''
        puts "stats_hash1: #{stats_hash1}"
        puts ''
        puts "analysis1, NYT, #{user_input_word}: #{analysis1[:d_nyt][user_input_word]}"
        puts ''
        puts "analysis1, Dracos, #{user_input_word}: #{analysis1[:d_dracos][user_input_word]}"
        if stats_hash2
          puts ''
          puts "stats_hash2: #{stats_hash2}"
          puts ''
          puts "analysis2, NYT, #{user_input_word}: #{analysis2[:d_nyt][user_input_word]}"
          puts ''
          puts "analysis2, Dracos, #{user_input_word}: #{analysis2[:d_dracos][user_input_word]}"
        end
      end
    end

    # nothing was high enough (sigh!) - pick the best choice
    print_a_winner.call(choices.max_by{|word, score| [score, scrabble_sort ? -1 * scrabble_score(word) : 0]}[0])
  end

  def Commands::give_me_the_answer_2_deprecated(d, wordle_number)
    # improvements: eliminate previous solutions, tiebreak on repeated letters & lower scrabble score
    # to wit: Wordle 478 had six words all get a score of 100 (ilium/enjoy/knoll/jujus/excel/quaff)
    UI::suppress_on
    list_length = 5
    print_a_winner = ->(word) {
      UI::suppress_off
      puts "\n\n"
      UI::padded_puts("The answer to Wordle #{wordle_number} is #{word}.")
      puts "\n\n"
      true
    }

    stats_hash1 = Twitter::Query::regular_with_singletons.stats_hash
    analysis1 = Fingerprint::fingerprint_analysis(d, stats_hash1, suppress_output: true, dracos_override: true)

    dup_discount = ->(word, score) {
      score * [0.2, 0.4, 0.6, 1.0, 1.0][word.chars.uniq.length-1]
    }

    # These are sorted by score only - make following refinements:
    # - eliminate previous solutions (considered backward from current wordle number)
    # - sort by lower scrabble score
    # - (future) sort by repeated letters?
    # - (future) eliminate (or drastically discount) plurals?
    results = {
      :with_singletons => {
        :nyt => analysis1[:d_nyt]
          .delete_if{|word, _| PreviousWordleSolutions.occurred_before(word)}
          .map{|word, data| data[:modified_nyt_score] = dup_discount.call(word, data[:nyt_score]); [word, data]}
          .map{|word, data| data[:modified_nyt_score] *= 0.5 if plural?(word); [word, data]}
          .sort_by.with_index{|(word, data), i| [-1 * data[:modified_nyt_score], scrabble_score(word), i]}
          .map{|word, data| [word, data[:modified_nyt_score]]}[0..list_length-1],
        :dracos => analysis1[:d_dracos]
          .delete_if{|word, _| PreviousWordleSolutions.occurred_before(word)}
          .map{|word, data| data[:modified_dracos_score] = dup_discount.call(word, data[:dracos_score]); [word, data]}
          .map{|word, data| data[:modified_dracos_score] *= 0.5 if plural?(word); [word, data]}
          .sort_by.with_index{|(word, data), i| [-1 * data[:modified_dracos_score], scrabble_score(word), i]}
          .map{|word, data| [word, data[:modified_dracos_score]]}[0..list_length-1],
      },
    }

    append_first_element_if_positive_score = ->(array_to_append, data_array) {
      if data_array.size > 0 && data_array[0][1] > 0
        array_to_append.append(data_array[0])
      end
    }
    choices = []
    append_first_element_if_positive_score.call(choices, results[:with_singletons][:nyt])
    append_first_element_if_positive_score.call(choices, results[:with_singletons][:dracos])

    # Remove potential bad tweets and re-run
    if StatsHash.num_singletons(stats_hash1) > 0
      analysis2 = Fingerprint::fingerprint_analysis(
        d, stats_hash2 = Twitter::Query::regular.stats_hash, suppress_output: true, dracos_override: true)

      results[:without_singletons] = {
        :nyt => analysis2[:d_nyt]
          .delete_if{|word, _| PreviousWordleSolutions.occurred_before(word)}
          .map{|word, data| data[:modified_nyt_score] = dup_discount.call(word, data[:nyt_score]); [word, data]}
          .map{|word, data| data[:modified_nyt_score] *= 0.5 if plural?(word); [word, data]}
          .sort_by.with_index{|(word, data), i| [-1 * data[:modified_nyt_score], scrabble_score(word), i]}
          .map{|word, data| [word, data[:modified_nyt_score]]}[0..list_length-1],
        :dracos => analysis2[:d_dracos]
          .delete_if{|word, _| PreviousWordleSolutions.occurred_before(word)}
          .map{|word, data| data[:modified_dracos_score] = dup_discount.call(word, data[:dracos_score]); [word, data]}
          .map{|word, data| data[:modified_dracos_score] *= 0.5 if plural?(word); [word, data]}
          .sort_by.with_index{|(word, data), i| [-1 * data[:modified_dracos_score], scrabble_score(word), i]}
          .map{|word, data| [word, data[:modified_dracos_score]]}[0..list_length-1],
      }

      choices.append(*[results[:without_singletons][:nyt][0], results[:without_singletons][:dracos][0]])
    end

    # debugging
    while true do
      puts ''
      print 'Enter a word to see its score, or ENTER to continue: ==> '
      user_input_word = gets.chomp
      break if '' == user_input_word
      exit if 'quit' == user_input_word || 'exit' == user_input_word
      puts ''
      puts "stats_hash1: #{stats_hash1}"
      puts ''
      puts "analysis1, NYT, #{user_input_word}: #{analysis1[:d_nyt][user_input_word]}"
      puts ''
      puts "analysis1, Dracos, #{user_input_word}: #{analysis1[:d_dracos][user_input_word]}"
      if stats_hash2
        puts ''
        puts "stats_hash2: #{stats_hash2}"
        puts ''
        puts "analysis2, NYT, #{user_input_word}: #{analysis2[:d_nyt][user_input_word]}"
        puts ''
        puts "analysis2, Dracos, #{user_input_word}: #{analysis2[:d_dracos][user_input_word]}"
      end
    end

    # nothing was high enough (sigh!) - pick the best choice
    print_a_winner.call(choices.max_by{|word, score| [score, -1 * scrabble_score(word)]}[0])
  end

  def Commands::give_me_the_answer_1_deprecated(d, wordle_number)
    # frozen on 10/26/2022
    UI::suppress_on
    list_length = 2 # second could be useful to see if there is a "clear winner"
    threshold = 60.0
    print_a_winner = ->(word) {
      UI::suppress_off
      puts "\n\n"
      UI::padded_puts("The answer to Wordle #{wordle_number} is #{word}.")
      puts "\n\n"
      true
    }
    maybe_print_a_winner = ->(word, score) { return false if score < threshold; print_a_winner.call(word)}

    stats_hash1 = Twitter::Query::regular_with_singletons.stats_hash
    analysis1 = Fingerprint::fingerprint_analysis(d, stats_hash1, suppress_output: true, dracos_override: true)

    results = {
      :with_singletons => {
        :nyt => analysis1[:d_nyt].map{|word,data| [word, data[:nyt_score]]}[0..list_length-1],
        :dracos => analysis1[:d_dracos].map{|word,data| [word, data[:dracos_score]]}[0..list_length-1],
      },
    }
    # puts results

    # First choice NYT, then dracos with its smaller fingerprints, otherwise save top choices and continue
    if analysis1[:d_nyt].size > 0
      return if maybe_print_a_winner.call(*results[:with_singletons][:nyt][0])
      return if maybe_print_a_winner.call(*results[:with_singletons][:dracos][0])
      choices = [results[:with_singletons][:nyt][0], results[:with_singletons][:dracos][0]]
    else
      choices = []
    end
    # puts "choices=#{choices}"

    # If neither is high enough, remove potential bad tweets and re-run
    if StatsHash.num_singletons(stats_hash1) > 0
      analysis2 = Fingerprint::fingerprint_analysis(
        d, Twitter::Query::regular.stats_hash, suppress_output: true, dracos_override: true)
      results[:without_singletons] = {
        :nyt => analysis2[:d_nyt].map{|word,data| [word, data[:nyt_score]]}[0..list_length-1],
        :dracos => analysis2[:d_dracos].map{|word,data| [word, data[:dracos_score]]}[0..list_length-1],
      }
      # puts results

      # NYT, dracos, save top choices
      return if maybe_print_a_winner.call(*results[:without_singletons][:nyt][0])
      return if maybe_print_a_winner.call(*results[:without_singletons][:dracos][0])
      choices.append(*[results[:without_singletons][:nyt][0], results[:without_singletons][:dracos][0]])
      # puts "choices=#{choices}"
    end

    # nothing was high enough (sigh!) - pick the best choice
    print_a_winner.call(choices.max_by{|_word, score| score}[0])
  end

  def Commands::goofball_analysis
    wordle_number = UI.prompt_for_numeric_input("Enter daily wordle number (to check for goofballs):")
    Twitter::Configuration.set_wordle_number_override wordle_number
    stats_hash, answers = Twitter::Query::goofball.stats_hash_and_answers
    solution = PreviousWordleSolutions.lookup_by_number wordle_number

    singleton_keys = []
    stats_hash
      .map{|k, v| answers.each{|ans| singleton_keys.append([k, ans]) if ans.matches_key(k)} if v == 1; [k, v]}
      .map{|k, v| answers.each{|ans| singleton_keys.append([k, ans]) if ans.matches_key(k)} if v == 2; [k, v]}
      .map{|k, v| answers.each{|ans| singleton_keys.append([k, ans]) if ans.matches_key(k)} if v == 3; [k, v]}
      .map{|k, _| answers.each{|ans| ans.pp if ans.matches_key(k)} if k=='4g.5.1' && false} # debug printing

    [
      '',
      '',
      '',
      '/--------------------------------------\\',
      "|              Wordle #{wordle_number}              |",
      '|            Goofball report           |',
      '\--------------------------------------/',
      '',
    ].each{|s| UI::padded_puts(s)}

    answers_and_verdicts = [] # [answer, key, reasoning, verdict, title]

    singleton_keys.each do |el|
      key = el[0]
      answer = el[1]
      penultimate = answer.penultimate
      interestingness = InterestingWordleResponses::determine_interestingness(penultimate)
      name, subname, _key = InterestingWordleResponses::calculate_name_subname_key(penultimate, interestingness)
      count = name == '4g' ? key[5].to_i : 0
      all_words = populate_valid_wordle_words
      if interestingness == InterestingWordleResponses::WORDLE_4G
        # special handling for 4g: Find actual high-water-mark, see if the reported count is reasonable
        gray_index = subname[0].to_i - 1
        valid_alternatives = ALPHABET
          .map{|c| Filter::replace_ith_letter(solution, gray_index, c)}
          .delete_if {|word_to_check| word_to_check == solution || !all_words.key?(word_to_check)}
        is_goofball = (count > valid_alternatives.length)

        title = !is_goofball ? 'Not a Goofball' :
          (valid_alternatives.length == 0 ? 'Definite Goofball!' : 'Possible Goofball')
      else
        # Everything besides 4g: Go through all available words, see what words get that match.
        valid_alternatives = []
        all_words.each{|key, _| valid_alternatives.append(key) if penultimate == wordle_response(key, solution)}
        is_goofball = valid_alternatives.length == 0
        title = is_goofball ? 'Definite Goofball!' : 'Not a Goofball'
      end

      reasoning = "(#{valid_alternatives.join('/')})"
      verdict = is_goofball ? 'deny' : 'allow'

      answers_and_verdicts.append(
        [answer, key, reasoning, verdict, title]
      )
    end

    answers_and_verdicts = answers_and_verdicts.sort_by {|_, _, _, _, title| title}

    print_goofball_report_entry = ->(answer, key, reasoning, verdict, title) {
      nm = wordle_number
      sn = solution
      aid = answer.author_id

      # Goofball report
      puts "Author ID #{aid} already in denylist" if Twitter::Configuration.author_id_denylist.include?(aid)
      puts "Author ID #{aid} already in allowlist" if Twitter::Configuration.author_id_allowlist.include?(aid)
      puts "- name: #{answer.username}"
      puts "  author_id: #{aid}"
      puts "  tweet: #{answer.tweet_url}"
      puts "  analysis: Wordle #{nm} (#{sn}), #{key}, #{reasoning}"
      puts "  verdict: #{verdict} # #{title}"
      puts ''
    }

    check_lists = ->(author_id) {
      Twitter::Configuration.author_id_denylist.include?(author_id) \
      || Twitter::Configuration.author_id_allowlist.include?(author_id)
    }

    num_suppressed = 0
    answers_and_verdicts
      .map{|el| num_suppressed += 1 if check_lists.call(el[0].author_id); el}
      .delete_if{|el| check_lists.call(el[0].author_id)}
      .each{|el| print_goofball_report_entry.call(el[0], el[1], el[2], el[3], el[4])}

    if num_suppressed > 0
      if 'show' == UI::prompt_for_input("#{num_suppressed} entries suppressed ('show' to display)")
        puts ''
        answers_and_verdicts
          .map{|el| el} # make a copy
          .delete_if{|el| !check_lists.call(el[0].author_id)}
          .each{|el| print_goofball_report_entry.call(el[0], el[1], el[2], el[3], el[4])}
      end
    end

    puts ''
    puts 'Exiting because wordle_number_override was set manually...'
    puts ''
    puts '##################################################'
    exit
  end

  def Commands::filter_twitter(d, stats_hash)
    # Idea is to only filter on the max 4g seen
    max_4gs_seen = StatsHash.max_4gs(stats_hash)

    stats_hash.each do |key, _value|
      if Twitter::Configuration.instrumentation_only
        Debug.log "instrumentation_only mode, skipping penultimate_twitter() call for key #{key}..."
        next
      end
      key_array = key.split('.', 2)

      # doesn't make sense to filter first on 4g.3.1 if 4g.3.2 is coming next
      if key_array[0] == '4g'
        key_array2 = key_array[1].split('.')
        array_position = key_array2[0].to_i - 1
        count = key_array2[1].to_i
        if max_4gs_seen[array_position] != count
          UI::padded_puts "skipping filtering for key #{key} due to higher count still to come..."
          next
        end
      end

      penultimate_twitter(d, key_array[0], key_array[1])
      UI.print_remaining_count(d) # moving this here, to show filtering as it goes
    end
    d
  end

  def Commands::penultimate_twitter_absence_of_evidence(d, stats_hash)
    UI::padded_puts 'Absence of evidence is not evidence of absence!'

    # 4g-based analysis
    # sample entry in stash_hash: key=4g.3.1, value=7
    # Translation: The 3rd letter was white one time, for seven people
    # Plan
    #   1. Normalize the knowledge in stats_hash
    #   2. For remaining words in d, find how many matching words there are in valid-wordle-words.txt
    #   3. Do a text-based comparison (for now)

    # get max 4gs seen
    max_4gs_seen = StatsHash.max_4gs stats_hash

    # calculate how many actual 4g matches there are per key
    # key=laved, all_4g_matches=[6, 2, 10, 0, 2]
    # defined distances between ith all-4g-matches and possible observed Twitter values
    # Question: it is possible to see more matches on Twitter than mag-4gs if using
    #           a smaller dictionary (like dracos)
    # Answer: The scoring should _always_ use NYT when eliminating words,
    #         but could change it up when doing the subsequent scoring
    new_d = {}
    d.each do |word, _value|
      matches = all_4g_matches(word, Twitter::Configuration.absence_of_evidence_filename)
      difference = [0, 0, 0, 0, 0]
      (0...5).each {|i| difference[i] = Fingerprint::Distance::individual_distance(matches[i], max_4gs_seen[i])}
      new_d[word] = [difference.sum, difference, matches, max_4gs_seen]
    end
    new_d = new_d.sort_by {|_, value| value[0]}.to_h

    puts ''
    UI::padded_puts '/------------------------------------------------------\\'
    UI::padded_puts "|              Absence of Evidence report              |"
    UI::padded_puts '\------------------------------------------------------/'
    UI::padded_puts ''
    UI::padded_puts "max 4gs seen on Twitter: #{max_4gs_seen}"
    puts ''

    page_size = 10
    absence_of_evidence_string = ->(key, value, maybe_alert) {
      maybe_word_details = Debug::THRESHOLD >= Debug::LOG_LEVEL_VERBOSE ? " (#{value[2]})" : ''
      "#{key} has a distance of #{'%.1f' % value[0]}#{maybe_word_details}#{maybe_alert}"
    }
    (0...10).each do |page_number|
      break if (page_number * page_size) > new_d.length
      new_d.each_with_index do |(word, value), index|
        next if index < page_number * page_size
        break if index >= (page_number+1) * page_size
        maybe_alert = PreviousWordleSolutions.maybe_alert_string(word)
        UI::padded_puts absence_of_evidence_string.call(word, value, maybe_alert)
      end
      while true do
        more = [0, new_d.length - ((page_number+1) * page_size)].max
        user_input = UI.prompt_for_input("Enter a word to see its score, 'next', or (q)uit (#{more} more):")
        break if (user_input == 'q' || user_input == 'next')
        if new_d.key?(user_input)
          UI::padded_puts(absence_of_evidence_string.call(
            user_input,
            new_d[user_input],
            PreviousWordleSolutions.maybe_alert_string(user_input)))
        end
      end
      break if user_input == 'q'
    end

    puts ''
    UI::padded_puts 'Exiting absence-of-evidence...'
    puts ''
  end

  def Commands::penultimate_twitter(d, pattern, subpattern)
    UI::padded_puts "penultimate_twitter called, pattern=#{pattern}, subpattern=#{subpattern}"
    case pattern
    when '4g' # 4g.3.2 = 8
      subpattern_array = subpattern.split('.')
      raise 'Error: unexpected length (4g subpattern)' if subpattern_array.length() != 2
      gray = subpattern_array[0].to_i - 1
      count = subpattern_array[1].to_i
      Filter::filter_4g(d, gray, count)
    when '3g1y' # 3g1y.yellow3.white4 = 3
      subpattern_array = subpattern.split('.')
      raise 'unexpected length (3g1y subpattern)' if subpattern_array.length() != 2
      yellow = subpattern_array[0][6].to_i - 1
      gray = subpattern_array[1][5].to_i - 1
      Filter::filter_3g1y(d, yellow, gray)
    when '3g2y' # 3g2y.yellow24
      yellow1 = subpattern[6].to_i - 1
      yellow2 = subpattern[7].to_i - 1
      Filter::filter_3g2y(d, yellow1, yellow2)
    when '2g3y' # 2g3y.green24
      green1 = subpattern[5].to_i - 1
      green2 = subpattern[6].to_i - 1
      Filter::filter_2g3y(d, green1, green2)
    when '1g4y' # 1g4y.green3
      green = subpattern[5].to_i - 1
      Filter::filter_1g4y(d, green)
    when '0g5y' # 0g5y.
      Filter::filter_0g5y(d)
    else
      UI::padded_puts "#{pattern} not yet supported"
    end
  end

  def Commands::penultimate(d)
    UI::padded_puts 'Choose a Twitter penultimate guess'
    UI::padded_puts '4 greens (4g)'
    UI::padded_puts '3 greens and 1 yellow (3g1y)'
    UI::padded_puts '3 greens and 2 yellows (3g2y)'
    UI::padded_puts '2 greens and 3 yellows (2g3y)'
    UI::padded_puts '1 green and 4 yellows (1g4y)'
    UI::padded_puts '0 greens and 5 yellows (0g5y)'
    choice = UI.prompt_for_input('')
    case choice
    when '4g'
      gray = UI.prompt_for_input('Enter the position of the gray (1-5):').to_i - 1
      count = UI.prompt_for_input('Enter the count:').to_i
      Filter::filter_4g(d, gray, count)
    when '3g1y'
      yellow = UI.prompt_for_input('Enter the position of the yellow (1-5):').to_i - 1
      gray = UI.prompt_for_input('Enter the position of the gray (1-5):').to_i - 1
      Filter::filter_3g1y(d, yellow, gray)
    when '3g2y'
      yellows = UI.prompt_for_input('Enter the positions of the two yellows (1-5):')
      yellow1 = yellows[0].to_i - 1
      yellow2 = yellows[1].to_i - 1
      Filter::filter_3g2y(d, yellow1, yellow2)
    when '2g3y'
      greens = UI.prompt_for_input('Enter the positions of the two greens (1-5):')
      green1 = greens[0].to_i - 1
      green2 = greens[1].to_i - 1
      Filter::filter_2g3y(d, green1, green2)
    when '1g4y'
      green = UI.prompt_for_input('Enter the position of the green (1-5):').to_i - 1
      Filter::filter_1g4y(d, green)
    when '0g5y'
      Filter::filter_0g5y(d)
    end
  end

  def Commands::hint(d)
    UI::padded_puts "remaining: #{d.size}"

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
    UI::padded_puts top_n_dict

    # for all remaining words, they are a great guess if all of the "top N" characters are contained
    # and they are a "good" guess if all but one of the top N characters occur
    # avoid repeated letters, lower scrabble score is better
    max_to_print = 30
    great_guesses = d.dup
      .map{|word, _line_num| [word, word.chars.sort.join.squeeze.count(top_n_dict.keys.join())]}
      .delete_if{|word, top_n_count| top_n_count != top_n}
      .map{|word, _| word}
      .sort_by{|word, _| [5 - word.chars.sort.join.squeeze.size, scrabble_score(word)]}
      .to_a
    great_guesses[0...max_to_print].each{|word| UI::padded_puts "#{word} is a GREAT guess"}

    if great_guesses.size < max_to_print
      remaining_to_print = max_to_print - great_guesses.size
      good_guesses = d.dup
        .map{|word, _line_num| [word, word.chars.sort.join.squeeze.count(top_n_dict.keys.join())]}
        .delete_if{|word, top_n_count| top_n_count != top_n-1}
        .map{|word, _| word}
        .sort_by{|word, _| [5 - word.chars.sort.join.squeeze.size, scrabble_score(word)]}
        .to_a
      good_guesses[0...remaining_to_print].each{|word| UI::padded_puts "#{word} is a GOOD guess"}
    end
  end

  def Commands::pick_a_profession
    valid_entries = {
      :color => ['red', 'blue', 'green'],
      :food => ['pizza', 'hamburger'],
      :subject => ['math', 'science'],
    }
    prompts = valid_entries.map{|k, vlist| [k, "Favorite #{k} (#{vlist.join('/')}):"]}.to_h
    multipliers = {:color => 4, :food => 2, :subject => 1}
    professions = [
      'doctor', 'astronaut', 'olympian', 'competitive food eater',
      'teacher', 'professor', 'nurse', 'senator',
      'baseball player', 'Lyft driver', 'banker', 'streamer',
    ]
    recommended_profession_index = [:color, :food, :subject]
      .map{|category| [category, UI.prompt_for_input(prompts[category], valid_entries: valid_entries[category])]}
      .map{|category, user_input| [category, valid_entries[category].index(user_input)]}
      .map{|category, user_input_index| user_input_index * multipliers[category]}
      .sum
    puts "Your recommended profession is #{professions[recommended_profession_index]}."
  end

  def Commands::pick_a_profession_simple
    color = UI.prompt_for_input('Favorite color (red/blue/green):')
    food = UI.prompt_for_input('Favorite food (pizza/hamburger):')
    subject = UI.prompt_for_input('Favorite subject (math/science):')
    professions = {
      :red_pizza_math => 'doctor',
      :red_pizza_science => 'astronaut',
      :red_hamburger_math => 'olympian',
      :red_hamburger_science => 'competitive food eater',
      :blue_pizza_math => 'teacher',
      :blue_pizza_science => 'professor',
      :blue_hamburger_math => 'nurse',
      :blue_hamburger_science => 'senator',
      :green_pizza_math => 'baseball player',
      :green_pizza_science => 'Lyft driver',
      :green_hamburger_math => 'banker',
      :green_hamburger_science => 'streamer',
    }
    puts "Your recommended profession is #{professions[[color, food, subject].join('_').to_sym]}."
  end

  def Commands::pick_a_profession_hard(pks: nil)
    valid_entries = {
      :color => ['red', 'blue', 'green'],
      :food => ['pizza', 'hamburger'],
      :subject => ['math', 'science'],
      :superhero => ['Superman', 'Wonder Woman', 'Thor', 'She-Hulk', 'Daredevil'],
      :car => ['Porsche', 'Ferrari', 'Lamborghini'],
    }
    prompts = valid_entries.map{|k, vlist| [k, "Favorite #{k} (#{vlist.join('/')}):"]}.to_h
    # The general case of multipliers is hard
    multipliers = {:color => 4, :food => 2, :subject => 1, :superhero => 1, :car => 1} # [15-15]
    professions = [
      'doctor', 'astronaut', 'olympian', 'competitive food eater',
      'teacher', 'professor', 'nurse', 'senator',
      'baseball player', 'Lyft driver', 'banker', 'streamer',
    ]
    recommended_profession_index = [:color, :food, :subject, :superhero, :car]
      .map{|sym| [sym, (pks && pks[sym]) || UI.prompt_for_input(prompts[sym], valid_entries: valid_entries[sym])]}
      .map{|category, user_input| [category, valid_entries[category].index(user_input)]}
      .map{|category, user_input_index| user_input_index * multipliers[category]}
      .sum % professions.length
    puts "Your recommended profession is #{professions[recommended_profession_index]}." if pks == nil
    professions[recommended_profession_index]
  end

  def Commands::pick_a_profession_hard_test
    professions = {}
    valid_entries = {
      :color => ['red', 'blue', 'green'],
      :food => ['pizza', 'hamburger'],
      :subject => ['math', 'science'],
      :superhero => ['Superman', 'Wonder Woman', 'Thor', 'She-Hulk', 'Daredevil'],
      :car => ['Porsche', 'Ferrari', 'Lamborghini'],
    }
    valid_entries[:color].each do |color|
      valid_entries[:food].each do |food|
        valid_entries[:subject].each do |subject|
          valid_entries[:superhero].each do |superhero|
            valid_entries[:car].each do |car|
              choices = {
                :color => color,
                :food => food,
                :subject => subject,
                :superhero => superhero,
                :car => car,
              }
              profession = pick_a_profession_hard(pks: choices)
              professions[profession] = 0 if !professions.key?(profession)
              professions[profession] += 1
            end
          end
        end
      end
    end
    puts professions
  end
end
