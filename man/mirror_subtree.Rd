% tinyrox says don't edit this manually, but it can't stop you!
\name{mirror_subtree}
\alias{mirror_subtree}
\title{Mirror a subtree from one todo file into another}
\usage{
mirror_subtree(source_file, target_file, source_path, target_path,
               period = "Week", conflict = c("source", "target"),
               preview = .preview_default())
}
\arguments{
\item{period}{Character period label passed to \code{\link{parse_todo}}.}

\item{conflict}{Which status wins on shared paths: \code{"source"} or
\code{"target"}.}

\item{preview}{If TRUE, report the planned changes and write nothing.}

\item{source_file,target_file}{Paths to the two todo files.}

\item{source_path,target_path}{Full breadcrumb of the subtree root in
each file (e.g. \code{"Troy > cornball.ai"} and \code{"cornball.ai"}).}
}
\value{
Invisibly: \code{target_file} on write, or a list with
  \code{added} and \code{restatused} path vectors on preview.
}
\description{
Copies the \code{source_path} subtree of \code{source_file} into the
\code{target_path} location of \code{target_file}, matching items by
their full \code{"A > B > C"} breadcrumb. The merge is additive:
\itemize{
\item paths in the source but not the target are added under the
translated parent (shallow-first, so parents land before children);
\item paths in the target but not the source are kept untouched;
\item shared paths take the source status when
\code{conflict = "source"} (the default) or keep the target status
when \code{conflict = "target"}.
}
Nothing is ever deleted. Use it to keep a shared planning subtree in
step across two repos, e.g. mirror cornelius's
\code{"Troy > cornball.ai"} week subtree down into tiny's top-level
\code{"cornball.ai"}.
}
