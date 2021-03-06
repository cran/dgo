devtools::load_all()
data(opinion)
toy_dgirt_in <- shape(opinion,
                 time_name = "year",
                 item_names = c("affirmative_action", "gaymarriage_amendment"), 
                 geo_name = "state",
                 group_names = "race3",
                 survey_name = "source",
                 geo_filter = c("VA", "SC"),
                 time_filter = 2009:2010,
                 weight_name = "weight")
devtools::use_data(toy_dgirt_in, overwrite = TRUE)

toy_dgirtfit <- dgirt(toy_dgirt_in, iter = 400, chains = 4, cores = 4)
devtools::use_data(toy_dgirtfit, overwrite = TRUE)
