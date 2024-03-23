library(tidyverse)

AtomicWrite <- function(s, file) {
    OUTFILETMP <- paste(file, ".tmp", sep="")
    write_file(s, OUTFILETMP)
    if (file.exists(file)) {
        file.remove(file)
    }
    file.rename(OUTFILETMP, file)
}

MIN.RUN <- 8 # at least MIN.RUN files for a stack
OUT  <- "~/tmp/link.sh"

LINK.SCRIPT <- '
if [ -e "${PENDDIR}" ]; then
  echo "${PENDDIR} already exists.  skipping..." 1>&2
else
  mkdir -p "${PENDDIR}" || { echo "failed creating ${PENDDIR}"; exit 1;} 1>&2
${LINK.CMDS}
fi
'

INCDIR <- Sys.getenv("INCDIR")
DESTDIR <- Sys.getenv("DESTDIR")

CMDS <- ""

if (INCDIR == "" || DESTDIR == "") {
    stop("unset INCDIR or DESTDIR env variables. I=\"", INCDIR,"\" D=\"",DESTDIR,"\"")
}

files <- grep("20[0-9]{6}-[0-9]{6}", dir(INCDIR), value = T, perl = T)

if (length(files) == 0) {
    stop("no matching files found in ", INCDIR)
}

for (f in files) {
    in.dir <- paste0(INCDIR, "/", f)
    inf <- paste0(in.dir, "/meta.csv")
    cat("\n", inf, "\n")

    if ( ! file.exists(inf) ) {
        warning("file not found ", inf)
        next
    }

    meta <- NULL

    meta <- read_csv(file=inf,
                     col_types = cols(
                         SourceFile = col_character()
                       , SerialNumber = col_character()
                       , SubSecCreateDate = col_character()
                     ))

    ## check for parsing problems
    probs <- problems(meta)

    if (nrow(probs) > 0) {
        warning(nrow(probs), " problems found parsing ", inf, "\n")
    }

    n.read <- nrow(meta)
    cat("rows:", nrow(meta), "\n")

    if (n.read < 1) {
        cat("no rows read ... skipping\n")
        next
    }

    meta$cdate <- parse_date_time(meta$SubSecCreateDate,
                                  orders=c("%Y:%m:%d %H:%M:%OS%z"
                                         , "%Y:%m:%d %H:%M:%s%z")
                                  )
    meta$ext <- gsub("[^.]*\\.","", meta$SourceFile)
    meta$fnm <- gsub(".*/","", meta$SourceFile)
    meta$stack <- NA
    meta$seq <- NA

    ## sort by sn then cdate.
    meta  <- ( meta
        %>% group_by(SerialNumber)
        %>% arrange(cdate, .by_group = TRUE)
    )


    ## pull out the things that either have no date or are not images
    ii <- which(is.na(meta$cdate) | ! grepl('NEF$|ORF$', meta$SourceFile))

    if (length(ii) > 0) {
        out <- meta[ii, , drop=F]
        out$stack <- "Other"
        meta <- meta[-ii, , drop=F]
    } else {
        out <- NULL
    }

    ## Loop over images partitioning into stacks

    while (nrow(meta) > 0) {
        cdatediff <- c(diff(meta$cdate))
        diffdiff <- abs(c(0, diff(cdatediff), 3600))

        irun <- min(which(diffdiff > 1.1))

        if (irun < MIN.RUN) {
            meta$stack[1] <- "Misc"
            out <- rbind(out, meta[1, , drop=F])
            meta <- meta[-1, ,drop=F]
        } else {
            stack.key <- strftime(min(meta$cdate[1:irun])
                                , format="%Y%m%d-%H%M%S"
                                , tz=""
                                  )

            ## cat(stack.key, irun, min(meta$cdate[1:irun]),"\n")
            ns <- meta[1:irun,]
            ns$stack <- stack.key

            seqfmt <- sprintf("%%0%dd", trunc(log10(irun)+1.0))
            ns$seq <- sprintf(seqfmt, 1:irun)

            ns <- ns %>% mutate(fnm = paste0(stack, "-", ns$seq, ".", ext))

            out <- rbind(out, ns)

            meta <- meta[-(1:irun), , drop=F]
        }
    }

    ## Generate the shell script to run the linking
    ss <- ( out %>% group_by(stack)
        %>% summarize(n = length(stack)
                    , penddir = paste0(DESTDIR, "/", f, "/", stack[1])
                    , srcdir = paste0(INCDIR, "/", f)
                    , link.cmds = paste0("  ln \""
                                       , srcdir, "/", SourceFile
                                       , "\" \""
                                       , penddir, "/", fnm, "\"", collapse="\n")
                    , f1=fnm[1]
                    , script = str_interp(LINK.SCRIPT, list(PENDDIR = penddir, LINK.CMDS = link.cmds))
                      )
    )

    cat(paste(format(ss$n, width=10), ss$stack, ss$penddir, collapse="\n"),"\n\n")

    if (nrow(out) != n.read) {
        stop("row output missmatch", n.read,"read", nrow(out),"output")
    }

    CMDS <- paste0(CMDS
                 , "##\n## ", INCDIR, "/", f, "\n##\n"
                 , paste0(ss$script, collapse="\n")
                   )

}

AtomicWrite(CMDS, OUT)
cat("Wrote ", OUT,"\n")
