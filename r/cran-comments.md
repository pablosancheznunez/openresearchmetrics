## Submission

First submission of openresearchmetrics.

## Test environments

* GitHub Actions: Ubuntu (R devel, release, oldrel-1), macOS (release), Windows (release).
* Local: Windows 11 x64, R 4.6.2 ucrt.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Notes for CRAN

* Network access is used only by `orm_collect()` and `orm_assess()`; their examples are wrapped in `\donttest{}` and check for an internet connection. Tests and other examples use recorded responses and never access the network.
* Examples and tests write only to `tempdir()`.
