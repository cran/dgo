source("setup.r")

context("raking")

test_that("basic syntax works", {
  data(annual_state_race_targets)
  data.table::setDT(annual_state_race_targets)
  annual_state_race_targets = annual_state_race_targets[year %in% 2006:2010]
  expect_silent(suppressMessages(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight",
                              raking = ~ state)))
  expect_silent(suppressMessages(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight",
                              raking = list(~ state, ~ year))))
  expect_silent(suppressWarnings(suppressMessages(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight",
                              raking = ~ state + year))))
  expect_silent(suppressWarnings(suppressMessages(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight",
                              raking = list(~ state + year, ~ race3)))))
  expect_silent(suppressWarnings(suppressMessages(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight",
                              raking = list(~ race3)))))
  expect_silent(suppressWarnings(suppressMessages(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight",
                              raking = ~ race3))))
  expect_silent(suppressWarnings(suppressMessages(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight",
                              raking = list(~ year, ~ race3)))))
})

test_that("raking variables must exist", {
  data(annual_state_race_targets)
  # raking gives a single formula 
  expect_error(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight",
                              raking = ~ source),
               "\"source\" is a raking formula term but isn't a variable name in \"target_data\"")
  expect_error(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight",
                              raking = ~ proportion),
               "\"proportion\" is a raking formula term but isn't a variable name in \"item_data\"")

  # raking gives a list of formulas
  expect_error(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight", survey_name = "source",
                              raking = list(~ source, ~ weight)),
               "\"source\" is a raking formula term but isn't a variable name in \"target_data\"")
  expect_error(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight", survey_name = "source",
                              raking = list(~ proportion, ~ weight)),
               "\"weight\" is a raking formula term but isn't a variable name in \"target_data\"")
  expect_error(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight", survey_name = "source",
                              raking = list(~ proportion, ~ proportion)),
               "\"proportion\" is a raking formula term but isn't a variable name in \"item_data\"")
  expect_error(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight", survey_name = "source",
                              raking = list(~ state, ~ proportion)),
               "\"proportion\" is a raking formula term but isn't a variable name in \"item_data\"")

  # raking gives formulas with operators
  expect_error(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight", survey_name = "source",
                              raking = list(~ state + weight)),
               "\"weight\" is a raking formula term but isn't a variable name in \"target_data\"")
  expect_error(min_item_call(target_data = annual_state_race_targets,
                              weight_name = "weight", survey_name = "source",
                              raking = list(~ state + proportion)),
               "\"proportion\" is a raking formula term but isn't a variable name in \"item_data\"")
})

set_up_sample = function(w) {
  # From the warpbreaks data, create a sample with the unique combinations of
  # wool and tension, where wool \in A, B and tension \in L, M, H. All
  # observations are in the same time period  and each has a sampling weight.
  # For example, if w = 1:
  #    wool tension t weight
  # 1:    A       L 1      1
  # 2:    A       M 1      1
  # 3:    A       H 1      1
  # 4:    B       L 1      1
  # 5:    B       M 1      1
  # 6:    B       H 1      1
  data(warpbreaks)
  toy_data = warpbreaks
  data.table::setDT(toy_data)[, `:=`(t = 1), by = c("wool", "tension")]
  toy_data = unique(toy_data, by = c("wool", "tension"))
  toy_data[, weight := w]
  toy_data[, breaks := NULL]
  toy_data[]
}

set_up_pop = function(props) {
  # Set up population margins for the warpbreaks data from which the
  # combinations of wool and tension are sampled with equal probability.
  data(warpbreaks)
  toy_targets = unique(data.table::setDT(warpbreaks)[, .(wool, tension)])
  toy_targets[, t := 1]
  toy_targets[, proportion := 1 / .N]
  toy_targets[]
}

sum_by = function(tab, index) {
  tapply(tab$raked_weight, tab[[index]], sum)
}

setClass("Ctrl", slots = c("time_name", "weight_name",
    "proportion_name", "raking", "max_raked_weight"), prototype = list(time_name = "t",
    weight_name = "weight", "proportion_name" = "proportion",
    max_raked_weight = NULL))

test_that("raking has no effect if weights reflect population margins", {
  toy_data = set_up_sample(w = 1)
  toy_targets = set_up_pop(props = NULL)

  # raking should have no effect in a balanced sample whose observations are
  # weighted equally, regardless of the raking specification

  ctrl = new("Ctrl", raking = ~ wool)
  rake_result = dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl)
  # weight is the original weight; raked_weight is the raked weight
  expect_equal(rake_result$weight, rake_result$raked_weight)

  ctrl = new("Ctrl", raking = ~ wool + tension)
  rake_result = dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl)
  expect_equal(rake_result$weight, rake_result$raked_weight)

  ctrl = new("Ctrl", raking = ~ tension)
  rake_result = dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl)
  expect_equal(rake_result$weight, rake_result$raked_weight)

  ctrl = new("Ctrl", raking = list(~ wool, ~ tension))
  rake_result = dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl)
  expect_equal(rake_result$weight, rake_result$raked_weight)
})

test_that("raking equalizes weights when they should be equal", {

  # Population proportions for combinations of wool and tension are equal,
  # but in the sample wool A is downweighted 2:1 compared to wool B.
  toy_data = set_up_sample(w = rep(c(0.5, 1), each = 3))
  toy_targets = set_up_pop(props = NULL)
  ctrl = new("Ctrl", raking = ~ wool)
  toy_data

  # When raking on wool, we should recover equal weights
  rake_result = dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl)
  expect_equal(rake_result$raked_weight, rep(1, 6))

  ctrl = new("Ctrl", raking = ~ tension)
  # When raking on tension, the weights appear correct; the sum of weights
  # within each combination of wool and tension is equal. In the raked weights
  # the 2:1 downweighting of wool A to B should persist.
  rake_result = dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl)
  sums = sum_by(rake_result, "wool")
  expect_equal(unname(sums["A"]/sums["B"]), 0.5)

  # Now set up the sample such that wool A + tension L is unobserved, and all
  # observations are given equal weight.
  toy_data = set_up_sample(w = 1)
  toy_data = toy_data[-1]
  toy_targets = set_up_pop(props = NULL)

  # When raking on wool-tension, there's no observation we can upweight to
  # balance the sample.
  ctrl = new("Ctrl", raking = ~ wool + tension)
  rake_result = suppressWarnings(dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl))
  expect_equal(unique(rake_result$raked_weight), 1)

  # When raking on wool, the sum of raked weights within wool A and wool B
  # should be equal.
  ctrl = new("Ctrl", raking = ~ wool)
  rake_result = suppressWarnings(dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl))
  sums = rake_result[, .(sums = sum(raked_weight)), by = "wool"][["sums"]]
  expect_length(unique(sums), 1)

  # When raking on tension, the observation with tension L should be
  # upweighted 2:1 against the others. Equivalently, the sum of weights in
  # tensions L, M, and H should be the same.
  ctrl = new("Ctrl", raking = list(~ tension))
  rake_result = suppressWarnings(dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl))
  sums = rake_result[, .(sums = sum(raked_weight)), by = "tension"][["sums"]]
  expect_length(unique(sums), 1)

  # When raking on wool and tension, order matters! In the sample, wool A is
  # underweighted 2:3 and tension L is underweighted 1:2.

  # When raking on wool, then tension, wool A remains underweighted 2:3 and
  # tension weights are made equal.
  ctrl = new("Ctrl", raking = list(~ wool, ~ tension))
  rake_result = suppressWarnings(dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl))
  wool_sums = sum_by(rake_result, "wool")
  tension_sums = sum_by(rake_result, "tension")
  expect_length(unique(tension_sums), 1)
  expect_length(unique(wool_sums), 2)

  # When raking on tension, then wool, wool weights are made equal; tension L
  # is still underweighted, but 2:3 instead of 1:2.
  ctrl = new("Ctrl", raking = list(~ tension, ~ wool))
  rake_result = suppressWarnings(dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl))
  wool_sums = sum_by(rake_result, "wool")
  tension_sums = sum_by(rake_result, "tension")
  expect_length(unique(tension_sums), 2)
  expect_length(unique(round(wool_sums, 4)), 1)

  toy_data = rbind(set_up_sample(w = 1), set_up_sample(w = 2))
  toy_targets = set_up_pop(props = NULL)
  
  # # When raking on wool-tension, there's no observation we can upweight to
  # # balance the sample.
  ctrl = new("Ctrl", raking = ~ wool + tension)
  rake_result = suppressWarnings(dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl))
  expect_equal(length(unique(rake_result$raked_weight)), 2)
  
  # When raking on wool, the sum of raked weights within wool A and wool B
  # should be equal.
  ctrl = new("Ctrl", raking = ~ wool)
  rake_result = suppressWarnings(dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl))
  sums = rake_result[, .(sums = sum(raked_weight)), by = "wool"][["sums"]]
  expect_length(unique(sums), 1)

  # When raking on tension, the observation with tension L should be
  # upweighted 2:1 against the others. Equivalently, the sum of weights in
  # tensions L, M, and H should be the same.
  ctrl = new("Ctrl", raking = list(~ tension))
  rake_result = suppressWarnings(dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl))
  sums = rake_result[, .(sums = sum(raked_weight)), by = "tension"][["sums"]]
  expect_length(unique(sums), 1)

  # When raking on wool, then tension, weights are made equal
  ctrl = new("Ctrl", raking = list(~ wool, ~ tension))
  rake_result = suppressWarnings(dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl))
  wool_sums = sum_by(rake_result, "wool")
  tension_sums = sum_by(rake_result, "tension")
  expect_equivalent(wool_sums[1], wool_sums[2])
  expect_equivalent(tension_sums[1], tension_sums[2], tension_sums[3])

  # When raking on tension, then wool, weights are made equal
  ctrl = new("Ctrl", raking = list(~ tension, ~ wool))
  rake_result = suppressWarnings(dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl))
  wool_sums = sum_by(rake_result, "wool")
  tension_sums = sum_by(rake_result, "tension")
  expect_equivalent(wool_sums[1], wool_sums[2])
  expect_equivalent(tension_sums[1], tension_sums[2], tension_sums[3])
})

test_that("weights are trimmed by max_raked_weight argument", {
  toy_data = set_up_sample(w = rep(c(0.5, 1), each = 3))
  toy_targets = set_up_pop(props = NULL)
  ctrl = new("Ctrl", raking = ~ wool, max_raked_weight = 0.5)
  rake_result = suppressWarnings(dgo:::weight(data.table::copy(toy_data), toy_targets, ctrl))
  expect_equal(length(unique(rake_result[, raked_weight])), 1L) 
})

test_that("validation catches bad inputs to max_raked_weight argument", {
  data(annual_state_race_targets)
  expect_error(
    shape(item_data = opinion,
      item_names = "abortion",
      time_name = "year",
      geo_name = "state",
      group_names = "female",
      target_data = annual_state_race_targets,
      weight_name = "weight",
      raking = ~ race3,
      max_raked_weight = TRUE), 
    "should be a single number")
  expect_error(
    shape(item_data = opinion,
      item_names = "abortion",
      time_name = "year",
      geo_name = "state",
      group_names = "female",
      target_data = annual_state_race_targets,
      weight_name = "weight",
      raking = ~ race3,
      max_raked_weight = c(1, 2)),
    "should be a single number")
})
