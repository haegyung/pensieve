#' @title Construct *single* and *multiple* open sort matrix.
#'
#' @export
#'
#' @template construction_helpers
#'
#' @details
#' Open sorting categorizations *cannot* be compared between participants, because each participants defines her own categories.
#' **The canonical representation of open sorting data** is therefore a *list* of matrices, one for each participant.
#' Every *individual* matrix is a [psOpenSort()] object, and together, they form a [psOpenSorts()] list.
#' The rows in these matrices are the items, the columns are the category, and cells are the assignment.
#'
#' @examples
#' # Lisas open sort, matching by index
#' assignments <- matrix(data = c(TRUE, FALSE, FALSE, TRUE),
#'                       nrow = 2,
#'                       dimnames = list(handles = c("cat", "dog")))
#' descriptions <- c("a pet which largely takes care of itself",
#'                   "is known to have saved humans")
#' lisa <- psOpenSort(assignments = assignments, descriptions = descriptions)
#'
#' # Peters open sort, matching by name
#' assignments <- matrix(data = c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE),
#'                       nrow = 2,
#'                       dimnames = list(handles = c("cat", "dog"),
#'                                       categories = c("in_homes",
#'                                                      "quiet",
#'                                                      "herbivore")))
#' descriptions <- c(in_homes = "Animal found in peoples homes.",
#'                   quiet = "Does not make a lot of noise.",
#'                   herbivore = "Eats plants.")
#' peter <- psOpenSort(assignments = assignments, descriptions = descriptions)
#'
#' # Rebeccas open sort, without any descriptions provided
#' assignments <- matrix(data = c(FALSE, FALSE, TRUE, TRUE),
#'                       nrow = 2,
#'                       dimnames = list(handles = c("cat", "dog")))
#' rebecca <- psOpenSort(assignments = assignments, descriptions = NULL)
#' # providing no description is possible, but makes interpretation hard, if not meaningless.
#'
#' # now let's combine the individual sort into a list
#' open_sorts <- psOpenSorts(open_sorts = list(lisa = lisa, peter = peter, rebecca = rebecca))
#'
#' @name psOpenSorts
NULL

#' @describeIn psOpenSorts Creates *individual* open sort.
#'
#' @param assignments
#' a matrix with item-handles as row names, arbitrary or empty column names, and open sort value in cells.
#' Matrix must be either
#' - `logical` for *nominal*-scaled sort, where an open category applies (`TRUE`) or does not apply (`FALSE`),
#' - `integer` for *ordinally*-scaled sort, where an open category applies to some item *more* (`2nd` rank) *or less* (`3rd` rank) than to another other item,
#' - `numeric` for *interval* or *ratio*-scaled sort, where an open category applies to some item *by some amount more or less* (say `2.4` units) than to another item.
#' Notice that -- counterintuitively -- *categorically*-scaled open sorts are not allowed.
#' If columns are named, they must be the same as the names in `descriptions`.
#' Either way, `assignments` and `descriptions` are always *matched by index only*: the first column from `assignments`, must be the first element of `description`, and so forth.
#'
#' @param descriptions
#' a character vector giving the open-ended category description provided by the participant.
#' Can be named.
#' Defaults to `NULL`, in which case the user-defined categories are unknown (not recommended).
#'
#' @export
psOpenSort <- function(assignments, descriptions = NULL) {

  if (!is.null(descriptions)) {
    # prepare descriptions; must always be named LIST
    if (is.null(names(descriptions))) {
      names(descriptions) <- as.character(1:length(descriptions))
    }
    descriptions <- as.list(descriptions)
  }

  validate_psOpenSort(new_psOpenSort(assignments = assignments, descriptions = descriptions))
}

# constructor
new_psOpenSort <- function(assignments, descriptions) {
  # remember that matching is ALWAYS by index only, the rest is fluff
  do.call(what = structure, args = append(
    x = list(.Data = assignments,
             class = c("psOpenSort", "Matrix")),
    values = descriptions))
}

# validator
validate_psOpenSort <- function(assignments) {

  # validate assignments
  assert_matrix(x = assignments,
                row.names = "strict",
                null.ok = FALSE)

  descriptions <- attributes(assignments)
  descriptions <- descriptions[!(names(descriptions) %in% c("dim", "dimnames", "class"))]
  if (length(descriptions) == 0) {  # recreate NULL assignment, when there are none in attr
    descriptions <- NULL
  }

  if (!is.null(descriptions)) {
    # validate descriptions
    assert_list(x = descriptions,
                types = "character",
                any.missing = TRUE,
                all.missing = TRUE,
                unique = FALSE,  # oddly, duplicate NAs count as non-unique, hence extra test below
                names = "unique", # strict fails on "1" etc
                null.ok = FALSE,
                len = ncol(assignments)) # this already validates against assignments

    # must test if non-NAs are at least unique
    assert_list(x = descriptions[!(is.na(descriptions))],
                unique = TRUE)

    if (!is.null(colnames(assignments))) {
      # validate descriptions AND assignments
      assert_names(x = colnames(assignments),
                   type = "unique")

      assert_set_equal(x = names(descriptions),
                       y = colnames(assignments),
                       ordered = TRUE)
    }
  }
  return(assignments)
}

#' @describeIn psOpenSorts *Combine* individual open sorts in a list.
#'
#' @param open_sorts named list of matrices created by [psOpenSort()], one for each participant.
#' Must all be of equal data type and all have the same rows and rownames.
psOpenSorts <- function(open_sorts) {
  validate_psOpenSorts(new_psOpenSorts(open_sorts = open_sorts))
}

# constructor
new_psOpenSorts <- function(open_sorts) {
  structure(
    .Data = open_sorts,
    class = c("psOpenSorts")
  )
}

# validator
validate_psOpenSorts <- function(open_sorts) {
  assert_list(x = open_sorts,
              any.missing = TRUE,
              all.missing = TRUE,
              names = "strict",
              types = "matrix")

  # for no particular reason, we make the first in the list the benchmark
  data_type <- mode(open_sorts[[1]])
  n_items <- nrow(open_sorts[[1]])
  item_handles <- rownames(open_sorts[[1]])

  assert_choice(x = data_type, choices = c("logical", "integer", "numeric"))
  lapply(X = open_sorts, FUN = function(x) {
    validate_psOpenSort(assignments = x)
    assert_matrix(x = x,
                  mode = data_type,
                  nrows = n_items,
                  row.names = "strict")
    assert_set_equal(x = rownames(x),
                     y = item_handles,
                     ordered = TRUE)
  })
  return(open_sorts)
}

# import helper

#' @describeIn psOpenSorts descriptions and *logical* assignments from convenient, but messy format
#'
#' @export
#'
#' @param assignments_messy a character matrix with rows as items, columns as participants and  **logical category assignments** as character strings in cells.
#' Categories are identified by a subset from `LETTERS`, same as in `descriptions_messy`.
#' Assignments must be the same subset of `LETTERS` as the column names in `descriptions_messy`.
#' Rows and columns must be named.
#'
#' For example, if some participant assigned her (self-described) categories `A`, `D` and `Z` to some item, the cell for that item and participant would read `"A, D, Z"`.
#' Order and punctuation are ignored.
#'
#' See `note`.
#'
#' @param descriptions_messy a character matrix with rows as category indices, columns as participants and **category descriptions** in cells.
#' Rows *must* be named by a subset of `LETTERS` to conveniently enter, and identify them from `assignments_messy`.
#' The row names are arbitrary identifiers, but will be retained for the canonical form.
#' Columns *must* be named as participants.
#'
#' Defaults to `NULL`, in which case no descriptions are available.
#'
#' Notice category description in one row have *nothing in common* other than their *indices*:
#' For example, the category descriptions in a row named `'B'` are all by different participants, and may refer to entirely different aspects.
#' They are only conveniently entered in a table, and all share the fact that they were the *second* description provided.
#'
#' When some category has not been defined by the participant, the value in the cell should be `NA`.
#' Empty strings `""` will also be considered `NA`.
#'
#' @details
#' The canonical representation of open sorts in [psOpenSorts()] can be cumbersome to enter manually.
#' For *logical* (nominally-scaled) open sorts, a simpler, but messier format can be conveniently entered as two separate spreadsheets of `descriptions_messy` and `assignments_messy`.
#'
#' @examples
#'
#' # create psOpenSorts from convenient input
#' ass <- matrix(data = c("A, B",
#'                        # meaning A and B are assigned
#'                        "",
#'                        # meaning no category assigned
#'                        "B",
#'                        # only B assigned
#'                        NA),
#'                        # item never considered for assignment across *all* categories or vice versa
#'                        nrow = 2,
#'                        ncol = 2,
#'                        dimnames = list(items = c("cat", "dog"),
#'                        people = c("tony", "amy")))
#' desc <- matrix(data = c("",
#'                         # will be treated as NA
#'                         NA,
#'                         # participant provided no description, but assigned the category
#'                         "lives in cage",
#'                         # described, but never assigned
#'                         NA,
#'                         # never assigned, never described will be removed
#'                         "actually a predator!",
#'                         "lives on a farm"
#'                         # described, but never assigned
#'                         ),
#'                         nrow = 3,
#'                         dimnames = list(categories = c("A", "B", "C"),
#'                         people = c("tony", "amy")))
#' # notice how individual *nominal* categories are pasted together in cells here;
#' # this convenient form *only* works for nominally-scaled data
#' import_psOpenSorts(assignments_messy = ass, descriptions_messy = desc)
#'
#' @note
#' When category is assigned, but never described, it is `TRUE` in the respective logical matrix entries and their description is `NA`:
#' This is still considered valuable, if incomplete information.
#' When a category is described, but never assigned, it is omitted from the data entirely.
#'
#' When *no* category was assigned to some item in `assignments_messay`, an empty character string `""` should be in the respective cell.
#'
#' An `NA` value implies that the given participant never considered the given items *at all*, across *all* her categories.
#' Notice this implies *limited scenarios of `NA`* for data entered in this messy, convenient form.
#' The more complicated cases, where a participant did consider *some*, but *not all* items in the assignment of a category, or -- equivalently -- all categories in their assessment of all items, cannot be recorded in this convenience format.
#' Such more granular `NA` records can, however, be recorded in the canonical data representation, where the respective cell of the items x category logical matrix would be `NA`.
#' If your data gathering procedure produces such granular `NA` records, do not use this convenience function.
import_psOpenSorts <- function(assignments_messy, descriptions_messy = NULL) {
  # variable names are too long
  ass <- assignments_messy
  desc <- descriptions_messy

  # Input validation ====
  assert_matrix(x = ass,
                mode = "character",
                any.missing = TRUE,
                all.missing = FALSE,
                row.names = "strict",
                col.names = "strict",
                null.ok = FALSE)

  if (!is.null(desc)) {
    desc[desc == ""] <- NA  # empty strings are considered NAs
    assert_matrix(x = desc,
                  mode = "character",
                  any.missing = TRUE,
                  all.missing = FALSE,
                  null.ok = FALSE,
                  row.names = "strict",
                  col.names = "strict")
    check_subset(x = rownames(desc),
                 choices = LETTERS,
                 empty.ok = FALSE)
    assert_set_equal(x = colnames(desc), y = colnames(ass), ordered = TRUE)
  }

  # body ====
  # create empty object
  cat_canon <- sapply(X = colnames(ass), FUN = function(x) NULL)

  for (p in names(cat_canon)) {
    max_cats <- LETTERS[LETTERS %in% unlist(strsplit(x = ass[, p], split = ""))]
    # this used to be more complicated
    # we decided that described, but never assigned categories should be omitted.
    # See note in docs.
    max_cats <- max_cats[order(max_cats)]  # just in case, this makes results nicer to cross-check

    # now we can create the logical matrix of appropriate rank
    m <- matrix(data = NA,
                nrow = nrow(ass),
                ncol = length(max_cats),
                dimnames = list(items = rownames(ass), categories = max_cats))

    catsplit <- strsplit(x = ass[, p],
                         split = "")

    for (i in rownames(m)) {
      if (anyNA(catsplit[[i]])) {
        m[i, ] <- NA  # these are the items that participant never saw
      } else {
        m[i, ] <- max_cats %in% catsplit[[i]]
      }
    }
    better_desc <- desc[, p]  # these are the descriptions of current persons
    names(better_desc) <- rownames(desc)
    # let's retain the simple LETTERS, even if they are meaningless, they help with debugging at least
    m <- psOpenSort(assignments = m, descriptions = better_desc[max_cats])  # here kill all the unassigned, but described cats. sad.
    cat_canon[[p]] <- m
  }
  cat_canon <- psOpenSorts(open_sorts = cat_canon)
  return(cat_canon)
}


#' @title Create Co-Occurence Matrices.
#'
#' @export
#'
#' @description Creates co-occurence matrices from logical q-category assignments.
#'
#' @param ass Named list of logical matrices, one for each participant.
#' Each logical matrix has items as named rows, category indices as columns and logical values in cells.
#'
#' @return
#' An integer array with items as rows and columns, participants as third dimension and cells as co-occurence counts.
#'
#' @details
#' The diagonal is replaced with the *maximum number of categories* for that person, to standardize the entire table.
#'
#' @family import
#'
#' @author Maximilian Held
#'
count_cooccur <- function(ass) {

  # input validation ===
  expect_list(x = ass,
              types = "matrix",
              all.missing = FALSE)
  for (i in names(ass)) {
    expect_matrix(x = ass[[i]],
                  mode = "logical",
                  any.missing = TRUE,
                  all.missing = FALSE,
                  row.names = "unique",
                  null.ok = FALSE,
                  info = paste("Matrix", i, "is not as expected."))
  }

  # body ===
  a <- sapply(X = ass, USE.NAMES = TRUE, simplify = "array", FUN = function(x) {
    m <- tcrossprod(x)
    storage.mode(m) <- "integer"
    diag(m) <- ncol(x)
    return(m)
  })
  names(dimnames(a))[3] <- "people"
  return(a)
}