import GitFilterRepo as GFR
using Git_jll: git
using Dates
using Test

import CompatHelperLocal as CHL
CHL.@check()

@testset begin
    repodir = mktempdir();
    cd(repodir)

    run(`$git init`)
    write("file1", "content1")
    run(`$git add .`)
    run(`$git commit -m "first commit"`)
    write("file2", "content2")
    run(`$git add .`)
    run(`$git commit -m "second commit"`)
    
    options = GFR.FilteringOptions.default_options()
    options.force = true  # needed once, otherwise errors with "expected at most one entry in the reflog for HEAD"
    commits = []
    rfilter = GFR.RepoFilter(options; commit_callback=(commit, meta) -> push!(commits, commit))
    rfilter.run()
    @test [c.message for c in commits] == ["first commit\n", "second commit\n"]
    
    options = GFR.FilteringOptions.default_options()
    rfilter = GFR.RepoFilter(options; commit_callback=(commit, meta) -> (commit.author_date = GFR.date_to_string(DateTime(2010, 2, 3))))
    rfilter.run()
    @test readlines(`$git log --format="%aI %s"`) == ["2010-02-03T00:00:00+00:00 second commit", "2010-02-03T00:00:00+00:00 first commit"]

    GFR.RepoFilter(GFR.CommitCallback) do commit, meta
        commit.author_date = GFR.date_to_string(DateTime(2030, 10, 11, 12, 13, 14))
    end.run()
    @test readlines(`$git log --format="%aI %s"`) == ["2030-10-11T12:13:14+00:00 second commit", "2030-10-11T12:13:14+00:00 first commit"]

    GFR.RepoFilter(GFR.CommitCallback) do commit, meta
        dt = GFR.string_to_date(commit.committer_date)
        commit.author_date = GFR.date_to_string(trunc(dt, Year))
    end.run()
    @test readlines(`$git log --format="%aI %s"`) == ["2021-01-01T00:00:00+00:00 second commit", "2021-01-01T00:00:00+00:00 first commit"]
end
