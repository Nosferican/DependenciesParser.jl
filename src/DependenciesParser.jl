"""
    DependenciesParser.jl

    This package provides a quick way to access dependency information
"""
module DependenciesParser
    using Pkg: TOML.parsefile, Types.VersionRange
    using Base.Iterators: flatten

    """
        NameRepoVerDeps

        Alias for NamedTuple struct used for name, repository, version, and dependencies.
    """
    const NameRepoVerDeps = NamedTuple{(:name, :repository, :version, :dependency),
                                       Tuple{String,String,VersionNumber,Vector{String}}}
    """
        parse_package(name::AbstractString,
                      julia::VersionNumber = VersionNumber(1))::NameRepoVerDeps

        Returns information for latest compatible release of the package
    """
    function parse_package(name::AbstractString, julia::VersionNumber = VersionNumber(1))
        dir = joinpath(homedir(), ".julia/registries/General", uppercase(name[1:1]), name)
        version = joinpath(dir, "Versions.toml") |>
            parsefile |>
            keys |>
            (k -> maximum(VersionNumber, k))
        compat = joinpath(dir, "Compat.toml") |>
            parsefile |>
            (x -> [ ((name = n,
                    version = VersionRange(v))
                    for (n, v) in v) for (k, v) ∈ x if version ∈ VersionRange(k) ] ) |>
            flatten |>
            collect |>
            sort!
        if julia ∈ compat[findfirst(x-> isequal("julia", x.name), compat)].version
            package = joinpath(dir, "Package.toml") |>
                parsefile |>
                (x -> (name = x["name"],
                       uuid = x["uuid"],
                       repo = replace(x["repo"], r"\.git$" => "")))
            return (name = package.name,
                    repository = package.repo,
                    version = version,
                    dependency = filter!(!isequal("julia"), getproperty.(compat, :name)))
        end
    end

    """
        alldeps(julia::VersionNumber = VersionNumber(1))::Vector{NameRepoVerDeps}

        Returns information for all installable packages for the selected julia version
    """
    function alldeps(julia::VersionNumber = VersionNumber(1))
        data = readdir.(joinpath.(homedir(), ".julia/registries/General", string.('A':'Z'))) |>
        flatten |>
        collect |>
        (x -> filter!(x -> ~any(x ∈ ["julia", ".DS_Store"]) , x)) |>
        (x -> mapreduce(x -> parse_package(x, julia), vcat, x)) |>
        (x -> filter!(x -> ~isa(x, Nothing), x)) |>
        (x -> convert(Vector{NamedTuple{(:name, :repository, :version, :dependency),
                                        Tuple{String,String,VersionNumber,Vector{String}}}},
                      x))
        while true
            Δ = length(data)
            filter!(x -> all(x -> x ∈ getproperty.(data, :name), x.dependency), data)
            Δ == length(data) && break
        end
        data
    end

    """
        dependencies(name::AbstractString,
                     direct::Bool = false,
                     data::VersionNumber = DependenciesParser.data)::Vector{String}

        Returns all dependencies for the package (excludes stdlib)
        When direct is true, only direct dependencies are returned
        Dependencies.data = alldeps()
    """
    function dependencies(name::AbstractString,
                          direct::Bool = false,
                          data::AbstractVector{<:NameRepoVerDeps} = DependenciesParser.data)
        everyname = getproperty.(data, :name)
        idx = findfirst(isequal(name), everyname)
        isa(idx, Nothing) && throw(ArgumentError(string(name, "is not found in the registry.")))
        visited = Vector{String}()
        tovisit = copy(@view data[idx].dependency[1:end - 1])
        while ~isempty(tovisit)
            current = pop!(tovisit)
            if current ∉ visited
                for dependency ∈ data[findfirst(isequal(current), everyname)].dependency
                    dependency ∉ visited && push!(tovisit, dependency)
                end
                push!(visited, current)
            end
        end
        if direct
            secondary = Vector{String}()
            foreach(dep -> union!(secondary, dependencies(dep)), visited)
            visited = setdiff(visited, secondary)
        end
        sort!(visited)
    end

    """
        const data = alldeps()
    """
    const data = Vector{NameRepoVerDeps}()

    __init__() = append!(data, alldeps())

    export alldeps, dependencies, NameRepoVerDeps
end
