context("test_database")

test_that("works with a connection object", {
  con <- dbConnect(RSQLite::SQLite(), ":memory:")
  output <- test_database(
    con
    , pkg_test("simple-tests-alt.yml")
  )
  dbDisconnect(con)

  expect_s3_class(output[[1]], "dbtest_results")
  expect_equal(
    output[[1]]$results %>% as.data.frame() %>%
      distinct(file) %>% pull()
    , "simple-tests-alt"
  )
})

test_that("works with tbl_sql object", {
  con <- dbConnect(RSQLite::SQLite(), ":memory:")
  tdat <- copy_to(con, testdata, "test-database")
  output <- test_database(
    tdat
    , pkg_test("simple-tests-alt.yml")
  )
  dbDisconnect(con)

  expect_s3_class(output[[1]], "dbtest_results")
  expect_equal(
    output[[1]]$results %>% as.data.frame() %>%
      distinct(file) %>% pull()
    , "simple-tests-alt"
  )
})

test_that("works with multiple test files", {
  con <- dbConnect(RSQLite::SQLite(), ":memory:")
  output <- test_database(
    con
    , c(
      pkg_test("simple-tests.yml")
      , pkg_test("simple-tests-alt.yml")
    )
  )
  dbDisconnect(con)

  expect_s3_class(output[[1]], "dbtest_results")
  expect_equal(
    output[[1]]$results %>%
      as.data.frame() %>%
      .$file %>%
      unique()
    , c("simple-tests", "simple-tests-alt")
  )
})

test_that("works on successive tests to same connection", {
  con <- dbConnect(RSQLite::SQLite(), ":memory:")

  set.seed(1234)
  output <- test_database(
    con
    , pkg_test("simple-tests.yml")
  )

  set.seed(1234)
  output2 <- tryCatch({test_database(
    con
    , pkg_test("simple-tests.yml")
  )}, error = function(x){stop(x)})
  dbDisconnect(con)

  expect_s3_class(output[[1]], "dbtest_results")

  expect_s3_class(output2[[1]], "dbtest_results")
})

test_that("works with a yaml file", {
  con <- dbConnect(RSQLite::SQLite(), ":memory:")
  output <- test_database(
    pkg_config("config.yml")
    , pkg_test("simple-tests-alt.yml")
  )
  dbDisconnect(con)

  expect_s3_class(output[[1]], "dbtest_results")

  expect_equal(
    output[[1]]$results %>%
      as.data.frame() %>%
      .$file %>%
      unique()
    , c("simple-tests-alt")
  )
})

test_that("works with multiple connections in a yaml file", {
  con <- dbConnect(RSQLite::SQLite(), ":memory:")
  output <- test_database(
    pkg_config("multiple.yml")
    , pkg_test("simple-tests.yml")
  )
  dbDisconnect(con)

  lapply(output, expect_s3_class, class = "dbtest_results")
  expect_equal(length(output), 2)
})

test_that("works with multiple yaml files", {
  skip("TODO: need to write test")
})

test_that("throws out non-existent config files", {
  skip("TODO: need to write test")
})

test_that("works with a list of DBI connections", {
  con <- dbConnect(RSQLite::SQLite(), ":memory:")
  con2 <- dbConnect(RSQLite::SQLite(), ":memory:")
  output <- test_database(
    list(con, con2)
    , pkg_test("simple-tests-alt.yml")
  )
  lapply(output, expect_s3_class, class = "dbtest_results")
  lapply(output, function(x){
    expect_equal(
      x$results %>%
        as.data.frame() %>%
        distinct(file) %>%
        pull()
      , "simple-tests-alt"
    )
  })
})

test_that("works with a list of tbl_sql objects", {
  con <- dbConnect(RSQLite::SQLite(), ":memory:")
  tdat <- copy_to(con, testdata, "test-list-tbl-sql")
  tdat2 <- copy_to(con, testdata, "test-list-tbl-sql2")
  output <- test_database(
    list(tdat, tdat2)
    , pkg_test("simple-tests-alt.yml")
  )
  dbDisconnect(con)

  lapply(output, expect_s3_class, class = "dbtest_results")
  lapply(output, function(x){
    expect_equal(
      x$results %>%
        as.data.frame() %>%
        distinct(file) %>%
        pull()
      , "simple-tests-alt"
    )
  })
})

test_that("works with a DSN", {
  skip("TODO: need to write test - is this even possible? System dependent")
})

test_that("works with a list of DSNs", {
  skip("TODO: need to write test - is this even possible? System dependent")
})

test_that("throws out non-existent DSNs", {
  expect_warning(
    test_database("some-random-dsn-that-does-not-exist"
                  , tests = pkg_test()
                  )
    , "The following DSNs were not found and will be removed"
  )
})

test_that("works with a hybrid list of objects", {
  skip("TODO: need to write test")
})

test_that("works with multiple test files", {
  output <- test_database(
    pkg_config("config.yml")
    , c(
      pkg_test("simple-tests.yml")
      , pkg_test("simple-tests-alt.yml")
    )
  )

  expect_s3_class(output[[1]], "dbtest_results")
  expect_equal(
    output[[1]]$results %>%
      as.data.frame() %>%
      .$file %>%
      unique()
    , c("simple-tests", "simple-tests-alt")
  )
})

test_that("works with different integer types", {
  conn_path <- rprojroot::find_testthat_root_file("conn.yml")
  if (!fs::file_exists(conn_path)) {
    skip("requires a postgres database")
  }
  raw_conn <- suppressWarnings(yaml::read_yaml(conn_path)$default)
  if (!"pg" %in% names(raw_conn)) {
    skip("requires a postgres database")
  }

  tmp_file <- fs::file_temp("integer-test", ext=".yml")
  write_test(file = tmp_file
             , header = "integer-conversion"
             , expr = "fld_integer"
             , overwrite = TRUE
             )


  pg <- raw_conn$pg
  con <- do.call(DBI::dbConnect, pg)
  output <- suppressMessages(test_database(con, tmp_file))

  expect_equal(
    as.data.frame(output)[3,"results.failed"]
    , 0
    , info = "Test should pass if integer64 compares to integer"
    )
})

test_that("return_list parameter works as expected", {
  skip("TODO: write test")
})

test_that("recovers from a bad connection state", {

  # inherently a temporary test... until we can fix getting
  # into a bad state, in the first place

  # why does this only fail interactively...?

  conn_path <- rprojroot::find_testthat_root_file("conn.yml")
  if (!fs::file_exists(conn_path)) {
    skip("requires a postgres database")
  }
  suppressWarnings(raw_conn <- yaml::read_yaml(conn_path)$default)
  if (!"pg" %in% names(raw_conn)) {
    skip("requires a postgres database")
  }
  con <- do.call(DBI::dbConnect, raw_conn$pg)

  # break connection
  DBI::dbBegin(con)
  expect_error(DBI::dbExecute(con, "SELECT 1/0;"), "division by zero")
  expect_error(DBI::dbGetQuery(con, "SELECT 1;"), "current transaction is aborted")

  test_output <- test_database(
    con
    , pkg_test("simple-tests.yml")
  )
  #cat(capture.output(str(test_output)), file = "test.txt")
  expect_s3_class(test_output[[1]], "dbtest_results")

  DBI::dbDisconnect(con)
})

test_that("fails tests reasonably on a bad yaml connection", {
  skip("succeeds interactively... fails programmatically...")
  test_output <- test_database(rprojroot::find_testthat_root_file("bad-conn.yml"), pkg_test("simple-tests.yml"))

  expect_s3_class(test_output[[1]], "dbtest_results")
  expect_length(test_output[[1]]$results, 10)

  fail_msgs <- as.character(lapply(test_output[[1]]$results, function(x){x[["results"]][[1]] %>% as.character()}))
  expect_length(unique(fail_msgs), 1)
  expect_match(unique(fail_msgs), "nanodbc")
})

test_that("fails reasonably on a bad DBI connection", {
  skip("TODO: write test")
})

test_that("fails reasonably on a bad tbl_sql", {
  skip("TODO: write test")
})
