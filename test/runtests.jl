using Test, DependenciesParser

using Base.Iterators: flatten

@testset "Basic test" begin
    data = DependenciesParser.data
    for pkg ∈ getproperty.(data, :name)
        everydeps = dependencies(pkg)
        @test dependencies(pkg, true) ⊆ everydeps
        @test everydeps ==
            sort!(union(everydeps, flatten(dependencies.(everydeps))))
    end
end
