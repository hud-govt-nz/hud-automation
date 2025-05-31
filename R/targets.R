#' Get target report
#'
#' Generate a report for targets using both the progress and metadata reports.
#'
#' @name get_target_report
#' @export
get_target_report <- function() {
    report <-
        targets::tar_progress() %>%
        left_join(
            targets::tar_meta(),
            by = "name",
            relationship = "one-to-one") %>%
        mutate(minutes = case_when(
            progress == "completed" ~ round(seconds / 60, 1) %>% as.character(),
            TRUE ~ "-"))

    return(report)
}

#' Make project card
#'
#' Generate a fancy formatted Teams message describing the outcome of a targets
#' run.
#'
#' @name make_project_card
#' @param run_name Run name
#' @param project_name Project name
#' @export
make_project_card <- function(run_name, project_name) {
    report <- get_target_report()

    # Check report
    if ("errored" %in% report$progress) {
        status <- "FAILED"
        color <- "error"
    } else if (all(report$progress == "skipped")) {
        status <- "Skipped"
        color <- "warning"
    } else {
        status <- "SUCCESS"
        color <- "good"
    }

    # Items that go in the body of the card
    card_items <- list(
        # Run name
        list(
            type = "TextBlock",
            text = paste(project_name, run_name, sep = "/"),
            size = "medium",
            weight = "bolder"
        ),
        # Run status
        list(
            type = "TextBlock",
            text = status,
            size = "large",
            weight = "bolder",
            spacing = "none",
            color = color
        ),
        # Columns
        list(
            type = "ColumnSet",
            columns = list(
                list(type = "Column", items = make_column_items(report, "name")),
                list(type = "Column", items = make_column_items(report, "progress")),
                list(type = "Column", items = make_column_items(report, "minutes"))
            )
        )
    )

    # Create full payload around the card items
    payload <- make_card_payload(card_items)
    return(payload)
}

#' Store files from targets run
#'
#' Stores a specific list of upload targets, validation files and metadata.
#'
#' @name store_run_data
#' @param run_name Run name
#' @param project_name Project name
#' @param container_url Azure container URL
#' @param upload_targets Name-strings of targets that should be uploaded
#' @param forced Overwrite blob version
#' @export
store_run_data <- function(run_name, project_name, container_url, upload_targets = c(), forced = FALSE) {
    blob_path <- str_glue("{project_name}/{run_name}")

    for (tn in upload_targets) {
        message(str_glue("Uploading '{tn}'..."))
        hud.keep::store_data(
            tar_read_raw(tn),
            str_glue("{blob_path}/{tn}.rds"),
            container_url, forced = forced)
    }

    message("Uploading validation files...")
    hud.keep::store_folder(
        "validation",
        str_glue("{blob_path}/validation"),
        container_url, forced = forced)

    message("Uploading metadata...")
    hud.keep::store_data(
        get_target_report(),
        str_glue("{blob_path}/run_report.rds"),
        container_url, forced = forced)
}

#' Wrapper for running targets
#'
#' A complete wrapper for automated/one-touch target runs. Runs tar_make(),
#' checks for errors, then upload files and sends a Teams message.
#'
#' @name run_targets
#' @param run_name Run name
#' @param project_name Project name
#' @param container_url Azure container URL
#' @param upload_targets Name-strings of targets that should be uploaded
#' @param invalidate Re-run every target
#' @param forced Overwrite blob version
#' @export
run_targets <- function(run_name, project_name, container_url, upload_targets = c(), invalidate = FALSE, forced = FALSE) {
    message("Starting run '", run_name, "'...")
    if (forced) {
        message("\033[33;1m*** THIS WILL OVERWRITE THE OLD DATA, YOU HAVE 5 SECONDS TO ABORT ***\033[0m")
        Sys.sleep(5)
        message("\033[33mInvalidating old data...\033[0m")
        targets::tar_invalidate(everything())
    }

    message("\033[32mRunning targets...\033[0m")
    run_report <-
        tryCatch({
            targets::tar_make()
            targets::tar_progress()
        }, error = function(e) {
            message(e[1])
            return(e)
        })

    if ("error" %in% class(run_report)) {
        message("\033[31;1mtar_make() failed!\033[0m")
    }
    else if (all(run_report$progress == "skipped")) {
        message("\033[33;1mNothing to do. Do you need to invalidate the previous run?\033[0m")
    }
    else {
        message("\033[32;1mRun successful!\033[0m")
        store_run_data(run_name, project_name, container_url, upload_targets, forced)
        # Send card
        payload <- make_project_card(run_name, project_name)
        send_teams_message(payload)
        message("\033[1;32mDone.\033[0m")
    }
}

