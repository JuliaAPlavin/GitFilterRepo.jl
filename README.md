# Overview

Thin Julia wrapper around https://github.com/newren/git-filter-repo (Python). Provides both the raw `git-filter-repo` API, and several convenience functions on top of it.

# Examples

No additional setup is required after installation: the Python module gets automatically downloaded using the `Artifacts` system.

```julia
import GitFilterRepo as GFR
```

Gather all commit messages:

```julia
# uses the raw API
options = GFR.FilteringOptions.default_options()
commits = []
rfilter = GFR.RepoFilter(options; commit_callback=(commit, meta) -> push!(commits, commit))
rfilter.run()
[c.message for c in commits]
```

Set author dates of all commits to a specific value:

```julia
using Dates

# uses the raw API
options = GFR.FilteringOptions.default_options()
rfilter = GFR.RepoFilter(options; commit_callback=(commit, meta) -> (commit.author_date = GFR.date_to_string(DateTime(2010, 2, 3))))
rfilter.run()
```

Keep only the year of  all commit and author dates:

```julia
# uses more convenient wrappers
GFR.RepoFilter(GFR.CommitCallback) do commit, meta
    dt = GFR.string_to_date(commit.committer_date)
    dts_new = GFR.date_to_string(trunc(dt, Year))
    commit.author_date = dts_new
    commit.committer_date = dts_new
end.run()
```