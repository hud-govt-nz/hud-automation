#' Send Teams message
#'
#' Sends a Teams message to the specified channel using the Graph API. See
#' https://learn.microsoft.com/en-us/graph/api/chatmessage-post for details on
#' the API.
#'
#' Note that this relies on a user-level authentication. i.e. This can only
#' post a message where you can post a message.
#'
#' Also, the payload needs to be in JSON, but we are generating JSON-like
#' structures in R (using list() to describe dictionaries and arrays) and then
#' converting it into a JSON string. The content also needs to follow very
#' specific rules. See make_card_payload() to understand how to attach an
#' AdaptiveCard to a message, and use the WYSIWYG designer to understand how to
#' create an AdaptiveCard: https://adaptivecards.microsoft.com/designer.html
#' 
#' If you run into trouble, test with a
#' JSON string that is known to work and step up from there, e.g.:
#' '{"body": {"content": "Hello World"}}'
#' 
#' In R JSON-like structure, this is:
#' list(body = list(content = "Hello World"))
#'
#' @name send_teams_message
#' @param payload JSON-like structure for the message body, see https://learn.microsoft.com/en-us/graph/api/chatmessage-post
#' @param channel_name Name of the channel to post on
#' @param team_name Name of the team the channel belongs to
#' @export
send_teams_message <- function(payload, channel_name = "Bots Health Check", team_name = "Insights") {
    API_URL <- "https://graph.microsoft.com/v1.0"

    # Get channel details
    curr_team <- Microsoft365R::get_team(team_name)
    curr_channel <- curr_team$get_channel(channel_name)
    team_id <- curr_channel$team_id
    channel_id <- curr_channel$properties$id
    token <- curr_channel$token$credentials$access_token

    # Send
    res <- httr::POST(
        url = stringr::str_glue("{API_URL}/teams/{team_id}/channels/{channel_id}/messages"),
        body = jsonlite::toJSON(payload, auto_unbox = TRUE),
        httr::add_headers(Authorization = str_glue("Bearer {token}")),
        httr::content_type_json())

    if (httr::status_code(res) %in% c(200, 201)) {
        message("\033[32mMessage sent.\033[0m")
    } else {
        message("\033[31;1mFailed to send message: ", httr::content(res, "text"), "\033[0m")
    }
}

#' make_column_items
#' 
#' Make the cells within a column using a dataframe column. Designed to be part
#' of a card creator.
#' 
#' @name make_column_items
#' @param targ_df Dataframe to generate the column from
#' @param col_name Name of the channel to post on
#' @param team_name Name of the team the channel belongs to
make_column_items <- function(targ_df, col_name) {
    header <- list(
        type = "TextBlock",
        text = col_name,
        weight = "bolder")

    column_items <- c(
        list(header),
        lapply(targ_df[[col_name]], function(x) {
            list(
                type = "TextBlock",
                text = str_replace(x, "NA", "-"),
                spacing = "none",
                color = case_when(
                    x == "errored" ~ "attention",
                    x == "skipped" ~ "accent",
                    x == "completed" ~ "good",
                    TRUE ~ "Default"))
        }))

    return(column_items)
}

#' make_card_payload
#' 
#' Creates message and card wrappers around the content of a card. Designed to
#' be part of a card creator.
#' 
#' @name make_card_payload
#' @param card_items List of objects to go into a card body (see https://adaptivecards.microsoft.com/designer.html)
make_card_payload <- function(card_items) {
    card <- list(
        `$schema` = "http://adaptivecards.io/schemas/adaptive-card.json",
        type = "AdaptiveCard",
        version = "1.5",
        body = list(
            list(
                type = "Container",
                style = "accent",
                bleed = TRUE,
                items = card_items
            )
        )
    )

    payload <- list(
        body = list(
            contentType = "html",
            content = "<attachment id=\"1\"></attachment>"
        ),
        attachments = list(
            list(
                id = "1",
                contentType = "application/vnd.microsoft.card.adaptive",
                content = jsonlite::toJSON(card, auto_unbox = TRUE) # Card needs to be separately stringified
            )
        )
    )

    return(payload)
}
