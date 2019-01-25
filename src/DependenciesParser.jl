"""
    DependenciesParser.jl

    This package provides a quick way to access dependency information
"""
module DependenciesParser
    using Base.Iterators: flatten
    using Pkg: METADATA_compatible_uuid
    using Pkg.Operations: load_package_data_raw, deps_graph, simplify_graph!, resolve
    using Pkg.TOML: parsefile
    using Pkg.Types: Context, Fixed, Requires, stdlib, UUID, uuid_julia, VersionRange,
                     VersionSpec

    """
        All package names in the General registry
    """
    const data =
        readdir.(joinpath.(homedir(), ".julia/registries/General", string.('A':'Z'))) |>
        flatten |>
        collect |>
        (x -> filter!(x -> ~any(x ∈ ["julia", ".DS_Store"]), x))
    function find_repo(name)
        dir = joinpath(homedir(), ".julia/registries/General", uppercase(name[1:1]), name)
        toml = parsefile(joinpath(dir, "Package.toml"))
        repo = replace(toml["repo"], r"\.git$" => "")
        try
            request("GET", repo)
            true
        catch
            false
        end
    end
    # Identify deleted repositories
    # using HTTP: request
    # available = Vector{Bool}(undef, length(data))
    # @time for idx ∈ eachindex(available)
    #     println(idx)
    #     available[idx] = find_repo(data[idx])
    # end
    # Based on a cache solution from above on 2019-01-25
    """
        Packages that no longer exist (repositories have been deleted)
    """
    const deleted_repo =
        ["Arduino", "ChainRecursive", "Chunks", "CombinatorialBandits", "ControlCore",
         "DotOverloading", "DynamicalBilliardsPlotting", "GLUT", "GetC", "HTSLIB",
         "KeyedTables", "LazyCall", "LazyContext", "LazyQuery", "LibGit2", "NumberedLines",
         "OpenGL", "OrthogonalPolynomials", "Parts", "React", "RecurUnroll",
         "RequirementVersions", "SDL", "SessionHacker", "Sparrow", "StringArrays",
         "TypedBools", "ValuedTuples", "ZippedArrays"]
    filter!(pkg -> pkg ∉ deleted_repo, data)
    const deps = Dict{UUID,Dict{VersionRange,Dict{String,UUID}}}()
    const compat = Dict{UUID,Dict{VersionRange,Dict{String,VersionSpec}}}()
    const uuid_to_name = stdlib()
    uuid_to_name[uuid_julia] = "julia"
    const versions = Dict{UUID,Set{VersionNumber}}()
    for name ∈ data
        dir = joinpath(homedir(), ".julia/registries/General", uppercase(name[1:1]), name)
        uuid = UUID(parsefile(joinpath(dir, "Package.toml"))["uuid"])
        uuid_to_name[uuid] = name
        versions[uuid] = Set(VersionNumber.(keys(parsefile(joinpath(dir, "Versions.toml")))))
        deps[uuid] = load_package_data_raw(UUID, joinpath(dir, "Deps.toml"))
        compat[uuid] = load_package_data_raw(VersionSpec, joinpath(dir, "Compat.toml"))
    end
    """
        installable(pkg::AbstractString,
                    julia::VersionNumber = VERSION;
                    direct::Bool = false)::Tuple{Bool,Vector{String}}

        Return whether the package is installable and the dependencies for the solved version.
        If direct, only direct dependencies are returned.
    """
    function installable(pkg::AbstractString,
                         julia = VERSION::VersionNumber;
                         direct::Bool = false)
        uuid = METADATA_compatible_uuid(pkg)
        try
            graph = deps_graph(Context(),
                               uuid_to_name,
                               Requires(uuid => VersionSpec()),
                               Dict(uuid_julia => Fixed(julia)))
            simplify_graph!(graph)
            sol = get.(Ref(uuid_to_name),
                       filter(!isequal(uuid), keys(resolve(graph))),
                       nothing) |>
                  sort!
            if direct
                secondary = reduce((x,y) -> vcat(last(x), last(y)),
                                   installable.(sol)) |>
                            unique!
                sort!(filter!(dep -> dep ∉ secondary, sol))
            end
            return true, sol::Vector{String}
        catch
            return false, Vector{String}([pkg])
        end
    end
    # Code to get all installable packages
    # status = Vector{Tuple{Bool,Vector{String}}}()
    # @time for (idx, pkg) ∈ enumerate(data)
        # println(idx)
        # push!(status, installable(pkg))
    # end
    # data[first.(status)]
    # __init__() = append!(data, alldeps())
    export installable
end
