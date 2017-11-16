1#' Rank CpG probes
#'
#' Apply a linear model to Illumina's 450k or EPIC methylation data to get the
#' t-value of each CpG probe
#'
#' @param data A data frame or a matrix containing Illumina's CpG probes in rows
#'  and samples in columns
#' @param pheno A data frame or a matrix containing samples in rows and
#' covariates in columns
#' @param explanatory The column name or position from pheno used to perform the
#'  comparison between groups (default = first column)
#' @param covariates A list or character vector with column names from pheno
#' used as data covariates in the linear model
#' @param refGroup The group name or position from explanatory variable used to
#' perform the comparison (default = first group)
#' @param continuous A list or character vector with columns names from pheno
#' which should be treated as continuous variables (default = none)
#' @param typeInput Type of input data. "beta" for Beta-values and "M" for
#' M-values
#' @param typeAnalysis "M" to use M-values to rank the CpG probes (default).
#' "beta" to use Beta-values instead
#'
#' @return A named vector containing the t-values from the linear model for each
#'  CpG probe
#'
#' @author Jordi Martorell Marugán, \email{jordi.martorell@@genyo.es}
#'
#' @references Smyth, G. K. (2005). \emph{Limma: linear models for microarray
#' data}. Bioinformatics and Computational Biology Solutions using R and
#' Bioconductor, 397-420.
#'
#' @seealso \code{\link{mCSEATest}}
#'
#' @examples
#' \dontrun{
#' library(mCSEAdata)
#' data(mcseadata)
#' myRank <- rankProbes(betaTest, phenoTest, refGroup = "Control")
#' }
#' data(precomputedmCSEA)
#' head(myRank)
#' @export

rankProbes <- function(data, pheno, explanatory = 1, covariates = c(),
                    refGroup = 1, continuous = NULL,
                    typeInput = "beta", typeAnalysis = "M")
    {

    # Check input objects
    if (!any(class(data) == "data.frame" | class(data) == "matrix")){
        stop("data must be a data frame or a matrix")
    }

    if (!any(class(pheno) == "data.frame" | class(pheno) == "matrix")){
        stop("pheno must be a data frame or a matrix")
    }

    if (!any(class(explanatory) != "character" |
            !is.numeric(explanatory))){
        stop("explanatory must be a character or numeric object")
    }

    if (!any(class(covariates) == "character" | class(covariates) == "list" |
            is.null(covariates))){
        stop("covariates must be a character vector, a list or NULL")
    }

    if (!any(class(refGroup) != "character" |
            class(refGroup) != "numeric")){
        stop("refGroup must be a character or numeric object")
    }

    if (!any(class(continuous) == "character" | class(continuous) == "list" |
            is.null(continuous))){
        stop("continuous must be a character vector, a list or NULL")
    }

    if (class(typeInput) != "character"){
        stop("typeInput must be a character object")
    }

    if (class(typeAnalysis) != "character"){
        stop("typeAnalysis must be a character object")
    }

    if (is.null(continuous)){
        continuous <- c()
        categorical <- colnames(pheno)
    }
    else {
        if (class(continuous) != "character") {
            continuous <-colnames(pheno)[continuous]
        }
        categorical <- setdiff(colnames(pheno), continuous)
    }

    # Ensure all categorial variables are factors and continuous variables are
    # numeric
    for (column in colnames(pheno)) {
        if (column %in% categorical) {
            pheno[,column] <- factor(pheno[,column])
        }
        else {
            pheno[,column] <- as.numeric(as.character(pheno[,column]))
        }
    }

    typeInput <- match.arg(typeInput, c("beta", "M"))
    typeAnalysis <- match.arg(typeAnalysis, c("M", "beta"))

    if (class(explanatory) == "numeric") {
        explanatory <- colnames(pheno)[explanatory]
    }

    if (is.numeric(covariates)) {
        covariates <- colnames(pheno)[covariates]
    }

    if (class(refGroup) == "numeric") {
        refGroup <- levels(pheno[,explanatory])[refGroup]
    }

    if (length(intersect(explanatory, covariates)) > 0) {
        stop("You specified some variable(s) as both explanatory and covariate")
    }

    pheno <- data.frame(pheno[,c(explanatory, covariates)])
    colnames(pheno) <- c(explanatory, covariates)



    # Prepare methylation data for limma
    if (typeInput == "beta") {
        if (any(min(data, na.rm=TRUE) < 0 | max(data, na.rm=TRUE) > 1)) {
            warning("Introduced beta-values are not between 0 and 1. Are you
                    sure these are not M-values?")
        }

        if (typeAnalysis == "beta") {
            dataLimma <- data
        }
        else {
            message("Transforming beta-values to M-values")
            dataLimma <- log2(data) - log2(1 - data)
        }
    }
    else {
        if (min(data, na.rm=TRUE) >= 0 && max(data, na.rm=TRUE) <= 1) {
            warning("Introduced M-values are between 0 and 1. Are you sure these
                    are not beta-values?")
        }

        if (typeAnalysis == "beta") {
            message("Transforming M-values to beta-values")
            dataLimma <- 2^(data)/(1 + 2^(data))
        }
        else {
            dataLimma <- data
        }
    }

    # Perform linear model
    message("Calculating linear model...")
    message(paste("\tExplanatory variable:", explanatory))

    if (is.factor(pheno[,explanatory])){
        message(paste("\tReference group:", refGroup))
        pheno[,explanatory] <- relevel(pheno[,explanatory], ref=refGroup)
    }

    if (is.null(covariates)){
        message("\tCovariates: None")
        message(paste("\tCategorical variables:",
                    paste(categorical, collapse=" ")))
        message(paste("\tContinuous variables:",
                    paste(continuous, collapse=" ")))
        model <- model.matrix(~get(explanatory), data=pheno)
        }
    else {
        message(paste("\tCovariates:", paste(covariates, collapse=" ")))
        message(paste("\tCategorical variables:",
                    paste(categorical, collapse=" ")))
        message(paste("\tContinuous variables:",
                    paste(continuous, collapse=" ")))
        model <- model.matrix(~., data=pheno)
    }

    linearModel <- limma::eBayes(limma::lmFit(dataLimma, model))

    tValues <- linearModel$t[,2]

    return(tValues)
}