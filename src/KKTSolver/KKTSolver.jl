module KKT

using LinearAlgebra

export AbstractKKTSolver

const BlasReal = LinearAlgebra.BlasReal

"""
    AbstractKKTSolver{Tv}

Abstract container for solving an augmented system
```
    [-(Θ⁻¹ + Rp)   Aᵀ] [dx] = [ξd]
    [   A          Rd] [dy]   [ξp]
```
where `ξd` and `ξp` are given right-hand side.
"""
abstract type AbstractKKTSolver{Tv<:Real} end


"""
    LinearSystem

Indicates which linear system is solved.
"""
abstract type LinearSystem end

"""
    DefaultSystem

Choose linear system to be solved using default option.
"""
struct DefaultSystem <: LinearSystem end

"""
    AugmentedSystem

Solve the augmented system, i.e., without reducing to normal equations.
"""
struct AugmentedSystem <: LinearSystem end

"""
    NormalEquations

Solve the normal equations system.
"""
struct NormalEquations <: LinearSystem end

"""
    LSBackend

Backend used for solving linear systems.
"""
abstract type LSBackend end

"""
    DefaultBackend

Chose linear solver backend automatically.

* For `A::Matrix{Tv}`, defaults to [`Lapack`](@ref) (i.e., dense solver).
* For `A::AbstractMatrix{Float64}`, defaults to [`Cholmod`](@ref)
* Otherwise, defaults to [`LDLFact`](@ref)
"""
struct DefaultBackend <: LSBackend end

# 
# Specialized implementations should extend the functions below
# 

"""
    update!(ls, θ, regP, regD)

Update internal data, and re-compute factorization/pre-conditioner.

After this call, `ls` can be used to solve the augmented system
```
    [-(Θ⁻¹ + Rp)   Aᵀ] [dx] = [ξd]
    [   A          Rd] [dy]   [ξp]
```
for given right-hand sides `ξd` and `ξp`.
"""
function update! end


"""
    solve!(dx, dy, ls, ξp, ξd)

Solve the symmetric quasi-definite augmented system
```
    [-(Θ⁻¹ + Rp)   Aᵀ] [dx] = [ξd]
    [   A          Rd] [dy]   [ξp]
```
and over-write `dx`, `dy` with the result.

# Arguments
- `dx, dy`: Vectors of unknowns, modified in-place
- `ls`: Linear solver for the augmented system
- `ξp, ξd`: Right-hand-side vectors
"""
function solve! end


include("test.jl")

# 
include("lapack.jl")
include("cholmod.jl")
include("ldlfact.jl")

# Default settings
AbstractKKTSolver(
    ::DefaultBackend,
    ::DefaultSystem,
    A::Matrix{Tv}
) where{Tv<:Real} = AbstractKKTSolver(Lapack(), NormalEquations(), A)

AbstractKKTSolver(
    ::DefaultBackend,
    ::DefaultSystem,
    A::AbstractMatrix{Float64}
) = AbstractKKTSolver(Cholmod(), AugmentedSystem(), A)

AbstractKKTSolver(
    ::DefaultBackend,
    ::DefaultSystem,
    A::AbstractMatrix{Tv}
) where{Tv<:Real} = AbstractKKTSolver(LDLFact(), AugmentedSystem(), A)

end  # module