# HUD automation tools
**CAUTION: This repo is public. Do not include sensitive data or key materials.**

Tools for managing a [{targets}](https://docs.ropensci.org/targets/) run:
* Invalidate old data
* Run `tar_make()`
* Upload designated outputs files, along with validation and metadata files
* Sends a message on Teams afterwards


## Installation
You'll need `devtools::install_github` to install the package:
```R
devtools::install_github("hud-govt-nz/hud-automate")
```


## Usage
The recommended way of using this package is to let `run_targets()` manage the entire process.
```R
hud.automation::run_targets(
    run_name = Sys.Date(),
    project_name = "dvr-title-history",
    container_url = "https://dlprojectsdataprod.blob.core.windows.net/projects",
    upload_targets = c("spine_cleaned", "spine_simple"),
    invalidate = TRUE,
    forced = TRUE)
```

When providing the parameters for `run_targets()`, follow these rules:
* `project_name` should be kebab-case, and identical to the repository name (which should be kebab-case). This allows someone looking for the outputs of a project to find it easily on the blob.
* `run_name` should just be `YYYY-MM-DD`. `hud.keep::find_latest()` will look for last (A-Z sorted) folder with a matching structure. If you name the run something else, `hud.keep::find_latest()` will not find it (this may be desirable, if you want it to NOT be used by automated processes which rely on `hud.keep::find_latest()`). You can also use static run names during development.
* `upload_targets` should be in stored in parquet or RDS formats.


## Maintaining this package
If you make changes to this package, you'll need to rerun document from the root directory to update all the R generated files.
```R
roxygen2::roxygenise()
```
