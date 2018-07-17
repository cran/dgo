utils::globalVariables(c("facet_vars"))

#' @rdname plot-method
setGeneric("dgirt_plot", signature = "x", function(x, ...)
           standardGeneric("dgirt_plot"))

#' Plot estimates and diagnostic statistics
#'
#' \code{dgirt_plot} plots estimates from a dgo model. \code{plot_rhats} plots
#' split R-hats.
#'
#' @param x A \code{dgo_fit-class} object.
#' @param y_fun Summary function to be plotted as \code{y}.
#' @param y_min Summary function giving the \code{ymin} argument for a
#' \code{geom_pointrange} object.
#' @param y_max Summary function giving the \code{ymax} argument for a
#' \code{geom_pointrange} object.
#' @param pars Selected parameter.
#' @rdname plot-method
#' @export
#' @examples
#' \dontrun{
#' data(toy_dgirtfit)
#' dgirt_plot(toy_dgirtfit)
#' dgirt_plot(toy_dgirtfit, y_min = NULL, y_max = NULL)
#' p <- dgirt_plot(toy_dgirtfit)
#' p %+% ylab("posterior median")
#' }
setMethod("dgirt_plot", signature(x = "dgo_fit"),
  function(x, y_fun = "median", y_min = "q_025", y_max = "q_975", pars = "theta_bar") {
  assert(assertthat::is.string(pars))
  if (length(y_fun)) assert(assertthat::is.string(y_fun))
  if (length(y_min)) assert(assertthat::is.string(y_min))
  if (length(y_max)) assert(assertthat::is.string(y_max))

  ctrl <- x@dgirt_in$control
  samples <- summarize(x, funs = c(y_fun, y_min, y_max))

  plot_internal(samples, ctrl@group_names[1], ctrl@time_name, ctrl@geo_name,
    y_fun, y_min, y_max)
})

#' @rdname plot-method
#' @param group_name A discrete grouping variable that will be passed to the
#' \code{color} argument of \code{aes}.
#' @param time_name A time variable with numeric values that will be plotted on
#' the x axis.
#' @param geo_name A variable representing local areas that will be used in
#' faceting.
#' @export
#' @examples
#' \dontrun{
#' data(toy_dgirtfit)
#' ps <- poststratify(toy_dgirtfit, annual_state_race_targets, strata_names =
#'                    c("state", "year"), aggregated_names = "race3")
#' dgirt_plot(ps, group_name = NULL, time_name = "year", geo_name = "state")
#' }
setMethod("dgirt_plot", signature(x = "data.frame"),
  function(x, group_name, time_name, geo_name, y_fun = "median", y_min =
           "q_025", y_max = "q_975") {

    if (length(group_name)) assert(assertthat::is.string(group_name))
    if (length(time_name)) assert(assertthat::is.string(time_name))
    if (length(geo_name)) assert(assertthat::is.string(geo_name))
    if (length(y_min)) assert(assertthat::is.string(y_min))
    if (length(y_max)) assert(assertthat::is.string(y_max))

    if (length(y_fun)) {
      assert(assertthat::is.string(y_fun))
      x <- x[, do_funs(list(value), c(y_fun, y_min, y_max)),
             by = c(group_name, time_name, geo_name)]
      data.table::setnames(x, grep("^V\\d+", names(x),value = TRUE),
                           c(y_fun, y_min, y_max))
    }
    plot_internal(x, group_name, time_name, geo_name, y_fun, y_min, y_max)
})

plot_internal <- function(samples, group_name, time_name, geo_name, y_fun,
                          y_min, y_max) {

  if (!length(y_fun) & (length(y_min) | length(y_max))) {
    stop("If y_fun is unused then y_min and y_max should be too.")
  } else if (length(y_min) & !length(y_max)) {
    stop("If y_min is used then y_max should be too.")
  } else if (!length(y_min) & length(y_max)) {
    stop("If y_max is used then y_min should be too.")
  }

  p <- ggplot2::ggplot(data = samples,
         ggplot2::aes_string(x = time_name, y = y_fun, color = group_name)) +
       ggplot2::geom_line(alpha = 0.7) +
       ggplot2::facet_wrap(geo_name) +
       ggplot2::theme_bw() +
       ggplot2::scale_x_continuous(minor_breaks = NULL, breaks =
                                   unique(samples[[time_name]]))

  if (length(y_min) & length(y_max)) {
    p <- p + ggplot2::geom_pointrange(
               ggplot2::aes_string(y = y_fun, ymin = y_min, ymax = y_max),
               alpha = 0.7)
  } else {
    p <- p + ggplot2::geom_line(alpha = 0.7, ggplot2::aes_string(y = y_fun))
  }
  p
}

#' @rdname plot-method
#' @param y Ignored.
#' @param ... Further arguments to \code{\link{dgirt_plot}}.
#'
#' @export
#' @examples
#' \dontrun{
#' data(toy_dgirtfit)
#' plot(toy_dgirtfit)
#' }
setMethod("plot", signature(x = "dgo_fit", y = "missing"),
          function(x, ...) {
            dgirt_plot(x, ...)
          })

#' @rdname plot-method
#' @export
setGeneric("plot_rhats", signature = "x", function(x, ...)
           standardGeneric("plot_rhats"))

#' @rdname plot-method
#' @param facet_vars Optionally, one or more variables passed to \code{facet_wrap}
#' @param shape_var,color_var,x_var Optionally, a variable passed to the
#' \code{shape}, \code{color}, or \code{x} arguments of \code{aes_string},
#' respectively.
#' @export
#' @examples
#' \dontrun{
#' data(toy_dgirtfit)
#' plot_rhats(toy_dgirtfit)
#' plot_rhats(toy_dgirtfit, facet_vars = "race3") +
#'   scale_x_continuous(breaks = seq.int(2006, 2008))
#' }
setMethod("plot_rhats", signature(x = "dgo_fit"),
          function(x, pars = "theta_bar", facet_vars = NULL, shape_var = NULL,
                   color_var = NULL, x_var = NULL) {

  assert(assertthat::is.string(pars))
  if (length(shape_var)) assert(assertthat::is.string(shape_var))
  if (length(color_var)) assert(assertthat::is.string(color_var))
  if (length(x_var)) assert(assertthat::is.string(x_var))

  rhats <- rhats(x, pars = pars)
  time_var = x@dgirt_in$control@time_name
  free_vars = setdiff(names(rhats), c(time_var, "Rhat", "param", facet_vars,
                                      shape_var, color_var, x_var))

  check_plot_vars(c(facet_vars, shape_var, color_var, x_var), pars,
                  x@dgirt_in$control)

  if (!length(x_var)) {
    if (time_var %in% names(rhats)) {
      x_var = time_var
    } else if (length(free_vars)) {
      x_var = free_vars[1]
      free_vars = free_vars[-1]
    } else {
      x_var = "param"
    }
  }
  if (length(free_vars) && !length(color_var)) {
      color_var = free_vars[1]
      free_vars = free_vars[-1]
  }
  if (length(free_vars) && !length(shape_var)) {
      shape_var = free_vars[1]
      free_vars = free_vars[-1]
  }
  if (length(free_vars) && !length(facet_vars)) {
      facet_vars = free_vars
  }

  p = ggplot(rhats, aes_string(x = x_var, y = "Rhat", color = color_var,
                               shape = shape_var)) +
        geom_jitter(height = 0, width = 0.2)
  if (length(facet_vars)) {
    p = p + facet_wrap(facet_vars)
  }
  p
})

check_plot_vars <- function(varnames, pars, ctrl) {
  # Require that variables given as e.g. facet_vars index pars

  # get the indices of pars, e.g. c('time_name', 'group_name') for "theta_bar"
  indices <- unlist(index_names[pars])
  # get the corresponding variable names 
  index_varnames <- sapply(indices, slot, object = ctrl)
  for (varname in varnames) {
    if (!varname %in% index_varnames) {
      stop(paste(pars), " is not indexed by '", varname, "'")
    }
  }
}

