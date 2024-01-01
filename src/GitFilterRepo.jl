module GitFilterRepo

using Pkg.Artifacts
using PyCall
using Dates
using Git_jll: git


const gfr = PyNULL()

const Blob = PyNULL()
const Reset = PyNULL()
const FileChange = PyNULL()
const Commit = PyNULL()
const Tag = PyNULL()
const Progress = PyNULL()
const Checkpoint = PyNULL()
const FastExportParser = PyNULL()
const ProgressWriter = PyNULL()
const record_id_rename = PyNULL()
const GitUtils = PyNULL()
const FilteringOptions = PyNULL()

const _default_pytimezone = PyNULL()

function __init__()
    dir = only(readdir(artifact"git-filter-repo-py", join=true))
    pushfirst!(PyVector(pyimport("sys")."path"), dir)
    copy!(gfr, pyimport("git_filter_repo"))
    exported_asis = Symbol.(["Blob", "Reset", "FileChange", "Commit", "Tag", "Progress", "Checkpoint", "FastExportParser", "ProgressWriter", "record_id_rename", "GitUtils", "FilteringOptions"])
    for n in exported_asis
        copy!(getfield(GitFilterRepo, n), getproperty(gfr, n))
    end
    copy!(_default_pytimezone, gfr.FixedTimeZone(b"+0000"))
end

date_to_string(x::PyObject) = pybytes(gfr.date_to_string(x))
date_to_string(x::DateTime) = date_to_string(py"$x.replace(tzinfo=$_default_pytimezone)"o)

string_to_date(x::PyObject) = gfr.string_to_date(x)
string_to_date(x::String) = string_to_date(pybytes(x))

abstract type Callback end
kwarg_name(::T) where {T <: Callback} = replace(string(nameof(T)), r"[a-z][A-Z]" => s -> "$(s[1])_$(s[2])") |> lowercase |> Symbol

for op in (:Filename, :Message, :Name, :Email, :Refname, :Blob, :Commit, :Tag, :Reset, :Done)
    kwarg_name = Symbol(lowercase("$(op)_callback"))
    name = Symbol("$(op)Callback")
    @eval begin
        Base.@kwdef struct $name <: Callback
            f::Union{Nothing, Function} = nothing
        end

        kwarg_name(::$name) = $(QuoteNode(kwarg_name))
    end
end

RepoFilter(args::PyObject...; kwargs...) = gfr.RepoFilter(args...; kwargs...)
RepoFilter(cbs::Callback...; options=FilteringOptions.default_options()) = RepoFilter(options; map(cb -> kwarg_name(cb) => cb.f, cbs)...)
RepoFilter(func::Function, cb::Type{<:Callback}, cbs::Callback...; kwargs...) = RepoFilter(cb(func), cbs...; kwargs...)


function clone_process_push(func::Function; source::String, destination::String, force_push::Bool=false, y::Bool=false)
    force_arg = force_push ? `-f` : ``
    mktempdir() do dir
        cd(dir) do
            @info "Cloning" source dir
            run(`$git clone $source .`)
            @info "Processing"
            func()
            @info "Adding new remote" destination
            run(`$git remote add origin-new $destination`)
            @info "Doing push --dry-run"
            run(`$git push --dry-run $force_arg -u origin-new --all`)
            if !y
                r = Base.prompt("Confirm (y) that repo at $dir is ready to push to $destination")
                if r != "y"
                    @info "Cancelled" response=r
                    return
                end
            end
            @info "Pushing"
            run(`$git push $force_arg -u origin-new --all`)
        end
    end
end

end
