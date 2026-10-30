% tinyrox says don't edit this manually, but it can't stop you!
\name{survey_report}
\alias{survey_report}
\title{Render a survey as markdown}
\usage{
survey_report(x = survey(), max_items = 12L, date = Sys.Date())
}
\arguments{
\item{x}{A data.frame from [survey()].}

\item{max_items}{Lines per project before the rest folds into an
"and N more" line.}

\item{date}{Date for the title.}
}
\value{
A character vector of markdown lines. Show it with
  `writeLines()`.
}
\description{
Groups the rows of [survey()] by project and writes one section per
project, most urgent first, so the todo items, git state, open pull
requests and note items for one piece of work read together. Project
names are matched ignoring case, spaces and punctuation, so
`Lil Casey` in the todo file, the `LilCasey` repo and the `lilcasey`
notes folder share a section.
}
